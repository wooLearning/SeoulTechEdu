# UART + Async FIFO 브리지 상세 보고서

## 1. 대상

- DUT: `src/uart_rx_async_fifo_bridge.sv`
- 구성 RTL:
  - `src/uart_rx.v`
  - `src/async_fifo.sv`
  - `src/baud_rate_gen.v`
- TB Top: `tb/uart_async_fifo/tb_uart_async_fifo.sv`

UART RX 결과를 비동기 FIFO로 넘긴 뒤, 독립된 read clock 도메인에서 순서대로 꺼낼 수 있는지를 다루는 통합 사례입니다. protocol 검증과 CDC buffering 검증을 하나의 경로로 구성했습니다.

## 2. DUT 구조

`uart_rx_async_fifo_bridge.sv`의 내부 구조는 다음과 같습니다.

1. `uart_rx`
   - write clock 도메인에서 serial byte를 복원
2. `async_fifo`
   - write side는 UART RX valid를 push
   - read side는 외부 `iPop`으로 pop
3. bridge output
   - `oPopData`
   - `oPopValid`
   - `oFull`, `oEmpty`
   - `oRxData`, `oRxValid`

이 케이스의 핵심은 write/read clock이 서로 다르다는 점입니다. 따라서 단순 UART RX + FIFO보다 `ordering + flag behavior + dual-clock timing`을 함께 봐야 합니다.

## 3. 클래스별 역할

- `uart_async_fifo_transaction`
  - byte payload, scenario id, 송신 후 pop 개수를 담는 객체
- `uart_async_fifo_generator`
  - `fill_async`, `balanced_async`, `drain_async` phase를 생성
- `uart_async_fifo_driver`
  - UART serial byte를 write clock 도메인 입력으로 인가
  - scenario별로 read clock 도메인 pop 개수를 조절
- `uart_async_fifo_monitor`
  - read clock 도메인에서 `oPopValid/oPopData`를 관측
- `uart_async_fifo_scoreboard`
  - expected ordering과 actual pop ordering 비교
  - full/empty flag를 coverage로 함께 샘플링
- `uart_async_fifo_coverage`
  - 시나리오 hit와 flag-state hit를 수집
- `uart_async_fifo_environment`
  - dual-clock reset, run orchestration, 종료 타이밍 관리

## 4. 검증 시나리오

- `fill_async`
  - 몇 개의 byte를 먼저 쌓고 4개 단위 drain을 수행
  - 목적: write side 우세 상황에서 async FIFO depth가 증가하는지 확인
- `balanced_async`
  - 송신 후 pop 1개를 바로 수행
  - 목적: write/read traffic이 거의 균형인 상태에서 ordering 유지 확인
- `drain_async`
  - pop을 더 공격적으로 수행
  - 목적: read side 우세 상황에서 empty 근처 경계 동작 확인

이 환경은 UART RX 결과가 async FIFO를 지나 다른 clock domain으로 넘어가도 ordering이 유지되는지를 다룹니다.

### 시나리오별 coverage 관점

`tb_uart_async_fifo.sv`의 `RUN_COUNT=18`과 generator의 3-phase 분할 기준 때문에 각 시나리오는 6개 transaction씩 생성됩니다.

| 시나리오 | 생성 횟수 | 주요 자극 | 겨냥한 coverage |
| --- | ---: | --- | --- |
| `fill_async` | 6 | write 우세 후 4개 drain | `cp_scenario.fill_async`, normal/full 근처 상태 |
| `balanced_async` | 6 | 송신 후 pop 1개 | `cp_scenario.balanced_async`, dual-clock steady-state |
| `drain_async` | 6 | pop을 더 공격적으로 수행 | `cp_scenario.drain_async`, empty 근처 상태 |

## 5. assertion 전략

- `tb_uart_async_fifo.sv`
  - write clock 기준 `wTick16x` 1클럭 pulse property
  - read clock 기준 `oFull && oEmpty` 동시 high 금지
  - `oPopValid`일 때 `oPopData`의 X/Z 금지
- `uart_async_fifo_scoreboard`
  - pop ordering mismatch 시 즉시 fail

정리하면:

- protocol timing assertion: 있음
- async FIFO boundary assertion: 있음
- self-checking scoreboard: 있음

## 6. coverage 설명 및 근거

이 케이스의 functional coverage는 다음 항목을 포함합니다.

- `cp_scenario`
  - `fill_async`
  - `balanced_async`
  - `drain_async`
- `cp_flag_state`
  - `normal`
  - `full`
  - `empty`
- `cx_scenario_flag`
  - 어떤 async traffic 시나리오에서 어떤 flag state를 밟았는지 확인

이 coverage 구성을 택한 이유는 async FIFO 통합 검증에서는 data compare만으로는 부족하기 때문입니다. 시나리오별로 flag state가 실제로 어떻게 관측됐는지를 보여줘야 dual-clock buffer behavior를 설명할 수 있습니다.

### coverage 설정 근거

- `cp_scenario`
  - fill/balanced/drain 3개 async phase가 모두 수행됐는지 확인합니다.
- `cp_flag_state`
  - dual-clock buffer가 `normal`, `full`, `empty` 상태를 실제로 밟았는지 설명합니다.
- `cx_scenario_flag`
  - 어떤 async traffic phase에서 어떤 flag state가 나타났는지 연결합니다.

### 시나리오별 coverage 해석

| 시나리오 | coverage 의도 | 기대 해석 |
| --- | --- | --- |
| `fill_async` | write side 우세 구간 | async FIFO depth 증가와 write-side buffering 설명 근거가 됩니다. |
| `balanced_async` | write/read가 거의 균형 | dual-clock steady-state에서 ordering 유지 여부를 확인합니다. |
| `drain_async` | read side 우세 구간 | empty 근처와 pop pressure가 실제로 만들어졌음을 설명합니다. |

이 케이스의 coverage는 dual-clock 환경에서 scenario와 flag behavior가 함께 관측됐는지를 기록합니다.

## 7. 타이밍 관점 메모

- driver
  - write clock 쪽에 UART serial byte를 넣고
  - read clock 쪽에서는 scenario에 맞춰 `iPop` 횟수를 조절합니다.
- monitor
  - read domain에서 `oPopValid/oPopData`를 관측합니다.
- scoreboard
  - expected ordering을 read domain pop 결과와 비교합니다.

핵심 타이밍 경로는 `serial RX in write domain -> async FIFO crossing -> ordered pop in read domain`입니다.

## 8. 최종 결과

Vivado xsim 기준 최신 결과:

- 로그: `tb/uart_async_fifo/vivado_sim_tb_uart_async_fifo.log`
- 요약:
  - `sample=18`
  - `pass=18`
  - `fail=0`
- 최종 메시지:
  - `[UART-AF][SCB][PASS] UART+async FIFO scoreboard completed without mismatches`

## 9. 요약

- UART protocol verification을 async FIFO CDC path까지 확장
- single-clock 통합 검증에서 dual-clock 통합 검증으로 범위를 넓힘
- scenario-driven pop pressure를 이용해 fill/balanced/drain 상태를 명시적으로 검증
- protocol block과 buffering block을 결합한 시스템 검증 사례
