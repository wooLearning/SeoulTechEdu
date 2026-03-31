# UART 누적 방식 분주 상세 보고서

## 1. 문서 목적

이 문서는 현재 저장소의 UART baud rate 생성 방식이 어떤 구조로 구현되어 있는지, 왜 `phase accumulator` 방식이 선택되었는지, 평균 baud 정확도와 tick-to-tick jitter가 어떻게 동시에 나타나는지를 코드와 수식 중심으로 자세히 설명하는 보고서이다.

대상 RTL:

- [uart_apb_wrapper.v](../../src/uart_peri/uart_apb_wrapper.v)
- [uart_core.v](../../src/uart_peri/uart_core.v)
- [Top_UART.v](../../src/uart_peri/uart_source/Top_UART.v)
- [baud_tick_16oversample.v](../../src/uart_peri/uart_source/baud_tick_16oversample.v)
- [tx.v](../../src/uart_peri/uart_source/tx.v)
- [rx.v](../../src/uart_peri/uart_source/rx.v)

관련 검증 TB:

- [tb_uart_apb_wrapper_wave.sv](../../tb/tb_uart_apb_wrapper_wave.sv)

---

## 2. 한눈에 보는 결론

- 현재 UART baud generator는 단순 정수분주기가 아니라 `phase accumulator` 기반 NCO 방식이다.
- 내부 tick은 `UART baud` 자체가 아니라 `16x oversampling tick`을 생성한다.
- 평균 주파수는 매우 정확하지만, 매 tick 간격은 완전히 일정하지 않고 `N` 또는 `N+1` 클럭으로 흔들린다.
- 이 흔들림은 random jitter가 아니라 `deterministic quantization jitter`이다.
- TX와 RX는 동일한 16x tick을 공유하며, 16 tick을 1 bit 기간으로 본다.
- RX는 start bit에서 반 비트(8 tick) 확인 후, 이후 16 tick마다 단일 샘플링한다.

---

## 3. 코드 기준 전체 데이터 경로

UART baud 선택과 생성 경로는 아래처럼 이어진다.

```text
APB BAUDCFG write / external i_baud_sel
    -> uart_apb_wrapper
        -> w_uart_baud_sel
            -> uart_core
                -> Top_uart
                    -> baud_tick_16
                        -> w_b_tick
                            -> tx / rx FSM
```

실제 선택 신호는 [uart_apb_wrapper.v](../../src/uart_peri/uart_apb_wrapper.v)에서 만들어진다.

- `r_apb_baud_sel`: APB가 쓴 baud 선택값
- `r_baud_source_sel`: baud 선택 원천
- `w_uart_baud_sel = r_baud_source_sel ? r_apb_baud_sel : i_baud_sel`

즉,

- `r_baud_source_sel = 0`: 외부 스위치 `i_baud_sel` 사용
- `r_baud_source_sel = 1`: APB 레지스터 `r_apb_baud_sel` 사용

이 동작은 [uart_apb_wrapper.v](../../src/uart_peri/uart_apb_wrapper.v)에서 확인할 수 있다.

---

## 4. BAUDCFG 레지스터 해석

BAUD 설정 관련 주소는 `ADDR_BAUDCFG = 0x14`이다.

읽기 값 구성:

- `prdata[3:0]`: APB에 저장된 baud selector
- `prdata[4]`: source select bit
- `prdata[11:8]`: 현재 실제로 사용 중인 active baud selector

즉 BAUDCFG는 단순 설정 레지스터가 아니라, "저장값"과 "실제 활성값"을 동시에 보여주는 구조이다.

reset 후 초기값:

- `r_apb_baud_sel <= 4'd5`
- `r_baud_source_sel <= 1'b0`

즉 reset 직후엔 APB 저장값은 `5`지만, 실제 동작은 외부 `i_baud_sel`이 결정한다.

TB에서는 [tb_uart_apb_wrapper_wave.sv](../../tb/tb_uart_apb_wrapper_wave.sv)에서 reset 후 `i_baud_sel = 4'd5`를 넣어 기본 active baud를 `115200`으로 맞춘다.

그 다음 `0x17`을 BAUDCFG에 쓰면:

- `[3:0] = 7`
- `[4] = 1`

즉 "APB 선택 사용 + selector 7"이므로 active baud는 `460800`이 된다.

---

## 5. baud_tick_16 모듈의 핵심 아이디어

[baud_tick_16oversample.v](../../src/uart_peri/uart_source/baud_tick_16oversample.v)에서 핵심 파라미터는 아래와 같다.

- `SYS_CLK = 100_000_000`
- `OVERSAMPLE = 16`
- `ACC_WIDTH = 24`

핵심 내부 상태:

- `phase_acc`: 24비트 누적기
- `phase_inc`: 매 클럭 더할 증가량
- `phase_sum = phase_acc + phase_inc`
- `baud_tick = phase_sum[ACC_WIDTH]`

즉 매 시스템 클럭마다 일정량 `phase_inc`를 누적하고, 덧셈 carry가 발생하는 순간 1클럭 폭의 tick을 낸다.

이 구조는 DDS/NCO에서 매우 흔한 방식이다.

---

## 6. 수학적 모델

### 6.1 목표 tick 주파수

UART는 16x oversampling을 사용하므로, 목표 tick 주파수는 다음과 같다.

$$
f_{\text{tick,target}} = 16 \cdot f_{\text{baud}}
$$

예를 들어:

- `115200 baud` -> `1,843,200 Hz`
- `460800 baud` -> `7,372,800 Hz`

### 6.2 phase increment 계산

코드에서 사용한 계산식은 다음과 같다.

$$
K = \operatorname{round}\left(\frac{f_{\text{tick,target}} \cdot 2^W}{f_{\text{clk}}}\right)
$$

여기서:

- $K$: `phase_inc`
- $W$: `ACC_WIDTH = 24`
- $f_{\text{clk}}$: 시스템 클럭 (`100 MHz`)

코드 구현은 반올림을 위해 `(SYS_CLK / 2)`를 더한 정수 나눗셈 형태다.

$$
K =
\left\lfloor
\frac{f_{\text{tick,target}} \cdot 2^W + f_{\text{clk}}/2}{f_{\text{clk}}}
\right\rfloor
$$

### 6.3 누적기 상태 천이

클럭 인덱스를 $n$이라 하면,

$$
\phi[n+1] = (\phi[n] + K) \bmod 2^W
$$

그리고 carry 발생 여부를 tick으로 해석한다.

$$
\text{tick}[n] =
\left\lfloor \frac{\phi[n] + K}{2^W} \right\rfloor
$$

여기서 `tick[n]`은 0 또는 1이다.

### 6.4 평균 출력 주파수

장기 평균에서 tick 발생 비율은 $K / 2^W$에 수렴하므로,

$$
f_{\text{tick,actual}} = f_{\text{clk}} \cdot \frac{K}{2^W}
$$

최종 UART baud는 16x tick 기준이므로,

$$
f_{\text{baud,actual}} = \frac{f_{\text{tick,actual}}}{16}
$$

---

## 7. 왜 정수분주가 아니라 누적기 방식인가

정수분주기라면 tick 간격은 항상 같은 클럭 수여야 한다. 하지만 `100 MHz`에서 `115200 x 16 = 1.8432 MHz`는 정확히 나누어떨어지지 않는다.

이상적인 tick 간격은:

$$
T_{\text{tick,ideal(clocks)}} = \frac{f_{\text{clk}}}{f_{\text{tick,target}}}
$$

예를 들어 `115200 baud`에서는

$$
\frac{100,000,000}{1,843,200} \approx 54.253472\ \text{clocks}
$$

즉 "한 tick마다 54.253472 클럭" 같은 값은 정수분주기로 만들 수 없다.

누적기 방식은:

- 어떤 tick은 54클럭 만에 내고
- 어떤 tick은 55클럭 만에 내서
- 장기 평균이 54.253472에 맞도록 만든다.

즉 "순간 간격은 흔들리지만 평균은 매우 정확"해진다.

---

## 8. baud selector와 실제 증가량 테이블

현재 구현의 selector 매핑은 [baud_tick_16oversample.v](../../src/uart_peri/uart_source/baud_tick_16oversample.v)의 `case (i_baud_sel)`에 정의되어 있다.

| Selector | Baud | Target Tick (Hz) | phase_inc | Actual Tick (Hz) | Actual Baud | Error (ppm) |
|---:|---:|---:|---:|---:|---:|---:|
| 0 | 9600 | 153600 | 25770 | 153601.169586 | 9600.073099 | +7.614 |
| 1 | 14400 | 230400 | 38655 | 230401.754379 | 14400.109649 | +7.614 |
| 2 | 19200 | 307200 | 51540 | 307202.339172 | 19200.146198 | +7.614 |
| 3 | 38400 | 614400 | 103079 | 614398.717880 | 38399.919867 | -2.087 |
| 4 | 57600 | 921600 | 154619 | 921601.057053 | 57600.066066 | +1.147 |
| 5 | 115200 | 1843200 | 309238 | 1843202.114105 | 115200.132132 | +1.147 |
| 6 | 230400 | 3686400 | 618475 | 3686398.267746 | 230399.891734 | -0.470 |
| 7 | 460800 | 7372800 | 1236951 | 7372802.495956 | 460800.155997 | +0.339 |
| 8 | 921600 | 14745600 | 2473901 | 14745599.031448 | 921599.939466 | -0.066 |

관찰 포인트:

- 전체 평균 오차는 매우 작다.
- baud가 올라갈수록 `ideal tick clocks`는 작아지고, tick 간격 양자화 영향은 상대적으로 눈에 더 띌 수 있다.
- 그럼에도 평균 baud 정확도는 충분히 좋다.

---

## 9. tick 간격이 54/55, 13/14처럼 나오는 이유

tick 간격의 이상적인 클럭 수는 다음과 같다.

$$
N_{\text{ideal}} = \frac{f_{\text{clk}}}{f_{\text{tick,target}}}
$$

누적기 방식에서는 실제 tick 간격이 대체로 아래 두 값 사이를 오간다.

$$
\lfloor N_{\text{ideal}} \rfloor
\quad \text{or} \quad
\lceil N_{\text{ideal}} \rceil
$$

### 9.1 115200 baud 예시

목표 tick 주파수:

$$
f_{\text{tick,target}} = 115200 \cdot 16 = 1,843,200\ \text{Hz}
$$

이상적 tick 간격:

$$
N_{\text{ideal}} = \frac{100,000,000}{1,843,200}
 \approx 54.253472
$$

따라서 실제 tick spacing은 대체로 `54` 또는 `55` 클럭이다.

TB에서도 `switch_115200 avg_tick_cycles=54`로 관측되는데, 이는 TB가 정수 평균을 사용하기 때문이다. 이론 평균은 `54.253472...`이다.

### 9.2 460800 baud 예시

$$
f_{\text{tick,target}} = 460800 \cdot 16 = 7,372,800\ \text{Hz}
$$

$$
N_{\text{ideal}} = \frac{100,000,000}{7,372,800}
 \approx 13.563368
$$

따라서 실제 tick spacing은 대체로 `13` 또는 `14` 클럭이다.

TB의 `apb_460800 avg_tick_cycles=13` 역시 정수 평균 truncation 때문이고, 실제 이론 평균은 `13.563368...`이다.

---

## 10. TX가 이 tick을 어떻게 쓰는가

[tx.v](../../src/uart_peri/uart_source/tx.v)에서는 `baud_tick`이 16번 들어올 때마다 한 UART bit를 진행한다.

내부적으로:

- `c_baud_cnt`가 `0`부터 `15`까지 센다.
- `baud_tick`이 들어올 때만 카운트가 증가한다.
- `c_baud_cnt == 15`일 때 다음 bit로 넘어간다.

즉 1bit 시간은:

$$
T_{\text{bit}} = 16 \cdot T_{\text{tick}}
$$

그래서 TX의 실제 평균 baud는 `tick / 16`으로 정확히 연결된다.

TX 프레임 길이는:

- Start 1bit
- Data 8bit
- Stop 1bit

총 10bit이다.

따라서 115200 baud 기준 1프레임 시간은 대략:

$$
10 \cdot \frac{1}{115200} \approx 86.8\ \mu s
$$

---

## 11. RX가 이 tick을 어떻게 쓰는가

[rx.v](../../src/uart_peri/uart_source/rx.v)에서는 다음 순서로 동작한다.

### 11.1 입력 동기화

`i_rx_data`는 두 단계 FF (`rx_sync_ff1`, `rx_sync_ff2`)를 거쳐 동기화된다.

즉 비동기 UART 입력을 바로 FSM이 쓰지 않는다.

### 11.2 start 검출

IDLE 상태에서

- `baud_tick` 시점에
- 동기화된 입력이 low이면

`START` 상태로 진입한다.

### 11.3 반 비트 검증

`START` 상태에서 `baud_tick`을 세며,

- low가 유지되지 않으면 false start로 버린다.
- `8 tick` 동안 low가 유지되면 정상 start로 인정한다.

즉 start bit의 중앙 부근에서 유효성을 확인하는 셈이다.

### 11.4 데이터 샘플링

`DATA` 상태에 들어간 뒤에는 `16 tick`마다 한 번씩 샘플링한다.

즉 각 data bit 중심 근처에서 단일 샘플링을 수행한다.

여기서 중요한 점은:

- 16x oversampling tick을 쓰지만
- 16개 샘플 majority voting은 하지 않는다.
- 중앙 근처 single-point sampling 구조다.

따라서 평균 baud 정확도는 높지만, 외란/잡음/비대칭 jitter에 대한 여유는 majority voting 구조보다 작다.

---

## 12. 이 설계에서 BAUD_RATE 파라미터의 실제 의미

한 가지 주의할 점이 있다.

- `uart_apb_wrapper`
- `uart_core`
- `Top_uart`
- `baud_tick_16`

모두 `BAUD_RATE` 파라미터를 갖고 있지만, 현재 실제 baud 선택의 핵심은 `i_baud_sel`이다.

특히 [baud_tick_16oversample.v](../../src/uart_peri/uart_source/baud_tick_16oversample.v)에서는 `case (i_baud_sel)`로 baud를 고르므로, `BAUD_RATE` 파라미터는 현재 구현에서 실질적 동작 결정에 거의 쓰이지 않는다.

즉 현 구조는:

- "정적 parameter 기반 baud 설정"
보다는
- "런타임 selector 기반 baud 선택"

에 가깝다.

이 점은 문서화가 잘 안 되어 있으면 나중에 parameter만 바꾸고 실제 baud가 안 바뀌는 혼동을 만들 수 있다.

---

## 13. 장점과 한계

### 13.1 장점

- 정수분주로 만들 수 없는 baud도 평균적으로 매우 정확하게 생성 가능
- 여러 baud rate를 작은 selector와 산술식으로 유연하게 지원 가능
- 16x oversampling 구조에 잘 맞음
- `100 MHz` 기준으로 921600 baud까지도 매우 작은 평균 오차 유지

### 13.2 한계

- tick 간격은 완전히 일정하지 않음
- high baud로 갈수록 tick 간격의 절대 클럭 수가 작아져, 상대적으로 간격 양자화가 눈에 띔
- RX가 majority voting 없이 single-point sampling이므로, noise margin 관점에서 더 강건한 구조는 아님

---

## 14. TB 기반 관찰 결과와 코드 해석 연결

[tb_uart_apb_wrapper_wave.sv](../../tb/tb_uart_apb_wrapper_wave.sv)는 이 구현을 아주 잘 보여준다.

검증 포인트:

1. reset 후 `i_baud_sel = 5` 상태에서 tick 평균 측정
2. APB BAUDCFG에 `0x17` write
3. active selector가 `7`로 바뀌는지 확인
4. tick 간격이 더 짧아졌는지 확인
5. TX 1byte와 RX 1byte를 새 baud에서 실제 수행

즉 이 TB는 "레지스터 값이 바뀐다" 수준이 아니라,

- 내부 `phase_inc`
- tick 속도 변화
- TX/RX 동작 성공

까지 모두 연결해서 보여준다.

---

## 15. 발표용 핵심 문장

### 짧은 버전

> 현재 UART baud generator는 24비트 phase accumulator 기반 16x oversampling NCO로 구현되어 있으며, 평균 baud 오차는 매우 작지만 tick 간격은 `N/N+1` 클럭으로 양자화된다.

### 설명형 버전

> 이 설계는 시스템 클럭을 정수로 나누는 대신 phase accumulator를 사용해 16배 oversampling tick을 생성한다. 따라서 원하는 baud에 대해 평균 주파수는 매우 정확하게 맞출 수 있지만, 개별 tick 간격은 완전히 일정하지 않고 두 개의 인접한 정수 클럭 간격 사이를 오간다. TX와 RX는 이 16x tick을 공통으로 사용하며, RX는 start bit를 반 비트 시점에서 검증한 후 16 tick마다 단일 샘플링한다.

---

## 16. 최종 요약

- 현재 UART의 baud 생성 방식은 `phase accumulator 기반 16x oversampling 분주기`이다.
- 수식으로는 `K = round(f_tick * 2^W / f_clk)`를 사용한다.
- 평균 출력 주파수는 `f_clk * K / 2^W`로 해석된다.
- `115200`에서는 tick 간격이 대략 `54/55`클럭, `460800`에서는 `13/14`클럭으로 흔들린다.
- 이 흔들림은 구현 결함이 아니라 분수분주 방식의 정상적인 양자화 현상이다.
- 실제 UART bit timing은 이 16x tick을 16개 묶어서 만들기 때문에 평균 baud 정확도는 높다.
- 다만 RX는 majority voting이 아니라 single-point sampling 구조이므로, robustness 평가는 평균 baud 오차뿐 아니라 sampling margin까지 함께 봐야 한다.
