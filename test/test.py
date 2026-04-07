# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

# ---------------------------------------------------------------------------
# VGA timing (640×480)
# ---------------------------------------------------------------------------
H_MAX = 800   # total horizontal cycles per line (active + blanking)
V_MAX = 525   # total vertical lines per frame   (active + blanking)
V_TOP = 33    # top-border blanking lines that follow the vsync pulse

# ---------------------------------------------------------------------------
# Color decoding
#
# uo_out[7:0] = { hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1] }
#                  7      6      5      4      3      2      1      0
#
# To extract RGB independently of sync bits, mask with 0x77.
# ---------------------------------------------------------------------------
COLOR_MASK  = 0x77   # ignore hsync (bit 7) and vsync (bit 3)
GREEN_PIXEL = 0x22   # R=00, G=11, B=00  →  bits 1,5 set
WHITE_PIXEL = 0x77   # R=11, G=11, B=11  →  all six color bits set

# ---------------------------------------------------------------------------
# Gamepad button masks (12-bit word sent by the PMOD adapter)
#
# Bit order sent MSB→LSB:  B Y Sel Start Up Down Left Right A X L R
# Bit positions:           11 10  9    8   7   6    5     4  3 2 1 0
#
# In this design the decoder maps the bit directly to the button signal,
# so 1 = pressed (active-high from the decoder's perspective).
# If real hardware uses active-low SNES signalling the PMOD may invert;
# adjust BUTTON_* masks if running against real hardware.
# ---------------------------------------------------------------------------
BUTTON_A = 1 << 3


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

async def do_reset(dut):
    """Start clock and perform a clean reset."""
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())
    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value  = 1


async def send_gamepad(dut, buttons_12bit):
    """
    Simulate one SNES gamepad poll from the PMOD adapter.

    The adapter drives three lines back to the chip:
        ui_in[6]  pmod_data   – one serial data bit per clock
        ui_in[5]  pmod_clk    – shift clock (rising edge latches data)
        ui_in[4]  pmod_latch  – rising edge transfers shift_reg → data_reg

    We clock in 12 bits MSB-first (B button first), then pulse latch.
    The driver has a 2-stage synchroniser, so data must be stable at least
    2 cycles before the clock rising edge.
    """
    DATA  = 1 << 6
    CLK   = 1 << 5
    LATCH = 1 << 4

    for i in range(11, -1, -1):           # MSB (B) first
        bit_val = (buttons_12bit >> i) & 1
        cur = DATA if bit_val else 0      # data line; clk=0, latch=0
        dut.ui_in.value = cur
        await ClockCycles(dut.clk, 3)    # settle through 2-stage sync
        dut.ui_in.value = cur | CLK      # rising clock edge
        await ClockCycles(dut.clk, 2)
        dut.ui_in.value = cur            # falling clock edge
        await ClockCycles(dut.clk, 2)

    # Latch: commit shift_reg → data_reg
    dut.ui_in.value = LATCH
    await ClockCycles(dut.clk, 3)
    dut.ui_in.value = 0


async def find_color_in_region(dut, y_start, y_end, x_start, x_end, color):
    """
    Wait for the next vsync, then scan rows [y_start, y_end] for a pixel
    whose (uo_out & COLOR_MASK) equals `color` with x in [x_start, x_end].

    Strategy: use fast ClockCycles() to skip to just before the region,
    then do per-cycle sampling only for the rows we care about.  This
    keeps the slow Python loop short (typically < 25 000 iterations).

    Returns True as soon as a matching pixel is found, False if the
    entire scan window passes without a match.
    """
    proj = dut.user_project

    # Wait for vsync rising edge (end of the 2-line sync pulse,
    # vpos transitions from 491 → 492).
    await RisingEdge(proj.vsync)

    # Fast-forward: skip the 33 top-border lines and all rows before y_start.
    # We arrive a few cycles early to absorb any sub-line offset in vsync timing.
    early = 5
    await ClockCycles(dut.clk, (V_TOP + y_start) * H_MAX - early)

    # Per-cycle scan of [y_start, y_end] (plus a small guard at either end).
    scan_rows = y_end - y_start + 3
    for _ in range(scan_rows * H_MAX):
        await RisingEdge(dut.clk)
        px = int(proj.pix_x.value)
        py = int(proj.pix_y.value)
        if y_start <= py <= y_end and x_start <= px <= x_end:
            if (int(dut.uo_out.value) & COLOR_MASK) == color:
                dut._log.info(f"  Found color 0x{color:02x} at ({px}, {py})  "
                              f"uo_out=0x{int(dut.uo_out.value):02x}")
                return True
        if py > y_end + 1:   # past the window — bail out early
            break
    return False


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_crosshair_green_after_reset(dut):
    """
    After reset the crosshair initialises at (320, 240) with colour GREEN.

    The sprite is 10×10 pixels.  The horizontal bar (rows 8-9 of the bitmap,
    all 10 columns active) falls in y ∈ [239, 240] and y ∈ [241, 242] and
    spans x ∈ [311, 330].  We scan the full 20×20 bounding box and expect
    at least one green pixel.
    """
    dut._log.info("TEST: green crosshair pixels visible after reset")
    await do_reset(dut)

    found = await find_color_in_region(
        dut,
        y_start=231, y_end=250,
        x_start=311, x_end=330,
        color=GREEN_PIXEL,
    )

    assert found, (
        "No green (R=00 G=11 B=00) pixels found in the 20×20 region around "
        "crosshair centre (320, 240) after reset"
    )
    dut._log.info("PASS: green crosshair confirmed at screen centre")


@cocotb.test()
async def test_explosion_white_on_button_a(dut):
    """
    Pressing button A fires an explosion centred on the crosshair (320, 240).
    The explosion sprite is 24×24.  We wait two explosion-frame intervals
    (2 × FRAMES_DELAY = 4800 hsync periods) so the animation has grown past
    its initial tiny dot into a clearly visible circle, then check for white
    pixels inside the 24×24 bounding box (x ∈ [308, 332], y ∈ [228, 252]).

    The crosshair (10×10) sits on top and may mask some pixels with green;
    the outer arc of the explosion circle is still outside the crosshair area
    and should show white.
    """
    dut._log.info("TEST: white explosion pixels after pressing button A")
    await do_reset(dut)

    proj = dut.user_project

    # Let the game logic run through at least one hsync after reset so that
    # inp_a_prev is definitely 0 (necessary for the rising-edge detector).
    await ClockCycles(dut.clk, H_MAX * 2)

    # --- Press button A ---
    dut._log.info("  Pressing button A…")
    await send_gamepad(dut, BUTTON_A)

    # Give the game logic time to see the rising edge of inp_a on the next
    # hsync and set fire_pulse.  Three hsyncs is more than enough.
    await ClockCycles(dut.clk, H_MAX * 3)

    # Release all buttons (no further input).
    dut.ui_in.value = 0

    # --- Wait for the explosion animation to grow ---
    # explosion.v: FRAMES_DELAY = 0x0960 = 2400 hsync periods per frame.
    # After 2 × 2400 hsyncs the sprite is at animation frame 2
    # ("Larger circle, rows 13-23"), clearly larger than the initial 4-pixel dot.
    FRAMES_DELAY = 0x0960   # matches localparam in explossion.v
    await ClockCycles(dut.clk, 2 * FRAMES_DELAY * H_MAX)

    # --- Scan for white pixels in the explosion bounding box ---
    found = await find_color_in_region(
        dut,
        y_start=228, y_end=252,
        x_start=308, x_end=332,
        color=WHITE_PIXEL,
    )

    assert found, (
        "No white (R=11 G=11 B=11) pixels found in the 24×24 explosion region "
        "around (320, 240) after pressing button A"
    )
    dut._log.info("PASS: white explosion pixels confirmed after button A")
