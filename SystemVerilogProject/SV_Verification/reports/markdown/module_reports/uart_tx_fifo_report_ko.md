# UART TX + FIFO 브리지 상세 보고서

## 1. 대상

- DUT: `src/uart_tx_fifo_bridge.sv`
- 구성 RTL:
  - `src/sync_fifo.sv`
  - `src/uart_tx.v`
  - `src/uart_rx.v`
  - `src/baud_rate_gen.v`
- TB Top: `tb/uart_tx_fifo/tb_uart_tx_fifo.sv`

이 케이스는 FIFO에 적재된 byte가 UART TX로 순서대로 전달되는지를 검증하는 통합 사례입니다. 포인트는 UART RX처럼 serial input을 받는 경로가 아니라, `buffered transmit path`를 검증 대상으로 삼았다는 점입니다.

## 2. DUT 구조

`uart_tx_fifo_bridge.sv`는 내부적으로 세 부분으로 구성됩니다.

1. `sync_fifo`
   - 외부 `iPush` 요청으로 byte를 큐잉
2. bridge handoff control
   - UART가 idle일 때 FIFO read를 요청
   - FIFO read data가 register output이라는 점을 고려해
     - `rPopReq`
     - `rReadIssued`
     - `rLaunchPending`
     3단계로 launch 시점을 정렬
3. `uart_tx`
   - 최종적으로 byte를 serial line으로 송신

핵심은 FIFO dequeue와 UART launch 사이의 타이밍 정렬입니다. 실제 검증 중에는 `sync_fifo`의 read data가 한 사이클 늦게 반영되는데 bridge가 이를 너무 일찍 소비해 initial zero / 1-cycle shift 문제가 있었고, 이를 read-issued / launch-pending 구조로 분리해 clean pass를 얻었습니다.

## 3. 클래스별 역할

- `uart_tx_fifo_transaction`
  - 전송 byte와 scenario id를 담는 객체
- `uart_tx_fifo_generator`
  - `fill_queue`, `balanced_enqueue`, `burst_enqueue` phase를 생성
- `uart_tx_fifo_driver`
  - FIFO push를 수행
  - scenario에 따라 enqueue pacing을 조절
- `uart_tx_fifo_monitor`
  - UART launch 경계에서 `oLaunchValid/oLaunchData`를 샘플링
  - NBA update 이후 값을 읽기 위해 post-edge 샘플링 사용
- `uart_tx_fifo_scoreboard`
  - expected queue 순서와 actual launch 순서를 비교
- `uart_tx_fifo_coverage`
  - scenario hit와 full flag 관측 여부를 수집
- `uart_tx_fifo_environment`
  - reset, component run, 종료 타이밍 orchestration

## 4. 검증 시나리오

- `fill_queue`
  - 초반에 byte를 연속 push해 FIFO를 빠르게 채움
  - 목적: queue build-up 이후에도 launch ordering이 유지되는지 확인
- `balanced_enqueue`
  - UART busy 상태를 보면서 enqueue와 송신을 균형 있게 진행
  - 목적: steady-state handoff 검증
- `burst_enqueue`
  - 말미에 다시 push burst를 몰아 넣음
  - 목적: backlog가 있는 상태에서 dequeue ordering 유지 확인

이 시나리오 구성을 택한 이유는 TX path에서 중요한 포인트가 "serial output waveform 전체"보다 "FIFO가 쌓인 뒤 UART로 빠져나가는 순서"이기 때문입니다.

### 시나리오별 coverage 관점

`tb_uart_tx_fifo.sv`의 `RUN_COUNT=18`과 generator의 3-phase 분할 기준 때문에 각 시나리오는 6개 transaction씩 생성됩니다.

| 시나리오 | 생성 횟수 | 주요 자극 | 겨냥한 coverage |
| --- | ---: | --- | --- |
| `fill_queue` | 6 | 초반 enqueue 집중 | `cp_scenario.fill_queue`, queue pressure 형성 |
| `balanced_enqueue` | 6 | busy를 보며 enqueue | `cp_scenario.balanced_enqueue`, steady handoff |
| `burst_enqueue` | 6 | 말미 enqueue burst | `cp_scenario.burst_enqueue`, backlog 상황 ordering |

## 5. assertion 전략

- `tb_uart_tx_fifo.sv`
  - `wTick16x`가 정확히 1클럭 pulse인지 property로 확인
  - `oLaunchValid`일 때 `oLaunchData`가 X/Z가 아니어야 함
  - `oBusy` 동안 `oTx`가 X/Z가 아니어야 함
- `uart_tx_fifo_scoreboard`
  - expected launch ordering mismatch 시 즉시 fail

보조적으로 `sink_rx`를 TB 안에 유지해 loopback receiver를 붙여 두었지만, 메인 판정은 `FIFO -> UART launch boundary`에서 수행합니다. 이렇게 해야 TX-side 통합 검증의 의미가 더 명확하고, FIFO/UART handoff 타이밍을 직접 설명할 수 있습니다.

## 6. coverage 설명 및 근거

이 케이스의 functional coverage는 다음 항목으로 구성됩니다.

- `cp_scenario`
  - `fill_queue`
  - `balanced_enqueue`
  - `burst_enqueue`
- `cp_full`
  - full flag 관측 여부
- `cx_scenario_full`
  - 어떤 enqueue 시나리오에서 full pressure를 밟았는지 확인

coverage 설계 근거는 다음과 같습니다.

- TX path는 read/write accept count보다 "queue pressure가 실제로 형성됐는가"가 중요함
- launch ordering은 scoreboard가 판정하고
- scenario 분포와 full pressure hit 여부는 covergroup이 설명하도록 역할을 분리함

### 시나리오별 coverage 해석

| 시나리오 | coverage 의도 | 기대 해석 |
| --- | --- | --- |
| `fill_queue` | 초반 enqueue 집중으로 depth를 빠르게 올림 | FIFO backlog가 형성돼도 launch 순서가 보존돼야 합니다. |
| `balanced_enqueue` | enqueue와 launch가 번갈아 일어나는 steady-state | `oBusy`와 launch handoff가 안정적으로 이어졌음을 보여줍니다. |
| `burst_enqueue` | 말미에 다시 enqueue burst를 집중 | queue가 다시 쌓인 상태에서도 launch ordering이 흐트러지지 않음을 설명합니다. |

이 환경에서 coverage는 "full이 몇 번 떴는가"보다 "어떤 enqueue phase가 실제로 launch ordering 검증으로 이어졌는가"를 설명하는 역할입니다.

## 7. 타이밍 관점 메모

- driver
  - `negedge iClk`에서 `iPush/iPushData`를 인가해 DUT가 active edge에서 안정된 입력을 보게 합니다.
- bridge
  - `rPopReq -> rReadIssued -> rLaunchPending` 3단 pipeline으로 sync FIFO read data를 UART launch와 정렬합니다.
- monitor
  - `oLaunchValid/oLaunchData`를 post-edge로 샘플링해 registered launch 값을 읽습니다.
- scoreboard
  - launch boundary ordering을 기준으로 판정하고, `oTx`는 assertion으로 health check만 수행합니다.

즉, 이 케이스는 serial waveform 자체보다 "FIFO dequeue timing과 UART launch timing을 어떻게 검증 가능한 인터페이스로 바꿨는가"가 핵심입니다.

## 8. 최종 결과

Vivado xsim 기준 최신 결과:

- 로그: `tb/uart_tx_fifo/vivado_sim_tb_uart_tx_fifo.log`
- 요약:
  - `sample=18`
  - `pass=18`
  - `fail=0`
- 최종 메시지:
  - `[UART-TXF][SCB][PASS] UART TX+FIFO scoreboard completed without mismatches`

## 9. 포트폴리오 포인트

- UART TX를 단독 RTL이 아니라 `buffered transmitter path`로 확장해 검증
- FIFO read-data timing alignment 이슈를 직접 수정하고 clean pass 확보
- launch boundary scoreboard로 ordering 검증 포인트를 명확히 정의
- serial line assertion과 data ordering scoreboard를 분리해 검증 의도를 선명하게 구성
