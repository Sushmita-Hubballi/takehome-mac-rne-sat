# `mac_rne_sat` — Functional Specification

## 1. Overview

`mac_rne_sat` is a signed 8×8 multiply-accumulate unit with a rounded,
saturated readout port and a sticky overflow flag. All behavior is
synchronous to the rising edge of `clk`. Reset is synchronous and
active-high.

## 2. Interface

| Port        | Dir | Type              | Description                                      |
|-------------|-----|-------------------|--------------------------------------------------|
| `clk`       | in  | `logic`           | Clock. All sequential behavior on the rising edge. |
| `rst`       | in  | `logic`           | Synchronous, active-high reset.                  |
| `en`        | in  | `logic`           | Accumulate `a*b` this cycle.                     |
| `clr`       | in  | `logic`           | Clear the accumulator this cycle.                |
| `rd`        | in  | `logic`           | Request a readout this cycle.           |
| `a`         | in  | `logic signed [7:0]`  | Multiplicand.                                |
| `b`         | in  | `logic signed [7:0]`  | Multiplier.                                  |
| `res`       | out | `logic signed [15:0]` | Rounded + saturated readout result (registered). |
| `res_valid` | out | `logic`           | One-cycle pulse, exactly one cycle after each `rd`. |
| `ovf`       | out | `logic`           | Sticky saturation flag (registered).             |

All control inputs (`en`, `clr`, `rd`) are sampled on every rising edge and
may be asserted in any combination. `a` and `b` are consumed only on cycles
where the accumulator takes a product (see §3).

## 3. Accumulator

The internal accumulator `acc` is a 28-bit signed two's-complement register.
The product `p = a * b` is a signed 16-bit value, sign-extended to 28 bits
before use.

Accumulator update at each rising edge (with `rst = 0`):

| `clr` | `en` | `acc` next value |
|-------|------|------------------|
| 0     | 0    | `acc` (hold)     |
| 0     | 1    | `acc + p`        |
| 1     | 0    | `0`              |
| 1     | 1    | `p` — clear-then-accumulate: the accumulator becomes the new product alone |

The grading testbench guarantees the accumulator value never exceeds the
signed 28-bit range, so accumulator wrap behavior is unspecified and need
not be handled.

## 4. Readout path

Asserting `rd` in cycle *t* requests a readout.

**Snapshot value** The snapshot is the accumulator value as it stood at the end of 
cycle *t−1* — that is, before any accumulator update (en/clr) occurring in cycle *t*. 
An 'en' asserted in the same cycle as 'rd' still updates the accumulator normally; 
it is simply not part of that snapshot. 
A 'clr' asserted in the same cycle as rd clears the accumulator after the snapshot 
is taken (the readout returns the pre-clear value).

To perform rounding and saturation, use the value of accumulator at the end of cycle *t-1*in current cycle.
(Since accumulator is a registered value, it's update based on 'clr' or 'en'
 is effective only at the next clock edge).

**Rounding — round-half-to-even at the 8 LSBs.** Let
`q = floor(accumulator / 256)` and `r = accumulator − 256·q` to handle both 
 positive and negative values.
'r' is unsigned value with range `0 ≤ r ≤ 255` — including for negative snapshots. 

 The rounded value is:
- `q` if `r < 128`;
- `q + 1` if `r > 128`;
- on a tie (`r == 128`): `q` if `q` is even, else `q + 1`.

**Saturation — applied after rounding.** The rounded value is then clamped
to the signed 16-bit range `[−32768, +32767]`. Note the order: rounding is
performed first and may itself carry the value out of the 16-bit range;
saturation applies to the **rounded** value.

**res and res_valid update** 
 'res' and 'res_valid' are updated at each rising edge (with `rst = 0`).
 'res_valid' and 'res' are updated in the same cycle when 'rd' is 1.

`res` carries the rounded, saturated value. Since 'res' must be available in cycle *t+1*, 
 rounding and saturation must be computed combinationally. 
 Between readouts, `res` **holds** its last value; it does not clear when `res_valid` is low.
 Back-to-back `rd` cycles are permitted.


Worked examples (`accumulator → res`):

| accumulator | q  | r   | res | note                      |
|----------|----|-----|-----|---------------------------|
| 640      | 2  | 128 | 2   | tie, q even → stays       |
| 896      | 3  | 128 | 4   | tie, q odd → rounds up    |
| −384     | −2 | 128 | −2  | tie, q even → stays       |


## 5. Overflow flag

`ovf` is a registered, sticky flag:

- **Set** whenever a readout saturates, the flag update lands in the same cycle.
- **Cleared** only when `clr` = 1 or on 'rst'. 
- **Same-cycle priority:** A saturating readout sets 'ovf' irrespective 
 of 'clr'. 
 'ovf' is only cleared when 'clr' is 1 and no staurating readout occurs
- A readout that does not saturate leaves `ovf` unchanged. `res` always
  carries the clamped value; saturation is signaled only via `ovf`.

## 6. Reset

`rst` is synchronous and active-high, and overrides `en`/`clr`/`rd`. On a
rising edge with `rst = 1`: `acc`, `res`, `res_valid`, and `ovf` all clear
to 0.

## 7. Implementation constraints

- Synthesizable SystemVerilog, compatible with Icarus Verilog (`-g2012`).
  Note: output ports aren't allowed in functions in SystemVerilog for Icarus Verilog.
- No SystemVerilog Assertions (SVA).
- Do not change the module name, port names, directions, or widths.
- Single clock domain. No latches.
