# Design

## Design Principles

### No Memory Required

All visual patterns are computed entirely from the current pixel coordinates
and the frame counter. There is no framebuffer, no line buffer, and no lookup
table. Every output bit is a direct combinational function of the inputs. This
is possible because each rendering mode uses arithmetic expressions that vary
smoothly with position.

### Synthesizability Constraints

The design adheres to strict TinyTapeout synthesis rules:
- No `initial` blocks
- No delay statements (`#`)
- No floating-point arithmetic
- No hardware division (only right-shifts)
- Multipliers are limited to small operands (7-bit inputs, used only for
  the squared-distance computation in the original variant)
- All registers driven by synchronous clocks or asynchronous reset

### Optimization Techniques

- Inputs to expensive operations are pre-scaled by right-shift before use,
  reducing operand widths and preventing overflow.
- The octagonal radial norm (`max + min/2`) replaces a true Euclidean
  distance, eliminating any square-root or multiply-accumulate chain.
- Bit slicing replaces color lookup tables; the 8-bit pattern is partitioned
  directly into R, G, B fields.
- A single adder (`pattern + t`) provides global hue animation without
  per-channel logic.

---

## Mode 0: Radial Energy Field

### Intent

Produce smoothly expanding concentric rings with a gentle angular twist
(vortex effect).

### Computation

```
radial       = (r << 2) + (t << 1)
ripple       = r + (t >> 2)
vortex_final = radial XOR (ripple >> 2)
```

`radial` scales the radial distance by 4 and adds a fast time offset,
producing rings that appear to expand outward at approximately 2 ring-widths
per frame. `ripple` is a low-frequency secondary field. The XOR blend between
`radial` and `ripple >> 2` contributes at most 1/4 of the dynamic range,
preventing chaotic dominance while adding a subtle interference texture to
ring boundaries.

---

## Mode 1: Plasma

### Intent

Generate a smoothly varying diagonal color field reminiscent of classic
palette-cycling plasma effects.

### Computation

```
plasma = (cx >> 2) + t + (cy >> 2) + (t >> 1)
```

This sums a scaled horizontal position, a scaled vertical position, and two
time offsets at different rates. The result is a diagonal traveling wave where
the apparent direction and speed are determined by the ratio of the two time
terms. The expression is entirely additive: no XOR, no nonlinear operations.

---

## Mode 2: Interference

### Intent

Simulate two crossed standing waves to produce a grid-like interference
pattern.

### Computation

```
wave = (cx[9:3] XOR cy[9:3]) + (cx[9:4] + cy[9:4])
```

The XOR of coarsely scaled coordinates produces a regular checkerboard-like
carrier. The additive low-frequency term modulates the phase, creating a
diagonal band structure that drifts across the checkerboard. This mode does
not use `t`, so the pattern is static unless the global `color = pattern + t`
offset is considered; that offset provides the temporal animation.

---

## Mode 3: Chaos

### Intent

Produce a nonlinear, turbulent pattern that provides strong contrast to the
structured modes.

### Computation

```
chaos = (cx XOR (cy + t)) + ((cx AND cy) >> 2)
```

The time-shifted vertical coordinate is XORed with the horizontal coordinate,
producing a rapidly evolving bitwise pattern. The bitwise AND term adds a
slower-varying multiplicative envelope that darkens regions where both
coordinates share low-order bits, creating localized structure within the
turbulence. The two terms are summed, not XORed, which limits the overall
randomness compared to a pure XOR generator.
