# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

# ---------------------------------------------------------------------------
# Timing / protocol constants
# ---------------------------------------------------------------------------
CLK_PERIOD_NS = 40

# Full raster timing from the VGA generator
H_MAX = 800
V_MAX = 525
FRAME_CYCLES = H_MAX * V_MAX

# ---------------------------------------------------------------------------
# Output decoding
#
# uo_out[7:0] = { hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1] }
#                  7      6      5      4      3      2      1      0
# ---------------------------------------------------------------------------
COLOR_MASK  = 0x77
GREEN_PIXEL = 0x22   # R=00 G=11 B=00
WHITE_PIXEL = 0x77   # R=11 G=11 B=11

# ---------------------------------------------------------------------------
# Gamepad button masks
#
# Bit order sent MSB→LSB: B Y Sel Start Up Down Left Right A X L R
# ---------------------------------------------------------------------------
BUTTON_A     = 1 << 3
BUTTON_START = 1 << 8


# ---------------------------------------------------------------------------
# Safe DUT output helpers
# ---------------------------------------------------------------------------

def safe_uo_out_int(dut):
    """
    Return integer value of uo_out if fully resolved (0/1 only),
    else return None. This is gate-level friendly.
    """
    s = str(dut.uo_out.value)
    if any(ch not in "01" for ch in s):
        return None
    return int(s, 2)


def get_vsync_safe(dut):
    val = safe_uo_out_int(dut)
    if val is None:
        return None
    return (val >> 3) & 0x1


def get_rgb_safe(dut):
    val = safe_uo_out_int(dut)
    if val is None:
        return None
    return val & COLOR_MASK


# ---------------------------------------------------------------------------
# Basic testbench helpers
# ---------------------------------------------------------------------------

async def do_reset(dut):
    """Start clock and perform a clean reset."""
    clock = Clock(dut.clk, CLK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 10)

    dut.rst_n.value = 1

    # Give gate-level logic time to settle
    await ClockCycles(dut.clk, 100)


async def send_gamepad(dut, buttons_12bit):
    """
    Simulate one SNES-style PMOD gamepad poll.

    ui_in[6] = data
    ui_in[5] = clock
    ui_in[4] = latch
    """
    DATA  = 1 << 6
    CLK   = 1 << 5
    LATCH = 1 << 4

    for i in range(11, -1, -1):
        bit_val = (buttons_12bit >> i) & 1
        cur = DATA if bit_val else 0

        dut.ui_in.value = cur
        await ClockCycles(dut.clk, 3)

        dut.ui_in.value = cur | CLK
        await ClockCycles(dut.clk, 2)

        dut.ui_in.value = cur
        await ClockCycles(dut.clk, 2)

    dut.ui_in.value = LATCH
    await ClockCycles(dut.clk, 3)
    dut.ui_in.value = 0


async def press_button_once(dut, button_mask, settle_lines=4):
    """
    Send one controller packet with the requested button asserted,
    then idle the bus for a few scanlines so the DUT can consume it.
    """
    await send_gamepad(dut, button_mask)
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, H_MAX * settle_lines)


async def wait_for_vsync_rising_from_uo(dut):
    """
    Wait for a rising edge on the VSYNC bit carried in uo_out[3].
    Skip unresolved gate-level samples containing X/Z.
    """
    prev = None

    while True:
        await RisingEdge(dut.clk)
        cur = get_vsync_safe(dut)
        if cur is None:
            continue

        if prev is not None and prev == 0 and cur == 1:
            return

        prev = cur


async def find_color_on_screen(dut, color, frames=1):
    """
    Scan one or more full frames for a specific color anywhere on screen.
    This is robust for gate-level because it does not reconstruct x/y
    from internal signals or tight timing assumptions.
    """
    for frame_idx in range(frames):
        await wait_for_vsync_rising_from_uo(dut)

        for _ in range(FRAME_CYCLES):
            await RisingEdge(dut.clk)

            rgb = get_rgb_safe(dut)
            if rgb is None:
                continue

            if rgb == color:
                val = safe_uo_out_int(dut)
                dut._log.info(
                    f"Found color 0x{color:02x} during frame {frame_idx}, "
                    f"uo_out=0x{val:02x}"
                )
                return True

    return False


async def wait_frames(dut, nframes):
    """Wait for an integer number of full raster frames."""
    await ClockCycles(dut.clk, FRAME_CYCLES * nframes)


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_press_start_then_green_crosshair_visible(dut):
    """
    Game starts in banner mode. Press START, wait a short moment,
    then confirm that at least one green pixel appears somewhere on screen.

    This is intentionally broad and gate-level robust:
    the crosshair is expected to be the persistent green element after START.
    """
    dut._log.info("TEST: press START, then confirm a green crosshair pixel appears")
    await do_reset(dut)

    # Let reset/banner mode stabilize briefly
    await wait_frames(dut, 1)

    # Start the game
    await press_button_once(dut, BUTTON_START, settle_lines=6)

    # Give the design a little time to leave banner mode and render gameplay
    await wait_frames(dut, 1)

    found = await find_color_on_screen(dut, GREEN_PIXEL, frames=2)

    assert found, "No green pixels found anywhere on screen after pressing START"
    dut._log.info("PASS: green crosshair pixel confirmed after START")


#@cocotb.test()
#async def test_press_start_then_a_then_white_explosion_visible(dut):
#    """
#    Start the game, press A, wait for the explosion animation to reach
#    a visible phase, then confirm that at least one white pixel appears
#    somewhere on screen.
#
#    This stays broad on purpose so it remains robust under gate-level timing.
#    """
#    dut._log.info("TEST: press START, then A, then confirm a white explosion pixel appears")
#    await do_reset(dut)
#
#    # Stabilize after reset
#    await wait_frames(dut, 1)
#
#    # Start the game
#    await press_button_once(dut, BUTTON_START, settle_lines=6)
#
#    # Let gameplay render for a frame
#    await wait_frames(dut, 1)
#
#    # Fire the explosion
#    await press_button_once(dut, BUTTON_A, settle_lines=6)
#
#    # Wait for the explosion animation to develop.
#    # The original test waited for 2 * FRAMES_DELAY * H_MAX clocks.
#    # Keep the same intent but expressed in scanlines:
#    FRAMES_DELAY_HSYNC = 0x0960
#    await ClockCycles(dut.clk, 2 * FRAMES_DELAY_HSYNC * H_MAX)
#
#    found = await find_color_on_screen(dut, WHITE_PIXEL, frames=3)
#
#    assert found, "No white pixels found anywhere on screen after pressing A"
#    dut._log.info("PASS: white explosion pixel confirmed after A")
