# 검증 개요

## 목적

이 프로젝트의 목적은 단순히 RTL을 작성했다는 사실만 보여주는 것이 아니라, SystemVerilog를 사용해 검증 환경을 구조적으로 설계하고, 자동 판정과 결과 해석까지 연결할 수 있다는 점을 포트폴리오 관점에서 명확하게 보여주는 것입니다.

즉, 이 프로젝트는 아래 두 축을 동시에 강조합니다.

- RTL 구조를 이해하고 핵심 동작을 검증 포인트로 바꾸는 능력
- UVM 스타일의 역할 분리와 self-checking 기반 검증 환경을 직접 설계하는 능력

## 검증 아키텍처

showcase 환경은 정식 IEEE UVM 라이브러리를 사용하지 않고, UVM에서 자주 보이는 역할 분리를 참고한 커스텀 구조로 작성되어 있습니다.

- `transaction`
  - 한 번의 stimulus 또는 한 번의 monitor sample을 담는 데이터 객체
  - generator, driver, monitor, scoreboard가 동일한 데이터 단위를 공유하게 해줌
- `generator`
  - constrained-random 기반으로 stimulus를 생성
  - 단순 랜덤이 아니라 시뮬레이션 구간별로 phase bias를 적용해 특정 상태를 의도적으로 유도
- `driver`
  - transaction을 실제 DUT interface 신호로 변환
  - DUT가 active edge에서 안정된 입력을 보도록 inactive phase에서 요청을 배치
- `monitor`
  - DUT 입출력과 상태 신호를 관측해 transaction으로 재구성
  - async FIFO의 경우 pre-edge 상태와 post-edge 결과를 모두 담아 acceptance 판정 근거를 제공
- `coverage`
  - 시나리오 hit, request mix, accepted/blocked path, flag state를 기능 관점에서 집계
- `scoreboard`
  - queue 기반 reference model 또는 상태 추적 로직으로 DUT 결과를 자동 비교
  - mismatch 발생 시 즉시 fail 처리하고 summary를 출력
- `environment`
  - generator, driver, monitor, coverage, scoreboard를 연결
  - reset, 병렬 실행, 종료 조건을 통합 관리
- `interface`
  - DUT 연결 신호를 한 곳에 모아 가독성을 높이고, driver/monitor의 공용 접점 역할을 수행

이 구조는 포트폴리오 리뷰어가 파일만 보더라도 “어디서 stimulus를 만들고, 어디서 drive하고, 어디서 판정하는지”를 빠르게 파악할 수 있다는 장점이 있습니다.

## 구조 분리 관점

이번 정리에서 특히 강조한 부분은 “한 파일에 검증 코드가 길게 몰려 있는 형태” 대신 역할 단위로 파일을 분리했다는 점입니다.

- `objs/`
  - transaction class
- `components/`
  - generator, driver, monitor, coverage, scoreboard
- `env/`
  - 전체 environment
- top TB
  - DUT instantiation, clock/reset generation, environment 실행

이 방식은 다음 프로젝트에도 동일한 골격을 그대로 재사용할 수 있기 때문에 템플릿화 가치가 높습니다.

## 시나리오 설계 철학

이번 showcase의 시나리오는 완전한 pseudo-random보다 “의도가 읽히는 randomized verification”에 가깝게 설계했습니다.

- fill 계열 구간
  - queue를 빠르게 채워 full 근처 상태를 유도
- mixed 계열 구간
  - read/write가 혼재된 일반 동작 구간을 형성
- drain 계열 구간
  - queue를 비워 empty 근처 상태를 유도
- pressure 계열 구간
  - full 상태에서 추가 write, empty 상태에서 추가 read를 걸어 blocked path를 관측
- balanced/simul 계열 구간
  - sync FIFO에서 동시 read/write 정책을 적극적으로 자극

즉, 시나리오는 단순히 “랜덤을 많이 줬다”가 아니라, accepted path와 blocked path가 모두 발생하게 하여 scoreboard와 coverage가 의미 있는 숫자를 만들도록 설계했습니다.

UART 계열 확장도 같은 철학을 따릅니다.

- `uart_rx`
  - valid frame과 invalid stop frame을 분리해 positive/negative path를 함께 설명
- `uart_fifo`
  - fill/balanced/burst phase를 나눠 FIFO depth와 ordering을 동시에 설명
- `uart_tx_fifo`
  - fill/balanced/burst enqueue phase로 buffered transmit path를 설명
- `uart_async_fifo`
  - fill/balanced/drain async phase로 dual-clock buffer behavior를 설명

## Coverage 전략

Coverage는 이 프로젝트에서 중요한 어필 포인트입니다. 다만 여기서 말하는 coverage는 단일 툴의 자동 coverage 퍼센트만 뜻하지 않습니다.

현재 구조는 두 층으로 coverage를 해석합니다.

- covergroup 기반 항목 정의
  - scenario
  - domain 또는 request mix
  - accepted / blocked path
  - full / empty / normal 상태
  - scenario x domain 또는 scenario x flag cross
- hit 기반 요약 coverage
  - 각 주요 검증 항목이 실제로 한 번 이상 관측되었는지 집계
  - `get_coverage()`로 요약 퍼센트를 계산

이렇게 한 이유는 XSim 로그의 기본 functional coverage 출력이 프로젝트 구조상 제한적으로 보일 수 있기 때문입니다. 그래서 포트폴리오에서는 “툴 기본 퍼센트 숫자” 하나만 제시하는 대신, 어떤 시나리오가 실제로 실행되었고 어떤 accepted/blocked path가 관측되었는지를 함께 설명하도록 구성했습니다.

## Assertion 전략

대표 showcase 3종(`fifo`, `async_fifo`, `sync_fifo`)에는 모두 interface 수준의 기본 SVA가 들어 있습니다.

- reset 이후 `oEmpty=1`, `oFull=0` 기대
- `oFull`과 `oEmpty`가 동시에 1이 되는 비정상 상태 금지

즉, 현재 구조는 “기본적인 protocol sanity assertion + reference model 기반 self-checking” 조합으로 이해하면 됩니다. 더 복잡한 property보다는, 포트폴리오에서 설명 가능한 수준의 SVA와 scoreboard 정합성 검증을 함께 두는 방향을 택했습니다.

UART 계열도 같은 원칙을 따릅니다.

- `uart_rx`
  - tick pulse width, `oValid/oData` X/Z, invalid frame negative check
- `uart_fifo`
  - tick pulse width, `full && empty` 금지, `oPopValid/oPopData` X/Z 금지
- `uart_tx_fifo`
  - tick pulse width, `oLaunchValid/oLaunchData` X/Z 금지, busy 중 serial TX X/Z 금지
- `uart_async_fifo`
  - write-domain tick pulse width, read-domain full/empty sanity, `oPopData` X/Z 금지

## Clocking Block과 타이밍 정책

이 프로젝트는 최종 상태에서 `clocking block`을 실제 샘플링 구조까지 포함해 사용합니다. 다만 단순히 문법만 넣은 것이 아니라, XSim에서 안정적으로 통과하도록 `pre-edge`와 `post-update`를 서로 다른 clocking block으로 분리했습니다.

- driver
  - inactive phase인 `negedge` 기반 driver clocking block에서 요청과 write data를 인가
  - DUT는 `posedge`에서 안정된 입력을 보게 됨
- monitor
  - `pre_cb`는 `posedge` 기준 `#1step`으로 edge 직전 요청/flag를 저장
  - `mon_cb`는 다음 `negedge` 기준 `#1step`으로 DUT 업데이트가 끝난 결과를 수집
- scoreboard
  - async FIFO는 `preFull`, `preEmpty`로 accepted 여부를 계산
  - sync FIFO는 pre-count와 same-cycle read/write 정책으로 accepted 여부를 계산

즉, driver는 “안정된 입력 제공”, monitor는 “판정 근거와 결과를 분리 수집”, scoreboard는 “실제 수락된 transaction만 모델에 반영”이라는 역할 분담을 갖습니다.

## Showcase 1: Async FIFO

- DUT: `src/fifo.sv`
- TB top: `tb/fifo/tb_fifo.sv`

주요 검증 포인트는 다음과 같습니다.

- write/read가 서로 다른 클록 도메인에서 동작하는 비동기 환경 검증
- full/empty에 따라 실제 수락된 transaction만 reference queue에 반영
- read acceptance 시점과 read data 비교를 분리해 CDC 특성을 고려한 검증
- monitor가 write-domain sample과 read-domain sample을 구분해 scoreboard로 전달
- coverage를 통해 write/read/full/empty 조합이 실제로 관찰되었는지 집계

즉, 단순히 데이터가 나오느냐만 보는 것이 아니라, “언제 수락되었는가”와 “그 결과가 맞는가”를 함께 검증하는 구조입니다.

## Showcase 2: Dedicated Async FIFO RTL

- DUT: `src/async_fifo.sv`
- TB top: `tb/async_fifo/tb_async_fifo.sv`

이 케이스는 기존 showcase를 복제한 것이 아니라, 다른 reset polarity와 별도 RTL 구현체를 전용 환경으로 다시 맞춘 사례입니다.

주요 포인트는 다음과 같습니다.

- active-high reset DUT를 별도 interface와 driver preset으로 정리
- Gray-code pointer 기반 async FIFO에 맞는 accepted/blocked 판정 유지
- interface SVA, scenario-aware generator, CSV 기반 scoreboard 요약까지 포함

즉, 기존 템플릿을 다른 DUT에 이식해 독립 검증 환경으로 확장할 수 있다는 점을 보여줍니다.

## Showcase 3: Sync FIFO

- DUT: `src/sync_fifo.sv`
- TB top: `tb/sync_fifo/tb_sync_fifo.sv`

주요 검증 포인트는 다음과 같습니다.

- 단일 클록 환경에서의 write/read 혼합 자극 검증
- 동일 cycle 내 동시 read/write 허용 조건 반영
- scoreboard 내부 queue size를 기준으로 full/empty flag 기대값 계산
- read data order와 flag 정확도를 동시에 검증
- short run에서도 채우기, 비우기, 동시 요청 상황이 모두 나오도록 phase bias 적용

동기 FIFO는 구조가 더 단순하지만, 동시에 read/write가 발생하는 경계 조건 처리와 flag 검증 능력을 깔끔하게 보여줄 수 있다는 장점이 있습니다.

## Showcase 4: UART RX

- DUT: `src/uart_rx.v`
- TB top: `tb/uart_rx/tb_uart_rx.sv`

주요 검증 포인트는 다음과 같습니다.

- task 기반 serial stimulus로 UART 8N1 frame을 직접 생성
- directed payload + random payload로 data bin을 분산
- invalid stop frame을 별도 negative scenario로 검증
- covergroup과 scoreboard를 분리해 positive/negative path를 설명

## Showcase 5: UART RX + FIFO

- DUT: `src/uart_rx_fifo_bridge.sv`
- TB top: `tb/uart_fifo/tb_uart_fifo.sv`

주요 검증 포인트는 다음과 같습니다.

- UART RX 결과가 `sync_fifo`로 실제 push되는지 확인
- fill/balanced/burst traffic에서 ordering 유지 확인
- `oPopValid`와 register read-data 정렬을 검증
- protocol block과 buffering block의 통합 경로를 설명

## Showcase 6: UART TX + FIFO

- DUT: `src/uart_tx_fifo_bridge.sv`
- TB top: `tb/uart_tx_fifo/tb_uart_tx_fifo.sv`

주요 검증 포인트는 다음과 같습니다.

- buffered transmitter path의 FIFO dequeue ordering 검증
- sync FIFO read-data timing을 launch 경계와 정렬
- launch boundary scoreboard와 serial line assertion을 분리 적용

## Showcase 7: UART + Async FIFO

- DUT: `src/uart_rx_async_fifo_bridge.sv`
- TB top: `tb/uart_async_fifo/tb_uart_async_fifo.sv`

주요 검증 포인트는 다음과 같습니다.

- UART RX 결과를 async FIFO로 넘기는 dual-clock 통합 경로 검증
- write/read clock 분리 상황에서 ordering 보존 확인
- 시나리오별 flag-state coverage로 CDC buffer behavior 설명

## 보조 사례

- `sram`
  - 주소/데이터 중심의 self-checking 구조
  - coverage 수집 예제 포함
- `ff_en`
  - enable에 따른 hold/update 동작 검증
- `ff`
  - 비교적 작은 구조의 interface 기반 reference 환경
  - 학습 과정에서의 compact style 흔적을 보여주는 보조 예제 역할

## 도구 선택 이유

- 권장 실행 경로: FPGA_AUTO + Vivado `xsim`
- 이유:
  - class
  - mailbox
  - constrained-random
  - covergroup
  - assertion
  같은 SystemVerilog 기능을 비교적 안정적으로 소화할 수 있기 때문입니다.

이 프로젝트에서 open-source simulator는 참고용일 수는 있지만, 포트폴리오 증빙의 기본 기준은 Vivado/xsim으로 잡았습니다.
