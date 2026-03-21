# UART + FIFO 브리지 상세 보고서

## 1. 대상

- DUT: `src/uart_rx_fifo_bridge.sv`
- 구성 RTL:
  - `src/uart_rx.v`
  - `src/sync_fifo.sv`
  - `src/baud_rate_gen.v`
- TB Top: `tb/uart_fifo/tb_uart_fifo.sv`

UART serial input이 FIFO에 적재된 뒤 pop 순서가 유지되는지를 다루는 통합 검증 사례입니다. UART 구동은 `asdf`의 UART RX 스타일을 참고했고, FIFO는 현재 패키지의 `sync_fifo`를 재사용했습니다.

## 2. DUT 구조

`uart_rx_fifo_bridge.sv`의 내부 구성은 매우 단순합니다.

1. `uart_rx`
   - serial bitstream을 byte + valid pulse로 변환
2. `sync_fifo`
   - `oRxValid`가 뜬 byte를 push
   - 외부 `iPop` 요청에 따라 FIFO pop
3. bridge output
   - `oPopData`
   - `oPopValid`
   - `oFull`, `oEmpty`

핵심 포인트는 `sync_fifo`의 read-data가 register output이라서, `oPopValid`를 한 사이클 지연시켜 `oPopData`와 정렬했다는 점입니다. 실제 검증 중 이 타이밍 misalignment가 한 번 발생했고, bridge에서 valid 타이밍을 정렬한 뒤 clean pass가 나왔습니다.

## 3. 클래스별 역할

- `uart_fifo_transaction`
  - byte payload와 scenario id, 송신 후 pop 개수를 담음
- `uart_fifo_generator`
  - `fill_then_drain`, `balanced`, `burst_drain` phase를 생성
- `uart_fifo_driver`
  - UART serial byte를 iRx에 인가
  - scenario에 따라 pop 요청을 늦추거나 바로 내면서 FIFO depth를 변화시킴
- `uart_fifo_monitor`
  - `oPopValid` 시점의 `oPopData`를 scoreboard로 전달
- `uart_fifo_scoreboard`
  - generator가 보낸 expected byte 순서와 pop된 actual byte 순서를 비교
- `uart_fifo_coverage`
  - scenario hit와 flag state hit를 수집
- `uart_fifo_environment`
  - reset, parallel run, 종료 시점 관리

## 4. 검증 시나리오

- `fill_then_drain`
  - 몇 개의 byte를 연속으로 넣어 FIFO depth를 쌓은 뒤 한 번에 drain
  - 목적: burst push 이후 순서 유지 확인
- `balanced`
  - byte를 넣고 곧바로 pop
  - 목적: steady-state에서 UART RX와 FIFO pop이 균형 있게 이어지는지 확인
- `burst_drain`
  - 2개 단위 burst를 만들고 drain
  - 목적: 짧은 burst traffic에서 ordering 유지 확인

이 환경은 UART RX 동작 자체보다 UART RX 결과가 FIFO를 지나도 순서가 유지되는지에 초점을 둡니다.

### 시나리오별 coverage 관점

`tb_uart_fifo.sv`의 `RUN_COUNT=24`와 generator의 3-phase 분할 기준 때문에 각 시나리오는 8개 transaction씩 생성됩니다.

| 시나리오 | 생성 횟수 | 주요 자극 | 겨냥한 coverage |
| --- | ---: | --- | --- |
| `fill_then_drain` | 8 | 4개씩 쌓은 뒤 drain | `cp_scenario.fill_then_drain`, empty->normal 전이, depth build-up |
| `balanced` | 8 | 송신 후 pop 1개 | `cp_scenario.balanced`, steady-state ordering |
| `burst_drain` | 8 | 2개 단위 burst 후 drain | `cp_scenario.burst_drain`, burst traffic ordering |

## 5. assertion 전략

- `tb_uart_fifo.sv`
  - `wTick16x` 1클럭 pulse property
  - `oFull && oEmpty` 동시 high 금지
  - `oPopValid`와 `oPopData`의 X/Z 금지
- `uart_fifo_scoreboard`
  - expected ordering mismatch 시 즉시 fail

정리하면:

- protocol timing assertion: 있음
- FIFO boundary assertion: 있음
- self-checking scoreboard: 있음

## 6. coverage 설명 및 근거

이 케이스에서 중요한 coverage는 다음과 같습니다.

- `cp_scenario`
  - fill/drain/balanced phase가 모두 실행됐는지 확인
- `cp_flag_state`
  - normal / empty / full 상태 관측 여부 확인
- `cx_scenario_flag`
  - 어떤 시나리오에서 어떤 FIFO flag 상태를 밟았는지 연결

이 coverage를 둔 이유는 UART 통합 검증에서는 단순 data compare 외에도, burst traffic이 실제로 FIFO 상태를 어떻게 움직였는지를 설명해야 하기 때문입니다.

### coverage 설정 근거

- `cp_scenario`
  - generator가 의도한 fill/balanced/burst 세 phase가 실제로 모두 실행됐는지 확인합니다.
- `cp_flag_state`
  - `normal`, `empty`, `full` 관측 여부를 통해 FIFO 상태 공간을 설명합니다.
- `cx_scenario_flag`
  - 같은 UART traffic이라도 어떤 phase에서 어떤 flag 상태가 주로 나왔는지 연결해 설명할 수 있습니다.

### 시나리오별 coverage 해석

| 시나리오 | coverage 의도 | 기대 해석 |
| --- | --- | --- |
| `fill_then_drain` | FIFO를 먼저 쌓고 drain하면서 `empty -> normal` 변화를 강조 | ordering이 깨지지 않으면서 depth build-up이 발생해야 합니다. |
| `balanced` | 송신과 pop을 거의 1:1로 유지 | steady-state에서 serial RX와 FIFO pop의 균형 상태를 확인합니다. |
| `burst_drain` | 짧은 burst 뒤 drain | burst traffic에서도 FIFO ordering이 유지됨을 설명합니다. |

이 케이스는 scoreboard sample이 곧 coverage sample이므로, PASS 24건이 곧 24개의 ordered pop 사례를 의미합니다.

## 7. 타이밍 관점 메모

- driver
  - UART serial byte를 `16x tick` 기준 task로 전송하고, 시나리오에 따라 `iPop` 타이밍을 다르게 줍니다.
- monitor
  - `oPopValid` 기준으로 `oPopData`를 샘플링합니다.
- scoreboard
  - generator가 만든 expected ordering과 monitor가 관측한 pop ordering을 1:1로 비교합니다.

핵심 타이밍 경로는 `UART RX 수신 완료 -> FIFO push -> pop valid/data 정렬`입니다.

## 8. 최종 결과

Vivado xsim 기준 최신 결과:

- 로그: `tb/uart_fifo/vivado_sim_tb_uart_fifo.log`
- 요약:
  - `sample=24`
  - `pass=24`
  - `fail=0`
- 최종 메시지:
  - `[UART-FIFO][SCB][PASS] UART+FIFO scoreboard completed without mismatches`

## 9. 요약

- UART serial protocol과 FIFO ordering을 함께 다루는 통합 사례
- 기존 `sync_fifo` 자산을 실제 시스템 경로에 재사용
- 타이밍 misalignment를 실검증 중 수정해 clean pass 확보
- protocol + buffering 통합 검증 사례
