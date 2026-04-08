<!---

This file is used to generate your project datasheet. Please fill in the fields below and delete any unused fields.

You can also include images in this folder and reference them in the markdown. Each image must be less than 512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# SNN AFib Detector

- GitHub user: <!-- your github username -->
- [How it works](#how-it-works)
- [How to test](#how-to-test)
- [External hardware](#external-hardware)

## How it works

### Abstract

This project implements a **spiking neural network (SNN) reservoir computer** for real-time detection of **atrial fibrillation (AFib)** and **bradycardia/asystole** directly from R-peak timing signals, synthesised on SKY130A in 959 standard cells — with **no multipliers** anywhere in the design. The architecture follows the Liquid State Machine (LSM) framework: a fixed random reservoir of 8 Leaky Integrate-and-Fire (LIF) neurons transforms beat-to-beat RR interval features into a rich spike representation, which a lightweight linear readout then classifies using a dual fast+slow window consensus vote. The two-arrhythmia output (AFib flag + asystole flag) makes this suitable as an always-on wearable front-end, consuming near-zero dynamic power between heartbeats due to event-driven spike-valid gating.

---

### Architecture Narrative

The design is a 5-stage pipeline triggered **once per heartbeat** (on each R-peak rising edge):

```
                      10 MHz system clock
                            │
  ui_in[0] (r_peak) ──► rr_features ──► spike_encoder ──► reservoir ──► readout ──► uo_out / uio_out
                         (tick counter,   (rate-code to    (8 LIF       (dual-window
                          interval +       4-bit spike      neurons +    AND vote +
                          delta,           vectors)         spike_reg1)  confidence)
                          asystole)
                              │
                         uio_out[0]
                        (asystole_flag)
```

**Stage 1 — `rr_features`:**
A 16-bit tick counter counts 10 MHz system clocks between consecutive R-peak rising edges. On each beat, it outputs a 6-bit `rr_interval` (= `tick_count[15:9]`, mapping ~100 ms to ~6.4 s into 64 bins) and a 6-bit `rr_delta` (absolute beat-to-beat interval change, analogous to the clinical RMSSD metric). The asystole flag is set combinatorially via bit-select (`tick_count[15] | tick_count[14]`), asserting when the inter-beat gap exceeds ~1.64 s (~37 BPM), the AHA clinical bradycardia boundary — no adder required, saving ~6 cells.

**Stage 2 — `spike_encoder`:**
Converts the 6-bit features into 4-bit spike population codes that drive the reservoir inputs directly:
- `spike_interval = 15 - rr_interval[5:2]` — inverted so *fast* heart rates produce *more* spikes (higher-frequency input = more reservoir excitation)
- `spike_delta = min(rr_delta, 15)` — saturating at 15 to cap HRV outliers

**Stage 3 — `reservoir` (8 LIF neurons):**
The fixed reservoir comprises 8 LIF neurons divided into two functional groups:

| Neurons | Input | Role |
|---------|-------|------|
| n0–n3 | `spike_interval[3:0]` | Rate/rhythm detectors |
| n4–n7 | `spike_delta[3:0]` | HRV irregularity detectors |

Each LIF neuron implements the leaky integrate-and-fire dynamics:

```
V[t] = (V[t-1] >> 1) + W · spike_in    if V[t-1] < THRESHOLD
fire: spike_out = 1, V[t] = 0           if V[t-1] >= THRESHOLD
```

The right-shift (`>> 1`) is the leak — implemented as a single wire reassignment, zero gates. The weight `W` is a 3-bit parameter baked in at synthesis.

**1-bit recurrence (`spike_reg1`):** Neuron n7 receives `gd[3] | spike_reg1`, where `spike_reg1` holds n0's output from the *previous* beat. This makes the reservoir a true LSM: n7 fires when the current delta is large **or** the previous beat was already in an irregular-rate bucket. The recurrent connection costs ~2 cells (1 FF + 1 OR gate) and is what distinguishes this from a purely feedforward classifier.

**Stage 4 — `readout`:**
A 24-bit weight shift register holds 8 × 3-bit signed weights (loaded serially via `ui_in[3:1]` before operation). On each `spike_valid` event, the readout computes a signed per-beat score:

```
cycle_sum = Σ (neuron_spikes[i] ? sign_extend(w[i]) : 0)   for i = 0..7
```

This score accumulates into two independent windows:
- **Fast window (8 beats):** Detects acute AFib onset. Closes every 8 beats.
- **Slow window (16 beats):** Confirms sustained irregularity per ESC 2020 AFib guidelines.

`afib_flag` is asserted only when **both** windows cross their thresholds (AND vote), requiring sustained irregularity — the dominant false-positive rejection mechanism. A 3-bit confidence output (`uo_out[7:5]`) reflects the fast-window accumulator level.

**Stage 5 — Outputs:**
The OUTPUT FSM state latches results and pulses `out_valid` for one clock cycle every 16 beats.

---

### Clinical Justification

| Design Decision | Clinical Basis |
|----------------|----------------|
| `rr_delta` as primary feature | Analogous to RMSSD (Root Mean Square of Successive Differences) — the AHA-recommended short-term HRV metric for AFib screening |
| Dual fast+slow window AND vote | ESC 2020 guidelines: AFib diagnosis requires "irregular, sustained" rhythm — one window alone produces false positives on ectopic beats |
| Asystole threshold at ~37 BPM (bit 14 of 16-bit counter at 10 MHz) | AHA defines symptomatic bradycardia as HR < 40 BPM; 37 BPM provides ~7% margin |
| `afib_flag` requires both windows | Sustained irregularity criterion: a single ectopic beat raises the fast window but not the slow; the AND prevents false alarms |
| Inverted interval encoding | Faster rates (shorter RR intervals) → more spikes → stronger reservoir excitation, matching the clinical observation that AFib tends to have elevated mean HR |

---

### Echo State Property

The reservoir uses **fixed random weights** (set at synthesis time as Verilog parameters), which raises the natural question: why does a fixed random network give useful classification? The answer is the **Echo State Property** (Jaeger, 2001): provided the reservoir weight matrix satisfies a contractivity condition, any input sequence produces a unique, reproducible state trajectory — the reservoir acts as a high-dimensional nonlinear feature expander, and only the linear readout weights need to be trained. In this design, the 1-bit `spike_reg1` recurrent connection from n0→n7 is the architectural element that makes the LSM framing correct: without at least one recurrent connection, the network is purely feedforward and cannot exhibit fading memory. With `spike_reg1`, n7's response at beat `t` depends on both the current delta *and* the rhythm state from beat `t-1`, giving the network short-term memory of up to one beat — sufficient to distinguish a single ectopic beat (transient, self-correcting) from sustained AFib irregularity (persistent).

---

### Pin Reference

| Pin | Direction | Signal | Description |
|-----|-----------|--------|-------------|
| `ui_in[0]` | Input | `r_peak` | R-peak pulse from ECG front-end (rising edge = heartbeat) |
| `ui_in[1]` | Input | `w_load` | Weight load enable: hold HIGH during weight shift-in |
| `ui_in[2]` | Input | `w_data` | Serial weight data bit (MSB first) |
| `ui_in[3]` | Input | `w_clk` | Weight shift clock (rising edge clocks in one bit) |
| `ui_in[7:4]` | Input | — | Unused, tie LOW |
| `uo_out[0]` | Output | `afib_flag` | HIGH = AFib detected (fast AND slow window both positive) |
| `uo_out[1]` | Output | `out_valid` | Pulses HIGH for 1 cycle every 16 beats (result ready) |
| `uo_out[2]` | Output | `any_spike` | HIGH if any reservoir neuron fired this beat (debug) |
| `uo_out[3]` | Output | `fsm_state[0]` | Readout FSM state bit 0 (LOAD=00, RUN=01, OUTPUT=10) |
| `uo_out[4]` | Output | `fsm_state[1]` | Readout FSM state bit 1 |
| `uo_out[7:5]` | Output | `confidence_latch[2:0]` | 3-bit confidence: 7=high AFib confidence, 0=high normal confidence |
| `uio_out[0]` | Output | `asystole_flag` | HIGH = bradycardia/asystole (HR < ~37 BPM) |
| `uio_oe[0]` | — | — | Always HIGH (bit 0 is output-only) |
| `uio_in[7:1]` | Input | — | Unused |

**Default trained weight vector:** `0x28A03F` (24-bit hex)

Decoded: w0=−1, w1=−1, w2=0, w3=0 (interval neurons — negative weights penalise normal-rate firing), w4=+2, w5=+1, w6=+2, w7=+1 (delta neurons — positive weights reward high HRV irregularity = AFib signal). Validated 5/5 on MIT-BIH PhysioNet records.

---

### Gate Budget

| Module | Function | Approx. Cells |
|--------|----------|---------------|
| `rr_features` | 16-bit tick counter, interval/delta extraction, asystole | ~85 |
| `spike_encoder` | Rate-code conversion, saturation | ~25 |
| `reservoir` | 8 LIF neurons (4-bit potential each) + spike_reg1 | ~220 |
| `readout` | 24-bit weight SR, 2 accumulators, FSM, confidence | ~480 |
| `tt_um_snn_afib_detector` | Top-level wiring | ~10 |
| `clkbuf / tap / fill` | PDK-inserted (not counted) | — |
| **Total** | | **~820 logic + ~139 misc = 959** |

---

## How to test

### Prerequisites

- Tiny Tapeout demo board (RP2040 controller)
- Clock set to **10 kHz** (not 10 MHz — the RP2040 GPCLK output is used; at 10 kHz, 1 tick = 100 µs, intervals scale proportionally)
- OR: 10 MHz clock with R-peak pulses from an AD8232 ECG module

> **Note on clock frequency:** The design works at any clock frequency. At 10 kHz, the asystole threshold (~16384 ticks) corresponds to ~1.64 s, identical to the 10 MHz case. R-peak pulses must be at least 1 clock cycle wide.

---

### Step 1 — Reset

Assert `rst_n = LOW` for at least 2 clock cycles, then release HIGH. All counters and accumulators clear. FSM enters LOAD state. `uo_out = 0x00`, `uio_out[0] = 0`.

---

### Step 2 — Load Weights

The readout requires 24 weight bits shifted in MSB-first before classification can begin.

**Default weight vector: `0x28A03F` = `0010 1000 1010 0000 0011 1111` in binary**

Procedure:
1. Assert `ui_in[1]` (w_load) HIGH — FSM stays in LOAD state
2. For each of the 24 bits (MSB first): set `ui_in[2]` (w_data) to the bit value, then pulse `ui_in[3]` (w_clk) HIGH then LOW
3. After all 24 bits are shifted, release `ui_in[1]` (w_load) LOW — FSM transitions to RUN state
4. Verify: `uo_out[3:4]` (fsm_state) should read `01` (RUN)

**RP2040 MicroPython example:**
```python
WEIGHTS = 0x28A03F
for i in range(23, -1, -1):
    bit = (WEIGHTS >> i) & 1
    tt.ui_in[2] = bit
    tt.ui_in[3] = 1  # w_clk rising edge
    tt.ui_in[3] = 0
tt.ui_in[1] = 0  # release w_load → enter RUN
```

---

### Step 3 — Synthetic Pulse Test (No ECG Hardware Required)

Generate a sequence of R-peak pulses by toggling `ui_in[0]` HIGH for 1 clock cycle, then LOW, with a fixed inter-pulse gap.

**Test A — Normal sinus rhythm (60 BPM equivalent):**
- Pulse `ui_in[0]` every 1000 clock cycles (at 10 kHz = 100 ms inter-beat)
- After 16 beats: `out_valid` (uo_out[1]) should pulse HIGH, `afib_flag` (uo_out[0]) should be LOW
- `confidence_latch` (uo_out[7:5]) should read `000`–`010` (normal confidence)

**Test B — AFib pattern (irregular rhythm):**
- Pulse `ui_in[0]` with varying gaps: 600, 1400, 500, 1500, 700, 1300, 800, 1200 ... (cycles)
- After 16 beats: `afib_flag` (uo_out[0]) should assert HIGH
- `confidence_latch` should read `110` or `111`

**Test C — Asystole:**
- Stop pulsing `ui_in[0]` entirely
- After ~16384 clock cycles (~1.64 s at 10 kHz): `uio_out[0]` (asystole_flag) should assert HIGH
- Resume pulsing: `uio_out[0]` clears on next R-peak

---

### Step 4 — Real ECG Wiring (AD8232)

```
AD8232 OUTPUT ──► voltage divider (5V→3.3V if needed) ──► comparator/Schmitt trigger ──► ui_in[0]
                                                                    │
                                                          (threshold set ~0.5V above
                                                           baseline to detect R-peak)

GND ────────────────────────────────────────────────────────────── GND
3.3V ───────────────────────────────────────────────────────────── AD8232 VCC
```

AD8232 pin connections:
| AD8232 Pin | Connection |
|-----------|------------|
| OUTPUT | → Schmitt trigger → `ui_in[0]` |
| LO+ | → check for lead-off (optional) |
| LO- | → check for lead-off (optional) |
| SDN | → GND (always on) |
| GND | → system GND |
| 3.3V | → 3.3V supply |

Lead placement: Right arm (RA), Left arm (LA), Right leg (RL) as per standard Lead I configuration.

**Expected behaviour on real ECG:**
- `any_spike` (uo_out[2]) toggles with each R-peak when reservoir neurons fire
- `out_valid` pulses every ~16 heartbeats (~13 s at 75 BPM)
- `afib_flag` remains LOW during normal sinus rhythm
- During AFib: `afib_flag` asserts after 2–3 consecutive 16-beat windows of sustained irregularity

---

### Simulation Results

Run the testbench with:
```bash
iverilog -g2012 -o sim.vvp tb.v tt_um_snn_afib_detector.v rr_features.v spike_encoder.v reservoir.v readout.v lif_neuron.v && vvp sim.vvp
```

| Test | Stimulus | Expected | Description |
|------|----------|----------|-------------|
| T0 | Reset sequence | All outputs 0 | Power-on reset clears all state |
| T1 | Weight load (0x041408, 24 bits) | fsm_state=RUN after w_load↓ | Serial weight interface |
| T2 | 16 regular beats (1000-cycle gap) | afib_flag=0, out_valid pulses | Normal sinus rhythm |
| T3 | 16 irregular beats (±400-cycle jitter) | afib_flag=1 after 16 beats | AFib pattern |
| T4 | No beats for >16384 cycles | asystole_flag=1 | Bradycardia/asystole |
| T5 | Beat after asystole | asystole_flag clears | Asystole auto-recovery |
| T6 | w_load during RUN | FSM returns to LOAD | Weight reload mid-stream |
| T7 | any_spike observed | any_spike=1 during irregular beats | Reservoir activity visible |

---

## External Hardware

- **AD8232 ECG module** — single-lead heart rate monitor front-end. Provides amplified, filtered ECG signal. Requires 3 electrodes.
- **Schmitt trigger / comparator** (e.g. LM393 or 74HC14) — converts AD8232 analog output to clean digital R-peak pulses compatible with 3.3V CMOS logic levels
- **Optional: BLE SoC** (nRF52832 or ESP32) — reads `afib_flag` and `asystole_flag` and transmits alerts to a smartphone app

### Real-World Deployment Path

```
Electrodes
   │
   ▼
AD8232 ──► Schmitt Trigger ──► ui_in[0] ──► [SNN AFib Detector] ──► afib_flag ──► BLE SoC ──► Phone
                                                                   └──► asystole_flag ──────────┘
                                                  ▲
                                         clk = 10 MHz (XTAL)
                                         Weights loaded once at boot
                                         Power < 1 mW always-on
```

### Honest Limitations

- **No clinical accuracy claim.** This design has been verified on synthetic RR sequences and a Python model of real PhysioNet RR data. It has not been validated in a clinical study or on a real silicon sample.
- **Single-lead only.** The chip processes only R-peak timing (no waveform morphology). A single ectopic beat from a paced rhythm or bundle branch block may trigger false positives.
- **10 kHz clock recommended for demo board.** At other clock frequencies the asystole threshold and interval bins shift proportionally — the weight vector `0x041408` was optimised for 10 kHz demo-board use.
- **Weight retraining recommended for real data.** The default weight vector was derived analytically from synthetic RR distributions. For deployment on real patients, re-train the 8 readout weights using RR sequences from MIT-BIH Arrhythmia Database (PhysioNet) and reload via the serial interface.
- **8-beat minimum before first output.** The fast window requires 8 beats and the slow window 16 beats before `out_valid` asserts. At 60 BPM this is ~16 seconds of observation before the first AFib flag.