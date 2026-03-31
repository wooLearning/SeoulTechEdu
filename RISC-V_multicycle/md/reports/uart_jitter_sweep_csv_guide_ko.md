# UART Jitter Sweep CSV 컬럼 가이드

이 문서는 jitter sweep 결과 CSV 파일의 각 컬럼 의미를 설명합니다.

대상 파일:

- `uart_jitter_sweep_results.csv`
- `uart_jitter_threshold_summary.csv`

## 1. `uart_jitter_sweep_results.csv`

각 행은 "특정 baud 설정 + 특정 jitter 비율"에 대한 1회 시뮬레이션 결과입니다.

| 컬럼 | 의미 |
|---|---|
| `baud_sel` | DUT에 넣은 `i_baud_sel` 값 |
| `baud_rate` | 실제 baud 값 |
| `jitter_permille` | 주입한 jitter 크기. permille 단위라 `10`은 `1.0%`, `430`은 `43.0%` |
| `jitter_percent` | 사람이 보기 쉬운 `%` 단위 jitter |
| `nominal_bit_ns` | 해당 baud의 이상적인 1bit 길이(ns) |
| `jitter_ns` | 실제로 한 bit에 더하거나 뺀 jitter 절대 시간(ns) |
| `short_bit_ns` | `nominal - jitter`일 때의 짧은 bit 길이 |
| `long_bit_ns` | `nominal + jitter`일 때의 긴 bit 길이 |
| `short_baud_rate` | 짧은 bit 길이를 baud로 환산한 값 |
| `long_baud_rate` | 긴 bit 길이를 baud로 환산한 값 |
| `short_baud_error_percent` | 짧은 bit가 nominal baud보다 얼마나 빠른지(%) |
| `long_baud_error_percent` | 긴 bit가 nominal baud보다 얼마나 느린지(%) |
| `passed` | PASS면 `1`, FAIL이면 `0` |
| `xsim_returncode` | xsim 프로세스 종료 코드 |
| `sim_wall_time_s` | 실제 wall-clock 실행 시간(초) |
| `failure_reason` | FAIL일 때 추출한 대표 실패 메시지 |

### 핵심 해석

- `jitter_percent`는 "얼마나 흔들었는가"를 보여줍니다.
- `short_bit_ns`와 `long_bit_ns`는 "실제 선로에서는 각 bit가 어느 길이로 들어갔는가"를 보여줍니다.
- `short_baud_error_percent`, `long_baud_error_percent`는 그 흔들림을 baud 오차 관점으로 환산한 값입니다.
- `passed`가 이 CSV의 최종 판정 컬럼입니다.

## 2. `uart_jitter_threshold_summary.csv`

이 파일은 sweep 결과를 baud별로 요약한 summary입니다.

| 컬럼 | 의미 |
|---|---|
| `baud_sel` | DUT에 넣은 `i_baud_sel` 값 |
| `baud_rate` | 실제 baud 값 |
| `max_pass_jitter_permille` | PASS한 가장 큰 jitter permille |
| `max_pass_jitter_percent` | PASS한 가장 큰 jitter % |
| `max_pass_jitter_ns` | PASS한 가장 큰 jitter의 절대 시간(ns) |
| `first_fail_jitter_permille` | 처음 FAIL이 나온 jitter permille |
| `first_fail_jitter_percent` | 처음 FAIL이 나온 jitter % |
| `short_baud_error_percent_at_limit` | 최대 PASS 지점에서 짧은 bit의 등가 baud 오차(+) |
| `long_baud_error_percent_at_limit` | 최대 PASS 지점에서 긴 bit의 등가 baud 오차(-) |
| `pass_count` | PASS한 포인트 개수 |
| `fail_count` | FAIL한 포인트 개수 |
| `tested_points` | 해당 baud에서 sweep한 전체 포인트 수 |

### 핵심 해석

- `max_pass_jitter_percent`가 가장 중요합니다.
  이 값이 "그 baud에서 현재 alternating jitter 패턴으로 검증된 최대 허용 jitter"입니다.
- `first_fail_jitter_percent`는 경계 직후의 실패 지점입니다.
- `max_pass_jitter_ns`는 같은 퍼센트라도 저속 baud에서는 절대 시간 여유가 더 크고, 고속 baud에서는 더 작다는 것을 보여줍니다.

## 3. 예시 해석

예를 들어 `baud_rate = 115200`에서:

- `max_pass_jitter_percent = 44.0`
- `first_fail_jitter_percent = 45.0`

라면 의미는 다음과 같습니다.

- 현재 TB의 alternating jitter 패턴에서는 `115200 baud`에서 `44%`까지 PASS
- `45%`부터 FAIL

즉 팀 발표에서는 아래처럼 말하면 됩니다.

> 115200 baud 기준으로 alternating jitter를 1% 단위로 sweep했을 때, 현재 RX는 44%까지는 수신에 성공했고 45%에서 처음 실패했다.

## 4. 해석 시 주의점

- 이 CSV는 random jitter가 아니라 alternating deterministic jitter 결과입니다.
- 따라서 "실제 모든 noise 환경에서의 절대 허용 한계"라고 단정하면 안 됩니다.
- 다만 현재 RX sampling 구조의 상대적인 margin과 baud별 경향을 보여주는 자료로는 매우 유용합니다.
