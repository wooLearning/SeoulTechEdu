# 시작 안내

RISC-V pipeline 검증 프로젝트의 주요 문서와 산출물 위치를 정리한 안내 문서입니다.

## 먼저 볼 문서

- [README.md](README.md)
- [Compact 보고서](reports/markdown/overview/rv32i_exec_compact_report_ko.md)
- [시각화 보고서](reports/markdown/overview/rv32i_spike_visual_report_ko.md)
- [케이스 매트릭스 보고서](reports/markdown/overview/rv32i_case_matrix_report_ko.md)
- [성능 보고서](md/performance_metrics_report.md)
- [케이스 인덱스](spike_cases/index.md)
- [HTML compact 보고서](reports/html/rv32i_exec_compact_report_ko.html)

## 읽는 순서

1. `README.md`에서 프로젝트 범위 확인
2. `reports/markdown/overview/rv32i_exec_compact_report_ko.md`에서 대표 결과 확인
3. `reports/markdown/overview/rv32i_spike_visual_report_ko.md`에서 시각화 확인
4. `spike_cases/index.md`에서 케이스별 보관본 확인
5. `md/performance_metrics_report.md`에서 Fmax / slack / CPI 확인
6. `evidence/logs/`에서 xsim 로그 확인

## 경로

- RTL: `src/`
- Testbench: `tb/`
- 보고서: `reports/`
- 케이스 보관본: `spike_cases/`
- 로그/CSV: `evidence/`
- 스크립트: `scripts/`, `tools/`
