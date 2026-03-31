# 시작 안내

RISC-V multicycle CPU와 주변장치 연동 자료를 빠르게 따라가기 위한 안내 문서입니다.

## 먼저 볼 문서

- [README.md](README.md)
- [개요 보고서](md/reports/riscv_multicycle_peri_overview_ko.md)
- [UART 주변장치 보고서](md/reports/uart_peripheral_report_ko.md)
- [UART jitter sweep 보고서](md/reports/uart_jitter_sweep_report_ko.md)
- [Peripheral 반복 실행 보고서](md/reports/test_peri_repeat_execution_report_ko.md)
- [Register configuration](md/reports/register_config.md)
- [발표자료.pdf](발표자료.pdf)

## 읽는 순서

1. `README.md`에서 프로젝트 범위와 폴더 구성을 확인
2. `md/reports/riscv_multicycle_peri_overview_ko.md`에서 전체 흐름과 대표 결과를 확인
3. `md/reports/register_config.md`에서 MMIO 주소와 register 구성을 확인
4. `md/reports/uart_peripheral_report_ko.md`와 `md/reports/uart_jitter_sweep_report_ko.md`에서 UART 검증 내용을 확인
5. `md/reports/test_peri_repeat_execution_report_ko.md`에서 full-top ROM 실행 로그를 확인
6. 필요하면 `발표자료.pdf`와 `md/build_reports/`로 마무리

## 주요 경로

- RTL: `src/`
- Testbench: `tb/`
- 보고서: `md/reports/`
- 시각 자료: `md/visuals/`
- C firmware: `cpu_test/`
- build report: `md/build_reports/`
- transcript / ELF: `output/`
