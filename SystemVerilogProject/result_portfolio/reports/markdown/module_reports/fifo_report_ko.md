# Async FIFO 모듈 상세 보고서

## 1. 대상

- DUT: `src/fifo.sv`
- TB Top: `tb/fifo/tb_fifo.sv`
- 패키지: `tb/fifo/fifo_tb_pkg.sv`

이 모듈은 `veri1` 포트폴리오에서 가장 중요한 대표 사례입니다. 비동기 FIFO라는 특성상 단일 클록 설계보다 검증 포인트가 풍부하고, CDC를 고려한 검증 사고방식을 보여주기 좋습니다.

## 2. DUT 요약

`fifo.sv`는 write clock과 read clock이 서로 다른 dual-clock FIFO입니다.

- write domain
  - `iWrClk`
  - `iWrEn`
  - `iWData`
- read domain
  - `iRdClk`
  - `iRdEn`
  - `oRData`
- 상태 신호
  - `oFull`
  - `oEmpty`

핵심 구현 포인트는 다음과 같습니다.

- Gray-code pointer 사용
- write pointer와 read pointer의 clock domain crossing 처리
- full/empty를 포인터 비교 기반으로 계산
- read data는 read domain에서 등록

## 3. 검증 환경 구성

### 3-1. top testbench

`tb_fifo.sv`의 역할은 아래와 같습니다.

- 비동기 write/read clock 생성
- DUT 인스턴스화
- `fifo_if` 생성
- `fifo_environment` 생성 및 실행

즉, top TB는 전체 orchestration을 담당하고 실제 검증 로직은 class 기반 환경으로 위임합니다.

### 3-2. interface

`fifo_if.sv`는 DUT와 TB를 연결하는 공통 접점입니다.

- write domain 신호
- read domain 신호
- reset
- full/empty
- read data

현재 구조에서는 `clocking block`을 실제 샘플링까지 포함해 사용합니다. driver / pre-sample / post-sample을 분리해 비동기 도메인의 판정 시점과 관측 시점을 명시적으로 드러냅니다.

### 3-3. transaction class

`objs/fifo_transaction.svh`는 한 번의 자극 또는 관측 샘플을 담는 객체입니다.

주요 필드는 다음과 같습니다.

- request 측
  - `iWrEn`
  - `iRdEn`
  - `iWData`
- monitor tag
  - `isWrSample`
  - `isRdSample`
- acceptance 판단용 pre-state
  - `preFull`
  - `preEmpty`
- response/state 측
  - `oRData`
  - `oFull`
  - `oEmpty`

특히 `preFull`, `preEmpty`는 아주 중요합니다. FIFO에서는 enable이 1이라고 해서 항상 transaction이 수락되는 것이 아니므로, active edge 직전 상태를 따로 저장해야 scoreboard가 정확한 accepted transaction만 추적할 수 있습니다.

## 4. 클래스별 역할

### 4-1. generator

`components/fifo_generator.svh`

역할:

- 랜덤 write/read 요청 생성
- run 초반에는 fill 경향, 후반에는 drain 경향을 주도록 bias 적용
- 주기적으로 write/read 동시 요청도 넣음

의미:

- 짧은 시뮬레이션에서도 empty 상태, fill 상태, mixed traffic가 고르게 나오도록 의도된 generator입니다.

### 4-2. driver

`components/fifo_driver.svh`

역할:

- write domain에서는 write-driver clocking block으로 `negedge iWrClk`에 입력을 세팅하고 `posedge iWrClk`에서 DUT가 안정된 값을 보게 함
- read domain에서도 같은 방식으로 `iRdEn`을 인가
- reset preset 수행

의미:

- 비동기 FIFO에서는 두 클록 도메인을 각자 독립적으로 다뤄야 하므로, driver가 두 domain 타이밍을 분리해서 관리합니다.

### 4-3. monitor

`components/fifo_monitor.svh`

역할:

- write domain sample 수집
- read domain sample 수집
- `pre_cb`로 active edge 직전 요청과 flag를 저장
- `mon_cb`로 DUT 출력이 반영된 뒤의 snapshot 생성

의미:

- 이 monitor는 단순 신호 복사기가 아니라, scoreboard가 “실제 accepted transaction”을 판정할 수 있도록 pre/post edge 정보를 정리하는 역할까지 수행합니다.

### 4-4. coverage

`components/fifo_coverage.svh`

역할:

- write sample / read sample 구분
- write request on/off 및 transition
- read request on/off 및 transition
- full / empty 상태
- `cp_kind x cp_full x cp_empty` cross 수집

의미:

- coverage는 “어떤 종류의 시점에서 어떤 상태를 봤는가”를 수집합니다.
- 특히 async FIFO에서는 read tick과 write tick이 서로 다른 의미를 가지므로 `cp_kind`가 중요합니다.

### 4-5. scoreboard

`components/fifo_scoreboard.svh`

역할:

- queue 기반 reference model 유지
- accepted write만 queue에 push
- accepted read만 queue에서 pop 후 data compare
- summary/pass/fail 출력

핵심 로직:

- `tr.iWrEn && !tr.preFull`
  - 실제 write acceptance 조건
- `tr.iRdEn && !tr.preEmpty`
  - 실제 read acceptance 조건

즉, scoreboard는 enable만 보고 판단하지 않고, 직전 full/empty 상태를 기반으로 “진짜 수락된 트랜잭션”만 reference model에 반영합니다.

### 4-6. environment

`env/fifo_environment.svh`

역할:

- generator, driver, monitor, scoreboard 생성
- mailbox/event 연결
- `drv.preset()` 실행
- parallel run 시작
- scoreboard 완료 시 전체 종료

의미:

- environment는 실행 제어자 역할을 합니다.
- 종료 시점을 scoreboard가 소유하게 함으로써 “목표 sample 수를 다 봤는가”를 기준으로 테스트를 종료합니다.

## 5. 전체 데이터 흐름

흐름은 아래와 같습니다.

1. generator가 transaction 생성
2. generator가 `gen2drv_mbox`로 driver에 전달
3. driver가 write/read clock domain에 맞춰 DUT에 입력 인가
4. monitor가 pre-edge 상태와 post-edge 결과를 모아 transaction 생성
5. monitor가 `mon2scb_mbox`로 scoreboard에 전달
6. scoreboard가 queue reference model과 비교
7. scoreboard가 완료된 sample마다 내부 통계 업데이트
8. 목표 read tick 수 도달 시 summary 출력 후 종료

## 6. 검증 시나리오

이 환경이 실제로 커버하려는 시나리오는 다음과 같습니다.

- reset 후 empty 상태 확인
- write만 계속 들어오는 fill phase
- read만 비중이 커지는 drain phase
- read/write 동시 요청
- full 상태에서 write 요청 무시
- empty 상태에서 read 요청 무시
- accepted read 시 FIFO 순서 보장

즉, 단순 랜덤이 아니라 phase bias를 둔 constrained-random 시나리오입니다.

시나리오를 조금 더 자세히 풀면 아래와 같습니다.

- `fill_burst`
  - write 비중을 높여 queue depth를 빠르게 끌어올림
  - 목표는 full 플래그 관찰과 write blocked path 유도
- `mixed_stress`
  - write와 read를 함께 섞어 일반 동작 구간을 형성
  - accepted write와 accepted read가 교차하면서 scoreboard ordering 검증이 가장 활발히 일어나는 구간
- `drain_burst`
  - read 비중을 높여 queue를 비움
  - empty 직전과 empty 이후의 read block을 관찰하는 구간
- `full_pressure`
  - 이미 깊이가 높은 상태에서 write를 지속적으로 요청
  - DUT가 추가 write를 막는지, monitor가 blocked path를 잡는지 확인
- `empty_pressure`
  - 깊이가 낮거나 비어 있는 상태에서 read를 지속적으로 요청
  - underflow 보호와 empty flag 일관성을 검증

포트폴리오 관점에서 중요한 점은 “accepted path만 많이 나왔다”가 아니라, blocked path도 의도적으로 만들어 full/empty 보호 동작이 숫자로 남도록 설계했다는 점입니다.

## 7. assertion 전략

이 모듈의 showcase 환경에는 interface-level SVA와 immediate assertion, scoreboard 기반 자동 판정이 함께 들어 있습니다.

구성은 다음과 같습니다.

- `fifo_if.sv`
  - write/read domain에서 `oFull && oEmpty` 동시 high 금지
  - reset 이후 `oEmpty=1`, `oFull=0` 기대
- `fifo_driver.svh`
  - `vif`와 `transaction` null 여부 immediate assertion
- `fifo_scoreboard.svh`
  - expected data 또는 expected flag mismatch 시 `$fatal`

정리하면:

- SVA assertion: 있음
- immediate assertion: 있음
- 핵심 자동 판정: scoreboard 기반 self-checking

## 8. coverage 전략

functional coverage는 구현돼 있습니다.

포함 항목:

- write/read sample 종류
- request on/off
- request transition
- full/empty 상태
- sample 종류와 flag 상태의 cross

한계:

- assertion coverage 리포트는 없음
- CDC 특화 corner를 위한 별도 temporal property coverage는 없음

coverage를 조금 더 실무적으로 해석하면 다음과 같습니다.

- `cp_domain`
  - write domain sample과 read domain sample이 모두 실제로 관측됐는지 확인
  - async FIFO에서 두 domain을 모두 다루고 있다는 증거
- `cp_scenario`
  - 5개 phase 시나리오가 최소 한 번 이상 실행됐는지 확인
- `cp_wr_path`
  - write idle, write accepted, write blocked가 모두 발생했는지 확인
  - 특히 blocked bin은 full pressure가 실제로 동작했는지를 보여줌
- `cp_rd_path`
  - read idle, read accepted, read blocked 관측 여부 확인
  - blocked bin은 empty pressure와 underflow protection 증빙
- `cp_flag_state`
  - normal, full, empty 상태가 모두 관측됐는지 확인
- `cx_scenario_domain`
  - 모든 시나리오가 write/read domain 중 어디에서 관측됐는지 연결
- `cx_scenario_flag`
  - 특정 시나리오에서 full 또는 empty가 실제로 발생했는지 연결

즉, coverage의 핵심 메시지는 “랜덤을 많이 돌렸다”가 아니라, scenario와 boundary state가 서로 연결되어 실제로 관측되었다는 점입니다.

최신 실행 기준 시나리오별 coverage 집계는 아래와 같습니다.

| 시나리오 | 샘플 | WR Acc | RD Acc | WR Block | RD Block | 커버리지 해석 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `fill_burst` | 229 | 23 | 8 | 19 | 1 | fill/full pressure가 실제로 발생했고 write blocked path가 관측됐음을 보여줍니다. |
| `mixed_stress` | 231 | 28 | 29 | 6 | 0 | accepted read/write가 동시에 활발히 발생해 ordering 검증 구간으로 해석됩니다. |
| `drain_burst` | 231 | 10 | 24 | 0 | 18 | drain과 empty 보호가 함께 관찰된 구간입니다. |
| `full_pressure` | 231 | 26 | 11 | 16 | 0 | full 근처 backpressure를 반복적으로 유도해 blocked write를 증빙합니다. |
| `empty_pressure` | 230 | 9 | 22 | 0 | 20 | underflow protection과 empty flag 일관성을 read blocked 수치로 설명합니다. |

## 9. clocking block과 타이밍 정책

현재 `fifo` showcase는 `clocking block`을 중심으로 drive/sample discipline을 구성합니다.

- driver는 `wr_drv_cb`, `rd_drv_cb`를 통해 `negedge iWrClk`, `negedge iRdClk`에 요청을 세팅
- `wr_pre_cb`, `rd_pre_cb`는 `posedge` 기준 `#1step`으로 `preFull`, `preEmpty`와 요청 상태를 저장
- `wr_mon_cb`, `rd_mon_cb`는 다음 `negedge` 기준 `#1step`으로 `oRData`, `oFull`, `oEmpty`를 샘플링

이 타이밍을 선택한 이유는 async FIFO에서 acceptance를 정확히 판정하려면 edge 직전 상태와 edge 직후 결과를 분리해야 하기 때문입니다.

정리하면 아래와 같습니다.

- driver의 역할
  - DUT active edge 전에 입력을 고정
- monitor의 역할
  - acceptance 기준이 되는 pre-state와 결과 state를 함께 전달
- scoreboard의 역할
  - `preFull`, `preEmpty`를 기준으로 accepted transaction만 reference queue에 반영

즉, 단순 지연문에 의존하지 않고 clocking block 자체에 타이밍 의도를 담아 acceptance 판정과 결과 관측을 분리한 구조입니다.

## 10. 포트폴리오에서 강조할 포인트

- 비동기 clock domain을 분리해 다루는 driver/monitor 구조
- accepted transaction 중심 scoreboard 설계
- 단순 결과 비교를 넘어 pre-state를 저장해 판정하는 구조
- class 기반 custom UVM-style verification 구조
- coverage 수집과 self-checking 로그 출력

## 11. 현재 한계 및 개선 아이디어

- 기본 flag/reset SVA만 있고 CDC 특화 property는 아직 없음
- coverage 결과가 현재 로그에서 높게 나오지 않아 coverage plan 추가 개선 여지 있음
- CDC 전용 property나 pointer consistency check를 추가하면 더 강한 포트폴리오 사례가 될 수 있음
