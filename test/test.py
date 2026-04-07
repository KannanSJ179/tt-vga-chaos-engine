# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

# ---------------------------------------------------------------------------
# VGA timing (640×480)
# ---------------------------------------------------------------------------
H_MAX = 800
V_MAX = 525
V_TOP = 33

# ---------------------------------------------------------------------------
# Color decoding
#
# uo_out[7:0] = { hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1] }
#                  7      6      5      4      3      2      1      0
# ---------------------------------------------------------------------------
COLOR_MASK  = 0x77
GREEN_PIXEL = 0x22
WHITE_PIXEL = 0x77

# ---------------------------------------------------------------------------
# Gamepad masks
# ---------------------------------------------------------------------------
BUTTON_A     = 1 << 3
BUTTON_START = 1 << 8


def get_hsync(uo_out_val: int) -> int:
    return (uo_out_val >> 7) & 0x1


def get_vsync(uo_out_val: int) -> int:
    return (uo_out_val >> 3) & 0x1


def get_rgb(uo_out_val: int) -> int:
    return uo_out_val & COLOR_MASK


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


async def wait_for_vsync_rising_from_uo(dut):
    """
    Wait for a rising edge on the VSYNC bit carried in uo_out[3].
    Gate-level safe because it uses only top-level outputs.
    """
    prev = get_vsync(int(dut.uo_out.value))

    while True:
        await RisingEdge(dut.clk)
        cur = get_vsync(int(dut.uo_out.value))
        if prev == 0 and cur == 1:
            return
        prev = cur


async def find_color_in_region(dut, y_start, y_end, x_start, x_end, color):
    """
    Gate-level-safe scan:
    - synchronise to next frame using VSYNC from uo_out[3]
    - reconstruct raster position by counting clk cycles
    - search only inside the requested window
    """
    await wait_for_vsync_rising_from_uo(dut)

    # Same timing assumption your original test used:
    # after vsync rising, skip top blanking plus lines before the region.
    early = 5
    skip_cycles = (V_TOP + y_start) * H_MAX - early
    if skip_cycles > 0:
        await ClockCycles(dut.clk, skip_cycles)

    scan_rows = y_end - y_start + 3
    total_scan_cycles = scan_rows * H_MAX

    # We are 'early' cycles before the nominal first pixel of row y_start
    frame_cycles = (V_TOP + y_start) * H_MAX - early

    for _ in range(total_scan_cycles):
        await RisingEdge(dut.clk)
        frame_cycles += 1

        px = frame_cycles % H_MAX
        py = (frame_cycles // H_MAX) - V_TOP

        if y_start <= py <= y_end and x_start <= px <= x_end:
            rgb = get_rgb(int(dut.uo_out.value))
            if rgb == color:
                dut._log.info(
                    f"Found color 0x{color:02x} at approx ({px}, {py}), "
                    f"uo_out=0x{int(dut.uo_out.value):02x}"
                )
                return True

        if py > y_end + 1:
            break

    return False


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_press_start_banner_then_crosshair_green(dut):
    """
    Game now starts in idle/banner mode with impacts == 0.
    So first press START, then verify the green crosshair appears
    around the center once the game becomes active.
    """
    dut._log.info("TEST: press START, then confirm green crosshair")
    await do_reset(dut)

    # Start game
    await ClockCycles(dut.clk, H_MAX * 2)
    await send_gamepad(dut, BUTTON_START)
    await ClockCycles(dut.clk, H_MAX * 4)

    found = await find_color_in_region(
        dut,
        y_start=231, y_end=250,
        x_start=311, x_end=330,
        color=GREEN_PIXEL,
    )

    assert found, (
        "No green crosshair pixels found in the 20x20 region around "
        "the center after pressing START"
    )
    dut._log.info("PASS: green crosshair confirmed after START")


@cocotb.test()
async def test_explosion_white_on_button_a(dut):
    """
    Start the game, then press A and confirm that white explosion pixels appear
    near the crosshair region.
    """
    dut._log.info("TEST: white explosion pixels after pressing START and A")
    await do_reset(dut)

    # Leave idle/banner mode first
    await ClockCycles(dut.clk, H_MAX * 2)
    await send_gamepad(dut, BUTTON_START)
    await ClockCycles(dut.clk, H_MAX * 4)

    # Ensure inp_a_prev settles low first
    await ClockCycles(dut.clk, H_MAX * 2)

    # Press A
    dut._log.info("Pressing button A...")
    await send_gamepad(dut, BUTTON_A)

    # Let fire_pulse be seen by the game logic
    await ClockCycles(dut.clk, H_MAX * 3)
    dut.ui_in.value = 0

    # Wait for explosion animation to develop
    FRAMES_DELAY = 0x0960
    await ClockCycles(dut.clk, 2 * FRAMES_DELAY * H_MAX)

    found = await find_color_in_region(
        dut,
        y_start=228, y_end=252,
        x_start=308, x_end=332,
        color=WHITE_PIXEL,
    )

    assert found, (
        "No white explosion pixels found in the 24x24 region around "
        "(320, 240) after pressing A"
    )
    dut._log.info("PASS: white explosion pixels confirmed after button A")
