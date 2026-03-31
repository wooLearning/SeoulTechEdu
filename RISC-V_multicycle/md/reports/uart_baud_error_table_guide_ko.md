# UART Baud Error CSV 컬럼 설명

대상 파일:

- [uart_baud_error_table.csv](../data/uart_baud_error_table.csv)

이 CSV는 baud generator의 평균 오차와 tick 양자화 특성을 정리한 표입니다. 각 컬럼의 의미는 아래와 같습니다.

## 1. 컬럼 설명

| 컬럼명 | 의미 | 해석 포인트 |
|---|---|---|
| `baud` | UART baud rate 설정값 | 사용자가 선택하는 통신 속도 |
| `target_tick_hz` | 목표 16x oversample tick 주파수 | `baud * 16` |
| `actual_tick_hz` | phase accumulator가 실제로 만들어내는 평균 tick 주파수 | 실제 하드웨어 평균값 |
| `error_percent` | 목표 대비 실제 tick 주파수 오차율(%) | signed 값, `+`면 목표보다 빠름 |
| `error_ppm` | 오차율을 ppm으로 변환한 값 | 작은 오차 비교에 유리 |
| `tick_min_clk` | 16x tick 사이 간격의 최소 clock cycle 수 | 분수분주 때문에 생기는 짧은 간격 |
| `tick_max_clk` | 16x tick 사이 간격의 최대 clock cycle 수 | 분수분주 때문에 생기는 긴 간격 |
| `bit_min_clk` | 1bit 길이의 최소 clock cycle 수 | `tick_min/max`가 16개 모였을 때 최소 쪽 |
| `bit_max_clk` | 1bit 길이의 최대 clock cycle 수 | `tick_min/max`가 16개 모였을 때 최대 쪽 |

## 2. 각 factor를 어떻게 봐야 하는가

### `baud`

- UART 통신 속도 자체입니다.
- 예: `115200`이면 초당 115200 bit 전송을 의미합니다.

### `target_tick_hz`

- 이 설계는 16x oversampling을 사용하므로, 실제 내부 sampling tick의 목표 주파수는 `baud * 16`입니다.
- 예: `115200 baud -> 1,843,200 Hz`

### `actual_tick_hz`

- phase accumulator가 실제 평균적으로 만들어내는 tick 주파수입니다.
- `target_tick_hz`와 거의 같지만, 정수/분수 연산 때문에 아주 미세한 차이가 있습니다.

### `error_percent`

- `actual_tick_hz`가 `target_tick_hz`에서 얼마나 벗어나는지를 퍼센트로 표시한 값입니다.
- 양수면 조금 빠르고, 음수면 조금 느립니다.

예:

- `+0.000114698%`는 목표보다 아주 조금 빠름
- `-0.000046990%`는 목표보다 아주 조금 느림

### `error_ppm`

- `error_percent`를 더 보기 쉬운 ppm 단위로 바꾼 값입니다.
- ppm은 `1,000,000분율`이라 아주 작은 차이를 비교할 때 편합니다.

예:

- `+7.614 ppm`
- `-0.470 ppm`

현재 값들은 전반적으로 매우 작아서 평균 baud 정확도는 좋은 편이라고 해석할 수 있습니다.

### `tick_min_clk` / `tick_max_clk`

- 16x oversample tick이 매번 같은 간격으로 나오지 않고 `N` 또는 `N+1` 클럭으로 나오는 특성을 보여줍니다.
- 이 값이 바로 quantization jitter를 나타냅니다.

예:

- `115200 baud`에서 tick 간격은 `54` 또는 `55` 클럭
- `921600 baud`에서 tick 간격은 `6` 또는 `7` 클럭

즉 baud generator는 평균은 정확하지만, 순간 tick spacing은 약간 흔들립니다.

### `bit_min_clk` / `bit_max_clk`

- UART 1bit 길이를 clock cycle 기준으로 봤을 때 최소값과 최대값입니다.
- 16x tick이 누적되면서 한 비트 길이도 완전히 고정되지 않고 좁은 범위에서 변합니다.

예:

- `115200 baud`에서 1bit 길이는 `868` 또는 `869` 클럭

이 값은 RX가 bit center를 얼마나 안정적으로 잡아야 하는지 설명할 때 유용합니다.

## 3. 실무 해석

이 CSV를 볼 때 핵심은 아래 두 줄입니다.

1. `error_percent`, `error_ppm`이 매우 작다
   - 평균 baud 정확도는 좋다

2. `tick_min_clk`와 `tick_max_clk`가 다르다
   - 순간 tick 간격에는 양자화 jitter가 존재한다

따라서 이 CSV는 "baud generator 평균 정확도는 충분히 좋지만, tick-to-tick timing은 완전히 일정하지 않다"는 점을 보여주는 자료입니다.

## 4. 발표용 한 줄 설명

> CSV의 앞쪽 컬럼은 평균 baud 정확도를, 뒤쪽 컬럼은 분수분주로 인해 생기는 tick 및 bit 길이의 양자화 흔들림을 보여준다.
