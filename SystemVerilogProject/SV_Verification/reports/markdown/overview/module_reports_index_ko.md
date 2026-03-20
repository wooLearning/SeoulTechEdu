# 모듈별 상세 보고서 인덱스

이 문서는 `result_portfolio` 패키지에서 확인할 수 있는 showcase DUT/검증 환경별 상세 한글 보고서 진입점입니다.

## 보고서 목록

- Async FIFO showcase(`src/fifo.sv`) 보고서: [fifo_report_ko.md](../module_reports/fifo_report_ko.md)
- Async FIFO dedicated RTL(`src/async_fifo.sv`) 보고서: [async_fifo_src_report_ko.md](../module_reports/async_fifo_src_report_ko.md)
- Sync FIFO 보고서: [sync_fifo_report_ko.md](../module_reports/sync_fifo_report_ko.md)
- UART RX 보고서: [uart_rx_report_ko.md](../module_reports/uart_rx_report_ko.md)
- UART + FIFO 브리지 보고서: [uart_fifo_report_ko.md](../module_reports/uart_fifo_report_ko.md)
- UART TX + FIFO 브리지 보고서: [uart_tx_fifo_report_ko.md](../module_reports/uart_tx_fifo_report_ko.md)
- UART + Async FIFO 브리지 보고서: [uart_async_fifo_report_ko.md](../module_reports/uart_async_fifo_report_ko.md)

## 읽는 순서 추천

- 포트폴리오 대표 사례부터 볼 경우
  - `fifo`
  - `sync_fifo`
  - `uart_rx`
  - `uart_fifo`
  - `uart_tx_fifo`
  - `uart_async_fifo`
## 공통 해석 가이드

- `transaction`
  - generator가 만든 자극 또는 monitor가 관측한 결과를 담는 데이터 객체
- `generator`
  - 랜덤 또는 제어된 자극을 생성하는 역할
- `driver`
  - transaction을 DUT 입력 신호로 변환해 인가하는 역할
- `monitor`
  - DUT 입출력을 샘플링해 scoreboard로 넘기는 역할
- `scoreboard`
  - reference model 또는 기대값과 DUT 결과를 비교해 PASS/FAIL을 판단하는 역할
- `environment`
  - 전체 컴포넌트를 연결하고 테스트 종료 시점을 관리하는 역할

## 주의 사항

- assertion coverage 수치 자체는 현재 별도 리포트로 추출하지 않았습니다.
- 따라서 각 보고서의 assertion 섹션은 “무슨 assertion이 있는가”, “어떤 체크 방식으로 대체되는가”를 설명하는 형태입니다.
- functional coverage는 `covergroup`이 구현된 showcase 모듈을 중심으로 설명했습니다.
