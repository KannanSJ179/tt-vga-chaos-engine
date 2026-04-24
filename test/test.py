import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_vga_engine(dut):
    """Basic smoke test for VGA engine"""

    clock = Clock(dut.clk, 40, "ns")   # ✅ FIXED
    cocotb.start_soon(clock.start())

    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.ena.value    = 1
    dut.rst_n.value  = 0

    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    await ClockCycles(dut.clk, 500)

    dut._log.info(
        f"PASS: uo_out={dut.uo_out.value} "
        f"uio_out={dut.uio_out.value} "
        f"uio_oe={dut.uio_oe.value}"
    )
