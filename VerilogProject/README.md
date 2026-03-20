# VerilogProject
> Verilog-based FPGA integration project archive

이 폴더는 Verilog 기반으로 진행한 FPGA 설계 결과물을 정리한 공간입니다.  
시계/스톱워치, UART 통신, 센서 제어를 개별 기능에서 통합 시스템으로 확장한 흐름을 확인할 수 있습니다.

## 폴더 구성

| 경로 | 설명 |
| --- | --- |
| [SourceCode](./SourceCode) | Verilog RTL, testbench, constraint 파일이 모여 있는 소스 폴더 |
| `FPGA StopWatch & Clock Project.pdf` | Stopwatch / Clock 설계 문서 |
| `FPGA UART Project.pdf` | UART 통신 설계 문서 |
| `FPGA Seneor 통합 Project.pdf` | 센서 통합 시스템 설계 문서 |

## SourceCode 구성

| 경로 | 설명 |
| --- | --- |
| [SourceCode/src](./SourceCode/src) | top-level 및 하위 RTL 모듈 |
| [SourceCode/tb](./SourceCode/tb) | 주요 모듈 단위 testbench |
| [SourceCode/constrs](./SourceCode/constrs) | FPGA 핀/제약 설정 파일 |

## 주요 모듈

- `Top.v`: UART, watch, sensor, FND를 묶는 최상위 통합 모듈
- `watch_top.v`: clock / stopwatch 표시 로직 상위 모듈
- `clock_core.v`, `stopwatch.v`, `stopwatch_mem.v`: 시간 표시 및 기록 기능
- `uart_rx.v`, `uart_tx.v`, `uart_ascii_decoder.v`, `uart_ascii_sender.v`: UART 통신 경로
- `Fifo.v`, `tx_fifo_top.v`: UART 데이터 버퍼링
- `sr04_controller.v`, `dht11_controller.v`: 센서 제어
- `fnd_controller.v`, `gen_clk.v`, `baud_rate_gen.v`, `button_sync.v`: 공통 주변 모듈

## 읽는 순서

1. PDF 문서로 프로젝트 흐름 확인
2. [SourceCode/src](./SourceCode/src)에서 `Top.v`부터 읽기
3. 필요한 기능별 하위 모듈 확인
4. [SourceCode/tb](./SourceCode/tb)에서 개별 testbench 확인
