# UART 주변장치 분석 보고서

## 1. 개요

이 문서는 현재 저장소의 UART 주변장치 RTL 구조를 정리하고, TX/RX 동작 흐름, jitter 해석, class 기반 테스트벤치 검증 결과를 한글로 정리한 보고서입니다.

연계 자료:

- [영문 원본 보고서](./uart_peripheral_report.md)
- [시각화 보고서](./uart_verification_visual_report.md)
- [실행 로그 요약](./uart_verification_run_log.md)
- [노트북](../notebooks/uart_verification_notebook.ipynb)
- [CSV 컬럼 설명](./uart_baud_error_table_guide_ko.md)
- [Baud 오차 CSV](../data/uart_baud_error_table.csv)
- [Jitter sweep 보고서](./uart_jitter_sweep_report_ko.md)
- [Jitter sweep 결과 CSV](../data/uart_jitter_sweep_results.csv)
- [Jitter sweep 요약 CSV](../data/uart_jitter_threshold_summary.csv)
- [Jitter sweep CSV 가이드](./uart_jitter_sweep_csv_guide_ko.md)

주요 RTL 파일:

- [uart_apb_wrapper.v](../../src/uart_peri/uart_apb_wrapper.v)
- [uart_core.v](../../src/uart_peri/uart_core.v)
- [Top_UART.v](../../src/uart_peri/uart_source/Top_UART.v)
- [tx.v](../../src/uart_peri/uart_source/tx.v)
- [rx.v](../../src/uart_peri/uart_source/rx.v)
- [baud_tick_16oversample.v](../../src/uart_peri/uart_source/baud_tick_16oversample.v)

주요 검증 파일:

- [tb_uart_apb_wrapper.sv](../../tb/uart_peri_tb/tb_uart_apb_wrapper.sv)
- [test_uart_directed.svh](../../tb/uart_peri_tb/tests/test_uart_directed.svh)
- [interface.sv](../../tb/uart_peri_tb/interface.sv)

## 2. 핵심 요약

- 현재 UART는 `APB wrapper + UART core + TX/RX FIFO + TX/RX 블록 + 16x baud tick generator` 구조입니다.
- APB 프로그래밍 모델이 단순해서 소프트웨어에서 polling 방식으로 다루기 쉽습니다.
- TX와 RX의 정상 경로, frame error, overflow, jitter 포함 RX 시나리오까지 directed TB로 검증했습니다.
- baud generator는 `phase accumulator` 기반이라 평균 baud 오차는 매우 작습니다.
- 팀에서 말한 jitter 이슈의 핵심은 평균 baud 오차보다 RX sampling robustness입니다.
- RX는 16x oversampling timing을 사용하지만 실제 bit 판정은 single-point sampling이라 majority voting 구조보다 외란 여유가 적습니다.

## 3. 시스템 내 위치

UART는 APB 서브시스템 내부에 인스턴스되어 있고, base address는 `0x2000_4000`입니다.

관련 파일:

- [Top_APB.sv](../../src/apb/Top_APB.sv)
- [Top_module.sv](../../src/Top_module.sv)
- [mmio.h](../reference/mmio.h)

연결 흐름:

```text
CPU / MMIO
  -> APB master
    -> uart_apb_wrapper
      -> uart_core
        -> TX FIFO -> TX -> o_uart_tx
        -> i_uart_rx -> RX -> RX FIFO
```

## 4. 레지스터 맵

UART base address:

- `UART_BASE = 0x2000_4000`

| Offset | 이름 | 접근 | 설명 |
|---|---|---|---|
| `0x00` | `UART_ID` | R | UART 식별값 |
| `0x04` | `UART_STATUS` | R | TX/RX 상태 및 sticky error flag |
| `0x08` | `UART_TXDATA` | W | TX FIFO에 1바이트 push |
| `0x0C` | `UART_RXDATA` | R | RX FIFO에서 1바이트 pop |
| `0x10` | `UART_CONTROL` | R/W | sticky error clear |

STATUS bit:

| Bit | 이름 | 의미 |
|---|---|---|
| 0 | `TX_FULL` | TX FIFO 가득 참 |
| 1 | `TX_EMPTY` | TX FIFO 비어 있음 |
| 2 | `RX_FULL` | RX FIFO 가득 참 |
| 3 | `RX_EMPTY` | RX FIFO 비어 있음 |
| 4 | `TX_BUSY` | 현재 TX frame 송신 중 |
| 5 | `RX_OVERFLOW` | RX FIFO가 가득 찬 상태에서 새 byte 수신 |
| 6 | `FRAME_ERROR` | stop bit 검증 실패 |

CONTROL bit:

| Bit | 이름 | 의미 |
|---|---|---|
| 0 | `CLR_OVERFLOW` | RX overflow sticky clear |
| 1 | `CLR_FRAME` | frame error sticky clear |

## 5. 블록 구조

| 블록 | 역할 | 비고 |
|---|---|---|
| `uart_apb_wrapper` | APB 레지스터 인터페이스 | 주소 decode, APB 응답, TX/RX register access |
| `uart_core` | 내부 제어 블록 | FIFO와 UART datapath 연결, sticky flag 관리 |
| `Top_uart` | TX/RX wrapper | 하나의 baud tick을 공유 |
| `tx` | UART serializer | start, 8 data bit, stop 전송 |
| `rx` | UART receiver | sync, start detect, bit sample, stop check |
| `baud_tick_16` | 16x baud tick generator | phase accumulator 기반 |
| `Top_FIFO` | 공용 FIFO wrapper | TX/RX 모두 사용 |

## 6. TX 동작

### 6.1 전체 흐름

| 단계 | 동작 |
|---|---|
| 1 | 소프트웨어가 `UART_TXDATA`에 1바이트 write |
| 2 | APB wrapper가 TX FIFO가 full이 아니면 `tx_push` 생성 |
| 3 | TX FIFO에 바이트 저장 |
| 4 | `uart_core`가 FIFO non-empty이면서 TX idle일 때 `w_tx_start` 생성 |
| 5 | TX FSM이 `o_uart_tx`로 직렬화 |
| 6 | stop bit 종료 후 `TX_BUSY` deassert |

### 6.2 TX 프레임 형식

| 필드 | 길이 | 값 |
|---|---|---|
| Idle | 무한 | `1` |
| Start | 1 bit | `0` |
| Data | 8 bit | LSB first |
| Stop | 1 bit | `1` |

### 6.3 TX 특징

- TX FSM은 16개의 baud tick을 1비트 길이로 사용합니다.
- 소프트웨어 write는 바로 선로로 나가는 것이 아니라 먼저 FIFO에 적재됩니다.
- 실제 송신 시작 시점은 TX가 idle일 때입니다.
- TX FIFO가 full이면 `TXDATA` write 시 `PSLVERR`가 발생합니다.

## 7. RX 동작

### 7.1 전체 흐름

| 단계 | 동작 |
|---|---|
| 1 | 외부 serial 입력이 `i_uart_rx`로 들어옴 |
| 2 | 2FF synchronizer를 통과 |
| 3 | `baud_tick` 시점에 low를 보면 start 후보로 진입 |
| 4 | 8tick 동안 low가 유지되면 정상 start로 인정 |
| 5 | 16tick마다 1bit씩 샘플링 |
| 6 | stop bit 검사 |
| 7 | stop bit가 정상이면 `o_rx_done`과 함께 RX FIFO push |
| 8 | 소프트웨어가 `RXDATA`를 읽으면 FIFO pop |

### 7.2 RX 설계 특징

| 항목 | 현재 구현 |
|---|---|
| Synchronization | 2FF synchronizer 있음 |
| Start detect | `baud_tick` 기준 |
| Start validation | 반 비트 시점 8tick 검사 |
| Data sample | single-point sampling |
| Stop validation | single-bit high check |
| Majority voting | 없음 |

### 7.3 RX 에러 동작

| 조건 | 기대 동작 |
|---|---|
| stop bit가 low | `FRAME_ERROR` sticky flag set |
| RX FIFO full 상태에서 byte 수신 완료 | `RX_OVERFLOW` sticky flag set, 새 byte drop |

## 8. FIFO 동작

| FIFO | Depth | Data Width |
|---|---:|---:|
| TX FIFO | 16 | 8 |
| RX FIFO | 32 | 8 |

overflow 시 정책:

- 새로 들어온 마지막 byte는 FIFO에 저장되지 않습니다.
- 기존 FIFO 데이터는 유지됩니다.
- sticky overflow flag만 set됩니다.

즉 overflow가 나면 "가장 마지막에 들어온 byte가 버려지는 구조"입니다.

## 9. Baud generator

### 9.1 구현 방식

이 UART는 단순 정수분주가 아니라 `phase accumulator`를 사용합니다.

- `target_tick_hz = baud_rate * 16`
- `phase_inc`를 계산해서 accumulator에 매 클럭 더함
- carry가 발생하면 `baud_tick = 1`

### 9.2 의미

이 방식은 다음 특징을 가집니다.

- 평균 baud 오차가 매우 작음
- tick 간격이 완전히 일정하지 않고 `N` 또는 `N+1` 클럭으로 양자화됨

즉 여기서의 jitter는 랜덤 노이즈라기보다 deterministic quantization jitter입니다.

## 10. Baud 오차와 tick 양자화

`SYS_CLK = 100 MHz` 기준:

| Baud | 목표 Tick 주파수 | 평균 오차 | Tick 간격 | 1bit 길이 |
|---|---:|---:|---|---|
| 9600 | 153600 Hz | `+0.000761449%` | `651/652 clk` | `10416/10417 clk` |
| 14400 | 230400 Hz | `+0.000761449%` | `434/435 clk` | `6944/6945 clk` |
| 19200 | 307200 Hz | `+0.000761449%` | `325/326 clk` | `5208/5209 clk` |
| 38400 | 614400 Hz | `-0.000208678%` | `162/163 clk` | `2604/2605 clk` |
| 57600 | 921600 Hz | `+0.000114698%` | `108/109 clk` | `1736/1737 clk` |
| 115200 | 1843200 Hz | `+0.000114698%` | `54/55 clk` | `868/869 clk` |
| 230400 | 3686400 Hz | `-0.000046990%` | `27/28 clk` | `434/435 clk` |
| 460800 | 7372800 Hz | `+0.000033854%` | `13/14 clk` | `217/218 clk` |
| 921600 | 14745600 Hz | `-0.000006568%` | `6/7 clk` | `108/109 clk` |

## 11. Jitter 해석

### 11.1 중요한 구분

실제로 "jitter"라고 부를 수 있는 내용은 두 가지입니다.

| 항목 | 의미 | 현재 설계에서의 중요도 |
|---|---|---|
| 평균 baud 오차 | 장기 평균 속도 mismatch | 낮음 |
| 샘플링 강건성 | bit 폭 흔들림과 위상 오차를 얼마나 버티는가 | 매우 중요 |

### 11.2 현재 설계의 장점

- 평균 baud 오차가 매우 작습니다.
- 16x oversampling timing을 사용합니다.
- 2FF synchronizer가 있어 비동기 입력 안정성에 도움이 됩니다.

### 11.3 현재 설계의 약점

| 항목 | 이유 |
|---|---|
| Start detect가 baud tick 경계에서만 동작 | start edge 인식이 최대 1 oversample tick 늦어질 수 있음 |
| single-point data sampling | majority voting보다 noise/jitter 내성이 약함 |
| majority vote 없음 | bit center 주변 외란에 덜 강함 |
| `i_baud_sel` 즉시 반영 | frame 중간 baud 변경 시 timing 깨질 수 있음 |

### 11.4 실무적 해석

팀 설명용으로는 아래 문장이 가장 중요합니다.

> 이 UART에서 중요한 jitter 이슈는 baud generator 평균 오차가 아니라, RX가 16x timing을 쓰면서도 실제 bit 판정은 single-point sampling이라는 점이다.

## 12. Class 기반 테스트벤치

참고하신 `Top_tb` 스타일을 따라 `interface/package/components/env/tests/top` 구조로 정리했습니다.

| 파일 | 역할 |
|---|---|
| `tb_uart_apb_wrapper.sv` | TB top |
| `tb_pkg.sv` | include/package hub |
| `interface.sv` | APB/UART interface 및 serial helper |
| `driver.svh` | APB transaction 및 UART stimulus |
| `monitor.svh` | serial TX capture |
| `scoreboard.svh` | TX expected/actual 비교 |
| `environment.svh` | driver/monitor/scoreboard 묶음 |
| `base_test.svh` | 공통 base test |
| `test_uart_directed.svh` | directed scenario 구현 |

또한 APB driver와 monitor timing은 clocking block 기반으로 정리했습니다.

## 13. 검증 시나리오

| 시나리오 | 자극 | 기대 결과 | 잡는 버그 |
|---|---|---|---|
| Reset / ID | reset 후 `UART_ID`, `UART_STATUS` read | ID 일치, TX/RX empty 상태 정상 | reset/init, register map 문제 |
| TX Path | `TXDATA`에 `0x55`, `0xA3`, `0x0D` write | 동일한 값이 `o_uart_tx`에서 관측 | FIFO/TX FSM/bit order 문제 |
| RX Normal | clean serial `0x3C` 주입 | `RXDATA=0x3C`, pop 후 empty | RX sample/FIFO 문제 |
| RX Jitter | bit period를 alternation jitter로 흔든 `0xA6` 주입 | `RXDATA=0xA6` 정상 복원 | timing margin 문제 |
| Frame Error | bad stop bit가 있는 `0xF0` 주입 | `FRAME_ERROR` set/clear 정상 | stop check/sticky clear 문제 |
| RX Overflow | 32byte 채운 뒤 1byte 추가 주입 | overflow set, 처음 32byte 유지, 마지막 byte drop | FIFO full 경계조건 문제 |

## 14. 현재 TB assertion

현재 TB top에는 simulator에서 안정적으로 유지되는 assertion만 남겨두었습니다.

| Assertion | 목적 |
|---|---|
| `p_pready_always_high` | UART slave가 zero-wait-state인지 확인 |
| `p_tx_idle_during_reset` | reset 동안 TX line이 idle high 유지되는지 확인 |
| `p_apb_response_known` | active read access 동안 `prdata/pslverr`가 X/Z가 아닌지 확인 |

추가 추천 assertion:

| 추천 assertion | 이유 |
|---|---|
| `frame_error` sticky until clear | software-visible sticky 성질을 formal하게 보장 |
| `rx_overflow` sticky until clear | overflow 유지 성질 점검 |
| `tx_busy`와 FSM 상태 일치 | status/FSM 정합성 확인 |
| RX done only after valid stop | 수신 완료 조건 강화 |

이런 assertion은 TB top보다 `bind` 방식이나 RTL 내부 assertion으로 넣는 것이 더 안정적입니다.

## 15. 검증 결과

Vivado 기준:

| 단계 | 결과 |
|---|---|
| `xvlog` | PASS |
| `xelab` | PASS |
| `xsim -runall` | PASS |

최종 결과:

- `tb_uart_apb_wrapper PASSED`

### 15.1 Jitter Sweep 확장 결과

추가로 baud별 jitter tolerance sweep도 수행했습니다.

핵심 결과:

- `9600 ~ 38400` : `43%`까지 PASS, `44%`에서 최초 FAIL
- `57600 ~ 230400` : `44%`까지 PASS, `45%`에서 최초 FAIL
- `460800` : `46%`까지 PASS, `47%`에서 최초 FAIL
- `921600` : `48%`까지 PASS, `49%`에서 최초 FAIL

이 결과는 [uart_jitter_sweep_report_ko.md](./uart_jitter_sweep_report_ko.md)에 별도로 정리했습니다.

## 16. 장점과 개선 포인트

### 16.1 장점

| 장점 | 설명 |
|---|---|
| 단순한 MMIO 모델 | 소프트웨어에서 polling 방식으로 사용하기 쉬움 |
| TX/RX FIFO | software timing pressure 완화 |
| 낮은 평균 baud 오차 | phase accumulator 기반으로 평균 정확도 좋음 |
| 명확한 sticky error model | overflow/frame error 관측과 clear가 쉬움 |
| line-level 검증 완료 | register만이 아니라 실제 serial behavior 확인 |

### 16.2 개선 포인트

| 항목 | 설명 |
|---|---|
| RX majority vote 부재 | noise/jitter tolerance 향상 여지 |
| start detect granularity | tick 경계 기반이라 phase uncertainty 존재 |
| baud select 즉시 반영 | frame 중간 변경 시 위험 |
| interrupt 미지원 | software polling 부담 존재 |
| error counter 없음 | sticky flag만 노출 |

## 17. 권장 후속 작업

| 항목 | 목적 |
|---|---|
| Baud mismatch sweep | 실제 RX tolerance window 계측 |
| Random jitter test | alternating jitter 외 추가 stress |
| Long burst stress | 장시간 RX/TX backpressure 검증 |
| Mid-frame baud change test | illegal dynamic update 민감도 확인 |
| Board-level loopback | 실제 케이블/USB-UART 환경 검증 |

## 18. 한 줄 결론

현재 UART 주변장치는 기능적으로 안정적이고 directed verification도 통과했으며, 향후 기술 논의의 핵심은 평균 baud 정확도보다 RX sampling robustness를 어떻게 강화할지에 있습니다.
