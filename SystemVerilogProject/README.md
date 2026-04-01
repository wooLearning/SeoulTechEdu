# SystemVerilog Verification Project

FIFO와 UART 계열 RTL을 대상으로 구성한 SystemVerilog 검증 프로젝트입니다.  
검증 대상 RTL, testbench 환경, 보고서, 시뮬레이션 근거 자료를 역할별로 나누어 정리했습니다.

![Verification Dashboard](reports/html/assets/python_dashboard.png)

## 프로젝트 개요

- 대상 RTL: `fifo`, `async_fifo`, `sync_fifo`, `uart_rx`, `uart_rx_fifo_bridge`, `uart_tx_fifo_bridge`, `uart_rx_async_fifo_bridge`
- 검증 방식: `transaction / generator / driver / monitor / scoreboard / environment`
- 정리 기준: `src = RTL`, `tb = verification`, `reports = 설명 문서`, `evidence = 실행 근거`

## 먼저 볼 자료

- [START_HERE_ko.md](START_HERE_ko.md)
- [Markdown 시각화 보고서](reports/markdown/overview/systemverilog_python_visual_report_ko.md)
- [검증 개요](reports/markdown/overview/verification_overview.md)
- [전체 상세 보고서](reports/markdown/overview/portfolio_report_ko.md)
- [모듈 보고서 인덱스](reports/markdown/overview/module_reports_index_ko.md)
- [HTML 보고서](reports/html/index.html)
- [PDF 보고서](reports/pdf/systemverilog_python_visual_report_ko.pdf)

## 소스코드와 자료 위치

| 경로 | 역할 |
| --- | --- |
| [src](src) | 검증 대상 RTL |
| [tb](tb) | class-based testbench 환경 |
| [reports](reports) | Markdown / HTML / PDF 보고서 |
| [evidence](evidence) | Vivado 로그와 CSV 근거 자료 |
| [tools](tools) | 분석/시각화 스크립트 |

## 대표 결과

| Target | Status | Sample | PASS | FAIL |
| --- | --- | ---: | ---: | ---: |
| Async FIFO | PASS | 1153 | 190 | 0 |
| Async FIFO (Dedicated RTL) | PASS | 1153 | 190 | 0 |
| Sync FIFO | PASS | 320 | 838 | 0 |
| UART RX | PASS | 16 | 16 | 0 |
| UART RX + FIFO | PASS | 24 | 24 | 0 |
| UART TX + FIFO | PASS | 18 | 18 | 0 |
| UART + Async FIFO | PASS | 18 | 18 | 0 |

## 폴더 구조

```text
SystemVerilogProject/
├─ src/                         # 검증 대상 RTL
├─ tb/                          # testbench
├─ reports/                     # 설명 문서와 시각화 결과
├─ evidence/                    # 로그와 CSV 근거 자료
├─ tools/                       # Python 도구
├─ fpga_auto.yml
├─ README.md
└─ START_HERE_ko.md
```

## 메모

- 이 프로젝트는 검증 구조를 보여주는 포트폴리오이기 때문에 `tb/`와 `reports/`를 함께 보는 편이 좋습니다.
- Coverage는 Vivado native `get_inst_coverage()` 기준으로 확인했습니다.
