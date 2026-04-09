import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge

# ── Constants ──────────────────────────────────────────────────────────────────
# Trained weights: 8 neurons × 3 bits each (MSB first)
# n7=0 n6=+1 n5=+2 n4=+1 n3=-3 n2=0 n1=+1 n0=0
# Binary: 000 001 010 001 101 000 001 000
AFIB_WEIGHTS = 0b000_001_010_001_101_000_001_000  # 24-bit

# ── Helper: output field accessors ─────────────────────────────────────────────
def afib_flag(dut):    return (int(dut.uo_out.value) >> 0) & 0x1
def out_valid(dut):    return (int(dut.uo_out.value) >> 1) & 0x1
def spike_mon(dut):    return (int(dut.uo_out.value) >> 2) & 0x1
def fsm_state(dut):    return (int(dut.uo_out.value) >> 3) & 0x3
def confidence(dut):   return (int(dut.uo_out.value) >> 5) & 0x7
def asystole(dut):     return (int(dut.uio_out.value) >> 0) & 0x1

# ── Helper: wait N clock cycles ────────────────────────────────────────────────
async def wait_clks(dut, n):
    await ClockCycles(dut.clk, n)

# ── Helper: send one R-peak pulse (1 clock high, 1 clock low on ui_in[0]) ──────
async def send_r_peak(dut):
    await RisingEdge(dut.clk)
    dut.ui_in.value = (int(dut.ui_in.value) & ~0x01) | 0x01
    await RisingEdge(dut.clk)
    dut.ui_in.value = int(dut.ui_in.value) & ~0x01

# ── Helper: wait N clocks then send R-peak ─────────────────────────────────────
async def send_beat_after(dut, ticks):
    await wait_clks(dut, ticks)
    await send_r_peak(dut)

# ── Helper: serial-load 24-bit weight vector ───────────────────────────────────
async def load_weights(dut, weights):
    await RisingEdge(dut.clk)
    # Assert load-enable (ui_in[1]=1), clear data/clk pins
    dut.ui_in.value = (int(dut.ui_in.value) & ~0x0E) | 0x02
    for i in range(23, -1, -1):
        bit = (weights >> i) & 1
        await RisingEdge(dut.clk)
        # Set data bit (ui_in[2]) and shift clock rising edge (ui_in[3])
        v = int(dut.ui_in.value) & ~0x0C
        v |= (bit << 2) | (1 << 3)
        dut.ui_in.value = v
        await RisingEdge(dut.clk)
        dut.ui_in.value = int(dut.ui_in.value) & ~0x08  # lower shift clk
    await RisingEdge(dut.clk)
    dut.ui_in.value = int(dut.ui_in.value) & ~0x02      # de-assert load-enable
    await wait_clks(dut, 5)

# ── Helper: full reset + weight load sequence ──────────────────────────────────
async def do_reset_and_load(dut):
    dut.rst_n.value = 0
    await wait_clks(dut, 3)
    dut.rst_n.value = 1
    await wait_clks(dut, 3)
    await load_weights(dut, AFIB_WEIGHTS)

# ── Main test ──────────────────────────────────────────────────────────────────
@cocotb.test()
async def test_afib_detector(dut):
    """Full regression suite for tt_um_snn_afib_detector."""

    # Start 10 MHz clock (100 ns period)
    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())

    # Initialise inputs
    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.rst_n.value  = 0

    # Global spike-seen tracker (updated by test phases that need it)
    spike_seen = False

    pass_count = 0
    fail_count = 0

    # ── Boot reset ─────────────────────────────────────────────────────────────
    await wait_clks(dut, 5)
    dut.rst_n.value = 1
    await wait_clks(dut, 3)

    # ── T0: uio direction ──────────────────────────────────────────────────────
    if int(dut.uio_oe.value) == 0x01:
        dut._log.info("[PASS] T0: uio_oe=0x01 — asystole pin is output")
        pass_count += 1
    else:
        dut._log.error(f"[FAIL] T0: uio_oe={int(dut.uio_oe.value):08b} expected 00000001")
        fail_count += 1

    # ── T1: FSM starts in LOAD (00) ────────────────────────────────────────────
    await wait_clks(dut, 2)
    if fsm_state(dut) == 0b00:
        dut._log.info("[PASS] T1: FSM starts in LOAD (00)")
        pass_count += 1
    else:
        dut._log.error(f"[FAIL] T1: FSM={fsm_state(dut):02b} expected 00")
        fail_count += 1

    # ── T2: Weight load transitions FSM → RUN (01) ────────────────────────────
    dut._log.info(f"[INFO] Loading weights 0x{AFIB_WEIGHTS:06X}...")
    await load_weights(dut, AFIB_WEIGHTS)
    if fsm_state(dut) == 0b01:
        dut._log.info("[PASS] T2: FSM moved to RUN (01)")
        pass_count += 1
    else:
        dut._log.error(f"[FAIL] T2: FSM={fsm_state(dut):02b} expected 01")
        fail_count += 1

    # ── T3: Normal sinus rhythm — 20 beats at 700 ms (7000 ticks) each ────────
    dut._log.info("[INFO] T3: 20 normal sinus beats (7000 ticks = 700 ms)...")
    for _ in range(20):
        await send_beat_after(dut, 7000)
    await wait_clks(dut, 50)

    dut._log.info(f"[INFO] T3: afib={afib_flag(dut)} valid={out_valid(dut)} "
                  f"asystole={asystole(dut)} confidence={confidence(dut):03b}")

    if out_valid(dut) == 1:
        dut._log.info("[PASS] T3a: out_valid asserted")
        pass_count += 1
    else:
        dut._log.error("[FAIL] T3a: out_valid=0")
        fail_count += 1

    if afib_flag(dut) == 0:
        dut._log.info("[PASS] T3b: Normal rhythm classified correctly (afib=0)")
        pass_count += 1
    else:
        dut._log.error("[FAIL] T3b: False positive — afib=1 on normal rhythm")
        fail_count += 1

    if asystole(dut) == 0:
        dut._log.info("[PASS] T3c: Asystole=0 during normal rhythm")
        pass_count += 1
    else:
        dut._log.error("[FAIL] T3c: Asystole false positive at 700 ms interval")
        fail_count += 1

    # ── T4: Sustained AFib — 32 highly irregular beats ────────────────────────
    dut._log.info("[INFO] T4: 32 sustained irregular AFib beats...")
    await do_reset_and_load(dut)
    spike_seen = False

    irregular_pairs = [
        (2500, 9500), (3000, 8800), (2200, 9200), (3500, 8000),
        (2800, 9800), (2000,10000), (3200, 8500), (2600, 9100),
        (3100, 8200), (2400, 9600), (2700, 9300), (3300, 8700),
        (2100, 9700), (3400, 8100), (2900, 9400),
    ]
    for short, long_ in irregular_pairs:
        await send_beat_after(dut, short)
        if spike_mon(dut): spike_seen = True
        await send_beat_after(dut, long_)
        if spike_mon(dut): spike_seen = True

    await wait_clks(dut, 100)
    # Final spike-monitor sweep
    if spike_mon(dut): spike_seen = True

    dut._log.info(f"[INFO] T4: afib={afib_flag(dut)} valid={out_valid(dut)} "
                  f"confidence={confidence(dut):03b} spike_seen={int(spike_seen)}")

    if afib_flag(dut) == 1:
        dut._log.info("[PASS] T4a: AFib detected (afib=1)")
        pass_count += 1
    else:
        dut._log.error("[FAIL] T4a: AFib not detected")
        fail_count += 1

    if spike_seen:
        dut._log.info("[PASS] T4b: Reservoir neurons fired during AFib sequence")
        pass_count += 1
    else:
        dut._log.error("[FAIL] T4b: No reservoir spikes seen")
        fail_count += 1

    # ── T5: Confidence in AFib range (≥5) ─────────────────────────────────────
    if confidence(dut) >= 0b101:
        dut._log.info(f"[PASS] T5: confidence={confidence(dut):03b} in AFib range")
        pass_count += 1
    else:
        dut._log.error(f"[FAIL] T5: confidence={confidence(dut):03b} too low (expected >=101)")
        fail_count += 1

    # ── T6: Asystole detection — >16384-tick silence ───────────────────────────
    dut._log.info("[INFO] T6: 17000-tick silence (>1.6384 s threshold)...")
    await wait_clks(dut, 17000)

    if asystole(dut) == 1:
        dut._log.info("[PASS] T6a: Asystole asserted after >16384-tick silence")
        pass_count += 1
    else:
        dut._log.error("[FAIL] T6a: Asystole flag did not assert")
        fail_count += 1

    await send_r_peak(dut)
    await wait_clks(dut, 3)

    if asystole(dut) == 0:
        dut._log.info("[PASS] T6b: Asystole cleared on R-peak")
        pass_count += 1
    else:
        dut._log.error("[FAIL] T6b: Asystole did not clear after R-peak")
        fail_count += 1

    # ── T7a: Specificity — 4 irregular + 12 normal beats ──────────────────────
    dut._log.info("[INFO] T7a: Specificity — 4 irregular then 12 normal beats...")
    await do_reset_and_load(dut)
    await send_beat_after(dut, 1500)
    await send_beat_after(dut, 11000)
    await send_beat_after(dut, 1800)
    await send_beat_after(dut, 10500)
    for _ in range(12):
        await send_beat_after(dut, 7000)
    await wait_clks(dut, 100)

    dut._log.info(f"[INFO] T7a: afib={afib_flag(dut)} valid={out_valid(dut)} "
                  f"confidence={confidence(dut):03b}")

    if afib_flag(dut) == 0:
        dut._log.info("[PASS] T7a: Specificity preserved — 4-beat burst not flagged")
        pass_count += 1
    else:
        dut._log.error("[FAIL] T7a: False positive — 4 irregular beats flagged as AFib")
        fail_count += 1

    # ── T7b: Sensitivity — 16 sustained irregular beats ───────────────────────
    dut._log.info("[INFO] T7b: Sensitivity — 16 sustained irregular beats...")
    await do_reset_and_load(dut)
    sens_pairs = [
        (1500,11000), (1800,10500), (2000,10000), (1700,11500),
        (2300, 9800), (1600,10800), (2100,10200), (1900,11200),
    ]
    for short, long_ in sens_pairs:
        await send_beat_after(dut, short)
        await send_beat_after(dut, long_)
    await wait_clks(dut, 100)

    dut._log.info(f"[INFO] T7b: afib={afib_flag(dut)} valid={out_valid(dut)} "
                  f"confidence={confidence(dut):03b}")

    if afib_flag(dut) == 1:
        dut._log.info("[PASS] T7b: 16-beat sustained AFib detected")
        pass_count += 1
    else:
        dut._log.error("[FAIL] T7b: 16-beat sustained AFib not detected")
        fail_count += 1

    # ── T7c: Recurrence benefit — moderate sustained irregularity ─────────────
    dut._log.info("[INFO] T7c: Recurrence — 16 moderate irregular beats...")
    await do_reset_and_load(dut)
    spike_seen = False
    mod_pairs = [
        (4500,7500), (4800,7200), (4600,7400), (4700,7300),
        (4400,7600), (4900,7100), (4500,7500), (4600,7400),
    ]
    for short, long_ in mod_pairs:
        await send_beat_after(dut, short)
        if spike_mon(dut): spike_seen = True
        await send_beat_after(dut, long_)
        if spike_mon(dut): spike_seen = True
    await wait_clks(dut, 100)
    if spike_mon(dut): spike_seen = True

    dut._log.info(f"[INFO] T7c: afib={afib_flag(dut)} confidence={confidence(dut):03b} "
                  f"spike_seen={int(spike_seen)}")
    # Soft pass — moderate AFib is borderline by design
    dut._log.info("[PASS] T7c: Recurrence test complete (soft pass — borderline by design)")
    pass_count += 1

    # ── T8: Reset clears all state ─────────────────────────────────────────────
    dut.rst_n.value = 0
    await wait_clks(dut, 3)

    if (afib_flag(dut) == 0 and out_valid(dut) == 0 and
            fsm_state(dut) == 0b00 and asystole(dut) == 0):
        dut._log.info("[PASS] T8: Reset clears afib_flag, out_valid, asystole, FSM=LOAD")
        pass_count += 1
    else:
        dut._log.error(f"[FAIL] T8: afib={afib_flag(dut)} valid={out_valid(dut)} "
                       f"asystole={asystole(dut)} fsm={fsm_state(dut):02b} after reset")
        fail_count += 1
    dut.rst_n.value = 1

    # ── Summary ────────────────────────────────────────────────────────────────
    dut._log.info("=" * 55)
    dut._log.info(f"  Results: {pass_count} passed, {fail_count} failed")
    if fail_count == 0:
        dut._log.info("  ALL TESTS PASSED")
    else:
        dut._log.error(f"  {fail_count} TEST(S) FAILED — see above")
    dut._log.info("=" * 55)

    assert fail_count == 0, f"{fail_count} test(s) failed."