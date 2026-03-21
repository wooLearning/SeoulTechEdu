# Sync FIFO 모듈 상세 보고서

## 1. 대상

- DUT: `src/sync_fifo.sv`
- TB Top: `tb/sync_fifo/tb_sync_fifo.sv`
- 패키지: `tb/sync_fifo/sync_fifo_tb_pkg.sv`

async FIFO보다 구조는 단순하지만, queue 기반 reference model과 full/empty flag 검증을 읽기 쉬운 형태로 다루는 사례입니다.

## 2. DUT 요약

`sync_fifo.sv`는 단일 clock 기반 FIFO입니다.

특징:

- `iClk` 단일 클록 사용
- `iWrEn`, `iRdEn` 동시 입력 가능
- 내부 count 기반 full/empty 계산
- read/write 동시 수행 가능
- full 상태에서도 read가 동시에 발생하면 write 허용

단일 FIFO 구조이지만 동시 read/write와 full/empty update 타이밍이 주요 검증 항목입니다.

## 3. 검증 환경 구성

### 3-1. top testbench

`tb_sync_fifo.sv`

역할:

- 단일 클록 생성
- DUT 연결
- interface 생성
- environment 실행

### 3-2. interface

`sync_fifo_if.sv`

역할:

- `iClk`, `iRstn`, `iWrEn`, `iRdEn`, `iWData`, `oRData`, `oFull`, `oEmpty`를 그룹화

### 3-3. transaction

`objs/sync_fifo_transaction.svh`

주요 필드:

- stimulus
  - `iWrEn`
  - `iRdEn`
  - `iWData`
- observed
  - `oRData`
  - `oFull`
  - `oEmpty`

async FIFO와 달리 단일 클록이라 pre-edge state 필드가 따로 필요하지 않습니다.

## 4. 클래스별 역할

### 4-1. generator

`components/sync_fifo_generator.svh`

역할:

- 랜덤 write/read 요청 생성
- fill/drain bias 적용
- 동시 read/write 케이스 주기적으로 삽입

의미:

- 짧은 run에서도 queue가 차고 비는 과정을 모두 보도록 의도된 자극기입니다.

### 4-2. driver

`components/sync_fifo_driver.svh`

역할:

- `negedge iClk`에 request 인가
- DUT가 `posedge iClk`에서 안정된 입력을 보게 함
- reset preset 수행

### 4-3. monitor

`components/sync_fifo_monitor.svh`

역할:

- `mon_cb`를 통해 cycle 완료 후 snapshot 생성
- 요청과 응답을 함께 scoreboard로 전달

의미:

- `pre-count` 기반 acceptance 판정과 post-update 결과 비교가 어긋나지 않도록, driver phase와 분리된 monitor clocking block에서 결과를 수집합니다.

### 4-4. coverage

`components/sync_fifo_coverage.svh`

포함 항목:

- `iWrEn`
- `iRdEn`
- `oFull`
- `oEmpty`
- scenario, request mix, accepted/blocked path, flag 상태 coverage

의미:

- 동기 FIFO의 핵심 조합인 read/write 요청과 flag 상태 조합을 수집합니다.

### 4-5. scoreboard

`components/sync_fifo_scoreboard.svh`

핵심 역할:

- queue 기반 reference model 유지
- pre_count 기준으로 read acceptance 계산
- same-cycle read가 있으면 full 상태에서도 write acceptance 허용
- post-transaction queue depth 기준으로 full/empty 기대값 계산

핵심 포인트:

- `wRdAccept = tr.iRdEn && (wPreCount > 0)`
- `wWrAccept = tr.iWrEn && ((wPreCount < rDepth) || wRdAccept)`

이 로직 덕분에 DUT의 same-cycle read/write 정책을 scoreboard가 정확히 따라갑니다.

### 4-6. environment

`env/sync_fifo_environment.svh`

역할:

- component 생성 및 연결
- preset 후 병렬 실행
- scoreboard 완료 시 전체 종료

## 5. 전체 흐름

1. generator가 transaction 생성
2. driver가 negedge에서 입력 세팅
3. DUT가 posedge에서 처리
4. monitor가 post-edge 결과 샘플링
5. scoreboard가 queue model과 비교
6. scoreboard가 flag와 read data를 동시에 검증

## 6. 시나리오

주요 시나리오는 다음과 같습니다.

- reset 이후 empty 확인
- write 위주 fill
- read 위주 drain
- write/read 동시 요청
- full 상태에서 read 없이 write 시 차단
- full 상태에서 read와 동시 write 시 허용
- empty 상태에서 read 시 무효 처리

세부 의도는 아래와 같습니다.

- `fill_burst`
  - write 비중을 높여 FIFO가 실제로 차는 과정을 유도
  - full flag와 write accepted/blocked 경계를 관찰
- `simul_stress`
  - read와 write를 동시에 거는 빈도를 높여 same-cycle policy를 집중 검증
  - 이 구간은 sync FIFO의 핵심 차별점인 동시 처리 규칙을 확인하는 데 중요
- `drain_burst`
  - read 위주로 queue를 비우고 empty 근처 behavior를 확인
- `flag_pressure`
  - full 또는 empty 근처에서 경계 상태를 반복적으로 자극
  - blocked write, blocked read를 모두 관찰하기 위한 pressure 구간
- `balanced_stream`
  - 너무 한쪽으로 치우치지 않은 steady-state traffic
  - normal 상태에서 read/write가 반복되는 일반 운용 구간

sync FIFO는 단일 clock DUT이며, 시나리오를 정상 처리, 동시 처리, 경계 압박으로 분리했습니다.

## 7. assertion 전략

이 환경은 interface-level SVA와 scoreboard 기반 자동 판정을 함께 사용합니다.

현재 자동 판정 방식:

- `sync_fifo_if.sv`
  - `oFull && oEmpty` 동시 high 금지
  - reset 이후 `oEmpty=1`, `oFull=0` 기대
- randomize failure 시 `$fatal`
- scoreboard mismatch 시 `$fatal`

정리:

- SVA assertion: 있음
- immediate assertion/자동 fail: 있음
- 핵심 판정 장치: scoreboard

## 8. coverage 전략

functional coverage는 구현돼 있습니다.

관측 대상:

- scenario hit
- request mix 분포
- write/read accepted 및 blocked 경로
- full/empty/normal 상태

한계:

- count boundary 전용 temporal coverage는 없음
- assertion coverage 리포트는 없음

coverage 항목을 해석하면 아래와 같습니다.

- `cp_scenario`
  - 5개 시나리오가 모두 실제 실행되었는지 확인
- `cp_req_mix`
  - idle, write-only, read-only, read+write 동시 요청이 모두 발생했는지 확인
  - sync FIFO에서는 이 항목이 특히 중요하며, `both` bin이 same-cycle policy 검증의 기초가 됨
- `cp_wr_path`
  - write accepted와 write blocked를 구분
  - full 상태에서도 same-cycle read가 있으면 write를 허용하는 DUT 정책이 반영되는지 확인
- `cp_rd_path`
  - read accepted와 read blocked를 구분
  - empty 보호가 제대로 작동하는지 확인
- `cp_flag_state`
  - full, empty, normal 상태 모두 관찰 여부 확인
- `cx_scenario_req`
  - 어떤 시나리오에서 어떤 request mix가 실제로 발생했는지 연결
- `cx_scenario_flag`
  - 특정 시나리오에서 full 또는 empty가 실제로 발생했는지 연결

sync FIFO coverage는 same-cycle read/write와 flag state를 함께 다룬다는 점이 핵심입니다.

최신 실행 기준 시나리오별 coverage 집계는 아래와 같습니다.

| 시나리오 | 샘플 | WR Acc | RD Acc | WR Block | RD Block | 커버리지 해석 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `fill_burst` | 64 | 31 | 15 | 33 | 1 | fill boundary에서 write blocked가 크게 발생해 full 근처 동작을 설명합니다. |
| `simul_stress` | 64 | 64 | 64 | 0 | 0 | same-cycle read/write 정책이 가장 강하게 exercised된 구간입니다. |
| `drain_burst` | 64 | 19 | 31 | 0 | 33 | drain과 empty 보호가 동시에 관찰된 구간입니다. |
| `flag_pressure` | 64 | 43 | 46 | 2 | 0 | full/empty 경계 상태를 반복적으로 두드린 pressure 구간입니다. |
| `balanced_stream` | 63 | 45 | 42 | 0 | 6 | steady-state stream과 경미한 empty pressure를 함께 확인합니다. |

## 9. clocking block과 타이밍 정책

현재 sync FIFO 환경도 `clocking block` 기반 timing discipline으로 정리되어 있습니다.

- driver
  - `drv_cb`가 `negedge iClk`에서 `iWrEn`, `iRdEn`, `iWData`를 세팅
  - DUT는 다음 `posedge iClk`에서 안정된 입력을 봄
- monitor
  - `mon_cb`가 다음 `negedge iClk` 기준 `#1step`으로 snapshot 생성
  - DUT sequential update가 끝난 뒤의 `oRData`, `oFull`, `oEmpty`를 수집
- scoreboard
  - pre-count를 기준으로 read acceptance 계산
  - same-cycle read가 있으면 full 상태에서도 write acceptance를 허용

sync FIFO는 async처럼 pre-edge flag를 transaction에 따로 담지 않지만, drive phase와 observe phase를 clocking block으로 분리해 request와 결과를 정렬합니다.

## 10. 요약

- queue model 기반 FIFO 검증
- same-cycle read/write 정책을 scoreboard에 반영한 설계
- full/empty flag를 데이터 정합성과 함께 검증
- async FIFO보다 읽기 쉬운 구조로 verification 사고방식 설명 가능

## 11. 개선 아이디어

- count 변화에 대한 SVA property 추가
- full to not-full, empty to not-empty transition 전용 coverpoint 추가
- simultaneous read/write 빈도 제어 시나리오 세분화
