# RISC-V Pipeline Verification Project

RV32I 5-stage pipeline CPU를 Spike 기준 결과와 비교해 검증한 프로젝트입니다.  
`test_top`과 `bubble_sort` 두 대표 케이스를 중심으로 retire compare, pipeline event 분석, coverage, timing 결과를 함께 정리했습니다.

![RV32I Compact Dashboard](reports/html/assets/rv32i_exec_compact_dashboard.png)

## 개요

- 구조: RV32I 5-stage pipeline CPU
- 기준 데이터: Spike 실행 결과 CSV
- 대표 케이스: `test_top`, `bubble_sort`
- 검증 환경:
  - `tb/pipeline/`: pipeline retire compare TB
  - `tb/Top_tb/`: class-based monitor / scoreboard / coverage 환경
- 추가 지표:
  - stall
  - redirect
  - forwarding
  - coverage
  - Fmax / slack / utilization

## 문서

- [START_HERE_ko.md](START_HERE_ko.md)
- [Compact 보고서](reports/markdown/overview/rv32i_exec_compact_report_ko.md)
- [시각화 보고서](reports/markdown/overview/rv32i_spike_visual_report_ko.md)
- [케이스 매트릭스 보고서](reports/markdown/overview/rv32i_case_matrix_report_ko.md)
- [성능 보고서](md/performance_metrics_report.md)
- [케이스 인덱스](spike_cases/index.md)
- [HTML compact 보고서](reports/html/rv32i_exec_compact_report_ko.html)
- [HTML 시각화 보고서](reports/html/rv32i_spike_visual_report_ko.html)

## 대표 결과

| Case | Pipeline TB | Top_tb | Retire Rows | Coverage | Stall | Redirect | Forward Total |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| `test_top` | PASS | PASS | 84 | 76.82% | 0 | 11 | 14 |
| `bubble_sort` | PASS | PASS | 490 | 81.36% | 94 | 20 | 235 |

성능 기준 요약:

| Variant | Fmax (MHz) | Slack (ns) | CPI | Runtime (us) |
| --- | ---: | ---: | ---: | ---: |
| `default` | 101.266 | 0.125 | 1.253165 | 0.978 |
| `bubble` | 101.245 | 0.123 | 1.568627 | 1.580 |
| `hazard` | 104.482 | 0.429 | 1.342857 | 0.450 |
| `test2` | 100.100 | 0.010 | 1.271739 | 1.169 |

## 폴더 구조

```text
RISC-V_pipeline/
├─ src/                         # pipeline RTL, path package, memory image
├─ tb/                          # pipeline TB, Top_tb env, Spike CSV
├─ reports/
│  ├─ markdown/                 # 개요/시각화/compact/case matrix 문서
│  └─ html/                     # HTML 보고서와 차트
├─ evidence/
│  ├─ csv/                      # combined summary, trace, event summary
│  └─ logs/                     # xsim 로그
├─ spike_cases/                 # test_top, bubble_sort 보관본
├─ scripts/                     # Windows 실행 스크립트
├─ tools/                       # artifact 생성 및 리포트 스크립트
├─ output/perf_measure/         # post-implementation timing/utilization 원본
├─ md/                          # 성능 보고서
├─ fpga_auto.yml
├─ README.md
└─ START_HERE_ko.md
```

## 주요 경로

- RTL: `src/`
- Testbench: `tb/`
- 케이스별 보관본: `spike_cases/`
- 보고서: `reports/`
- 성능 문서: `md/performance_metrics_report.md`
- 로그/CSV: `evidence/`

## 메모

- Spike CSV가 바뀌는 경우에는 TB 구조를 다시 작성하기보다 artifact를 다시 생성하는 방식으로 결과를 갱신했다.
- `src/InstrMemPathsPkg.sv`에는 절대경로 상수가 포함될 수 있다.
- 다른 위치에서 재실행할 경우 `LP_PROJECT_ROOT`를 현재 위치 기준으로 확인해야 한다.
