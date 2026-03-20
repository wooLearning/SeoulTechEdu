# 산출물 인덱스

이 문서는 `result_portfolio` 패키지에서 확인해야 할 핵심 산출물만 간단히 정리한 문서입니다.

## 핵심 보고서

- HTML 메인 보고서
  - `reports/html/index.html`
  - `reports/html/systemverilog_python_visual_report_ko.html`
- Markdown 개요 문서
  - `reports/markdown/overview/verification_overview.md`
  - `reports/markdown/overview/portfolio_report_ko.md`
  - `reports/markdown/overview/systemverilog_python_visual_report_ko.md`
  - `reports/markdown/overview/module_reports_index_ko.md`

## 모듈별 상세 보고서

- `reports/markdown/module_reports/fifo_report_ko.md`
- `reports/markdown/module_reports/async_fifo_src_report_ko.md`
- `reports/markdown/module_reports/sync_fifo_report_ko.md`
- `reports/markdown/module_reports/uart_rx_report_ko.md`
- `reports/markdown/module_reports/uart_fifo_report_ko.md`
- `reports/markdown/module_reports/uart_tx_fifo_report_ko.md`
- `reports/markdown/module_reports/uart_async_fifo_report_ko.md`

## 시각화 자산

- `reports/html/assets/python_dashboard.png`
- `reports/html/assets/python_module_overview.png`
- `reports/html/assets/python_scenario_heatmap.png`
- `reports/html/assets/python_trace_timeseries.png`
- `reports/html/assets/python_depth_histogram.png`

## CSV / 분석 데이터

- `evidence/csv/combined_summary.csv`
- `evidence/csv/combined_scenarios.csv`
- `evidence/csv/combined_trace.csv`
- `evidence/csv/*_summary.csv`
- `evidence/csv/*_scenarios.csv`
- `evidence/csv/*_trace.csv`

## Vivado 검증 로그

- Async FIFO
  - DUT: `src/fifo.sv`
  - TB: `tb/fifo/tb_fifo.sv`
  - 로그: `evidence/logs/async_fifo_vivado.log`
- Async FIFO (dedicated RTL)
  - DUT: `src/async_fifo.sv`
  - TB: `tb/async_fifo/tb_async_fifo.sv`
  - 로그: `evidence/logs/async_fifo_src_vivado.log`
- Sync FIFO
  - DUT: `src/sync_fifo.sv`
  - TB: `tb/sync_fifo/tb_sync_fifo.sv`
  - 로그: `evidence/logs/sync_fifo_vivado.log`
- UART RX
  - DUT: `src/uart_rx.v`
  - TB: `tb/uart_rx/tb_uart_rx.sv`
  - 로그: `evidence/logs/uart_rx_vivado.log`
- UART + FIFO Bridge
  - DUT: `src/uart_rx_fifo_bridge.sv`
  - TB: `tb/uart_fifo/tb_uart_fifo.sv`
  - 로그: `evidence/logs/uart_fifo_vivado.log`
- UART TX + FIFO Bridge
  - DUT: `src/uart_tx_fifo_bridge.sv`
  - TB: `tb/uart_tx_fifo/tb_uart_tx_fifo.sv`
  - 로그: `evidence/logs/uart_tx_fifo_vivado.log`
- UART + Async FIFO Bridge
  - DUT: `src/uart_rx_async_fifo_bridge.sv`
  - TB: `tb/uart_async_fifo/tb_uart_async_fifo.sv`
  - 로그: `evidence/logs/uart_async_fifo_vivado.log`

## 참고 메모

- 이 프로젝트의 메인 증빙 기준은 Vivado/xsim입니다.
- 이 패키지는 showcase 코드와 핵심 증빙만 남긴 GitHub 업로드용 최종본입니다.
