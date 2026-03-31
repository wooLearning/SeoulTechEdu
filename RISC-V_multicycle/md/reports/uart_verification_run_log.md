# UART Verification Run Log

## 1. Run Context

Testbench:

- [tb_uart_apb_wrapper.sv](../../tb/uart_peri_tb/tb_uart_apb_wrapper.sv)

Main scenario implementation:

- [test_uart_directed.svh](../../tb/uart_peri_tb/tests/test_uart_directed.svh)

Command flow used for verification:

```text
xvlog  -> compile
xelab  -> elaborate
xsim -runall -> execute directed UART verification
```

## 2. Result Summary

| Stage | Result |
|---|---|
| Compile | PASS |
| Elaborate | PASS |
| Simulate | PASS |
| Final line | `tb_uart_apb_wrapper PASSED` |

## 3. Curated Timeline

| Time | Event |
|---|---|
| `95 ns` | Directed UART peripheral test start |
| `115 ns` | `UART_ID` matched `0x55415254` |
| `145 ns` | `UART_STATUS` reset bits matched `0x0000000a` |
| `82.660 us` | TX byte `0x55` observed and matched |
| `169.400 us` | TX byte `0xA3` observed and matched |
| `256.210 us` | TX byte `0x0D` observed and matched |
| `364.765 us` | RX normal byte `0x3C` matched |
| `364.795 us` | RX empty after `RXDATA` read observed |
| `469.015 us` | RX jittered byte `0xA6` matched |
| `573.205 us` | Frame error sticky flag set observed |
| `573.295 us` | Frame error cleared observed |
| `4.010825 ms` | RX overflow sticky flag set observed |
| `4.012745 ms` | RX overflow drain `[31]` matched `0x1F` |
| `4.012835 ms` | RX overflow cleared and RX empty observed |
| `4.012835 ms` | Directed UART peripheral test finished |
| `4.013835 ms` | `tb_uart_apb_wrapper PASSED` |

## 4. Interpreting the Timeline

| Interval | Meaning |
|---|---|
| `95 ns -> 145 ns` | Reset release and APB-visible default state check |
| `145 ns -> 256.210 us` | TX FIFO enqueue and serial TX verification |
| `256.210 us -> 364.795 us` | RX clean frame decode and FIFO pop verification |
| `364.795 us -> 469.015 us` | RX jitter tolerance verification |
| `469.015 us -> 573.295 us` | Frame error set/clear verification |
| `573.295 us -> 4.012835 ms` | RX overflow fill, drain, and clear verification |

## 5. Observed Coverage Hits

| Covered Item | Evidence |
|---|---|
| APB read path | `UART_ID`, `UART_STATUS`, `RXDATA` reads completed successfully |
| APB write path | `TXDATA` and `CONTROL` accesses completed successfully |
| TX serialization | Three different bytes observed and matched on `o_uart_tx` |
| RX decode | Clean and jittered bytes both reconstructed correctly |
| Sticky error handling | Frame error and overflow set/clear paths observed |
| Boundary behavior | 32-byte RX FIFO fill + 33rd-byte overflow behavior observed |
| Assertion health | No TB assertions fired during final passing run |

## 6. Notes for Review Meetings

Recommended explanation:

- The run exercises nominal TX, nominal RX, timing-disturbed RX, frame error, and FIFO overflow behavior in one directed flow.
- The final passing run confirms both the software-visible APB interface and the actual serial line behavior.
- The longest segment in the run is the overflow scenario because it intentionally fills and drains the full RX FIFO.
