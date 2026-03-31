# UART 발표자료용 종합 보고서

## 1. 문서 목적

이 문서는 발표자료 제작에 바로 사용할 수 있도록 UART 주변장치의 구조, 동작, baud generator 특성, jitter 검증 결과, 시각화 자료의 의미를 한 번에 정리한 종합 Markdown 보고서입니다.

연계 자료:

- [메인 한글 보고서](./uart_peripheral_report_ko.md)
- [Jitter sweep 보고서](./uart_jitter_sweep_report_ko.md)
- [Jitter sweep 결과 CSV](../data/uart_jitter_sweep_results.csv)
- [Jitter sweep 요약 CSV](../data/uart_jitter_threshold_summary.csv)
- [Jitter pass/fail 전체 매트릭스 CSV](../data/uart_jitter_pass_fail_matrix.csv)
- [노트북](../notebooks/uart_verification_notebook.ipynb)

## 2. 한 줄 요약

현재 UART는 APB wrapper, UART core, TX/RX FIFO, TX/RX block, 16x baud tick generator로 구성되어 있고, 평균 baud 오차는 매우 작습니다.  
다만 실제 robustness 논의의 핵심은 baud 평균 오차보다 RX sampling 구조와 jitter tolerance이며, 이번 sweep 결과에서는 alternating deterministic jitter 조건에서 지원 baud 전체가 약 `43% ~ 48%` 수준까지 PASS했습니다.

## 3. UART 구조 요약

### 3.1 블록 구조

| 블록 | 역할 | 비고 |
|---|---|---|
| `uart_apb_wrapper` | APB 레지스터 인터페이스 | MMIO read/write, status/control 노출 |
| `uart_core` | 내부 제어 블록 | TX/RX FIFO와 UART datapath 연결 |
| `Top_uart` | TX/RX wrapper | TX, RX, baud tick 묶음 |
| `tx` | UART 송신기 | start/data/stop serial output |
| `rx` | UART 수신기 | start detect, bit sample, stop check |
| `baud_tick_16` | 16x baud tick 생성기 | phase accumulator 기반 |
| `Top_FIFO` | TX/RX FIFO | buffering 담당 |

### 3.2 데이터 흐름

```text
CPU/MMIO
  -> APB
    -> uart_apb_wrapper
      -> uart_core
        -> TX FIFO -> TX -> o_uart_tx
        -> i_uart_rx -> RX -> RX FIFO
```

## 4. TX / RX 동작 핵심

### 4.1 TX

- CPU가 `UART_TXDATA`에 write
- TX FIFO에 1바이트 저장
- TX idle이면 자동으로 serializer 시작
- start 1bit, data 8bit, stop 1bit 전송

### 4.2 RX

- 외부 `i_uart_rx`를 2FF synchronizer로 먼저 안정화
- `baud_tick` 기준으로 start low 검출
- 반 비트 지점 확인 후 DATA 상태로 이동
- 16tick마다 1bit씩 single-point sampling
- stop bit가 high면 완료, low면 frame error

### 4.3 설계적으로 중요한 점

| 항목 | 현재 구현 |
|---|---|
| Oversampling | 16x |
| Start detect | `baud_tick` 기준 |
| Data sampling | single-point |
| Majority vote | 없음 |
| Error flag | frame error, overflow sticky flag |

즉 이 UART는 16x timing은 쓰지만 실제 bit 판정은 majority vote가 아니라 single-point sampling입니다.

## 5. Baud generator 방식

### 5.1 일반적인 divider와의 차이

이 UART는 단순 정수 divider가 아니라 **phase accumulator 기반 NCO**를 사용합니다.

원리:

- 목표 tick 주파수 = `baud_rate * 16`
- 이를 `phase_inc`로 환산
- 매 클럭마다 accumulator에 `phase_inc`를 더함
- carry가 발생하면 `baud_tick = 1`

즉, "매번 정확히 같은 간격"으로 tick을 만드는 대신,
`N clk`와 `N+1 clk` 간격을 섞어서 **장기 평균 주파수**를 맞춥니다.

### 5.2 코드 기준 수식 정리

현재 코드 [baud_tick_16oversample.v](../../src/uart_peri/uart_source/baud_tick_16oversample.v) 기준으로 쓰면 수식은 아래처럼 정리할 수 있습니다.

1. 목표 16x oversampling tick 주파수

```text
f_target = baud_rate x 16
```

2. phase increment 계산

```text
phase_inc = round((f_target / f_sys) x 2^ACC_WIDTH)
```

여기서 현재 코드의 파라미터는:

- `f_sys = 100 MHz`
- `ACC_WIDTH = 24`

즉 실제 구현 관점에서는:

```text
phase_inc = round((baud_rate x 16 / 100000000) x 2^24)
```

3. 매 시스템 클럭마다 accumulator 업데이트

```text
phase_acc_next = phase_acc + phase_inc
```

4. carry가 발생한 클럭에서 baud tick 생성

```text
baud_tick = carry_out(phase_acc + phase_inc)
```

5. 장기 평균 실제 tick 주파수

```text
f_tick_actual ~= (phase_inc / 2^ACC_WIDTH) x f_sys
```

6. 실제 baud rate

```text
baud_actual ~= f_tick_actual / 16
```

즉 최종적으로는:

```text
baud_actual ~= (phase_inc / 2^24) x (100 MHz / 16)
```

### 5.3 정수 divider 방식과의 수식 차이

PDF에서 설명한 정수 divider 방식은 보통 아래처럼 계산합니다.

```text
C = floor(f_sys / (baud_rate x 16))
baud_actual = f_sys / (C x 16)
```

반면 현재 코드의 NCO 방식은 divider `C`를 직접 세지 않고,
`phase_inc`를 누적해서 평균 주파수를 맞춥니다.

즉 차이는 아래처럼 요약할 수 있습니다.

| 방식 | 핵심 수식 | 특징 |
|---|---|---|
| 정수 divider | `C = floor(f_sys / (baud x 16))` | tick 간격은 고정, 평균 오차는 커질 수 있음 |
| 현재 코드(NCO) | `phase_inc = round((baud x 16 / f_sys) x 2^24)` | tick 간격은 `N/N+1`, 평균 오차는 매우 작음 |

### 5.4 왜 이 방식이 좋은가

- 평균 baud 오차가 매우 작음
- 지원 baud 범위 전체에서 정밀하게 주파수 근사 가능
- 정수 divider보다 미세한 주파수 설정에 유리

### 5.5 이 방식에서 생기는 현상

- tick 간격이 완전히 일정하지 않음
- `N / N+1` 클럭 간격의 quantization jitter가 생김
- 하지만 이 jitter는 랜덤 노이즈가 아니라 **결정론적 양자화 jitter**임

## 6. ppm이 무엇인가

`ppm`은 `parts per million`입니다.

- `1 ppm = 0.0001%`
- `10 ppm = 0.001%`
- `100 ppm = 0.01%`

즉 아주 작은 오차를 보기 쉽게 표현하는 단위입니다.

예를 들어:

- `7.614 ppm`
- `= 0.0007614%`

그래서 baud generator 평균 오차를 비교할 때는 `%`보다 `ppm`이 더 보기 좋습니다.

## 7. 왜 baud rate가 낮을수록 ppm 오차가 더 커 보이는가

이건 매우 중요한 질문입니다.

핵심 이유는 **phase accumulator의 양자화 오차가 작은 `phase_inc` 값에서 상대적으로 더 크게 보이기 때문**입니다.

### 7.1 직관적 설명

- 낮은 baud에서는 목표 tick 주파수가 작음
- 따라서 accumulator에 더하는 `phase_inc`도 작음
- 작은 수를 정해진 비트폭에서 반올림하면 상대 오차 비율이 커지기 쉬움
- 높은 baud에서는 `phase_inc`가 더 커져서 같은 1 LSB 반올림 오차도 상대 비율은 작아짐

즉:

- 낮은 baud: 작은 숫자 반올림 -> 상대 오차 약간 큼
- 높은 baud: 큰 숫자 반올림 -> 상대 오차 더 작음

### 7.2 중요한 해석

이 말은 "낮은 baud가 나쁘다"는 뜻이 아닙니다.

- 낮은 baud 쪽 ppm이 상대적으로 더 크게 보여도 절대값은 여전히 매우 작음
- 예를 들어 `+7.614 ppm`도 UART 관점에서는 아주 작은 오차

즉 발표에서는 이렇게 말하면 됩니다.

> 낮은 baud에서 ppm 오차가 조금 더 커 보이는 이유는 phase accumulator의 양자화 오차가 작은 increment 값에서 상대적으로 더 크게 보이기 때문이고, 절대 오차 자체는 여전히 매우 작다.

## 8. Baud 오차 시각화와 의미

### 8.1 평균 baud 오차 그래프

![UART Baud Error](../visuals/figures/uart_baud_error_ppm.png)

이 그래프가 의미하는 것:

- 지원 baud별 평균 baud 오차의 절대값(ppm)
- 낮은 baud에서 ppm이 조금 더 큼
- 하지만 전 구간에서 절대 오차는 매우 작음

### 8.2 Tick quantization 그래프

![UART Tick Spacing](../visuals/figures/uart_tick_spacing.png)

이 그래프가 의미하는 것:

- 16x oversample tick 간격이 완전히 고정되지 않고 `N/N+1 clk`로 양자화됨
- 평균 baud는 정확하지만 순간 tick 간격은 조금씩 달라짐
- 결국 robustness는 평균 오차보다 RX sampling margin이 더 중요함

## 9. Jitter 테스트가 의미하는 것

이 테스트의 질문은 아주 명확합니다.

> bit 길이가 흔들리는 송신기를 상대로 현재 UART RX가 데이터를 얼마나 잘 복원하는가?

즉 이것은:

- 단순 baud 평균 오차 측정이 아니라
- **timing disturbance가 있을 때 RX가 얼마나 robust한지** 보는 테스트입니다

### 9.1 현재 TB의 jitter 주입 방식

- test byte: `0xA6`
- 각 bit period를 번갈아
  - `nominal - jitter`
  - `nominal + jitter`
- 즉 alternating deterministic jitter

### 9.2 PASS 조건

- DUT가 최종적으로 `RXDATA == 0xA6`를 복원하면 PASS

### 9.3 TB 코드에서 jitter를 어떻게 구현했는가

이번 TB의 jitter는 **RX line의 bit 길이를 직접 흔드는 방식**으로 구현했습니다.

즉, DUT 내부 baud generator를 흔든 것이 아니라,
테스트벤치가 외부 송신기 역할을 하면서 `i_uart_rx`에 들어가는 프레임의 각 bit 길이를 일부러 늘였다 줄였다 한 것입니다.

구현 흐름은 아래 순서입니다.

1. `config`에서 baud와 기본 jitter 크기 설정
2. test에서 jittered RX 전송 함수 호출
3. driver가 interface의 `send_uart_rx_frame()`를 호출
4. interface가 각 bit 구간마다 `nominal +/- jitter` 지연을 번갈아 적용
5. DUT가 이를 실제 UART line 입력으로 받아 복원

### 9.4 기본 설정값

[config.svh](../../tb/uart_peri_tb/objs/config.svh#L14) 에서 기본값은 아래처럼 잡혀 있습니다.

```systemverilog
function new();
    m_clk_period_ns      = 10;
    m_timeout_cycles     = 1_000_000;
    m_apb_timeout_cycles = 100_000;
    m_verbose            = 1'b1;
    set_baud_sel(4'd5);
    m_jitter_ns          = m_bit_period_ns * 0.08;
endfunction
```

의미:

- 기본 baud 선택은 `4'd5 = 115200`
- 기본 bit period는

```text
m_bit_period_ns = 1e9 / baud_rate
```

- 기본 jitter 크기는

```text
m_jitter_ns = m_bit_period_ns x 0.08
```

즉 기본 directed test에서는 `115200 baud`, `±8% jitter`를 사용합니다.

### 9.5 clocking block과 jitter 주입의 역할 차이

이 TB를 설명할 때 가장 중요한 포인트는 **APB 쪽 정상 타이밍**과 **UART line 쪽 의도적 timing disturbance**를 구분하는 것입니다.

#### 1. APB 타이밍은 clocking block으로 안정화

APB 접근은 DUT 클럭 `pclk` 기준으로 정확하고 안정적으로 맞추기 위해 clocking block을 사용합니다.

[interface.sv](../../tb/uart_peri_tb/interface.sv#L21) 의 핵심은 아래와 같습니다.

```systemverilog
clocking drv_cb @(posedge pclk);
    default input #1step output #0;
    output paddr;
    output psel;
    output penable;
    output pwrite;
    ...
endclocking
```

driver는 APB read/write를 할 때 이 clocking block 이벤트에 맞춰 동작합니다.

```systemverilog
@(vif_uart_peri.drv_cb);
vif_uart_peri.paddr   <= addr;
vif_uart_peri.pwrite  <= 1'b1;
...

@(vif_uart_peri.drv_cb);
vif_uart_peri.penable <= 1'b1;

@(vif_uart_peri.mon_cb);
slverr = vif_uart_peri.pslverr;
```

즉 clocking block은:

- DUT 클럭 기준 APB 타이밍 정렬
- read/write race 감소
- bus access를 안정적으로 만드는 역할

을 합니다.

중요한 점은 **clocking block 자체는 jitter를 넣는 장치가 아니라는 것**입니다.

#### 2. UART RX line은 realtime delay로 일부러 흔듦

반면 jitter는 APB처럼 clocking block으로 넣지 않고,
UART serial line `i_uart_rx`를 직접 구동하면서 **bit가 유지되는 시간(duration)** 만 조절해 넣습니다.

즉 이 테스트는:

- `pclk`를 흔들지 않음
- DUT 내부 `baud_tick`를 흔들지 않음
- APB bus timing도 흔들지 않음
- 오직 **외부에서 들어오는 UART RX bit 경계(edge) 시점만 일부러 앞당기거나 늦춤**

따라서 이 검증은

> "버스 타이밍 검증"이 아니라 "UART line timing disturbance에 대한 RX robustness 검증"

이라고 설명하는 것이 맞습니다.

### 9.6 test 코드에서의 호출

[test_uart_directed.svh](../../tb/uart_peri_tb/tests/test_uart_directed.svh#L48) 에서 jitter 검증은 아래처럼 시작됩니다.

```systemverilog
virtual task check_jitter_tolerance();
    byte unsigned rx_data;

    `UART_TB_INFO($sformatf(
        "Jitter test baud=%0d bit_period_ns=%0.3f jitter_ns=%0.3f jitter_pct=%0.3f",
        m_cfg.m_baud_rate,
        m_cfg.m_bit_period_ns,
        m_cfg.m_jitter_ns,
        (m_cfg.m_jitter_ns * 100.0) / m_cfg.m_bit_period_ns
    ));
    m_env.m_driver.uart_send_byte_jittered(8'hA6, m_cfg.m_jitter_ns);
    m_env.m_driver.wait_rx_not_empty();
    m_env.m_driver.read_rxdata(rx_data);
    check_eq8(rx_data, 8'hA6, "RX jittered byte");
endtask
```

여기서 중요한 점:

- test byte는 `0xA6`
- `uart_send_byte_jittered()`로 외부 RX 입력을 만듦
- DUT가 byte를 받아 RX FIFO에 넣을 때까지 기다림
- 최종적으로 `RXDATA == 0xA6`면 PASS

즉 jitter test의 검증 질문은 명확합니다.

> bit 길이가 흔들리는 외부 송신기를 상대로도 DUT가 원래 데이터를 그대로 복원할 수 있는가?

### 9.7 driver에서 interface로 전달

[driver.svh](../../tb/uart_peri_tb/components/driver.svh#L155) 에서는 아래처럼 interface task를 호출합니다.

```systemverilog
virtual task uart_send_byte_jittered(
    input byte unsigned data,
    input realtime jitter_ns,
    input bit bad_stop = 1'b0
);
    vif_uart_peri.send_uart_rx_frame(data, m_cfg.m_bit_period_ns, jitter_ns, bad_stop);
endtask
```

의미:

- `data`: 보낼 byte
- `m_cfg.m_bit_period_ns`: nominal bit 길이
- `jitter_ns`: bit마다 더하거나 뺄 시간
- `bad_stop`: stop bit를 깨뜨릴지 여부

즉 driver는 복잡한 계산을 하지 않고,
**"이 byte를 이 nominal period와 jitter로 line에 뿌려라"** 라는 지시만 interface에 넘깁니다.

### 9.8 실제 jitter 생성 핵심 코드

실제 jitter는 [interface.sv](../../tb/uart_peri_tb/interface.sv#L73) 의 `wait_line_interval()`에서 만들어집니다.

```systemverilog
task automatic wait_line_interval(
    input realtime nominal_ns,
    input realtime jitter_ns,
    inout bit jitter_polarity
);
    realtime delay_ns;
    delay_ns = nominal_ns;
    if (jitter_ns > 0.0) begin
        if (jitter_polarity) begin
            delay_ns = nominal_ns + jitter_ns;
        end else begin
            delay_ns = nominal_ns - jitter_ns;
        end
        jitter_polarity = ~jitter_polarity;
    end
    #(delay_ns);
endtask
```

이 코드의 의미:

- 기본 delay는 `nominal_ns`
- jitter가 0보다 크면
  - 이번 bit는 `nominal - jitter`
  - 다음 bit는 `nominal + jitter`
  - 그다음 bit는 다시 `nominal - jitter`
- 이런 식으로 polarity를 뒤집으면서 번갈아 적용

즉 현재 TB의 jitter 모델은:

```text
short bit, long bit, short bit, long bit, ...
```

형태의 **alternating deterministic jitter** 입니다.

### 9.9 "일부러 신호를 늦게 준다"는 게 정확히 무슨 뜻인가

네, 맞습니다. 더 정확하게 말하면:

- 어떤 bit는 원래보다 **더 짧게 유지**해서 다음 edge가 **더 빨리** 나오게 하고
- 어떤 bit는 원래보다 **더 길게 유지**해서 다음 edge가 **더 늦게** 나오게 만든 것입니다

UART는 serial line protocol이라서, 수신기 입장에서는 각 bit가 **얼마 동안 유지되다가 언제 바뀌는지**가 핵심입니다.

예를 들어 nominal bit period가 `T`, jitter가 `j`라면:

- 이상적 입력: edge가 `T, 2T, 3T, ...` 시점에 바뀜
- jitter 입력: edge가 `T-j`, `T-j + T+j`, `...` 식으로 바뀜

즉 TB는 실제로 **edge timing을 일부러 앞당기거나 늦추는 방식**으로 jitter를 만든 것입니다.

그래서 발표할 때는 아래처럼 말하면 됩니다.

> TB에서는 UART RX 선로의 bit 경계 시점을 일부러 앞당기거나 늦춰서, 수신기가 샘플링 중심을 얼마나 잘 유지하는지 본다.

### 9.10 UART frame 전체에 적용되는 방식

같은 파일의 [send_uart_rx_frame()](../../tb/uart_peri_tb/interface.sv#L91) 에서 start/data/stop 전체에 동일한 방식이 적용됩니다.

```systemverilog
task automatic send_uart_rx_frame(
    input byte unsigned data,
    input realtime bit_period_ns,
    input realtime jitter_ns,
    input bit bad_stop
);
    bit jitter_polarity;
    jitter_polarity = 1'b0;

    i_uart_rx <= 1'b1;
    #(bit_period_ns);

    i_uart_rx <= 1'b0;
    wait_line_interval(bit_period_ns, jitter_ns, jitter_polarity);

    for (int idx = 0; idx < 8; idx++) begin
        i_uart_rx <= data[idx];
        wait_line_interval(bit_period_ns, jitter_ns, jitter_polarity);
    end

    i_uart_rx <= (bad_stop) ? 1'b0 : 1'b1;
    wait_line_interval(bit_period_ns, jitter_ns, jitter_polarity);

    i_uart_rx <= 1'b1;
    #(bit_period_ns);
endtask
```

즉 TB는 UART 프레임 전체를 직접 만들고,
각 구간의 유지 시간만 `nominal +/- jitter`로 조절합니다.

### 9.11 예시로 해석하면

예를 들어 `115200 baud`에서:

```text
nominal bit period ~= 8680.556 ns
jitter = 8% -> 694.444 ns
```

그러면 실제 line에 들어가는 bit 길이는 번갈아:

```text
7986.111 ns
9375.000 ns
7986.111 ns
9375.000 ns
...
```

이렇게 됩니다.

즉 이 테스트는 "랜덤하게 조금 흔들린다"가 아니라,
일부러 짧은 bit와 긴 bit를 교대로 주는 꽤 빡센 패턴입니다.

### 9.12 숫자로 보는 `nominal +/- jitter` 예시

발표할 때는 아래 표를 같이 보여주면 훨씬 직관적입니다.

| Baud | Jitter | Nominal bit period | `nominal - jitter` | `nominal + jitter` |
|---|---:|---:|---:|---:|
| 115200 | `8%` | `8680.556 ns` | `7986.111 ns` | `9375.000 ns` |
| 9600 | `43%` | `104166.667 ns` | `59375.000 ns` | `148958.333 ns` |
| 921600 | `48%` | `1085.069 ns` | `564.236 ns` | `1605.903 ns` |

이 표가 의미하는 것:

- `nominal - jitter`는 bit를 원래보다 **짧게 유지**해서 edge를 더 빨리 내보내는 경우
- `nominal + jitter`는 bit를 원래보다 **길게 유지**해서 edge를 더 늦게 내보내는 경우

즉 TB는 실제로 이런 길이의 bit를 번갈아 넣어서 수신기를 흔든 것입니다.

### 9.13 이 구현의 의미

이 TB 구현은 아래를 검증하는 데 적합합니다.

- RX가 샘플링 중심을 얼마나 잘 유지하는가
- start detect 이후 data sample 위치가 얼마나 안정적인가
- single-point sampling 구조가 큰 bit-width disturbance를 얼마나 버티는가

반대로 아직 직접 보지 않는 것은:

- random jitter
- burst noise
- 평균 baud mismatch만 있는 경우

즉 현재 결과는 **alternating deterministic jitter에 대한 tolerance** 결과로 해석하는 것이 맞습니다.

### 9.14 발표용 설명 문장

아래 문장을 그대로 써도 괜찮습니다.

> APB 쪽 타이밍은 clocking block으로 DUT 클럭에 맞춰 안정적으로 구동했고, jitter는 UART RX 선로만 별도로 직접 구동해서 만들었다.  
> 즉 DUT 클럭을 흔든 것이 아니라, `i_uart_rx` bit가 유지되는 시간을 일부러 짧게 또는 길게 만들어 edge 시점을 앞당기거나 늦추는 방식으로 timing disturbance를 준 것이다.  
> 이 테스트는 따라서 bus timing 검증이 아니라 UART 수신기의 sampling robustness 검증이다.

## 10. 검증 시나리오 요약

| 시나리오 | 자극 | 기대 결과 |
|---|---|---|
| Reset / ID | reset 후 ID, STATUS read | 기본 레지스터 상태 정상 |
| TX Path | `0x55`, `0xA3`, `0x0D` write | serial TX가 동일 데이터 출력 |
| RX Normal | clean `0x3C` 주입 | `RXDATA = 0x3C` |
| RX Jitter | jittered `0xA6` 주입 | `RXDATA = 0xA6` |
| Frame Error | bad stop bit 주입 | frame error set/clear |
| RX Overflow | 32byte+1byte burst | overflow set, 마지막 byte drop |

## 11. Jitter Sweep 결과 요약

### 11.1 임계점 요약 표

| Baud | 최대 PASS jitter | 최초 FAIL jitter | 최대 PASS jitter(ns) |
|---|---:|---:|---:|
| 9600 | `43%` | `44%` | `44791.667` |
| 14400 | `43%` | `44%` | `29861.111` |
| 19200 | `43%` | `44%` | `22395.833` |
| 38400 | `43%` | `44%` | `11197.917` |
| 57600 | `44%` | `45%` | `7638.889` |
| 115200 | `44%` | `45%` | `3819.444` |
| 230400 | `44%` | `45%` | `1909.722` |
| 460800 | `46%` | `47%` | `998.264` |
| 921600 | `48%` | `49%` | `520.833` |

### 11.2 발표용 compact 표

| baud rate / jitter | 1% | 2% | 43% | 44% | 45% | 46% | 47% | 48% | 49% | 50% |
|---|---|---|---|---|---|---|---|---|---|---|
| 9600 | PASS | PASS | PASS | FAIL | FAIL | FAIL | FAIL | FAIL | FAIL | FAIL |
| 14400 | PASS | PASS | PASS | FAIL | FAIL | FAIL | FAIL | FAIL | FAIL | FAIL |
| 19200 | PASS | PASS | PASS | FAIL | FAIL | FAIL | FAIL | FAIL | FAIL | FAIL |
| 38400 | PASS | PASS | PASS | FAIL | FAIL | FAIL | FAIL | FAIL | FAIL | FAIL |
| 57600 | PASS | PASS | PASS | PASS | FAIL | FAIL | FAIL | FAIL | FAIL | FAIL |
| 115200 | PASS | PASS | PASS | PASS | FAIL | FAIL | FAIL | FAIL | FAIL | FAIL |
| 230400 | PASS | PASS | PASS | PASS | FAIL | FAIL | FAIL | FAIL | FAIL | FAIL |
| 460800 | PASS | PASS | PASS | PASS | PASS | PASS | FAIL | FAIL | FAIL | FAIL |
| 921600 | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | FAIL | FAIL |

엑셀/CSV 파일:

- [compact/발표용 매트릭스 CSV](../data/uart_jitter_pass_fail_compact_table.csv)
- [원본 sweep CSV](../data/uart_jitter_sweep_results.csv)

## 12. Jitter 시각화와 의미

### 12.1 PASS/FAIL Heatmap

![UART Jitter Heatmap](../visuals/figures/uart_jitter_pass_fail_heatmap.png)

이 그림이 의미하는 것:

- X축: injected jitter(%)
- Y축: baud rate
- 색: PASS/FAIL

해석:

- 각 baud에서 어느 지점까지 PASS하고 어디서 FAIL이 시작되는지 한 번에 보임
- 경계가 비교적 단조로워서 threshold 해석이 쉬움

### 12.2 Baud별 threshold 그래프

![UART Jitter Threshold by Baud](../visuals/figures/uart_jitter_threshold_by_baud.png)

이 그림이 의미하는 것:

- baud별 최대 PASS 지점과 최초 FAIL 지점 비교
- 이번 alternating jitter 모델에서는 baud가 높을수록 threshold가 약간 올라감

### 12.3 시간 영역(ns) threshold 그래프

![UART Jitter Threshold NS](../visuals/figures/uart_jitter_threshold_ns.png)

이 그림이 의미하는 것:

- 같은 `% jitter`라도 시간(ns) 기준으로 보면 저속 baud가 훨씬 큰 여유를 가짐
- 예:
  - `9600 @ 43%` -> 약 `44.79 us`
  - `921600 @ 48%` -> 약 `0.521 us`

즉 `% 기준`과 `시간 기준`은 해석이 다를 수 있습니다.

## 13. 시각화 자료를 발표에서 어떻게 설명하면 좋은가

### 13.1 baud error ppm 그래프

추천 멘트:

> 이 그래프는 baud generator 평균 정확도를 보여준다. 낮은 baud에서 ppm이 조금 더 커 보이지만, phase accumulator 양자화 특성 때문이며 절대 오차는 전 구간에서 매우 작다.

### 13.2 tick quantization 그래프

추천 멘트:

> tick은 완전히 균일하지 않고 N/N+1 클럭으로 분포한다. 즉 이 설계의 jitter는 랜덤 노이즈가 아니라 분수 분주에 따른 양자화 jitter다.

### 13.3 jitter heatmap

추천 멘트:

> 이 그림은 timing disturbance를 넣었을 때 RX가 어느 수준까지 정상 수신하는지 보여준다. 즉 평균 baud 오차가 아니라 수신 robustness를 보는 그림이다.

### 13.4 threshold 그래프

추천 멘트:

> 이번 alternating jitter 모델에서는 지원 baud 전체가 대략 43~48% 수준까지 PASS했다. 다만 이 수치는 random jitter 환경의 절대 허용 한계가 아니라 현재 자극 모델에서의 상대적인 sampling margin 결과다.

## 14. 최종 결론

발표용 결론은 아래처럼 정리하면 가장 깔끔합니다.

1. 현재 UART는 phase accumulator 기반 baud generator를 사용해서 평균 baud 정확도가 매우 좋다.
2. 낮은 baud에서 ppm 오차가 조금 더 크게 보이는 것은 작은 phase increment의 양자화 상대오차 때문이다.
3. 실제 robustness 논의의 핵심은 baud 평균 오차보다 RX sampling 구조와 jitter tolerance다.
4. 이번 alternating jitter sweep에서는 지원 baud 전체가 약 `43% ~ 48%` 구간까지 PASS했다.
5. 향후 더 현실적인 robustness 검증을 위해서는 random jitter, baud mismatch, noise pulse 실험이 추가로 필요하다.
