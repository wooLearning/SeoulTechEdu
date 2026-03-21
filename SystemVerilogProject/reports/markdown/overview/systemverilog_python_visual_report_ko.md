# SystemVerilog Python 시각화 보고서

FIFO 계열 검증 CSV를 Python으로 시각화한 보고서입니다.

## 요약

- TB scoreboard가 직접 만든 CSV를 Python(`pandas`, `matplotlib`)으로 시각화했습니다.
- accepted path와 blocked path를 함께 보여줘 boundary condition 검증 범위를 설명할 수 있습니다.
- `clocking block`을 drive / pre-sample / post-sample 단계로 분리해 안정적인 타이밍을 유지했습니다.
- Python 시각화는 FIFO 계열 showcase 중심이며, UART 항목은 모듈별 보고서와 Vivado 로그를 함께 봅니다.

## UART 보고서

UART 항목 문서:

- `../module_reports/uart_rx_report_ko.md`
- `../module_reports/uart_fifo_report_ko.md`
- `../module_reports/uart_tx_fifo_report_ko.md`
- `../module_reports/uart_async_fifo_report_ko.md`

이 문서는 FIFO 계열의 CSV와 그래프 해석을 중심으로 구성합니다.

## 핵심 산출물

- 대시보드: `../../html/assets/python_dashboard.png`
- 모듈 비교 차트: `../../html/assets/python_module_overview.png`
- 시나리오 heatmap: `../../html/assets/python_scenario_heatmap.png`
- depth 추세: `../../html/assets/python_trace_timeseries.png`
- depth histogram: `../../html/assets/python_depth_histogram.png`

## 그래프 해석 가이드

### 1. Verification Dashboard

- 의미: 4개 핵심 그래프를 한 화면에 배치한 요약판입니다.
- 용도: 전체 검증 범위를 한 번에 확인합니다.

### 2. Module Transfer Overview

- x축: 모듈
- y축: 횟수(count)
- 의미: WR/RD accepted와 WR/RD blocked를 함께 비교합니다.
- 용도: 정상 경로와 full/empty 경계 조건을 함께 읽습니다.

### 3. Scenario Activity Heatmap

- x축: 시나리오
- y축: 모듈
- 색/숫자: `wr_acc + rd_acc` 기준 activity
- 의미: 어떤 시나리오가 실제로 활발히 수행됐는지 나타냅니다.
- 용도: phase-aware scenario 실행 분포를 확인합니다.

### 4. Reference Model Depth Trend

- x축: sample index
- y축: transaction 이후 reference model depth
- 의미: 시간 순서에 따른 FIFO depth 변화를 나타냅니다.
- 용도: fill, mixed, drain 흐름과 depth 변화를 함께 확인합니다.

### 5. Depth Histogram

- x축: depth 값
- y축: 빈도(frequency)
- 의미: 특정 depth 구간의 관측 빈도를 나타냅니다.
- 용도: empty/full 근처 경계 상태 분포를 확인합니다.

## 모듈 요약

| 모듈 | 결과 | 샘플 | PASS | FAIL | WR Acc | RD Acc | WR Block | RD Block | Coverage |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Async FIFO (Dedicated RTL) | PASS | 1153 | 190 | 0 | 96 | 94 | 41 | 39 | 100.00% |
| Async FIFO (Showcase) | PASS | 1153 | 190 | 0 | 96 | 94 | 41 | 39 | 100.00% |
| Sync FIFO | PASS | 320 | 838 | 0 | 202 | 198 | 35 | 40 | 100.00% |

## 클래스별 역할

### Async FIFO (Dedicated RTL)

- `transaction`: preFull/preEmpty, request, response를 함께 담아 accepted transaction 판정 근거를 보관
- `generator`: fill, mixed, drain, pressure phase bias를 주는 constrained-random stimulus 생성
- `driver`: dual-clock driver clocking block으로 negedge에서 request를 세팅
- `monitor`: pre_cb와 mon_cb를 분리해 acceptance 기준과 post-update 결과를 각각 샘플링
- `scoreboard`: accepted write/read만 reference queue에 반영하고 data/flag 정합성 판정
- `coverage`: scenario, domain, path, flag 항목을 수집하고 Vivado `get_inst_coverage()`로 출력
- `environment`: mailbox와 종료 이벤트를 연결하고 전체 실행 수명주기를 제어

### Async FIFO (Showcase)

- `transaction`: preFull/preEmpty, request, response를 함께 담아 accepted transaction 판정 근거를 보관
- `generator`: fill, mixed, drain, pressure phase bias를 주는 constrained-random stimulus 생성
- `driver`: dual-clock driver clocking block으로 negedge에서 request를 세팅
- `monitor`: pre_cb와 mon_cb를 분리해 acceptance 기준과 post-update 결과를 각각 샘플링
- `scoreboard`: accepted write/read만 reference queue에 반영하고 data/flag 정합성 판정
- `coverage`: scenario, domain, path, flag 항목을 수집하고 Vivado `get_inst_coverage()`로 출력
- `environment`: mailbox와 종료 이벤트를 연결하고 전체 실행 수명주기를 제어

### Sync FIFO

- `transaction`: request, response, pre-count 기반 판정에 필요한 snapshot을 보관
- `generator`: fill, simul, drain, pressure, balanced phase를 생성
- `driver`: single-clock driver clocking block으로 negedge에 request와 data를 고정
- `monitor`: 다음 negedge #1step 시점에서 cycle 결과를 수집
- `scoreboard`: same-cycle read/write 정책을 반영한 queue model 유지
- `coverage`: scenario, request mix, path, flag 항목을 수집하고 Vivado `get_inst_coverage()`로 출력
- `environment`: 컴포넌트 생성, 연결, preset, 종료 제어 담당

## Coverage 설정 설명 및 근거

- `cp_scenario`: generator가 의도한 phase-aware 시나리오가 모두 실제로 실행됐는지 확인합니다.
- `cp_wr_path` / `cp_rd_path`: accepted path뿐 아니라 blocked path까지 실제로 나왔는지 확인합니다. full/empty 보호 동작을 설명하는 핵심 근거입니다.
- `cp_flag_state`: normal/full/empty 상태가 모두 관측됐는지 확인합니다.
- async 계열의 `cp_domain`: write/read domain이 모두 실제로 샘플링됐는지 확인합니다.
- sync FIFO의 `cp_req_mix`: idle, write-only, read-only, both를 구분해 same-cycle 정책 검증 근거로 사용합니다.
- Vivado 설정: coverage class는 `option.per_instance = 1;`, `type_option.merge_instances = 1;`를 사용하고, scoreboard는 `cg_*.get_inst_coverage()`를 직접 출력합니다.
- CSV 기반 `trace` 분석: Vivado covergroup 퍼센트와 함께 depth 분포와 시간 흐름을 다시 시각화해 coverage 해석 근거를 보강합니다.

최신 Vivado xsim 로그 기준으로 `functional_coverage`는 showcase 3종과 UART 확장 케이스 모두 `100.00%`입니다. 이 문서는 covergroup 의도, scenario별 통계, trace CSV, Vivado native coverage 퍼센트를 함께 다룹니다.

## 시나리오 상세 설명

### fill_burst

- 목적: queue depth를 빠르게 끌어올려 full 근처 동작과 write blocked path를 의도적으로 만든 시나리오입니다.
- 커버리지 해석: WR Acc가 충분히 나오면서 WR Block이 함께 관측되면 fill/full pressure가 실제로 검증된 것입니다.

### mixed_stress

- 목적: read/write를 섞어 일반 운용 구간에서 ordering과 accepted path를 동시에 검증하는 시나리오입니다.
- 커버리지 해석: WR Acc와 RD Acc가 함께 높게 나타나면 scoreboard ordering 검증이 활발히 수행된 것으로 해석합니다.

### drain_burst

- 목적: queue를 비우는 방향으로 bias를 줘 empty 근처 동작과 read blocked path를 유도하는 시나리오입니다.
- 커버리지 해석: RD Acc와 RD Block이 함께 나타나면 drain과 underflow protection이 모두 검증된 것입니다.

### full_pressure

- 목적: 깊이가 높은 상태에서 write를 지속적으로 인가해 backpressure와 full flag 일관성을 보는 시나리오입니다.
- 커버리지 해석: WR Block이 의미 있게 잡히면 DUT가 full 보호를 수행했고 monitor/scoreboard가 이를 포착한 것입니다.

### empty_pressure

- 목적: 비어 있는 상태에서 read를 반복해 underflow protection과 empty flag 일관성을 확인하는 시나리오입니다.
- 커버리지 해석: RD Block이 의미 있게 나타나면 empty 보호 경로가 실제로 수행된 것입니다.

### simul_stress

- 목적: sync FIFO에서 same-cycle read/write 정책을 강하게 두드리는 시나리오입니다.
- 커버리지 해석: WR Acc와 RD Acc가 같은 구간에서 동시에 높으면 동시 처리 정책 검증이 충분히 일어났다고 볼 수 있습니다.

### flag_pressure

- 목적: sync FIFO의 full/empty 근처를 반복적으로 두드려 flag 경계 조건과 blocked path를 강조하는 시나리오입니다.
- 커버리지 해석: WR Block 또는 RD Block이 함께 보이면 boundary pressure가 실제로 먹혔다는 의미입니다.

### balanced_stream

- 목적: 한쪽으로 치우치지 않은 steady-state traffic에서 sustained throughput과 flag 안정성을 보는 시나리오입니다.
- 커버리지 해석: WR Acc와 RD Acc가 균형 있게 유지되면 steady-state stream 검증 근거로 활용할 수 있습니다.

## 시나리오별 커버리지 집계

| 모듈 | 시나리오 | 의도 | 샘플 | WR Acc | RD Acc | WR Block | RD Block | 해석 포인트 |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| Async FIFO (Showcase) | fill_burst | queue depth를 빠르게 끌어올려 full 근처 동작과 write blocked path를 의도적으로 만든 시나리오입니다. | 229 | 23 | 8 | 19 | 1 | WR Acc가 충분히 나오면서 WR Block이 함께 관측되면 fill/full pressure가 실제로 검증된 것입니다. |
| Async FIFO (Showcase) | mixed_stress | read/write를 섞어 일반 운용 구간에서 ordering과 accepted path를 동시에 검증하는 시나리오입니다. | 231 | 28 | 29 | 6 | 0 | WR Acc와 RD Acc가 함께 높게 나타나면 scoreboard ordering 검증이 활발히 수행된 것으로 해석합니다. |
| Async FIFO (Showcase) | drain_burst | queue를 비우는 방향으로 bias를 줘 empty 근처 동작과 read blocked path를 유도하는 시나리오입니다. | 231 | 10 | 24 | 0 | 18 | RD Acc와 RD Block이 함께 나타나면 drain과 underflow protection이 모두 검증된 것입니다. |
| Async FIFO (Showcase) | full_pressure | 깊이가 높은 상태에서 write를 지속적으로 인가해 backpressure와 full flag 일관성을 보는 시나리오입니다. | 231 | 26 | 11 | 16 | 0 | WR Block이 의미 있게 잡히면 DUT가 full 보호를 수행했고 monitor/scoreboard가 이를 포착한 것입니다. |
| Async FIFO (Showcase) | empty_pressure | 비어 있는 상태에서 read를 반복해 underflow protection과 empty flag 일관성을 확인하는 시나리오입니다. | 230 | 9 | 22 | 0 | 20 | RD Block이 의미 있게 나타나면 empty 보호 경로가 실제로 수행된 것입니다. |
| Async FIFO (Dedicated RTL) | fill_burst | queue depth를 빠르게 끌어올려 full 근처 동작과 write blocked path를 의도적으로 만든 시나리오입니다. | 229 | 23 | 8 | 19 | 1 | WR Acc가 충분히 나오면서 WR Block이 함께 관측되면 fill/full pressure가 실제로 검증된 것입니다. |
| Async FIFO (Dedicated RTL) | mixed_stress | read/write를 섞어 일반 운용 구간에서 ordering과 accepted path를 동시에 검증하는 시나리오입니다. | 231 | 28 | 29 | 6 | 0 | WR Acc와 RD Acc가 함께 높게 나타나면 scoreboard ordering 검증이 활발히 수행된 것으로 해석합니다. |
| Async FIFO (Dedicated RTL) | drain_burst | queue를 비우는 방향으로 bias를 줘 empty 근처 동작과 read blocked path를 유도하는 시나리오입니다. | 231 | 10 | 24 | 0 | 18 | RD Acc와 RD Block이 함께 나타나면 drain과 underflow protection이 모두 검증된 것입니다. |
| Async FIFO (Dedicated RTL) | full_pressure | 깊이가 높은 상태에서 write를 지속적으로 인가해 backpressure와 full flag 일관성을 보는 시나리오입니다. | 231 | 26 | 11 | 16 | 0 | WR Block이 의미 있게 잡히면 DUT가 full 보호를 수행했고 monitor/scoreboard가 이를 포착한 것입니다. |
| Async FIFO (Dedicated RTL) | empty_pressure | 비어 있는 상태에서 read를 반복해 underflow protection과 empty flag 일관성을 확인하는 시나리오입니다. | 230 | 9 | 22 | 0 | 20 | RD Block이 의미 있게 나타나면 empty 보호 경로가 실제로 수행된 것입니다. |
| Sync FIFO | fill_burst | queue depth를 빠르게 끌어올려 full 근처 동작과 write blocked path를 의도적으로 만든 시나리오입니다. | 64 | 31 | 15 | 33 | 1 | WR Acc가 충분히 나오면서 WR Block이 함께 관측되면 fill/full pressure가 실제로 검증된 것입니다. |
| Sync FIFO | simul_stress | sync FIFO에서 same-cycle read/write 정책을 강하게 두드리는 시나리오입니다. | 64 | 64 | 64 | 0 | 0 | WR Acc와 RD Acc가 같은 구간에서 동시에 높으면 동시 처리 정책 검증이 충분히 일어났다고 볼 수 있습니다. |
| Sync FIFO | drain_burst | queue를 비우는 방향으로 bias를 줘 empty 근처 동작과 read blocked path를 유도하는 시나리오입니다. | 64 | 19 | 31 | 0 | 33 | RD Acc와 RD Block이 함께 나타나면 drain과 underflow protection이 모두 검증된 것입니다. |
| Sync FIFO | flag_pressure | sync FIFO의 full/empty 근처를 반복적으로 두드려 flag 경계 조건과 blocked path를 강조하는 시나리오입니다. | 64 | 43 | 46 | 2 | 0 | WR Block 또는 RD Block이 함께 보이면 boundary pressure가 실제로 먹혔다는 의미입니다. |
| Sync FIFO | balanced_stream | 한쪽으로 치우치지 않은 steady-state traffic에서 sustained throughput과 flag 안정성을 보는 시나리오입니다. | 63 | 45 | 42 | 0 | 6 | WR Acc와 RD Acc가 균형 있게 유지되면 steady-state stream 검증 근거로 활용할 수 있습니다. |

## 시나리오 해석

- `fill_burst`: queue를 채워 full과 write blocked path를 확인합니다.
- `mixed_stress`: read/write가 혼재된 일반 운용 구간에서 ordering을 검증합니다.
- `drain_burst`: queue를 비워 empty와 read blocked path를 확인합니다.
- `full_pressure`: 꽉 찬 상태에서 backpressure를 확인합니다.
- `empty_pressure`: 비어 있는 상태에서 underflow protection을 확인합니다.
- `simul_stress`, `balanced_stream`: sync FIFO의 동시 read/write 정책과 steady-state traffic을 설명합니다.

## Coverage 해석

- summary CSV는 pass/fail만이 아니라 `wr_acc`, `rd_acc`, `wr_block`, `rd_block`를 함께 남깁니다.
- scenario CSV는 각 phase에서 accepted path와 blocked path 발생 횟수를 기록합니다.
- trace CSV는 sample 단위 depth 변화를 남겨 time-series plot과 histogram의 근거가 됩니다.

## Assertion과 자동 판정

### Async FIFO (Dedicated RTL)

- `async_fifo_if.sv`: write/read domain에서 `oFull && oEmpty` 동시 high 금지
- `async_fifo_if.sv`: reset 이후 `oEmpty=1`, `oFull=0` 기대
- `async_fifo_driver.svh`: `vif`, `transaction` null 여부 immediate assertion
- `async_fifo_scoreboard.svh`: mismatch 시 `$fatal`로 즉시 fail 처리

### Async FIFO (Showcase)

- `fifo_if.sv`: write/read domain에서 `oFull && oEmpty` 동시 high 금지
- `fifo_if.sv`: reset 이후 `oEmpty=1`, `oFull=0` 기대
- `fifo_driver.svh`: `vif`, `transaction` null 여부 immediate assertion
- `fifo_scoreboard.svh`: mismatch 시 `$fatal`로 즉시 fail 처리

### Sync FIFO

- `sync_fifo_if.sv`: `oFull && oEmpty` 동시 high 금지
- `sync_fifo_if.sv`: reset 이후 `oEmpty=1`, `oFull=0` 기대
- `sync_fifo_scoreboard.svh`: data/flag mismatch 시 즉시 fail 처리

## 타이밍 메모

- async FIFO는 driver clocking block이 `negedge`에서 요청을 인가하고, `pre_cb`가 `posedge #1step`, `mon_cb`가 다음 `negedge #1step`으로 샘플합니다.
- sync FIFO도 같은 discipline을 유지하되 single-clock 정책에 맞춰 pre-count 기반 scoreboard를 사용합니다.
- 따라서 그래프에 보이는 depth 변화는 DUT가 실제로 받아들인 transaction 흐름과 정합됩니다.

## 포트폴리오 패키지 경로

- HTML: `reports/html/systemverilog_python_visual_report_ko.html`
- Markdown: `reports/markdown/overview/systemverilog_python_visual_report_ko.md`
- 차트 폴더: `reports/html/assets`
- 데이터 폴더: `evidence/csv`
