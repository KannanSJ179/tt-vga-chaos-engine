# Architecture

## Overview

The design is a synchronous pixel-clock pipeline. On every rising clock edge,
the VGA sync generator produces a new (hpos, vpos) coordinate. All downstream
logic is combinational: given the current pixel position and the frame counter
value, the correct RGB output is computed within one clock cycle.

## Block Diagram

```
                    ┌──────────────────────┐
        clk ───────►│  hvsync_generator    │──► hsync, vsync
        reset ─────►│  (hpos, vpos)        │──► display_on
                    └──────────┬───────────┘
                               │ hpos, vpos
                               ▼
                    ┌──────────────────────┐
                    │  Frame Counter       │──► frame[9:0]
                    │  (reg, clocked)      │
                    └──────────┬───────────┘
                               │ frame[9:8] = mode
                               │ frame[9:0] = t
                               ▼
                    ┌──────────────────────┐
                    │  Coordinate          │
                    │  Transform           │──► cx, cy (signed)
                    │  cx = hpos - 320     │──► ax, ay (absolute)
                    │  cy = vpos - 240     │──► ax_s, ay_s (scaled)
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │  Radial Approximation│──► r (octagonal norm)
                    │  r = max + min/2     │
                    └──────────┬───────────┘
                               │
              ┌────────────────┼────────────────────┐
              ▼                ▼                     ▼
        ┌──────────┐   ┌────────────┐   ┌───────────────────┐
        │  Mode 0  │   │  Mode 1    │   │  Mode 2 / Mode 3  │
        │  Radial  │   │  Plasma    │   │  Interference /   │
        │  Energy  │   │            │   │  Chaos            │
        └────┬─────┘   └─────┬──────┘   └────────┬──────────┘
             └───────────────┴──────────────────┬─┘
                                                │
                                   ┌────────────▼──────────┐
                                   │  Mode MUX (case)      │──► pattern[7:0]
                                   └────────────┬──────────┘
                                                │
                                   ┌────────────▼──────────┐
                                   │  color = pattern + t  │
                                   └────────────┬──────────┘
                                                │
                                   ┌────────────▼──────────┐
                                   │  RGB Bit Slice        │──► R[1:0] G[1:0] B[1:0]
                                   │  & display_on gate    │──► uo_out[6:0]
                                   └───────────────────────┘
```

## Data Flow

### 1. Sync Generation

`hvsync_generator` is a standard VGA timing module. It counts pixel clocks
horizontally (0–799) and lines vertically (0–524), asserting `display_on` only
within the 640x480 active area. `hsync` and `vsync` are active-low pulses
generated at the correct positions.

### 2. Frame Counter

A 10-bit register `frame` increments once per frame at the pixel position
(hpos=0, vpos=0). Its upper two bits `frame[9:8]` form a 2-bit `mode` signal,
causing an automatic mode transition every 256 frames (approximately every 4
seconds at 60 fps).

### 3. Coordinate Transformation

Pixel coordinates are recentered by subtracting the screen midpoint:
- `cx = hpos - 320` (range: -320 to +319)
- `cy = vpos - 240` (range: -240 to +239)

Absolute values `ax`, `ay` are computed by negating the signed value when its
sign bit is set.

### 4. Radial Approximation

To avoid a hardware square root, the octagonal norm is used:

```
r = max(ax_s, ay_s) + min(ax_s, ay_s) / 2
```

where `ax_s = ax >> 2` and `ay_s = ay >> 2` are scaled inputs that keep the
result in 8 bits. This approximation is monotonic and produces visually smooth
concentric shapes.

### 5. Pattern Generators

Each of the four modes computes an 8-bit pattern value as a function of
`cx`, `cy`, `r`, and `t` (frame counter). The active pattern is selected
by a combinational `case` statement on `mode`.

### 6. Color Output

A global time offset `t` is added to the pattern to provide uniform hue
cycling across all modes. The resulting 8-bit color value is sliced into
three 2-bit channels (R, G, B), which are gated with `display_on` and
routed to the TinyTapeout VGA output pins.
