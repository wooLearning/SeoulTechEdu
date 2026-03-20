# SystemVerilog Verification Portfolio

비동기 FIFO, 동기 FIFO, UART RX, UART+FIFO 통합 경로를 대상으로 직접 구성한 SystemVerilog 검증 포트폴리오입니다.
정식 IEEE UVM 라이브러리를 사용한 프로젝트는 아니지만, `transaction / generator / driver / monitor / scoreboard / environment` 역할 분리와 `interface + clocking block + self-checking` 구조를 기반으로 UVM 스타일의 검증 설계 역량이 드러나도록 정리했습니다.

![Verification Dashboard](reports/html/assets/python_dashboard.png)

## Quick Start

- 메인 안내: [START_HERE_ko.md](START_HERE_ko.md)
- HTML 보고서: [reports/html/index.html](reports/html/index.html)
- 검증 개요: [reports/markdown/overview/verification_overview.md](reports/markdown/overview/verification_overview.md)
- 전체 상세 보고서: [reports/markdown/overview/portfolio_report_ko.md](reports/markdown/overview/portfolio_report_ko.md)
- 모듈 보고서 인덱스: [reports/markdown/overview/module_reports_index_ko.md](reports/markdown/overview/module_reports_index_ko.md)

## What This Repo Shows

- Async FIFO와 Sync FIFO를 대상으로 한 self-checking verification environment
- UART RX 단독 검증과 UART+FIFO 통합 검증
- `clocking block` 기반 drive / pre-sample / post-sample 타이밍 분리
- accepted / blocked path와 flag state를 함께 추적하는 scoreboard/coverage 구조
- TB가 직접 만든 CSV를 Python으로 시각화한 HTML/Markdown 보고서
- Vivado xsim 기준으로 재현 가능한 로그 증빙

## Main Showcase

### 1. Async FIFO Showcase

- RTL: [src/fifo.sv](src/fifo.sv)
- TB: [tb/fifo](tb/fifo)
- 포인트:
  - dual-clock async FIFO
  - accepted write/read와 blocked path 구분
  - `pre_cb`, `mon_cb`를 분리한 timing-aware monitor

### 2. Dedicated Async FIFO RTL

- RTL: [src/async_fifo.sv](src/async_fifo.sv)
- TB: [tb/async_fifo](tb/async_fifo)
- 포인트:
  - active-high reset 기반 async FIFO
  - 별도 verification environment로 재구성
  - scenario-aware scoreboard와 interface assertion

### 3. Sync FIFO

- RTL: [src/sync_fifo.sv](src/sync_fifo.sv)
- TB: [tb/sync_fifo](tb/sync_fifo)
- 포인트:
  - single-clock FIFO
  - same-cycle read/write 정책 반영
  - pre-count 기반 acceptance 판정

### 4. UART RX

- RTL: [src/uart_rx.v](src/uart_rx.v)
- TB: [tb/uart_rx](tb/uart_rx)
- 포인트:
  - 16x oversampling UART RX
  - valid frame + invalid stop frame 검증
  - serial task driver 기반 protocol stimulus

### 5. UART RX + FIFO

- RTL: [src/uart_rx_fifo_bridge.sv](src/uart_rx_fifo_bridge.sv)
- TB: [tb/uart_fifo](tb/uart_fifo)
- 포인트:
  - UART RX 결과를 `sync_fifo`로 버퍼링
  - fill/balanced/burst traffic 시나리오
  - ordering과 FIFO flag 상태 검증

### 6. UART TX + FIFO

- RTL: [src/uart_tx_fifo_bridge.sv](src/uart_tx_fifo_bridge.sv)
- TB: [tb/uart_tx_fifo](tb/uart_tx_fifo)
- 포인트:
  - buffered transmitter path 검증
  - FIFO dequeue와 UART launch 타이밍 정렬
  - launch boundary scoreboard + serial line assertion

### 7. UART + Async FIFO

- RTL: [src/uart_rx_async_fifo_bridge.sv](src/uart_rx_async_fifo_bridge.sv)
- TB: [tb/uart_async_fifo](tb/uart_async_fifo)
- 포인트:
  - UART RX 결과를 async FIFO로 넘기는 dual-clock 통합 경로
  - fill/balanced/drain async traffic 시나리오
  - ordering과 async FIFO flag 상태 검증

## Verified Results

| Target | Status | Sample | PASS | FAIL |
| --- | --- | ---: | ---: | ---: |
| Async FIFO (Showcase) | PASS | 1153 | 190 | 0 |
| Async FIFO (Dedicated RTL) | PASS | 1153 | 190 | 0 |
| Sync FIFO | PASS | 320 | 838 | 0 |
| UART RX | PASS | 16 | 16 | 0 |
| UART RX + FIFO | PASS | 24 | 24 | 0 |
| UART TX + FIFO | PASS | 18 | 18 | 0 |
| UART + Async FIFO | PASS | 18 | 18 | 0 |

검증 로그:

- [evidence/logs/async_fifo_vivado.log](evidence/logs/async_fifo_vivado.log)
- [evidence/logs/async_fifo_src_vivado.log](evidence/logs/async_fifo_src_vivado.log)
- [evidence/logs/sync_fifo_vivado.log](evidence/logs/sync_fifo_vivado.log)
- [evidence/logs/uart_rx_vivado.log](evidence/logs/uart_rx_vivado.log)
- [evidence/logs/uart_fifo_vivado.log](evidence/logs/uart_fifo_vivado.log)
- [evidence/logs/uart_tx_fifo_vivado.log](evidence/logs/uart_tx_fifo_vivado.log)
- [evidence/logs/uart_async_fifo_vivado.log](evidence/logs/uart_async_fifo_vivado.log)

## Repository Layout

```text
SV_Verification/
├─ src/                         # showcase RTL
├─ tb/                          # showcase verification env
├─ reports/
│  ├─ html/                     # Toss-style HTML reports + chart images
│  └─ markdown/
│     ├─ overview/              # overview, portfolio, index docs
│     └─ module_reports/        # module-by-module detailed reports
├─ evidence/
│  ├─ logs/                     # Vivado xsim proof logs
│  └─ csv/                      # raw/combined CSV used by Python analysis
├─ tools/                       # Python analysis/plot scripts
├─ fpga_auto.yml
└─ requirements.txt
```

## Notes

- 이 폴더는 GitHub 업로드용으로 재패키징한 최종본입니다.
- `reference`, `generated_docs` 같은 보조 자료는 제외하고 showcase 중심으로만 남겼습니다.
- Python 대시보드는 FIFO 계열 CSV를 중심으로 구성돼 있고, UART 케이스는 모듈 보고서와 Vivado 로그에서 상세 설명을 이어갑니다.
