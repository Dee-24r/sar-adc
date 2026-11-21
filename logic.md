# comparator
When `start` goes high in `IDLE`, the SAR controller tries bit 7 first by sending `10000000` to the DAC (`LOAD`). It waits for the voltage to settle (`SETTLE`), then reads the comparator (`DECIDE`). If the knob voltage is at or above the DAC voltage, it keeps the trial bit. Otherwise, it clears it. It repeats for bits 6 through 0, keeping all earlier decisions, then latches the final 8-bit result, pulses `done`, and returns to `IDLE`.


# entire

The knob produces an **analog voltage** that changes as you turn it. Your ADC figures out what number represents that voltage by comparing it against voltages it knows. The controller first guesses `128`, and the DAC turns that guess into a voltage halfway up the range. The comparator tells the controller whether the knob’s voltage is above or below that halfway point. The controller then checks halfway into the appropriate half, and keeps narrowing the range. After eight comparisons, it has an **8-bit number from `0` to `255`** that represents where the knob voltage falls in the range.


**Your SAR ADC repeatedly tries a digital number, converts that number into a voltage, and asks whether that voltage is too high.** Each answer decides one output bit, starting with bit 7 and ending with bit 0.

The **27 flip-flops, 6 NOT gates, and 90 AND gates** we counted belong to the digital controller we chose. It also uses OR gates. Those counts cover the register and control equations below. Your complete ADC additionally needs the analog sampling circuit, DAC, and comparator.

Let’s connect the purpose of each part to its actual wiring.

**1. Understand one complete conversion**

Suppose the sampled input is **3 V** and, for this example, the reference is **5 V**.

An ideal 8-bit DAC turns a trial code into:

\[
V_{\text{DAC}}=\frac{\text{trial code}}{256}\times 5\text{ V}
\]

The controller first tries `10000000`, which is 128. The DAC produces 2.5 V. Since the input is higher, keep that bit.

Next, try `11000000`, which is 192. The DAC produces 3.75 V. That’s too high, so clear the bit just tested.

Repeat through all eight bits:

| Bit | Trial code | DAC voltage | Decision |
|---|---:|---:|---|
| 7 | 128 | 2.5000 V | Keep |
| 6 | 192 | 3.7500 V | Clear |
| 5 | 160 | 3.1250 V | Clear |
| 4 | 144 | 2.8125 V | Keep |
| 3 | 152 | 2.9688 V | Keep |
| 2 | 156 | 3.0469 V | Clear |
| 1 | 154 | 3.0078 V | Clear |
| 0 | 153 | 2.9883 V | Keep |

The result is **153 = `10011001`**.

The comparator provides the decision as one digital signal:

```text
CMP = 1 when sampled input ≥ DAC trial voltage
CMP = 0 when sampled input < DAC trial voltage
```

**2. What your flip-flops store**

Each D flip-flop stores one bit. At a rising clock edge, it copies the value at **D** to **Q**.

Your circuit has these groups:

| Group | Size | Purpose |
|---|---:|---|
| `R` | 8 bits | Stores the bits accepted so far |
| `M` | 8 bits | Identifies which bit is currently being tested |
| `OUT` | 8 bits | Holds the last completed reading |
| `S1`, `S0` | 2 bits | Stores the controller’s current state |
| `DONE` | 1 bit | Signals that a result has just been captured |

**Connect the same `CLK` signal to every flip-flop’s triangle pin.** The gates calculate each flip-flop’s next D value between clock edges.

Throughout the instructions, a name such as `R7` means the **Q output** of that flip-flop.

**3. Set up the Wokwi workspace**

Open your saved Tiny Tapeout logic project.

- Keep the input switches, clock controls, reset circuit, and green input/output blocks.
- Remove the example inverters and display.
- Add ordinary D flip-flops under **+ → Logic**.
- Arrange three banks of eight, followed by the two state flip-flops and the DONE flip-flop.
- Label the banks `R`, `M`, and `OUT`, with bit 7 at the top and bit 0 at the bottom.

Use these input connections:

| Green input-block signal | Your signal |
|---|---|
| `CLK` | Shared clock |
| `RST_N` | Reset |
| `IN0` | `START` |
| `IN1` | `CMP` |

For this digital test, switch `IN1` supplies the comparator decision manually.

**4. Build the state decoder**

The controller uses four states:

| `S1 S0` | State | What the circuit is doing |
|---|---|---|
| `00` | IDLE | Waiting for a conversion request |
| `01` | SAMPLE | Acquiring the input voltage |
| `10` | SETTLE | Allowing the trial voltage and comparator to settle |
| `11` | DECIDE | Preparing to capture the comparator answer |

Add two NOT gates for `NOT S1` and `NOT S0`. Then wire four AND gates:

```text
IDLE   = (NOT S1) AND (NOT S0)
SAMPLE = (NOT S1) AND S0
SETTLE = S1 AND (NOT S0)
DECIDE = S1 AND S0
```

For example, when the state is `10`, only `SETTLE` becomes HIGH.

**5. Build the shared control signals**

Wire:

```text
LOAD = IDLE AND START
```

`LOAD` becomes HIGH when a new conversion is requested while the controller is idle.

Then wire:

```text
FINISH = DECIDE AND M0

MORE = DECIDE AND (NOT M0)
```

The mask reaches `00000001` when bit 0 is being tested. Therefore, `M0 = 1` identifies the final decision.

Finally, build these signals once and share their wires:

```text
HOLD_MASK = NOT (LOAD OR DECIDE)

KEEP_RUNNING = RST_N AND (NOT LOAD)

NOT_FINISH = NOT FINISH
```

**6. Connect the state flip-flops’ D inputs**

Wire these equations:

```text
D of S1 = RST_N AND (SAMPLE OR SETTLE OR MORE)

D of S0 = RST_N AND (LOAD OR SETTLE)
```

An expression with three OR inputs uses two two-input OR gates.

These connections implement:

| Current state | Condition | Next state |
|---|---|---|
| IDLE | `START = 0` | IDLE |
| IDLE | `START = 1` | SAMPLE |
| SAMPLE | — | SETTLE |
| SETTLE | — | DECIDE |
| DECIDE | More bits remain | SETTLE |
| DECIDE | Final bit | IDLE |

ANDing the final D values with `RST_N` forces both state bits to zero on a reset clock edge.

**7. Build the mask register `M`**

The mask selects the bit under test. It starts with:

```text
10000000
```

After each decision, it shifts right:

```text
01000000
00100000
00010000
...
00000001
```

For **M7**, wire:

```text
D of M7 =
RST_N AND (
    LOAD OR (HOLD_MASK AND M7)
)
```

That requires:

1. AND `HOLD_MASK` with `M7`.
2. OR the result with `LOAD`.
3. AND the result with `RST_N`.
4. Connect the final result to M7’s D pin.

For **M6**, wire:

```text
D of M6 =
RST_N AND (
    (HOLD_MASK AND M6)
    OR
    (DECIDE AND M7)
)
```

That requires:

1. AND `HOLD_MASK` with `M6`.
2. AND `DECIDE` with `M7`.
3. OR those results.
4. AND the result with `RST_N`.
5. Connect the result to M6’s D pin.

Repeat that second arrangement down the bank:

| D input being calculated | Current bit for holding | Bit shifted into it |
|---|---|---|
| M6 | M6 | M7 |
| M5 | M5 | M6 |
| M4 | M4 | M5 |
| M3 | M3 | M4 |
| M2 | M2 | M3 |
| M1 | M1 | M2 |
| M0 | M0 | M1 |

**8. Build the trial-code wires**

For every bit, add an OR gate:

```text
TRIALi = Ri OR Mi
```

Here, `i` means repeat the circuit for bits 0 through 7.

For example:

```text
R     = 10000000
M     = 00100000
TRIAL = 10100000
```

`R` supplies the previously accepted bits. `M` temporarily sets the current bit to 1 so you can test it.

**These eight TRIAL wires eventually connect to the DAC’s digital inputs.**

**9. Build the accepted-bit register `R`**

The R register must:

- Clear when a conversion starts.
- Set the current bit when `CMP = 1` during DECIDE.
- Hold its value at other times.

For every bit:

```text
D of Ri =
KEEP_RUNNING AND (
    Ri OR (DECIDE AND Mi AND CMP)
)
```

For **R7**, connect:

1. `DECIDE` and `M7` to an AND gate.
2. That result and `CMP` to another AND gate.
3. That result and `R7` to an OR gate.
4. That result and `KEEP_RUNNING` to an AND gate.
5. The final output to R7’s D pin.

Repeat for R6 through R0, using the corresponding mask bit.

If the current bit gets rejected, its R bit stays zero. Since previously accepted R bits feed back through the OR gate, they stay set.

**10. Calculate the value to capture at the end**

Make a separate signal for each bit:

```text
ACCEPTEDi = Ri OR (Mi AND CMP)
```

For each bit, that takes an AND gate followed by an OR gate.

Why do we need this signal? On the final clock edge, **R and OUT update together**. OUT needs the result that includes the final comparator decision. `ACCEPTED` calculates that value before the edge.

**11. Build the completed-output register**

For each output bit:

```text
D of OUTi =
RST_N AND (
    (FINISH AND ACCEPTEDi)
    OR
    (NOT_FINISH AND OUTi)
)
```

For **OUT7**, connect:

1. AND `FINISH` with `ACCEPTED7`.
2. AND `NOT_FINISH` with `OUT7`.
3. OR those two results.
4. AND the result with `RST_N`.
5. Connect it to OUT7’s D pin.

Repeat for all eight bits.

This circuit selects between capturing the completed result and holding the previous output.

Connect each output flip-flop’s Q to the matching green output-block input, `OUT0` through `OUT7`.

For the DONE flip-flop:

```text
D of DONE = RST_N AND FINISH
```

DONE becomes HIGH immediately after the final decision edge and returns LOW on the following clock edge.

**12. Test the digital logic**

Use manual clock mode.

1. Set START LOW.
2. Hold Reset, tap Step once, and release Reset.
3. Set START HIGH and tap Step. You should now have `M = 10000000`, `R = 0`, and state SAMPLE.
4. Set START LOW.
5. Tap Step to enter SETTLE.
6. Tap Step to enter DECIDE.
7. Set CMP, then tap Step to capture the decision.
8. For every remaining bit, tap once to enter DECIDE, set CMP, and tap again to capture it.

Supply these eight decisions, in order:

```text
1, 0, 0, 1, 1, 0, 0, 1
```

After the eighth decision:

```text
OUT  = 10011001
DONE = 1
State = IDLE
```

Also test eight zero decisions, which should produce `00000000`, and eight one decisions, which should produce `11111111`.

**13. Connect the analog blocks after the controller works**

The final connections will be:

| Signal | Connection |
|---|---|
| Analog input | Sampling circuit input |
| `SAMPLE` | Sampling circuit’s acquisition control |
| Held input voltage | Comparator’s positive input |
| `TRIAL7–TRIAL0` | DAC’s eight digital inputs |
| DAC output voltage | Comparator’s negative input |
| Comparator’s digital output | Controller’s `CMP` input |

The analog sampling circuit holds the measured voltage steady while the eight decisions run. The DAC generates each trial voltage, and the comparator supplies the decision automatically.

I chose one clock period each for SAMPLE and SETTLE to make this controller straightforward to build and trace. Their required durations depend on your eventual analog circuits. **The Wokwi gate schematic above verifies the SAR decision logic. The analog circuitry is the remaining part needed to complete your ADC.**