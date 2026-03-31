# UART Jitter Sweep 보고서

## 1. 개요

이 문서는 UART RX jitter tolerance를 baud별로 sweep한 결과를 정리한 한글 보고서입니다.

연계 자료:

- [메인 한글 보고서](./uart_peripheral_report_ko.md)
- [Sweep 결과 CSV](../data/uart_jitter_sweep_results.csv)
- [Sweep 요약 CSV](../data/uart_jitter_threshold_summary.csv)
- [Sweep 실행 로그](./uart_jitter_sweep_run_log.md)
- [Sweep CSV 컬럼 가이드](./uart_jitter_sweep_csv_guide_ko.md)
- [노트북](../notebooks/uart_verification_notebook.ipynb)

## 2. 테스트 목적

이 sweep의 목적은 아래 질문에 답하는 것입니다.

- 각 baud에서 alternating jitter가 얼마나 커져도 RX가 정상 수신하는가
- 최초 FAIL 지점이 baud에 따라 어떻게 달라지는가
- 동일한 `% jitter`라도 시간 영역(ns)으로 보면 얼마나 다른가

즉 단순 baud generator 평균 오차가 아니라, 실제 RX sampling robustness를 보는 실험입니다.

## 3. 테스트 방법

### 3.1 자극 방식

TB는 `0xA6` 프레임을 RX line에 직접 주입합니다.

각 bit 길이는 고정하지 않고 아래처럼 번갈아 흔듭니다.

- `nominal - jitter`
- `nominal + jitter`
- `nominal - jitter`
- `nominal + jitter`

즉 random jitter가 아니라 alternating deterministic jitter입니다.

구현 상세는 [uart_presentation_report_ko.md](./uart_presentation_report_ko.md)의 `9.3 ~ 9.10` 절에 정리했습니다.

핵심 구현 포인트만 요약하면:

- `check_jitter_tolerance()`가 `uart_send_byte_jittered()` 호출
- driver가 interface의 `send_uart_rx_frame()` 호출
- interface의 `wait_line_interval()`가 bit마다 `nominal - jitter`, `nominal + jitter`를 번갈아 적용
- DUT가 최종적으로 `RXDATA == 0xA6`를 복원하면 PASS

### 3.2 sweep 범위

| 항목 | 값 |
|---|---|
| 대상 baud | `9600, 14400, 19200, 38400, 57600, 115200, 230400, 460800, 921600` |
| jitter 범위 | `0.0% ~ 50.0%` |
| sweep step | `1.0%` |
| 총 시뮬레이션 포인트 | `459` |

### 3.3 PASS 기준

아래 조건을 만족하면 PASS입니다.

- RX jitter 시나리오에서 `0xA6`를 정상 복원
- `RXDATA == 0xA6`
- TB fatal/error 없이 종료

## 4. 결과 요약

| Baud | 최대 PASS jitter | 최초 FAIL jitter | 최대 PASS jitter(ns) |
|---|---:|---:|---:|
| 9600 | `43.0%` | `44.0%` | `44791.667` |
| 14400 | `43.0%` | `44.0%` | `29861.111` |
| 19200 | `43.0%` | `44.0%` | `22395.833` |
| 38400 | `43.0%` | `44.0%` | `11197.917` |
| 57600 | `44.0%` | `45.0%` | `7638.889` |
| 115200 | `44.0%` | `45.0%` | `3819.444` |
| 230400 | `44.0%` | `45.0%` | `1909.722` |
| 460800 | `46.0%` | `47.0%` | `998.264` |
| 921600 | `48.0%` | `49.0%` | `520.833` |

핵심 해석:

- 저속 baud군은 대체로 `43%`까지 PASS
- 중간 baud군은 `44%`까지 PASS
- 고속 baud군은 `46%`, `48%`까지 PASS
- 즉 현재 alternating jitter 패턴에서는 baud가 높아질수록 허용 jitter가 약간 증가했습니다

## 5. PASS/FAIL Heatmap

![UART Jitter Heatmap](../visuals/figures/uart_jitter_pass_fail_heatmap.png)

이 heatmap은 각 baud와 jitter 조합의 PASS/FAIL을 보여줍니다.

- 초록색: PASS
- 빨간색: FAIL

관찰 포인트:

- 모든 baud에서 PASS 영역과 FAIL 영역이 비교적 단조롭게 나뉩니다.
- sweep 결과는 noisy하지 않고 경계가 뚜렷합니다.
- 따라서 이번 자극 패턴에서는 threshold를 비교적 안정적으로 읽을 수 있습니다.

## 6. Baud별 임계점 그래프

![UART Jitter Threshold](../visuals/figures/uart_jitter_threshold_by_baud.png)

이 그래프는 baud별로:

- `최대 PASS jitter(%)`
- `최초 FAIL jitter(%)`

를 같이 표시합니다.

핵심 해석:

- `9600 ~ 38400` 구간: `43% PASS / 44% FAIL`
- `57600 ~ 230400` 구간: `44% PASS / 45% FAIL`
- `460800`: `46% PASS / 47% FAIL`
- `921600`: `48% PASS / 49% FAIL`

즉 현재 구현에서는 baud가 높을수록 허용 jitter가 조금 커지는 경향이 관찰됩니다.

## 7. 시간 영역(ns) 그래프

![UART Jitter Threshold NS](../visuals/figures/uart_jitter_threshold_ns.png)

같은 `% jitter`라도 시간 영역으로 보면 차이가 큽니다.

예를 들어:

- `9600 baud`에서 `43%`는 약 `44.79 us`
- `921600 baud`에서 `48%`는 약 `0.521 us`

즉 퍼센트 기준으로는 고속 baud가 더 유리해 보이더라도, 절대 시간 여유는 저속 baud가 훨씬 큽니다.

## 8. 왜 고속 baud가 약간 더 유리하게 보이는가

이번 결과만 놓고 보면 고속 baud일수록 PASS 한계가 조금 올라갑니다.

가능한 이유는 다음과 같습니다.

- 현재 RX는 `baud_tick` 기반으로 start를 인식하고 bit를 샘플링합니다.
- alternating jitter 패턴은 bit 하나는 짧고 다음 bit는 길어서 평균 위치가 계속 보정되는 성격이 있습니다.
- 고속 baud로 갈수록 NCO tick 간격의 양자화 패턴과 sampling 시점의 상호작용이 약간 달라질 수 있습니다.

중요한 점은:

- 이것이 곧 "고속 baud가 항상 더 robust하다"는 뜻은 아닙니다.
- 이번 결과는 어디까지나 **현재 TB의 alternating deterministic jitter 모델**에 대한 결과입니다.

## 9. 최대 PASS 지점의 등가 baud 오차

최대 PASS 지점에서 짧은 bit와 긴 bit를 baud 오차로 환산하면 아래와 같습니다.

| Baud | 짧은 bit 등가 baud 오차 | 긴 bit 등가 baud 오차 |
|---|---:|---:|
| 9600 | `+75.439%` | `-30.070%` |
| 14400 | `+75.439%` | `-30.070%` |
| 19200 | `+75.439%` | `-30.070%` |
| 38400 | `+75.439%` | `-30.070%` |
| 57600 | `+78.571%` | `-30.556%` |
| 115200 | `+78.571%` | `-30.556%` |
| 230400 | `+78.571%` | `-30.556%` |
| 460800 | `+85.185%` | `-31.507%` |
| 921600 | `+92.308%` | `-32.432%` |

이 값이 큰 이유는 jitter를 bit time의 매우 큰 비율로 주입했기 때문입니다.

즉 이 표는 "상대 baud mismatch를 직접 인가했다"기보다,
"alternating bit width distortion를 baud 오차 관점으로 환산하면 이 정도"라는 해석으로 보는 것이 맞습니다.

## 10. 실패 양상

최초 FAIL 지점의 대표 로그는 [uart_jitter_sweep_run_log.md](./uart_jitter_sweep_run_log.md) 에 정리했습니다.

실패는 대체로 아래 형태였습니다.

- `UART APB wrapper directed test failed`

즉 RX jitter 시나리오에서 기대한 `0xA6` 복원이 깨지면서 TB가 fatal로 종료된 것입니다.

## 11. 결론

이번 sweep 결과를 한 줄로 정리하면:

> 현재 UART RX는 alternating deterministic jitter 조건에서 지원 baud 전체에 대해 약 `43% ~ 48%` 범위까지 정상 수신했고, FAIL 경계는 baud가 높아질수록 약간 뒤로 이동했다.

실무적으로는 다음처럼 설명하면 좋습니다.

- "이 UART는 이번 jitter 모델에서 꽤 큰 bit-width disturbance까지 버틴다."
- "다만 이 수치는 random jitter나 외부 노이즈 환경의 절대 허용 한계로 해석하면 안 된다."
- "현재 결과는 RX sampling margin의 상대 비교 자료로 보는 것이 적절하다."

## 12. 권장 후속 실험

| 항목 | 목적 |
|---|---|
| random jitter sweep | deterministic alternation 외 일반적 위상 흔들림 확인 |
| baud mismatch sweep | 송신기/수신기 평균 속도 차이에 대한 tolerance 확인 |
| noise pulse injection | line glitch에 대한 내성 확인 |
| majority vote 적용 후 재측정 | sampling robustness 개선 효과 수치화 |
