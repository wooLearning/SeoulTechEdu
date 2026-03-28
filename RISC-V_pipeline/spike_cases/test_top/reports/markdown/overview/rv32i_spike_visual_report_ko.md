# RV32I Spike matplotlib 시각화 보고서

XSIM 로그를 pandas와 matplotlib로 다시 분석한 RV32I 검증 보고서입니다.

## 요약

- Pipeline TB는 `84/84` row match와 final memory 2건 통과 상태를 확인했습니다.
- Top_tb는 `rows=84`, `errors=0`, `coverage=76.82%`로 통과했습니다.
- 리포트 구조는 참고 레포처럼 `evidence/logs`, `evidence/csv`, `reports/markdown`, `reports/html/assets`로 정리했습니다.

## 핵심 산출물

- HTML 보고서: `../../html/rv32i_spike_visual_report_ko.html`
- Dashboard: `../../html/assets/rv32i_dashboard.png`
- Flow summary: `../../html/assets/rv32i_flow_summary.png`
- Opcode heatmap: `../../html/assets/rv32i_opcode_heatmap.png`
- Retire timeline: `../../html/assets/rv32i_retire_timeline.png`
- Top_tb events: `../../html/assets/rv32i_top_tb_events.png`

## 흐름 비교

| Flow | Result | Retire Rows | Row Pass | Errors | Mem Checks | Coverage | Cycle Window |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| Pipeline TB | PASS | 84 | 84 | 0 | 2 | N/A | 4 -> 105 |
| Top_tb Class Env | PASS | 84 | 84 | 0 | 2 | 76.82% | 5 -> 106 |

## 해석

- 두 flow 모두 같은 Spike golden trace를 정확히 따라갔기 때문에 기능 정합성은 확보됐다고 볼 수 있습니다.
- coverage가 100%가 아닌 이유는 현재 trace에서 stall/illegal 같은 일부 이벤트가 발생하지 않았기 때문입니다.
- Top_tb의 redirect, forwarding, memwrite는 실제로 관측되어 control-flow와 hazard 관련 경로 일부는 검증됐습니다.

## 아티팩트

- 로그: `../../../evidence/logs/pipeline_spike_xsim.log`
- 로그: `../../../evidence/logs/top_tb_class_xsim.log`
- CSV: `../../../evidence/csv/combined_summary.csv`
- CSV: `../../../evidence/csv/combined_instruction_mix.csv`
- CSV: `../../../evidence/csv/top_tb_event_summary.csv`
- 생성 스크립트: `../../../tools/rv32i_spike_report.py`

