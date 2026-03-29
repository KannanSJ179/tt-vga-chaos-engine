import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, ClockCycles

@cocotb.test()
async def test_cordic_engine(dut):
    """Test the CORDIC Engine (Deterministic GLS with Extended Wait & Logging)."""
    
    dut._log.info("Starting CORDIC Integration Test")

    # Set initial states
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    
    # 10 MHz clock
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    # Deep Reset
    dut._log.info("Applying Reset")
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    await FallingEdge(dut.clk)  
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    # --- Test 30 Degrees (16'h4305) ---
    dut._log.info("Sending 30 Degree Input (0x4305)")
    
    await FallingEdge(dut.clk)
    dut.uio_in.value = 0 

    # Cycle 1: Send MSB (0x43) and Start = 1
    await FallingEdge(dut.clk)
    dut.ui_in.value = 0x43
    dut.uio_in.value = 1  
    
    # Cycle 2: Hold start for safety in GLS
    await FallingEdge(dut.clk)

    # Cycle 3: Send LSB (0x05) and clear Start
    await FallingEdge(dut.clk)
    dut.ui_in.value = 0x05
    dut.uio_in.value = 0  

    # --- OPTION 1: INCREASED DETERMINISTIC WAIT ---
    dut._log.info("Waiting deterministically for 50 cycles to ensure stability...")
    await ClockCycles(dut.clk, 50)

    # Read Sine Output safely
    await FallingEdge(dut.clk)
    uo_out_val = dut.uo_out.value
    
    # --- OPTION 3: IMPROVED ERROR HANDLING ---
    try:
        sin_result = int(uo_out_val)
    except ValueError:
        dut._log.error(f"GLS ERROR: 'uo_out' contains invalid X/Z states: {uo_out_val.binstr}")
        sin_result = -1 

    dut._log.info(f"Computation Done! Sine Result: {sin_result} (Expected: ~64)")
    
    # Toggle Multiplexer to read Cosine
    dut._log.info("Toggling out_sel to read Cosine")
    await FallingEdge(dut.clk)
    dut.uio_in.value = 2  
    
    # Wait for physical propagation (extended to 5 cycles for safety)
    await ClockCycles(dut.clk, 5)
    await FallingEdge(dut.clk)
    
    uo_out_val_cos = dut.uo_out.value
    try:
        cos_result = int(uo_out_val_cos)
    except ValueError:
        dut._log.error(f"GLS ERROR: 'uo_out' contains invalid X/Z states: {uo_out_val_cos.binstr}")
        cos_result = -1

    dut._log.info(f"Cosine Result: {cos_result} (Expected: ~111)")

    # Assertions
    assert 63 <= sin_result <= 65, f"Sine output {sin_result} is out of bounds!"
    assert 110 <= cos_result <= 112, f"Cosine output {cos_result} is out of bounds!"
    
    dut._log.info("Tiny Tapeout CORDIC Test Passed Successfully!")
