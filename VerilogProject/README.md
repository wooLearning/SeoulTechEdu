# Verilog FPGA Integration Project

Verilog 기반으로 진행한 FPGA 통합 설계 프로젝트입니다.  
시계/스톱워치, UART 통신, 센서 제어를 개별 기능에서 시작해 하나의 상위 시스템으로 확장한 흐름을 정리했습니다.

## 프로젝트 개요

- 설계 언어: `Verilog`
- 성격: 기능 블록 설계 + 상위 통합
- 대표 기능: clock, stopwatch, UART, HC-SR04, DHT11, FND 표시

## 먼저 볼 자료

- [START_HERE_ko.md](./START_HERE_ko.md)
- [문서 인덱스](./docs/README.md)
- [StopWatch / Clock 문서](./docs/FPGA%20StopWatch%20%26%20Clock%20Project.pdf)
- [UART 문서](./docs/FPGA%20UART%20Project.pdf)
- [센서 통합 문서](./docs/FPGA%20Seneor%20%ED%86%B5%ED%95%A9%20Project.pdf)

## 소스코드와 자료 위치

| 경로 | 역할 |
| --- | --- |
| [SourceCode/src](./SourceCode/src) | RTL 소스 |
| [SourceCode/tb](./SourceCode/tb) | 모듈 단위 testbench |
| [SourceCode/constrs](./SourceCode/constrs) | FPGA 제약 파일 |
| [docs](./docs) | PDF 설계 문서 |

## 대표 모듈

- `Top.v`: UART, watch, sensor, FND를 묶는 최상위 통합 모듈
- `watch_top.v`: clock / stopwatch 표시 상위 로직
- `clock_core.v`, `stopwatch.v`, `stopwatch_mem.v`: 시간 표시 및 기록
- `uart_rx.v`, `uart_tx.v`, `uart_ascii_decoder.v`, `uart_ascii_sender.v`: UART 데이터 경로
- `Fifo.v`, `tx_fifo_top.v`: UART 전송 버퍼링
- `sr04_controller.v`, `dht11_controller.v`: 센서 제어

## 폴더 구조

```text
VerilogProject/
├─ SourceCode/
│  ├─ src/                     # RTL
│  ├─ tb/                      # testbench
│  └─ constrs/                 # XDC
├─ docs/                       # PDF 문서
├─ README.md
└─ START_HERE_ko.md
```

## 메모

- 이 프로젝트는 코드와 자료를 분리해서 볼 수 있도록 `SourceCode/`와 `docs/` 기준으로 정리했습니다.
- 처음 읽을 때는 문서를 먼저 보고 `SourceCode/src/Top.v`로 내려가면 흐름이 가장 자연스럽습니다.
