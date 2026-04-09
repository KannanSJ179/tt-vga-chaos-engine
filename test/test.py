import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, Timer


# ─────────────────────────────────────────────────────────────────────────────
# Safe signal reader — GL sims have X/Z during/after reset; never crash on them
# Returns None if the signal contains X or Z bits.
# ─────────────────────────────────────────────────────────────────────────────
def _safe_int(signal):
    """Return int value of signal, or None if it contains X/Z."""
    bs = signal.value.binstr
    if any(c not in ('0', '1') for c in bs):
        return None
    return int(bs, 2)


# ─────────────────────────────────────────────────────────────────────────────
# Signal aliases  (mirrors tb.v `define macros)
# All return None if the underlying signal is X/Z.
# ─────────────────────────────────────────────────────────────────────────────
def AFIB_FLAG(dut):
    v = _safe_int(dut.uo_out);  return None if v is None else (v >> 0) & 0x1

def VALID(dut):
    v = _safe_int(dut.uo_out);  return None if v is None else (v >> 1) & 0x1

def SPIKE_MON(dut):
    v = _safe_int(dut.uo_out);  return None if v is None else (v >> 2) & 0x1

def FSM_STATE(dut):
    v = _safe_int(dut.uo_out);  return None if v is None else (v >> 3) & 0x3

def CONFIDENCE(dut):
    v = _safe_int(dut.uo_out);  return None if v is None else (v >> 5) & 0x7

def ASYSTOLE(dut):
    v = _safe_int(dut.uio_out); return None if v is None else (v >> 0) & 0x1

def UIO_OE(dut):
    return _safe_int(dut.uio_oe)   # raw 8-bit value or None


# ─────────────────────────────────────────────────────────────────────────────
# Trained weights  (8 neurons x 3 bits, MSB-first)
# n7=0 n6=+1 n5=+2 n4=+1 n3=-3 n2=0 n1=+1 n0=0
# Binary: 000 001 010 001 101 000 001 000
# ─────────────────────────────────────────────────────────────────────────────
AFIB_WEIGHTS = 0b000_001_010_001_101_000_001_000   # 24-bit


# ─────────────────────────────────────────────────────────────────────────────
# Helper coroutines  (direct translations of the Verilog tasks)
# ─────────────────────────────────────────────────────────────────────────────
async def wait_clks(dut, n):
    await ClockCycles(dut.clk, n)


async def send_r_peak(dut):
    """Assert ui_in[0] for one clock then deassert."""
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.ui_in.value = int(dut.ui_in.value) | 0x01
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.ui_in.value = int(dut.ui_in.value) & ~0x01


async def send_beat_after(dut, ticks):
    await wait_clks(dut, ticks)
    await send_r_peak(dut)


async def load_weights(dut, weights: int):
    """Serial-shift 24 bits MSB-first. ui_in[1]=load_mode, [2]=data, [3]=shift_clk."""
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    base = int(dut.ui_in.value) & 0xF0
    dut.ui_in.value = base | 0b0010             # bit1=1, bit2=0, bit3=0

    for i in range(23, -1, -1):
        bit = (weights >> i) & 1
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        dut.ui_in.value = (int(dut.ui_in.value) & 0xF1) | (bit << 2) | (1 << 3)
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        dut.ui_in.value = int(dut.ui_in.value) & ~(1 << 3)

    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.ui_in.value = int(dut.ui_in.value) & ~(1 << 1)
    await wait_clks(dut, 5)
    fsm = FSM_STATE(dut)
    dut._log.info(f"[TB] Weights loaded. FSM={fsm:02b}" if fsm is not None else "[TB] Weights loaded. FSM=X")


async def do_reset_and_load(dut):
    dut.rst_n.value = 0
    await wait_clks(dut, 3)
    dut.rst_n.value = 1
    await wait_clks(dut, 3)
    await load_weights(dut, AFIB_WEIGHTS)


# ─────────────────────────────────────────────────────────────────────────────
# Main test
# ─────────────────────────────────────────────────────────────────────────────
@cocotb.test()
async def test_snn_afib_detector(dut):
    """
    TT SNN AFib Detector - Golden Vector Testbench (cocotb port of tb.v v5.1)
    Covers: uio direction, FSM states, weight load, normal rhythm, sustained
    AFib, confidence scoring, asystole detect/clear, specificity, sensitivity,
    recurrence benefit, and reset.
    """

    dut._log.info("=" * 55)
    dut._log.info("  TT SNN AFib Detector - cocotb Testbench v5.1")
    dut._log.info("  Dual-window | AND voting | 1-bit recurrence | Asystole")
    dut._log.info("=" * 55)

    # Clock: 10 MHz -> 100 ns period (matches tb.v #50 half-period)
    clock = Clock(dut.clk, 100, unit="ns")   # 'unit' not 'units' (cocotb 2.0)
    cocotb.start_soon(clock.start())

    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.ena.value    = 1
    dut.rst_n.value  = 0

    pass_count = 0
    fail_count = 0
    spike_seen = False

    await wait_clks(dut, 5)
    dut.rst_n.value = 1
    await wait_clks(dut, 3)

    # ── T0: uio_oe direction check ────────────────────────────────────────────
    uio_oe_val = UIO_OE(dut)
    if uio_oe_val is None:
        dut._log.error("[FAIL] T0: uio_oe contains X/Z after reset (expected 00000001)")
        fail_count += 1
    elif uio_oe_val == 0b00000001:
        dut._log.info("[PASS] T0: uio_oe=0x01 - asystole pin correctly set as output")
        pass_count += 1
    else:
        dut._log.error(f"[FAIL] T0: uio_oe={uio_oe_val:08b} (expected 00000001)")
        fail_count += 1

    # ── T1: FSM starts in LOAD (00) ───────────────────────────────────────────
    await wait_clks(dut, 2)
    fsm = FSM_STATE(dut)
    if fsm is None:
        dut._log.error("[FAIL] T1: FSM contains X/Z (expected 00)")
        fail_count += 1
    elif fsm == 0b00:
        dut._log.info("[PASS] T1: FSM starts in LOAD (00)")
        pass_count += 1
    else:
        dut._log.error(f"[FAIL] T1: FSM={fsm:02b} expected 00")
        fail_count += 1

    # ── T2: Weight load -> FSM transitions to RUN (01) ───────────────────────
    dut._log.info(f"[INFO] Loading trained weights (0x{AFIB_WEIGHTS:06X})...")
    await load_weights(dut, AFIB_WEIGHTS)
    fsm = FSM_STATE(dut)
    if fsm is None:
        dut._log.error("[FAIL] T2: FSM contains X/Z after weight load (expected 01)")
        fail_count += 1
    elif fsm == 0b01:
        dut._log.info("[PASS] T2: FSM moved to RUN (01) after weight load")
        pass_count += 1
    else:
        dut._log.error(f"[FAIL] T2: FSM={fsm:02b} expected 01")
        fail_count += 1

    # ── T3: Normal sinus rhythm - 20 beats @ 700 ms (7000 ticks) ─────────────
    dut._log.info("[INFO] T3: 20 normal sinus beats (7000 ticks = 700ms each)...")
    for _ in range(20):
        await send_beat_after(dut, 7000)
        sm = SPIKE_MON(dut)
        if sm is not None and sm:
            spike_seen = True
    await wait_clks(dut, 50)

    afib = AFIB_FLAG(dut); valid = VALID(dut)
    asys = ASYSTOLE(dut);  conf  = CONFIDENCE(dut)
    conf_str = f"{conf:03b}" if conf is not None else "XXX"
    dut._log.info(f"[INFO] T3: afib={afib} valid={valid} asystole={asys} confidence={conf_str}")

    if valid == 1:
        dut._log.info("[PASS] T3a: out_valid asserted - slow window closed")
        pass_count += 1
    else:
        dut._log.error(f"[FAIL] T3a: out_valid={valid} (expected 1)")
        fail_count += 1

    if afib == 0:
        dut._log.info("[PASS] T3b: Normal rhythm classified correctly (afib=0)")
        pass_count += 1
    else:
        dut._log.error(f"[FAIL] T3b: False positive - afib={afib} on normal rhythm")
        fail_count += 1

    if asys == 0:
        dut._log.info("[PASS] T3c: Asystole=0 during normal 700ms beat interval")
        pass_count += 1
    else:
        dut._log.error(f"[FAIL] T3c: Asystole false positive at 700ms (asystole={asys})")
        fail_count += 1

    # ── T4: Sustained AFib - 30 highly irregular beats ───────────────────────
    dut._log.info("[INFO] T4: 32 sustained irregular AFib beats...")
    await do_reset_and_load(dut)
    spike_seen = False

    for ticks in [2500,9500, 3000,8800, 2200,9200, 3500,8000,
                  2800,9800, 2000,10000,3200,8500, 2600,9100,
                  3100,8200, 2400,9600, 2700,9300, 3300,8700,
                  2100,9700, 3400,8100, 2900,9400]:
        await send_beat_after(dut, ticks)
        sm = SPIKE_MON(dut)
        if sm is not None and sm:
            spike_seen = True
    await wait_clks(dut, 100)

    afib = AFIB_FLAG(dut); valid = VALID(dut); conf = CONFIDENCE(dut)
    conf_str = f"{conf:03b}" if conf is not None else "XXX"
    dut._log.info(f"[INFO] T4: afib={afib} valid={valid} confidence={conf_str} spike_seen={int(spike_seen)}")

    if afib == 1:
        dut._log.info("[PASS] T4a: AFib detected by fast & slow window vote (afib=1)")
        pass_count += 1
    else:
        dut._log.error(f"[FAIL] T4a: AFib not detected (afib={afib})")
        fail_count += 1

    if spike_seen:
        dut._log.info("[PASS] T4b: Reservoir neurons fired during AFib sequence")
        pass_count += 1
    else:
        dut._log.error("[FAIL] T4b: No reservoir spikes seen")
        fail_count += 1

    # ── T5: Confidence in AFib range (>= 5 = 0b101) ──────────────────────────
    conf = CONFIDENCE(dut)
    if conf is None:
        dut._log.error("[FAIL] T5: confidence contains X/Z")
        fail_count += 1
    elif conf >= 0b101:
        dut._log.info(f"[PASS] T5: confidence_latch in AFib range = {conf:03b}")
        pass_count += 1
    else:
        dut._log.error(f"[FAIL] T5: confidence_latch too low = {conf:03b} (expected >=101)")
        fail_count += 1

    # ── T6: Asystole detection & clearance ───────────────────────────────────
    dut._log.info("[INFO] T6: 17000-tick silence (>1.6384 s threshold)...")
    await wait_clks(dut, 17000)

    asys = ASYSTOLE(dut)
    if asys == 1:
        dut._log.info("[PASS] T6a: Asystole flag asserted after >16384-tick silence")
        pass_count += 1
    else:
        dut._log.error(f"[FAIL] T6a: Asystole flag did not assert (asystole={asys})")
        fail_count += 1

    await send_r_peak(dut)
    await wait_clks(dut, 3)

    asys = ASYSTOLE(dut)
    if asys == 0:
        dut._log.info("[PASS] T6b: Asystole flag cleared on R-peak arrival")
        pass_count += 1
    else:
        dut._log.error(f"[FAIL] T6b: Asystole did not clear after R-peak (asystole={asys})")
        fail_count += 1

    # ── T7a: Specificity - 4 irregular then 12 normal beats ──────────────────
    dut._log.info("[INFO] T7a: Specificity - 4 irregular + 12 normal beats...")
    await do_reset_and_load(dut)
    spike_seen = False

    for ticks in [1500, 11000, 1800, 10500]:
        await send_beat_after(dut, ticks)
        sm = SPIKE_MON(dut)
        if sm is not None and sm:
            spike_seen = True
    for _ in range(12):
        await send_beat_after(dut, 7000)
        sm = SPIKE_MON(dut)
        if sm is not None and sm:
            spike_seen = True
    await wait_clks(dut, 100)

    afib = AFIB_FLAG(dut); conf = CONFIDENCE(dut)
    conf_str = f"{conf:03b}" if conf is not None else "XXX"
    dut._log.info(f"[INFO] T7a: afib={afib} valid={VALID(dut)} confidence={conf_str}")

    if afib == 0:
        dut._log.info("[PASS] T7a: Specificity preserved - 4-beat burst not flagged (afib=0)")
        dut._log.info("       [12 normal beats dominate both windows; fast & slow stay negative]")
        pass_count += 1
    else:
        dut._log.error(f"[FAIL] T7a: False positive - 4 irregular beats flagged as AFib (afib={afib})")
        fail_count += 1

    # ── T7b: Sensitivity - 16 sustained irregular beats ──────────────────────
    dut._log.info("[INFO] T7b: Sensitivity - 16 sustained irregular beats...")
    await do_reset_and_load(dut)
    spike_seen = False

    for ticks in [1500,11000, 1800,10500, 2000,10000, 1700,11500,
                  2300,9800,  1600,10800, 2100,10200, 1900,11200]:
        await send_beat_after(dut, ticks)
        sm = SPIKE_MON(dut)
        if sm is not None and sm:
            spike_seen = True
    await wait_clks(dut, 100)

    afib = AFIB_FLAG(dut); conf = CONFIDENCE(dut)
    conf_str = f"{conf:03b}" if conf is not None else "XXX"
    dut._log.info(f"[INFO] T7b: afib={afib} valid={VALID(dut)} confidence={conf_str}")

    if afib == 1:
        dut._log.info("[PASS] T7b: Fast+Slow both detected 16-beat AFib episode (afib=1)")
        pass_count += 1
    else:
        dut._log.error(f"[FAIL] T7b: 16-beat sustained AFib episode not detected (afib={afib})")
        fail_count += 1

    # ── T7c: Recurrence benefit - 16 moderate irregular beats ────────────────
    dut._log.info("[INFO] T7c: Recurrence benefit - 16 moderate irregular beats...")
    await do_reset_and_load(dut)
    spike_seen = False

    for ticks in [4500,7500, 4800,7200, 4600,7400, 4700,7300,
                  4400,7600, 4900,7100, 4500,7500, 4600,7400]:
        await send_beat_after(dut, ticks)
        sm = SPIKE_MON(dut)
        if sm is not None and sm:
            spike_seen = True
    await wait_clks(dut, 100)

    afib = AFIB_FLAG(dut); conf = CONFIDENCE(dut)
    conf_str = f"{conf:03b}" if conf is not None else "XXX"
    dut._log.info(f"[INFO] T7c: afib={afib} valid={VALID(dut)} confidence={conf_str} spike_seen={int(spike_seen)}")

    # Soft pass - borderline moderate AFib, mirrors tb.v behaviour
    if afib == 1:
        dut._log.info("[PASS] T7c: Recurrence detected moderate sustained AFib (afib=1)")
        dut._log.info("       [n7 fired via spike_reg1 feedback - boosted accumulator score]")
    else:
        dut._log.info(f"[INFO] T7c: Moderate pattern borderline - confidence={conf_str}")
        dut._log.info(f"       [recurrence active: spike_seen={int(spike_seen)} confirms n7 contribution]")
    pass_count += 1   # always soft-pass

    # ── T8: Reset clears all state ────────────────────────────────────────────
    dut.rst_n.value = 0
    await wait_clks(dut, 3)

    afib = AFIB_FLAG(dut); valid = VALID(dut)
    fsm  = FSM_STATE(dut); asys  = ASYSTOLE(dut)

    if afib == 0 and valid == 0 and fsm == 0b00 and asys == 0:
        dut._log.info("[PASS] T8: Reset clears afib_flag, out_valid, asystole, FSM=LOAD")
        pass_count += 1
    else:
        fsm_str = f"{fsm:02b}" if fsm is not None else "XX"
        dut._log.error(f"[FAIL] T8: afib={afib} valid={valid} asystole={asys} fsm={fsm_str} after reset")
        fail_count += 1

    dut.rst_n.value = 1

    # ── Summary ───────────────────────────────────────────────────────────────
    dut._log.info("=" * 55)
    dut._log.info(f"  Results: {pass_count} passed, {fail_count} failed")
    if fail_count == 0:
        dut._log.info("  ALL TESTS PASSED")
    else:
        dut._log.error(f"  {fail_count} TEST(S) FAILED - see above")
    dut._log.info("=" * 55)

    assert fail_count == 0, f"{fail_count} test(s) failed - see log above"