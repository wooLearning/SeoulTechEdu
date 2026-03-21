# SystemVerilog Verification Project

비동기 FIFO, 동기 FIFO, UART RX, UART+FIFO 통합 경로를 대상으로 구성한 SystemVerilog 검증 프로젝트입니다.  
검증 환경, 시뮬레이션 로그, CSV 결과, 시각화 자료, 모듈별 문서를 한 폴더에 정리했습니다.

![Verification Dashboard](reports/html/assets/python_dashboard.png)

## 개요

- 대상 RTL: `fifo`, `async_fifo`, `sync_fifo`, `uart_rx`, `uart_rx_fifo_bridge`, `uart_tx_fifo_bridge`, `uart_rx_async_fifo_bridge`
- 검증 방식: `transaction / generator / driver / monitor / scoreboard / environment`
- 보조 자료: Vivado xsim 로그, CSV 결과, Python 차트, Markdown/HTML/PDF 문서

## 문서

- [START_HERE_ko.md](START_HERE_ko.md)
- [Markdown 시각화 보고서](reports/markdown/overview/systemverilog_python_visual_report_ko.md)
- [검증 개요](reports/markdown/overview/verification_overview.md)
- [전체 상세 보고서](reports/markdown/overview/portfolio_report_ko.md)
- [모듈 보고서 인덱스](reports/markdown/overview/module_reports_index_ko.md)
- [HTML 보고서](reports/html/index.html)
- [PDF 보고서](reports/pdf/systemverilog_python_visual_report_ko.pdf)

UART 상세 문서:
- [UART RX](reports/markdown/module_reports/uart_rx_report_ko.md)
- [UART RX + FIFO](reports/markdown/module_reports/uart_fifo_report_ko.md)
- [UART TX + FIFO](reports/markdown/module_reports/uart_tx_fifo_report_ko.md)
- [UART + Async FIFO](reports/markdown/module_reports/uart_async_fifo_report_ko.md)

## 폴더 구조

```text
SystemVerilogProject/
├─ src/                         # 검증 대상 RTL
├─ tb/                          # testbench
├─ reports/
│  ├─ markdown/                 # 개요/상세 문서
│  ├─ html/                     # 브라우저용 보고서
│  └─ pdf/                      # PDF 산출물
├─ evidence/
│  ├─ logs/                     # Vivado xsim 로그
│  └─ csv/                      # summary/scenario/trace CSV
├─ tools/                       # Python 분석 스크립트
├─ fpga_auto.yml
├─ requirements.txt
├─ README.md
└─ START_HERE_ko.md
```

## 검증 대상

### FIFO 계열

- `src/fifo.sv`: Async FIFO
- `src/async_fifo.sv`: 별도 RTL 구현의 Async FIFO
- `src/sync_fifo.sv`: Sync FIFO

### UART 계열

- `src/uart_rx.v`: UART RX
- `src/uart_rx_fifo_bridge.sv`: UART RX + Sync FIFO
- `src/uart_tx_fifo_bridge.sv`: UART TX + Sync FIFO
- `src/uart_rx_async_fifo_bridge.sv`: UART RX + Async FIFO

## 검증 결과

| Target | Status | Sample | PASS | FAIL |
| --- | --- | ---: | ---: | ---: |
| Async FIFO | PASS | 1153 | 190 | 0 |
| Async FIFO (Dedicated RTL) | PASS | 1153 | 190 | 0 |
| Sync FIFO | PASS | 320 | 838 | 0 |
| UART RX | PASS | 16 | 16 | 0 |
| UART RX + FIFO | PASS | 24 | 24 | 0 |
| UART TX + FIFO | PASS | 18 | 18 | 0 |
| UART + Async FIFO | PASS | 18 | 18 | 0 |

관련 로그:
- [async_fifo_vivado.log](evidence/logs/async_fifo_vivado.log)
- [async_fifo_src_vivado.log](evidence/logs/async_fifo_src_vivado.log)
- [sync_fifo_vivado.log](evidence/logs/sync_fifo_vivado.log)
- [uart_rx_vivado.log](evidence/logs/uart_rx_vivado.log)
- [uart_fifo_vivado.log](evidence/logs/uart_fifo_vivado.log)
- [uart_tx_fifo_vivado.log](evidence/logs/uart_tx_fifo_vivado.log)
- [uart_async_fifo_vivado.log](evidence/logs/uart_async_fifo_vivado.log)

## 메모

- Coverage는 커스텀 퍼센트 함수가 아니라 Vivado native `get_inst_coverage()` 기준으로 확인했습니다.
- Python 차트는 `evidence/csv` 결과를 바탕으로 생성했습니다.
- Markdown 문서는 GitHub에서 바로 읽을 수 있는 형태로 정리했습니다.
