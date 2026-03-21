# UART RX 모듈 상세 보고서

## 1. 대상

- DUT: `src/uart_rx.v`
- 보조 RTL: `src/baud_rate_gen.v`
- TB Top: `tb/uart_rx/tb_uart_rx.sv`

`asdf` 경로의 UART RX 검증 스타일을 참고해 `veri1` 구조로 옮긴 UART 검증 사례입니다. 폴더 구조는 현재 패키지 형식을 따르고, serial protocol 자극은 task 기반 UART driver 방식으로 구성했습니다.

## 2. DUT 요약

`uart_rx.v`는 16배 oversampling tick을 사용해 UART 8N1 프레임을 수신하는 모듈입니다.

- `IDLE`
  - start bit를 기다림
- `START`
  - bit center 근처에서 start bit가 안정적으로 low인지 확인
- `DATA`
  - 8비트를 LSB first로 shift
- `STOP`
  - stop bit가 high인지 확인하고 `oValid`를 1사이클 pulse로 출력

구성 항목은 다음과 같습니다.

- 비동기 serial 입력을 2-stage synchronizer로 동기화
- `iTick16x` 기준으로 bit center를 맞춰 샘플링
- stop bit 오류가 나면 `oValid`를 내지 않음

## 3. 클래스별 역할

- `uart_rx_transaction`
  - 기대 바이트, 시나리오 종류, invalid frame 관측 윈도우를 담는 객체
- `uart_rx_generator`
  - directed pattern과 random payload를 생성
  - 마지막 transaction은 stop bit 없는 invalid frame으로 강제
- `uart_rx_driver`
  - UART start/data/stop bit를 serial line에 직접 인가
  - `asdf` 스타일의 `wait_16x_ticks()`와 `send_uart_byte()` task를 사용
- `uart_rx_monitor`
  - `oValid`가 뜨는 순간 `oData`를 scoreboard로 전달
- `uart_rx_scoreboard`
  - valid frame은 expected byte와 actual byte를 비교
  - invalid frame은 정해진 관찰 구간 동안 `oValid`가 없어야 PASS
- `uart_rx_coverage`
  - `0x00`, `0xFF`, printable ASCII, 기타 byte 분포
  - valid / invalid 시나리오 hit
- `uart_rx_environment`
  - reset, component run, 종료 시점을 orchestration

## 4. 검증 시나리오

- `valid_frame`
  - 초반 4개는 directed pattern
    - `0x55`, `0xA3`, `0x00`, `0xFF`
  - 이후는 random payload
  - 목적: 기본 framing과 data integrity 확인
- `invalid_stop`
  - stop bit를 high로 복구하지 않고 low를 유지
  - 목적: malformed frame에서 `oValid` 미발생 확인

UART RX는 정상 수신과 프레임 오류 시 valid 억제를 함께 검증합니다.

### 시나리오별 coverage 관점

| 시나리오 | 생성 횟수 | 주요 자극 | 겨냥한 coverage |
| --- | ---: | --- | --- |
| `valid_frame` | 15 | directed 4개 + random 11개 | `cp_scenario.valid_frame`, `cp_data.zero`, `cp_data.all_ones`, `cp_data.ascii`, `cp_data.other` |
| `invalid_stop` | 1 | stop bit를 의도적으로 low 유지 | negative path 검증, invalid frame 미검출 확인 |

여기서 중요한 점은 `invalid_stop`은 정상 data sample이 발생하면 오히려 실패여야 하므로, data covergroup보다는 scoreboard의 negative-path 판정으로 설명하는 것이 맞다는 점입니다.

## 5. assertion 전략

- `tb_uart_rx.sv`
  - `wTick16x`가 정확히 1클럭 pulse인지 property로 확인
  - `oValid`가 X/Z가 아니어야 함
  - `oValid=1`일 때 `oData`가 X/Z가 아니어야 함
- `uart_rx_scoreboard`
  - data mismatch 또는 invalid frame 오검출 시 즉시 fail

정리하면:

- protocol timing assertion: 있음
- runtime X/Z assertion: 있음
- self-checking scoreboard: 있음

## 6. coverage 설명 및 근거

이 케이스의 coverage는 퍼센트 숫자보다 “패턴과 오류 시나리오를 실제로 밟았는가”를 설명하는 데 목적이 있습니다.

- data bin
  - `0x00`
  - `0xFF`
  - printable ASCII
  - 기타 byte
- scenario bin
  - valid frame
  - invalid stop

이 coverage 구성은 sanity pattern과 framing 오류를 함께 다루기 위한 설정입니다.

### coverage 설정 근거

- `0x00`, `0xFF`
  - reset-like edge pattern과 all-ones pattern을 명시적으로 밟기 위해 separate bin으로 분리했습니다.
- printable ASCII
  - 사람이 읽기 쉬운 일반 payload 영역이 수신 경로를 통과하는지 확인합니다.
- other
  - sanity pattern 외 일반 binary payload 분포를 확인합니다.
- `valid_frame` / `invalid_stop`
  - 정상 경로와 framing error 경로를 분리해 protocol robustness를 설명하기 위한 최소 시나리오 축입니다.

### 시나리오별 coverage 해석

| 시나리오 | coverage 의도 | 실제 해석 |
| --- | --- | --- |
| `valid_frame` | data bin 분포와 정상 수신 경로 확인 | `valid=15`와 data bin hit(`zero=1`, `ones=1`, `ascii=4`, `other=9`)로 정상 payload 다양성이 확보됐습니다. |
| `invalid_stop` | framing error에서 `oValid`가 뜨지 않아야 함 | scoreboard가 12 bit-time 관찰 창에서 unexpected valid를 감시해 negative-path를 자동 판정합니다. |

UART RX coverage는 정상 프레임 payload 분포는 covergroup으로, 비정상 프레임 억제는 scoreboard negative check로 구분합니다.

## 7. 타이밍 관점 메모

- driver
  - `wait_16x_ticks()`와 `send_uart_byte()` task로 start/data/stop bit 길이를 16x tick 기준으로 맞춥니다.
- monitor
  - `oValid`가 1이 되는 clock에서 `oData`를 샘플링합니다.
- scoreboard
  - valid frame은 즉시 data compare를 수행하고
  - invalid frame은 별도 observation window 동안 unexpected valid가 없는지 확인합니다.

RX 경로는 `serial task stimulus -> oValid pulse monitor -> positive/negative scoreboard` 순서로 구성됩니다.

## 8. 최종 결과

Vivado xsim 기준 최신 결과:

- 로그: `tb/uart_rx/vivado_sim_tb_uart_rx.log`
- 요약:
  - `sample=16`
  - `pass=16`
  - `fail=0`
  - `valid=15`
  - `invalid=1`
- 최종 메시지:
  - `[UART-RX][SCB][PASS] UART RX scoreboard completed without mismatches`

## 9. 요약

- class 기반 custom SV 환경으로 UART serial protocol을 검증
- protocol driver를 task 기반으로 명확하게 모델링
- invalid stop frame까지 포함한 negative test 존재
- `asdf`의 UART 중심 구동 스타일과 `veri1`의 구조화된 패키징을 결합
