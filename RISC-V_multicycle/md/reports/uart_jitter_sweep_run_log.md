# UART Jitter Sweep Run Log

## Sweep Configuration

- Baud settings: 9600, 14400, 19200, 38400, 57600, 115200, 230400, 460800, 921600
- Jitter sweep: 0.0% to 50.0% (step 10 permille)
- Total simulation points: 459
- Total wall time: 1145.26 s

## Threshold Summary

| Baud | Max PASS Jitter | First FAIL Jitter | PASS Count | FAIL Count |
|---|---:|---:|---:|---:|
| 9600 | 43.0% | 44.0% | 44 | 7 |
| 14400 | 43.0% | 44.0% | 44 | 7 |
| 19200 | 43.0% | 44.0% | 44 | 7 |
| 38400 | 43.0% | 44.0% | 44 | 7 |
| 57600 | 44.0% | 45.0% | 45 | 6 |
| 115200 | 44.0% | 45.0% | 45 | 6 |
| 230400 | 44.0% | 45.0% | 45 | 6 |
| 460800 | 46.0% | 47.0% | 47 | 4 |
| 921600 | 48.0% | 49.0% | 49 | 2 |

## First Failure Samples

| Baud | Jitter | Failure Reason |
|---|---:|---|
| 9600 | 44.0% | Fatal: [1251195000][UART_TB][FATAL] UART APB wrapper directed test failed |
| 14400 | 44.0% | Fatal: [834535000][UART_TB][FATAL] UART APB wrapper directed test failed |
| 19200 | 44.0% | Fatal: [626205000][UART_TB][FATAL] UART APB wrapper directed test failed |
| 38400 | 44.0% | Fatal: [313695000][UART_TB][FATAL] UART APB wrapper directed test failed |
| 57600 | 45.0% | Fatal: [209535000][UART_TB][FATAL] UART APB wrapper directed test failed |
| 115200 | 45.0% | Fatal: [105365000][UART_TB][FATAL] UART APB wrapper directed test failed |
| 230400 | 45.0% | Fatal: [53285000][UART_TB][FATAL] UART APB wrapper directed test failed |
| 460800 | 47.0% | Fatal: [27245000][UART_TB][FATAL] UART APB wrapper directed test failed |
| 921600 | 49.0% | Fatal: [14225000][UART_TB][FATAL] UART APB wrapper directed test failed |
