# UART Verification Visual Report

## 1. Snapshot

This dashboard-style note summarizes the UART directed verification status, the scenario-to-feature coverage map, the assertion status, and the baud-rate error visualization.

Related files:

- [uart_peripheral_report.md](./uart_peripheral_report.md)
- [uart_verification_run_log.md](./uart_verification_run_log.md)
- [uart_baud_error_table.csv](../data/uart_baud_error_table.csv)
- [uart_jitter_sweep_results.csv](../data/uart_jitter_sweep_results.csv)
- [uart_jitter_threshold_summary.csv](../data/uart_jitter_threshold_summary.csv)
- [uart_jitter_sweep_run_log.md](./uart_jitter_sweep_run_log.md)

## 2. Pass Summary

| Item | Result |
|---|---|
| Compile | PASS |
| Elaborate | PASS |
| Simulate | PASS |
| Directed scenarios | 6 / 6 PASS |
| TB assertions enabled | 3 |
| TB assertions failed | 0 |
| Final status | `tb_uart_apb_wrapper PASSED` |

## 3. Scenario Flow

```mermaid
flowchart LR
    A["Reset / ID"] --> B["TX Path<br/>0x55, 0xA3, 0x0D"]
    B --> C["RX Normal<br/>0x3C"]
    C --> D["RX Jitter<br/>0xA6"]
    D --> E["Frame Error<br/>bad stop bit"]
    E --> F["RX Overflow<br/>33-byte burst"]
    F --> G["PASS"]
```

## 4. Scenario Coverage Matrix

Legend:

- `Y`: directly covered by the scenario
- `A`: covered by always-on TB assertion
- `-`: not directly checked in that scenario

| Feature / Checkpoint | Reset / ID | TX Path | RX Normal | RX Jitter | Frame Error | RX Overflow | Assertion |
|---|---|---|---|---|---|---|---|
| APB ID read path | Y | - | - | - | - | - | - |
| APB STATUS read path | Y | - | Y | - | Y | Y | - |
| `pready` constant-high behavior | - | - | - | - | - | - | A |
| TX line idle during reset | Y | - | - | - | - | - | A |
| APB read response known/no X | Y | - | Y | - | Y | Y | A |
| TX FIFO enqueue | - | Y | - | - | - | - | - |
| TX serial data correctness | - | Y | - | - | - | - | - |
| RX normal data path | - | - | Y | - | - | - | - |
| RX jitter tolerance | - | - | - | Y | - | - | - |
| Frame error sticky set | - | - | - | - | Y | - | - |
| Frame error clear path | - | - | - | - | Y | - | - |
| RX overflow sticky set | - | - | - | - | - | Y | - |
| RX FIFO drain ordering | - | - | - | - | - | Y | - |
| RX overflow clear path | - | - | - | - | - | Y | - |

## 5. Coverage Summary by Domain

```mermaid
pie showData
    title UART Verification Focus Distribution
    "APB / Register Interface" : 3
    "TX Data Path" : 2
    "RX Data Path" : 3
    "Error / Boundary Handling" : 3
    "Always-On Assertions" : 3
```

## 6. Directed Scenario Inventory

| Scenario | Stimulus | Expected Observation | Main RTL Area |
|---|---|---|---|
| Reset / ID | Read `UART_ID`, `UART_STATUS` after reset | Correct ID, TX/RX empty default state | `uart_apb_wrapper` |
| TX Path | APB writes `0x55`, `0xA3`, `0x0D` | Same bytes serialized on `o_uart_tx` | `uart_core`, `Top_FIFO`, `tx` |
| RX Normal | Inject clean serial `0x3C` | `RXDATA = 0x3C`, FIFO empties after pop | `rx`, `uart_core` |
| RX Jitter | Inject `0xA6` with alternating bit-period jitter | RX still decodes `0xA6` | `baud_tick_16`, `rx` |
| Frame Error | Inject `0xF0` with bad stop bit | `FRAME_ERROR` sets and clears | `rx`, `uart_core`, `uart_apb_wrapper` |
| RX Overflow | Fill 32-byte RX FIFO, then inject one extra byte | Overflow sets, first 32 bytes preserved, extra byte dropped | `Top_FIFO`, `uart_core` |

## 7. Assertion Set

Current TB assertions in [tb_uart_apb_wrapper.sv](../../tb/uart_peri_tb/tb_uart_apb_wrapper.sv):

| Assertion | Intent | Status |
|---|---|---|
| `p_pready_always_high` | Ensure the UART APB slave is zero-wait-state | PASS |
| `p_tx_idle_during_reset` | Ensure TX line stays idle high during reset | PASS |
| `p_apb_response_known` | Ensure APB read response is never X/Z during an active read | PASS |

Recommended next assertion set for future `bind`-based checking:

| Proposed assertion | Why it is useful |
|---|---|
| `frame_error` sticky until explicit clear | Encodes software-visible error retention |
| `rx_overflow` sticky until explicit clear | Encodes FIFO overflow persistence |
| `tx_busy` only during active TX FSM states | Checks status/FSM consistency |
| RX done only after valid stop check | Strengthens receiver correctness |
| TX start only when TX FIFO non-empty | Strengthens control-path legality |

## 8. Baud Error Visualization

Absolute baud error in ppm, computed from the phase-accumulator tick generator at `100 MHz` system clock:

![UART Baud Error](../visuals/figures/uart_baud_error_ppm.png)

```mermaid
xychart-beta
    title "Baud Rate vs Absolute Average Error (ppm)"
    x-axis [9600, 14400, 19200, 38400, 57600, 115200, 230400, 460800, 921600]
    y-axis "Absolute Error (ppm)" 0 --> 8
    bar [7.614, 7.614, 7.614, 2.087, 1.147, 1.147, 0.470, 0.339, 0.066]
```

Signed baud error:

| Baud | Signed Error (%) | Signed Error (ppm) |
|---|---:|---:|
| 9600 | `+0.000761449` | `+7.614` |
| 14400 | `+0.000761449` | `+7.614` |
| 19200 | `+0.000761449` | `+7.614` |
| 38400 | `-0.000208678` | `-2.087` |
| 57600 | `+0.000114698` | `+1.147` |
| 115200 | `+0.000114698` | `+1.147` |
| 230400 | `-0.000046990` | `-0.470` |
| 460800 | `+0.000033854` | `+0.339` |
| 921600 | `-0.000006568` | `-0.066` |

## 9. Tick Quantization Visualization

The baud generator is accurate on average, but each oversample tick spacing is quantized to either `N` or `N+1` clocks.

![UART Tick Spacing](../visuals/figures/uart_tick_spacing.png)

```mermaid
xychart-beta
    title "16x Tick Spacing Quantization (clock cycles)"
    x-axis [9600, 14400, 19200, 38400, 57600, 115200, 230400, 460800, 921600]
    y-axis "Tick Spacing (clks)" 0 --> 700
    line [651, 434, 325, 162, 108, 54, 27, 13, 6]
    line [652, 435, 326, 163, 109, 55, 28, 14, 7]
```

Interpretation:

- The average baud error is very small.
- The per-tick spacing is not perfectly uniform.
- The more meaningful robustness question is therefore RX sample placement and tolerance to disturbed bit timing.

## 10. Jitter Discussion Visual

```mermaid
flowchart TD
    A["Phase Accumulator Tick Generator"] --> B["Very Small Average Baud Error"]
    A --> C["Tick-to-Tick Quantization Jitter"]
    C --> D["RX Start Detect Phase Uncertainty"]
    D --> E["Single-Point Sampling Margin"]
    E --> F["Jitter Robustness Depends More on RX Sampling Than on Average Baud Error"]
```

## 11. Log Timeline Digest

![UART Timeline](../visuals/figures/uart_timeline.png)

```mermaid
flowchart TD
    T0["95 ns<br/>Test Start"] --> T1["145 ns<br/>Reset / ID PASS"]
    T1 --> T2["256.210 us<br/>TX Path PASS"]
    T2 --> T3["364.795 us<br/>RX Normal PASS"]
    T3 --> T4["469.015 us<br/>RX Jitter PASS"]
    T4 --> T5["573.295 us<br/>Frame Error PASS"]
    T5 --> T6["4.012835 ms<br/>RX Overflow PASS"]
    T6 --> T7["4.013835 ms<br/>Simulation PASS"]
```

## 12. Notebook-Generated Coverage Heatmap

![UART Coverage Heatmap](../visuals/figures/uart_coverage_heatmap.png)

## 13. Jitter Sweep Heatmap

The sweep covers `0% ~ 50%` alternating injected jitter with `1%` steps for every supported baud.

![UART Jitter Heatmap](../visuals/figures/uart_jitter_pass_fail_heatmap.png)

Threshold summary:

| Baud | Max PASS Jitter | First FAIL Jitter |
|---|---:|---:|
| 9600 | `43%` | `44%` |
| 14400 | `43%` | `44%` |
| 19200 | `43%` | `44%` |
| 38400 | `43%` | `44%` |
| 57600 | `44%` | `45%` |
| 115200 | `44%` | `45%` |
| 230400 | `44%` | `45%` |
| 460800 | `46%` | `47%` |
| 921600 | `48%` | `49%` |

## 14. Jitter Threshold Plots

![UART Jitter Threshold by Baud](../visuals/figures/uart_jitter_threshold_by_baud.png)

![UART Jitter Threshold in NS](../visuals/figures/uart_jitter_threshold_ns.png)

Interpretation:

- Thresholds move slightly upward as baud increases in this alternating-jitter model.
- The percentage threshold increases with baud, but the absolute time-domain margin in ns still shrinks at high baud.

## 15. Recommended Slide Usage

Suggested use for presentation:

| Slide | Suggested content |
|---|---|
| 1 | UART architecture + scenario flow |
| 2 | Scenario coverage matrix |
| 3 | Assertion set + next assertion roadmap |
| 4 | Baud error chart + tick quantization chart |
| 5 | Jitter sweep heatmap + threshold plot |
| 6 | Timeline digest + overall PASS summary |
