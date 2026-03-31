# UART Peripheral Analysis Report

## 1. Overview

This document summarizes the UART peripheral implementation in the current repository, explains the end-to-end TX/RX behavior, discusses jitter implications, and records the verification scenarios added in the class-based testbench.

Companion material:

- [uart_verification_visual_report.md](./uart_verification_visual_report.md)
- [uart_verification_run_log.md](./uart_verification_run_log.md)
- [uart_baud_error_table.csv](../data/uart_baud_error_table.csv)
- [uart_verification_notebook.ipynb](../notebooks/uart_verification_notebook.ipynb)

Primary RTL files:

- [uart_apb_wrapper.v](../../src/uart_peri/uart_apb_wrapper.v)
- [uart_core.v](../../src/uart_peri/uart_core.v)
- [Top_UART.v](../../src/uart_peri/uart_source/Top_UART.v)
- [tx.v](../../src/uart_peri/uart_source/tx.v)
- [rx.v](../../src/uart_peri/uart_source/rx.v)
- [baud_tick_16oversample.v](../../src/uart_peri/uart_source/baud_tick_16oversample.v)
- [Top_FIFO.v](../../src/uart_peri/fifo/Top_FIFO.v)
- [fifo_control.v](../../src/uart_peri/fifo/fifo_control.v)
- [fifo_register.v](../../src/uart_peri/fifo/fifo_register.v)

Primary testbench files:

- [tb_uart_apb_wrapper.sv](../../tb/uart_peri_tb/tb_uart_apb_wrapper.sv)
- [tb_pkg.sv](../../tb/uart_peri_tb/tb_pkg.sv)
- [interface.sv](../../tb/uart_peri_tb/interface.sv)
- [driver.svh](../../tb/uart_peri_tb/components/driver.svh)
- [monitor.svh](../../tb/uart_peri_tb/components/monitor.svh)
- [scoreboard.svh](../../tb/uart_peri_tb/env/scoreboard.svh)
- [test_uart_directed.svh](../../tb/uart_peri_tb/tests/test_uart_directed.svh)

## 2. Executive Summary

- The UART peripheral is built as `APB wrapper + UART core + FIFOs + TX/RX + 16x baud tick generator`.
- The APB programming model is simple and software-friendly.
- TX and RX paths are functionally correct for the tested scenarios.
- The baud generator uses a phase accumulator, so average baud accuracy is very good.
- The main jitter discussion point is not average baud error, but RX sampling robustness.
- RX uses 16x oversampling timing, but final data capture is single-point sampling rather than majority voting.
- A new class-based directed testbench was added and passes compile, elaboration, and simulation in Vivado.

## 3. System Integration Context

The UART is instantiated inside the APB subsystem and mapped at base address `0x2000_4000`.

Relevant integration files:

- [Top_APB.sv](../../src/apb/Top_APB.sv)
- [Top_module.sv](../../src/Top_module.sv)
- [mmio.h](../reference/mmio.h)

Integration path:

```text
CPU/MMIO
  -> APB master
    -> uart_apb_wrapper
      -> uart_core
        -> TX FIFO -> TX -> o_uart_tx
        -> i_uart_rx -> RX -> RX FIFO
```

## 4. Register Map

UART base address:

- `UART_BASE = 0x2000_4000`

Register map:

| Offset | Name | Access | Description |
|---|---|---|---|
| `0x00` | `UART_ID` | R | UART identification register |
| `0x04` | `UART_STATUS` | R | TX/RX state and sticky error flags |
| `0x08` | `UART_TXDATA` | W | Push one byte into TX FIFO |
| `0x0C` | `UART_RXDATA` | R | Pop one byte from RX FIFO |
| `0x10` | `UART_CONTROL` | R/W | Clear sticky error flags |

Status bits:

| Bit | Name | Meaning |
|---|---|---|
| 0 | `TX_FULL` | TX FIFO is full |
| 1 | `TX_EMPTY` | TX FIFO is empty |
| 2 | `RX_FULL` | RX FIFO is full |
| 3 | `RX_EMPTY` | RX FIFO is empty |
| 4 | `TX_BUSY` | TX frame is in progress |
| 5 | `RX_OVERFLOW` | RX byte arrived while FIFO was full |
| 6 | `FRAME_ERROR` | Stop bit check failed |

Control bits:

| Bit | Name | Meaning |
|---|---|---|
| 0 | `CLR_OVERFLOW` | Clear RX overflow sticky flag |
| 1 | `CLR_FRAME` | Clear frame error sticky flag |

## 5. Block-Level Structure

| Block | Role | Notes |
|---|---|---|
| `uart_apb_wrapper` | APB register interface | Address decode, APB responses, TX/RX register access |
| `uart_core` | Internal control block | Connects FIFOs and UART datapath, manages sticky flags |
| `Top_uart` | TX/RX wrapper | Shares one baud tick source |
| `tx` | UART serializer | Sends start, 8 data bits, stop |
| `rx` | UART receiver | Sync, start detect, bit sample, stop check |
| `baud_tick_16` | 16x baud tick generator | Phase accumulator based |
| `Top_FIFO` | Shared FIFO wrapper | Used for both TX and RX buffering |

## 6. TX Path Operation

### 6.1 Flow Summary

| Step | Operation |
|---|---|
| 1 | Software writes one byte to `UART_TXDATA` |
| 2 | APB wrapper asserts `tx_push` if TX FIFO is not full |
| 3 | TX FIFO stores the byte |
| 4 | `uart_core` asserts `w_tx_start` when FIFO is non-empty and TX is idle |
| 5 | TX FSM serializes the byte onto `o_uart_tx` |
| 6 | `TX_BUSY` is deasserted after stop bit completion |

### 6.2 TX Frame Format

| Field | Duration | Value |
|---|---|---|
| Idle | indefinite | `1` |
| Start | 1 bit | `0` |
| Data | 8 bits | LSB first |
| Stop | 1 bit | `1` |

### 6.3 TX Timing Behavior

- The TX FSM consumes one data bit for every 16 baud ticks.
- One complete frame is `1 start + 8 data + 1 stop = 10 bits`.
- A software write only places data in the FIFO. Actual line transmission starts when TX is idle.

### 6.4 TX Error Behavior

| Condition | Expected behavior |
|---|---|
| Write to `TXDATA` while TX FIFO full | `PSLVERR = 1` |
| TX FIFO empty | `TX_EMPTY = 1` |
| TX frame active | `TX_BUSY = 1` |

## 7. RX Path Operation

### 7.1 Flow Summary

| Step | Operation |
|---|---|
| 1 | External serial data enters on `i_uart_rx` |
| 2 | Signal passes through 2FF synchronizer |
| 3 | RX detects low level on a baud tick and enters start validation |
| 4 | If low is maintained for 8 ticks, start bit is accepted |
| 5 | RX samples one data bit every 16 ticks |
| 6 | RX checks stop bit |
| 7 | If stop bit is valid, `o_rx_done` is asserted and RX FIFO is pushed |
| 8 | Software reads one byte from `RXDATA` to pop the FIFO |

### 7.2 RX Design Characteristics

| Feature | Current implementation |
|---|---|
| Synchronization | 2FF synchronizer present |
| Start detection | Checked on `baud_tick` |
| Start validation | Half-bit validation at 8 ticks |
| Data sampling | Single-point sampling |
| Stop validation | Single-bit high check |
| Majority voting | Not implemented |

### 7.3 RX Error Behavior

| Condition | Expected behavior |
|---|---|
| Stop bit low | `FRAME_ERROR` sticky flag set |
| RX FIFO full when new byte completes | `RX_OVERFLOW` sticky flag set, new byte dropped |

## 8. FIFO Behavior

### 8.1 FIFO Depth

| FIFO | Depth | Data width |
|---|---:|---:|
| TX FIFO | 16 | 8 |
| RX FIFO | 32 | 8 |

### 8.2 Overflow Policy

When RX FIFO is full:

- The completed incoming UART byte is not pushed into the FIFO.
- The sticky overflow flag is set.
- Existing FIFO contents remain intact.

This means the newest byte is dropped in an overflow event.

## 9. Baud Tick Generation

### 9.1 Implementation Style

The baud tick generator is not a simple integer divider. It uses a phase accumulator:

- `target_tick_hz = baud_rate * 16`
- `phase_inc` is computed from `SYS_CLK` and desired tick rate
- Every `clk`, `phase_inc` is added to the accumulator
- Carry-out produces `baud_tick`

### 9.2 Why This Matters

This structure gives:

- Very low average baud error
- Slight cycle-to-cycle variation in tick spacing

That variation is deterministic quantization jitter, not random noise.

## 10. Baud Accuracy and Tick Jitter

Assuming `SYS_CLK = 100 MHz`, the derived timing is:

| Baud | Tick Frequency Target | Avg Error | Tick Spacing | 1-Bit Duration |
|---|---:|---:|---|---|
| 9600 | 153600 Hz | `+0.000761%` | `651/652 clk` | `10416/10417 clk` |
| 14400 | 230400 Hz | `+0.000761%` | `434/435 clk` | `6944/6945 clk` |
| 19200 | 307200 Hz | `+0.000761%` | `325/326 clk` | `5208/5209 clk` |
| 38400 | 614400 Hz | `-0.000209%` | `162/163 clk` | `2604/2605 clk` |
| 57600 | 921600 Hz | `+0.000115%` | `108/109 clk` | `1736/1737 clk` |
| 115200 | 1843200 Hz | `+0.000115%` | `54/55 clk` | `868/869 clk` |
| 230400 | 3686400 Hz | `-0.000047%` | `27/28 clk` | `434/435 clk` |
| 460800 | 7372800 Hz | `+0.000034%` | `13/14 clk` | `217/218 clk` |
| 921600 | 14745600 Hz | `-0.000007%` | `6/7 clk` | `108/109 clk` |

## 11. Jitter Discussion

### 11.1 Important Distinction

There are two different topics that can both be called "jitter":

| Topic | Meaning | Importance here |
|---|---|---|
| Baud average error | Long-term average baud mismatch | Low concern here |
| Sample timing robustness | How well RX tolerates bit width variation and phase offset | Main concern here |

### 11.2 What Is Good in the Current Design

- Average baud error is extremely small.
- 16x oversampling timing provides decent sampling granularity.
- 2FF synchronizer helps with asynchronous input stability.

### 11.3 What Is Less Robust

| Item | Why it matters |
|---|---|
| Start detection only at baud tick boundaries | Start edge may be recognized up to one oversample tick late |
| Single-point data sampling | Less tolerant to noise and jitter than majority voting |
| No majority vote around bit center | Reduced immunity to line distortion |
| `i_baud_sel` changes apply immediately | Mid-frame baud changes can disturb timing |

### 11.4 Practical Interpretation

A good summary for team discussion:

> The baud generator itself is accurate. The more meaningful jitter concern is RX robustness, because the receiver uses 16x timing but ultimately decides each bit from a single sample rather than a voted sample window.

## 12. New Class-Based Testbench

The new UART testbench was created with a class/package/interface structure inspired by the referenced `Top_tb` style.

### 12.1 Testbench File Structure

| File | Role |
|---|---|
| `tb_uart_apb_wrapper.sv` | Top-level TB module |
| `tb_pkg.sv` | Package include hub |
| `interface.sv` | APB/UART interface and serial helpers |
| `components/driver.svh` | APB transactions and UART stimulus |
| `components/monitor.svh` | Serial TX capture |
| `env/scoreboard.svh` | TX expected/actual comparison |
| `env/environment.svh` | Driver/monitor/scoreboard assembly |
| `tests/base_test.svh` | Common base test |
| `tests/test_uart_directed.svh` | Directed UART scenario implementation |

### 12.2 Testbench Strategy

The TB checks both:

- software-visible APB behavior
- actual serial line behavior

This is important because register access alone cannot prove that the serialized waveform is correct.

## 13. Verification Scenarios

### 13.1 Scenario Table

| Scenario | Stimulus | Expected Result | Bug Class Covered |
|---|---|---|---|
| Reset / ID | Read `UART_ID` and `UART_STATUS` after reset | Correct ID, TX/RX empty state | Reset/init bugs, register map bugs |
| TX path | Write `0x55`, `0xA3`, `0x0D` to `TXDATA` | Same bytes appear on serial TX with valid stop bits | TX FIFO/TX FSM/bit-order bugs |
| RX normal | Inject `0x3C` on `i_uart_rx` | `RXDATA = 0x3C`, FIFO empties after read | RX sampling/FIFO pop bugs |
| RX jitter tolerance | Inject jittered `0xA6` frame | RX still reconstructs `0xA6` | Timing margin issues |
| Frame error | Inject invalid stop bit | `FRAME_ERROR` sets and clears correctly | Stop-bit/error-flag bugs |
| RX overflow | Fill RX FIFO with 32 bytes, then send one more | Overflow flag sets, first 32 bytes preserved, extra byte dropped | Boundary and overflow policy bugs |
| Final scoreboard check | Verify all expected TX frames consumed | No missing TX observations | Monitor/scoreboard alignment bugs |

### 13.2 Detailed Scenario Descriptions

#### Reset / ID Check

- Reads `UART_ID`
- Verifies `0x5541_5254`
- Reads `UART_STATUS`
- Verifies reset-state bits indicate TX empty and RX empty

Purpose:

- confirms correct APB decode
- confirms reset values
- confirms read path behavior

#### TX Path Check

- Pushes three bytes into `TXDATA`
- Scoreboard records expected serial bytes
- Monitor watches `o_uart_tx`
- Captured bytes must match expected bytes exactly
- Stop bit must be valid for each frame

Why these bytes:

| Byte | Reason |
|---|---|
| `0x55` | Alternating bit pattern stresses bit position/order |
| `0xA3` | Mixed upper/lower bit pattern |
| `0x0D` | Additional non-symmetric pattern |

#### RX Normal Check

- Sends one clean UART frame carrying `0x3C`
- Waits until RX FIFO becomes non-empty
- Reads `RXDATA`
- Verifies exact byte value
- Confirms FIFO becomes empty after pop

#### RX Jitter Tolerance Check

- Sends `0xA6`
- Each bit period is alternately shortened and lengthened by a configured jitter amount
- Verifies the receiver still reconstructs the correct byte

Current setting:

- baud selection: `115200`
- jitter amplitude: about `8%` of one bit period

This is not a random-noise model. It is a deterministic alternating timing stress model.

#### Frame Error Check

- Sends a frame where stop bit is forced low
- Polls `FRAME_ERROR`
- Confirms sticky flag sets
- Writes `UART_CONTROL` clear bit
- Confirms sticky flag clears

#### RX Overflow Check

- Sends 32 sequential bytes into RX path
- Sends one extra byte
- Polls `RX_OVERFLOW`
- Drains 32 bytes from FIFO
- Verifies drained bytes are still `0x00` through `0x1F`
- Clears overflow bit
- Confirms FIFO returns to empty state

## 14. Verification Results

Vivado verification status:

| Step | Status |
|---|---|
| `xvlog` compile | PASS |
| `xelab` elaboration | PASS |
| `xsim -runall` | PASS |

Final runtime result:

- `tb_uart_apb_wrapper PASSED`

## 15. Strengths and Weaknesses

### 15.1 Strengths

| Strength | Description |
|---|---|
| Simple MMIO model | Easy for software to use |
| TX/RX buffering | FIFO reduces timing pressure on software |
| Good baud accuracy | Phase accumulator gives strong average precision |
| Clear sticky error model | Overflow and frame error handling are easy to observe |
| Verified serial behavior | TB checks actual line-level TX and RX |

### 15.2 Weaknesses or Improvement Opportunities

| Item | Description |
|---|---|
| No RX majority vote | Reduced tolerance to line noise and large jitter |
| Start detect only on oversample tick | Introduces phase uncertainty |
| Immediate baud select changes | Can disturb timing if changed during active frame |
| No interrupt support in this wrapper | Software must poll |
| No deeper error counters | Only sticky flags are exposed |

## 16. Recommended Follow-Up Tests

Recommended next steps:

| Test | Purpose |
|---|---|
| Baud mismatch sweep | Find actual RX tolerance window vs external baud mismatch |
| Random jitter injection | Go beyond deterministic alternating jitter |
| Long burst stress | Explore sustained RX/TX backpressure behavior |
| Mid-frame baud select change | Check robustness to illegal dynamic baud updates |
| Board-level external loopback | Validate real cable/USB-UART/PHY effects |

## 17. Suggested Team Communication Points

Recommended talking points:

- The UART architecture is functionally clean and easy to explain.
- The baud generator is accurate enough that average baud error is not the main concern.
- The real robustness discussion should focus on RX sampling strategy.
- Current verification already covers normal path, jittered RX, frame error, and overflow.
- If the team wants stronger field robustness, the most meaningful next upgrade is RX majority voting or more advanced sampling logic.

## 18. One-Line Summary

The current UART peripheral is functionally sound and verified for key directed scenarios, and the main technical discussion point for future improvement is RX robustness under timing disturbance rather than average baud generation accuracy.
