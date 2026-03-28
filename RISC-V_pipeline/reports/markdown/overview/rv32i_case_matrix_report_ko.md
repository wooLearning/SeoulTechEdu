# RV32I ROM 통합 검증 보고서

보관된 ROM 케이스별 verification 결과를 한 곳에서 비교한 통합 보고서입니다.

## 핵심 산출물

- HTML 보고서: `../../html/rv32i_case_matrix_report_ko.html`
- Dashboard: `../../html/assets/rv32i_case_dashboard.png`
- Flow compare: `../../html/assets/rv32i_case_flow_compare.png`
- Top metrics: `../../html/assets/rv32i_case_top_metrics.png`
- CSV: `../../../evidence/csv/case_matrix_summary.csv`
- CSV: `../../../evidence/csv/case_flow_matrix.csv`

## Case Summary

| ROM Case | Result | Retire Rows | Coverage | Stall | Redirect | MemWrite | Branch | Jump |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| bubble_sort | PASS | 490 | 81.36% | 94 | 20 | 42 | 29 | 8 |
| test_top | PASS | 84 | 76.82% | 0 | 11 | 4 | 14 | 3 |

## 해석

- `bubble_sort`는 Top_tb 기준 coverage `81.36%`, stall `94`, redirect `20`로 hazard와 control-flow 검증이 더 풍부하게 관측됐습니다.
- `test_top`은 retire `84` 규모의 짧은 directed ROM으로, final memory check `2`건과 coverage `76.82%`를 확인했습니다.
- 두 ROM 모두 Pipeline TB와 Top_tb가 같은 retire row 수를 PASS로 통과해 scoreboard 정합성은 확보됐습니다.

## 케이스 링크

### bubble_sort

- HTML: `../../../spike_cases/bubble_sort/reports/html/rv32i_spike_visual_report_ko.html`
- Markdown: `../../../spike_cases/bubble_sort/reports/markdown/overview/rv32i_spike_visual_report_ko.md`
- CSV: `tb/bubble_sort.csv`

### test_top

- HTML: `../../../spike_cases/test_top/reports/html/rv32i_spike_visual_report_ko.html`
- Markdown: `../../../spike_cases/test_top/reports/markdown/overview/rv32i_spike_visual_report_ko.md`
- CSV: `tb/spike_test_top.csv`

