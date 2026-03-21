# Async FIFO Dedicated RTL 보고서

## 1. 개요

- DUT: `src/async_fifo.sv`
- TB Top: `tb/async_fifo/tb_async_fifo.sv`
- 검증 목적:
  - 별도로 작성된 비동기 FIFO RTL이 실제 Gray-code pointer 기반 async FIFO로 동작하는지 확인
  - `fifo.sv` showcase와는 다른 RTL 구현체를 동일한 포트폴리오급 검증 구조로 재구성
  - dual-clock 환경에서 `full`, `empty`, read data ordering이 정상인지 self-checking 방식으로 검증

이 케이스는 `src/async_fifo.sv`의 reset polarity와 인터페이스 정의를 반영해 `tb/async_fifo/` 환경으로 분리한 사례입니다.

## 2. DUT 구조 해석

`src/async_fifo.sv`는 다음 특징을 갖는 비동기 FIFO입니다.

- write clock: `iWrClk`
- read clock: `iRdClk`
- reset: active-high `iRst`
- write request: `iWrEn`
- read request: `iRdEn`
- 입력 데이터: `iWData`
- 출력 데이터: `oRData`
- 상태 플래그: `oFull`, `oEmpty`

구성 항목은 다음과 같습니다.

- binary pointer와 Gray pointer를 각각 유지
- read pointer를 write domain으로 2-flop sync
- write pointer를 read domain으로 2-flop sync
- classic async FIFO 방식으로 full/empty를 계산
- read-side에서 수락된 read에 대해 `oRData`를 registered output으로 갱신

FSM 기반 모듈이 아니라 pointer/synchronizer 기반 제어 구조이며, 검증 항목은 상태 천이보다 clock-domain crossing 이후 flag 일관성과 data ordering에 맞춰집니다.

## 3. 테스트벤치 구조

### 3.1 파일 구성

- `tb/async_fifo/async_fifo_if.sv`
- `tb/async_fifo/objs/async_fifo_transaction.svh`
- `tb/async_fifo/components/async_fifo_generator.svh`
- `tb/async_fifo/components/async_fifo_driver.svh`
- `tb/async_fifo/components/async_fifo_monitor.svh`
- `tb/async_fifo/components/async_fifo_coverage.svh`
- `tb/async_fifo/components/async_fifo_scoreboard.svh`
- `tb/async_fifo/env/async_fifo_environment.svh`
- `tb/async_fifo/async_fifo_tb_pkg.sv`
- `tb/async_fifo/tb_async_fifo.sv`

### 3.2 역할 분리

- `transaction`
  - generator가 만든 stimulus 정보와 monitor가 관측한 sample 정보를 담는 공용 데이터 객체
- `generator`
  - 시나리오 phase에 따라 write/read enable 패턴을 제어
- `driver`
  - transaction을 write/read clock에 맞춰 실제 DUT 입력으로 변환
- `monitor`
  - write/read domain에서 각각 샘플을 떠서 scoreboard로 전달
- `coverage`
  - scenario, domain, accepted/blocked path, flag state를 기능 관점으로 집계
- `scoreboard`
  - reference queue model을 유지하며 read ordering과 flag 기반 accept/block 판정을 수행
- `environment`
  - mailbox/event 기반 연결, reset, 종료 시점 제어

## 4. 클래스별 상세 설명

### 4.1 `async_fifo_transaction`

주요 역할:

- random stimulus 필드 보관
- monitor sample 필드 보관
- scenario id와 scenario name 제공

핵심 필드:

- `iWrEn`, `iRdEn`, `iWData`
- `scenario_id`
- `isWrSample`, `isRdSample`
- `preFull`, `preEmpty`
- `oRData`, `oFull`, `oEmpty`

의미:

- `preFull`, `preEmpty`는 edge 직전 상태를 저장하는 값입니다.
- async FIFO는 full/empty가 동기화 지연을 가지므로, scoreboard는 edge 후 flag만 보면 안 되고 “해당 read/write가 받아들여질 수 있었는지”를 직전 상태 기준으로 판단해야 합니다.

### 4.2 `async_fifo_generator`

주요 역할:

- 전체 run을 5개 phase로 나눠 scenario-aware stimulus 생성

구성된 시나리오:

- `fill_burst`
  - write 위주로 빠르게 채우면서 full 도달을 유도
- `mixed_stress`
  - read/write를 함께 섞어 일반 운영 구간과 경합 구간을 만듦
- `drain_burst`
  - read 위주로 queue를 비우며 empty 근처 behavior를 관찰
- `full_pressure`
  - 이미 찬 상태에서 지속 write를 넣어 backpressure를 유도
- `empty_pressure`
  - 비어 있는 상태 혹은 거의 비어 있는 상태에서 지속 read를 넣어 underflow 방지 동작을 확인

비고:

- 단순 랜덤이 아니라 “phase-aware randomized scenario” 형태로 구성되어 검증 의도가 분명합니다.
- 각 scenario는 scoreboard 로그에 별도 집계되어 결과 해석이 쉽습니다.

### 4.3 `async_fifo_driver`

주요 역할:

- active-high reset 시퀀스 수행
- write/read 요청을 각 clock domain에 맞춰 drive

동작 흐름:

- `preset()`
  - reset assert
  - write/read clock 각각 몇 cycle 진행
  - reset deassert
- `run()`
  - generator가 넣은 transaction을 mailbox에서 수신
  - `fork`를 사용해 write path와 read path를 병렬 구동

왜 중요한가:

- async FIFO는 단일 clock DUT가 아니므로, write/read를 분리해서 drive하지 않으면 실제 동작 특성이 드러나지 않습니다.
- 이 TB는 write와 read를 각각의 edge에 맞춰 독립적으로 움직이게 하여 async 환경을 흉내냅니다.

### 4.4 `async_fifo_monitor`

주요 역할:

- write domain sample과 read domain sample을 각각 수집
- edge 직전 flag와 edge 후 DUT 상태를 같이 담아 scoreboard로 전달

핵심 구현 포인트:

- `pre_cb`가 `posedge clk` 기준 `#1step`으로 `preFull`, `preEmpty`, 요청 상태를 캡처
- `mon_cb`가 다음 `negedge clk` 기준 `#1step`으로 DUT 상태를 읽어서 transaction 생성

왜 이렇게 하나:

- scoreboard가 accepted/block 판정을 하려면 “요청 직전의 flag”가 필요합니다.
- read data와 플래그는 edge 후 갱신되므로, edge 직전과 직후를 함께 보관하는 방식이 필요합니다.

### 4.5 `async_fifo_coverage`

주요 역할:

- functional coverage를 수치화할 기본 데이터 수집

포함 항목:

- domain coverage
  - write tick / read tick
- scenario coverage
  - 5개 scenario hit 여부
- write path coverage
  - accepted / blocked
- read path coverage
  - accepted / blocked
- flag state coverage
  - normal / full / empty

보완 설명:

- 최신 Vivado xsim 로그에서는 `[SCB][COVERAGE] functional_coverage=100.00%`가 확인됩니다.
- 이 퍼센트는 covergroup instance의 `get_inst_coverage()` 값입니다.
- coverage class는 `option.per_instance = 1;`, `type_option.merge_instances = 1;`를 사용해 Vivado native functional coverage로 집계합니다.

### 4.6 `async_fifo_scoreboard`

주요 역할:

- reference queue model 유지
- write accepted 시 push
- read accepted 시 expected data와 DUT data 비교
- scenario별 통계와 최종 summary 출력

핵심 체크 로직:

- write accepted 조건:
  - `isWrSample && iWrEn && !preFull`
- read accepted 조건:
  - `isRdSample && iRdEn && !preEmpty`

이 기준이 중요한 이유:

- async FIFO는 flag가 CDC 지연과 함께 바뀌므로, scoreboard는 edge 이후 현재 flag가 아니라 edge 직전 flag를 기준으로 request acceptance를 판단해야 합니다.
- 이 방식 덕분에 full/empty 전환 구간에서도 false mismatch를 피할 수 있습니다.

최종 출력:

- `[SCB][SUMMARY]`
- `[SCB][COVERAGE]`
- `[SCB][SCENARIO]`
- `[SCB][PASS]` 또는 `$fatal`

### 4.7 `async_fifo_environment`

주요 역할:

- generator, driver, monitor, scoreboard 인스턴스화
- mailbox/event 연결
- reset 이후 병렬 실행
- scoreboard 완료 이벤트를 기준으로 테스트 종료

요약:

- UVM factory나 phase mechanism은 사용하지 않았고, 역할 분리와 top-level orchestration 중심으로 구성했습니다.

## 5. 전체 검증 흐름

1. `tb_async_fifo.sv`에서 DUT와 interface를 연결
2. environment 생성
3. driver가 reset sequence 수행
4. generator가 scenario 기반 transaction 생성
5. driver가 dual-clock 요청을 DUT에 인가
6. monitor가 write/read domain에서 sample 수집
7. scoreboard가 reference model과 비교
8. 모든 read tick이 끝나면 summary 출력 후 종료

## 6. 시나리오 상세 설명

이 환경은 5개 시나리오를 phase-aware randomized 형태로 구성했습니다.

- `fill_burst`
  - write 비중을 높여 FIFO 깊이를 끌어올림
  - full 근처에 도달했을 때 `wr_acc`와 `wr_block`이 함께 나타나는지가 핵심
- `mixed_stress`
  - read와 write를 혼합해 일반 운용 구간을 형성
  - dual-clock 환경에서 request가 엇갈릴 때 scoreboard가 ordering을 안정적으로 추적하는지 확인
- `drain_burst`
  - read 비중을 높여 queue를 비움
  - empty 직전과 empty 이후 read blocked path를 확인
- `full_pressure`
  - 이미 깊이가 높은 상태에서 추가 write를 지속적으로 인가
  - backpressure와 full flag 일관성이 핵심 관측 포인트
- `empty_pressure`
  - 거의 비었거나 비어 있는 상태에서 read를 지속적으로 인가
  - underflow protection과 empty flag 일관성이 핵심 관측 포인트

이 시나리오의 중요한 점은 단순 랜덤이 아니라는 것입니다. accepted path만 많이 나오면 scoreboard는 PASS가 나오더라도 boundary behavior를 충분히 설명하기 어렵습니다. 그래서 blocked path가 일부러 생기도록 pressure phase를 분리해 두었습니다.

## 7. Assertion

전용 interface assertion은 `async_fifo_if.sv`에 들어 있습니다.

- write domain에서 `oFull && oEmpty` 동시 high 금지
- read domain에서 `oFull && oEmpty` 동시 high 금지
- reset 직후 `oEmpty=1`, `oFull=0` 기대

의미:

- FIFO 플래그 기본 일관성 체크
- reset 이후 초기 상태 체크

한계:

- pointer Gray-code 자체를 직접 assertion으로 검증하지는 않음
- full/empty transition latency 자체를 property로 명시하지는 않음

현재 구조는 interface-level SVA와 scoreboard 중심 데이터 무결성 검증 조합입니다.

## 8. Coverage 해석

이번 실행 기준 summary는 다음과 같습니다.

- `sample=1153`
- `rd_tick=420`
- `pass=190`
- `fail=0`
- `wr_acc=96`
- `rd_acc=94`
- `wr_block=41`
- `rd_block=39`

coverage 항목은 다음 관점으로 읽을 수 있습니다.

- scenario hit
  - 5개 시나리오가 모두 최소 한 번 이상 실행되었는지 확인
- domain hit
  - write domain sample과 read domain sample이 모두 관측되었는지 확인
- write path hit
  - write accepted와 write blocked가 모두 발생했는지 확인
- read path hit
  - read accepted와 read blocked가 모두 발생했는지 확인
- flag hit
  - normal, full, empty 상태가 모두 관측되었는지 확인

coverage는 동작 여부보다 의도한 시나리오와 경계 상태의 관측 여부를 정량화합니다.

시나리오별 집계:

- `fill_burst`
  - 채우기 중심, full 도달과 write block 확인
- `mixed_stress`
  - read/write 혼합 상황에서 accepted path 다수 확인
- `drain_burst`
  - drain과 read block이 뚜렷하게 관찰
- `full_pressure`
  - backpressure에 따른 write block 관찰
- `empty_pressure`
  - underflow 보호에 따른 read block 관찰

검증 관점 해석:

- accepted path만 본 것이 아니라 blocked path도 충분히 발생함
- full/empty flag가 실제로 테스트 흐름 안에서 관찰됨
- read ordering mismatch가 0건이므로 queue model과 DUT ordering이 일치

최신 실행 기준 시나리오별 coverage 집계는 아래와 같습니다.

| 시나리오 | 샘플 | WR Acc | RD Acc | WR Block | RD Block | 커버리지 해석 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `fill_burst` | 229 | 23 | 8 | 19 | 1 | fill/full pressure가 실제로 관측됐고 write blocked path가 함께 검증됐습니다. |
| `mixed_stress` | 231 | 28 | 29 | 6 | 0 | read/write accepted가 균형 있게 발생해 ordering 검증 구간으로 해석됩니다. |
| `drain_burst` | 231 | 10 | 24 | 0 | 18 | drain과 empty 보호가 동시에 관찰된 구간입니다. |
| `full_pressure` | 231 | 26 | 11 | 16 | 0 | backpressure에 따른 blocked write가 의도대로 나왔습니다. |
| `empty_pressure` | 230 | 9 | 22 | 0 | 20 | underflow protection과 empty flag 일관성이 read blocked 수치로 드러납니다. |

## 9. clocking block과 타이밍 정책

현재 dedicated async FIFO 환경은 `clocking block`을 실제 검증 타이밍 구조의 중심으로 사용합니다.

현재 타이밍 규칙은 아래와 같습니다.

- driver
  - `wr_drv_cb`, `rd_drv_cb`가 `negedge`에서 write/read 요청을 인가
  - DUT는 각 `posedge`에서 안정된 입력을 봄
- monitor
  - `pre_cb`가 `posedge` 기준 `#1step`으로 edge 직전 요청과 flag를 저장
  - `mon_cb`가 다음 `negedge` 기준 `#1step`으로 DUT 결과를 수집
- scoreboard
  - `preFull`, `preEmpty`를 기준으로 accepted 여부 판정
  - accepted write만 model queue에 push
  - accepted read만 pop 후 `oRData` 비교

이 구조는 수동 `#1` 지연 대신 clocking block에 타이밍 의도를 두고, driver는 입력 안정화, monitor는 판정 근거와 결과 수집, scoreboard는 accepted transaction 추적을 담당합니다.

## 10. 최종 검증 결과

Vivado xsim 기준 결과:

- 로그: `evidence/logs/async_fifo_src_vivado.log`
- 보존 위치: `reports/markdown/module_reports/async_fifo_src_report_ko.md`
- 결과: `[SCB][PASS] async_fifo scoreboard completed without mismatches`

핵심 요약:

- `src/async_fifo.sv`는 실제 async FIFO DUT로 판단 가능
- 별도 `tb/async_fifo/` 구조를 통해 독립 검증 완료
- dual-clock scenario, scoreboard, assertion, coverage 관점이 모두 포함됨
- 기존 RTL 구현체를 별도 환경으로 구조화해 검증한 사례
