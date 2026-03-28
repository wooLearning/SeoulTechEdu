# RV32I Compact 검증 + 성능 보고서

필요한 그래프만 남긴 compact 보고서입니다. 대상은 `전체 명령어 테스트(test_top)`와 `버블 정렬(bubble_sort)` 두 케이스입니다.

## 한 줄 결론

- 두 케이스 모두 검증은 `PASS`이며, `버블 정렬`은 stall `94`와 coverage `81.36%`로 파이프라인 이벤트 관측성이 더 높고, `전체 명령어 테스트`는 directed 회귀와 final memory check에 더 적합합니다. Fmax는 두 케이스 모두 약 `101 MHz` 수준으로 비슷합니다.

## 핵심 산출물

- HTML: `../../html/rv32i_exec_compact_report_ko.html`
- Dashboard: `../../html/assets/rv32i_exec_compact_dashboard.png`
- Verification CSV: `../../../evidence/csv/case_matrix_summary.csv`
- Performance report: `../../../md/performance_metrics_report.md`

## Verification Summary

| Case | Result | Retire Rows | Coverage | Stall | Redirect | Forward Total | MemWrite |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 버블 정렬 | PASS | 490 | 81.36% | 94 | 20 | 235 | 42 |
| 전체 명령어 테스트 | PASS | 84 | 76.82% | 0 | 11 | 14 | 4 |

## Performance Summary

| Case | Perf Variant | Fmax (MHz) | Slack (ns) | CPI | Runtime (us) | LUTs | Regs |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 버블 정렬 | bubble | 101.245 | 0.123 | 1.568627 | 1.580 | 1279 | 817 |
| 전체 명령어 테스트 | default | 101.266 | 0.125 | 1.253165 | 0.978 | 1841 | 1440 |

## Notes

- `버블 정렬`은 verification에서도 stall이 실제로 많이 관측되고, performance에서도 CPI `1.568627`와 runtime `1.580 us`로 부담이 더 크게 보입니다.
- `전체 명령어 테스트`는 directed 회귀 성격이 강해서 final memory check가 있고, retire `84` 규모의 짧은 회귀 테스트로 쓰기 좋습니다.
- 성능 표의 `전체 명령어 테스트`는 기존 perf flow의 `default` ROM variant를 사용해 비교했습니다. Fmax는 `101.266 MHz`입니다.

