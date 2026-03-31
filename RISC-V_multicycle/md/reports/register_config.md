# Register Configuration Guide

## 1. 문서 목적

이 문서는 현재 `RISC-V_multicycle` 프로젝트의 MMIO/APB 레지스터 구성을 전체 관점에서 정리한 문서입니다.  
UART만 따로 설명하는 문서가 아니라, CPU가 접근하는 전체 peripheral register page를 한 번에 이해할 수 있도록 구성했습니다.

기준 자료:

- [mmio.h](../reference/mmio.h)
- [Top_Memory_CNTL.sv](../../src/cpu/Top_Memory_CNTL.sv)
- [Top_APB.sv](../../src/apb/Top_APB.sv)
- [mmio_map.html](../data/mmio_map.html)

## 2. 전체 주소 구조

현재 시스템에서 CPU가 보는 주요 주소 영역은 아래와 같습니다.

| 영역 | 시작 주소 | 끝 주소 | 크기 | 설명 |
|---|---:|---:|---:|---|
| ROM | `0x0000_0000` | `0x0000_0FFF` | 4 KB | 부트 코드/프로그램 메모리 |
| RAM | `0x1000_0000` | `0x1000_0FFF` | 4 KB | 데이터 메모리 |
| MMIO | `0x2000_0000` | `0x2000_4FFF` | 20 KB | APB peripheral register window |

MMIO 영역은 4 KB 단위 page로 나뉘며, 현재 활성 peripheral은 아래 5개입니다.

| Peripheral | Base Address | 설명 |
|---|---:|---|
| GPO | `0x2000_0000` | General-purpose output |
| GPI | `0x2000_1000` | General-purpose input |
| GPIO | `0x2000_2000` | Bidirectional GPIO |
| FND | `0x2000_3000` | 4-digit seven-segment counter |
| UART | `0x2000_4000` | UART TX/RX peripheral |

## 3. Reset 값 해석 기준

이 문서에서는 reset 관련 값을 두 관점으로 구분합니다.

| 구분 | 의미 |
|---|---|
| 하드웨어 reset값 | RTL reset 직후 레지스터가 가지는 값 |
| demo firmware 초기값 | 부팅 후 `test.c`가 초기 설정으로 write하는 값 |

즉, `*_INIT` 매크로는 소프트웨어가 나중에 써주는 초기 설정값이고, 반드시 하드웨어 reset값과 같지는 않습니다.

## 4. Peripheral별 Register 구성

### 4.1 GPO Register Page

Base address: `0x2000_0000`

역할:

- 16-bit 출력 제어
- 각 bit별 output enable과 output data 제공

| Register | Address | Access | 하드웨어 reset값 | Demo firmware 초기값 | 설명 |
|---|---:|---|---:|---:|---|
| `GPO_CTL` | `0x2000_0000` | R/W | `0x0000` | `0xFFFF` | 각 bit의 출력 enable mask. `1`이면 출력 구동, `0`이면 high-Z |
| `GPO_ODATA` | `0x2000_0004` | R/W | `0x0000` | `0x0000` | enable된 bit에 대해 실제로 구동할 출력 데이터 |

소프트웨어 관점 요약:

- `GPO_CTL`을 먼저 설정해야 출력이 실제 핀에 반영됩니다.
- `GPO_ODATA`는 출력 데이터 레지스터입니다.
- demo firmware는 부팅 후 모든 GPO bit를 출력으로 열고(`0xFFFF`), 이후 상태 정보를 이 레지스터에 반영합니다.

### 4.2 GPI Register Page

Base address: `0x2000_1000`

역할:

- 외부 입력값 읽기
- 특정 bit를 UART baud 선택, source 선택, FND run 제어, GPIO pattern 입력으로 사용

| Register | Address | Access | 하드웨어 reset값 | Demo firmware 초기값 | 설명 |
|---|---:|---|---:|---:|---|
| `GPI_CTL` | `0x2000_1000` | R/W | `0x0000` | `0x07FF` | 입력 enable mask |
| `GPI_IDATA` | `0x2000_1004` | R | `0x0000` | 입력 상태 의존 | mask 적용 후 읽히는 입력 데이터 |

현재 demo 기준 bit 의미:

| Bit | 이름 | 설명 |
|---|---|---|
| `[3:0]` | `UART_APB_SEL` | UART baud code 요청값 |
| `[4]` | `UART_SOURCE_SEL` | `0`이면 switch baud 사용, `1`이면 APB baud 사용 |
| `[5]` | `FND_RUN_REQ` | FND run 요청 |
| `[9:6]` | `GPIO_PATTERN` | GPIO pattern 입력 |
| `[10]` | user bit | 현재 demo에서는 직접 소비하지 않는 추가 bit |

소프트웨어 관점 요약:

- `GPI_CTL`이 켜진 bit만 `GPI_IDATA`에 반영됩니다.
- demo firmware는 `0x07FF`로 설정하여 하위 11비트를 활성화합니다.

### 4.3 GPIO Register Page

Base address: `0x2000_2000`

역할:

- bidirectional GPIO 제어
- 방향, 출력 데이터, 입력 데이터 분리

| Register | Address | Access | 하드웨어 reset값 | Demo firmware 초기값 | 설명 |
|---|---:|---|---:|---:|---|
| `GPIO_CTL` | `0x2000_2000` | R/W | `0x0000` | `0x000F` | `1`은 output, `0`은 input |
| `GPIO_ODATA` | `0x2000_2004` | R/W | `0x0000` | `0x0005` | output mode bit에 대해 구동할 값 |
| `GPIO_IDATA` | `0x2000_2008` | R | `0x0000` | 입력 상태 의존 | 실제 입력 샘플 값 |

구현상 참고:

- top-level에서는 현재 `io_gpio[3:0]`만 실제 연결됩니다.
- 따라서 의미 있는 active bit는 주로 하위 4비트입니다.

소프트웨어 관점 요약:

- `GPIO_CTL`로 방향을 정하고
- `GPIO_ODATA`로 출력값을 씁니다.
- 입력으로 설정된 경우 상태는 `GPIO_IDATA`에서 읽습니다.

### 4.4 FND Register Page

Base address: `0x2000_3000`

역할:

- 4-digit seven-segment counter 동작/정지 제어

| Register | Address | Access | 하드웨어 reset값 | Demo firmware 초기값 | 설명 |
|---|---:|---|---:|---:|---|
| `FND_RUN` | `0x2000_3000` | R/W | `0x0` | `0x1` | bit0 기준 `0`은 stop, `1`은 run |

bit 정의:

| Bit | 이름 | 설명 |
|---|---|---|
| `[0]` | `FND_RUN_EN` | 카운터 실행 enable |

소프트웨어 관점 요약:

- FND peripheral은 단일 control register만 갖는 최소 인터페이스입니다.
- demo firmware는 기본적으로 run 상태로 켭니다.

### 4.5 UART Register Page

Base address: `0x2000_4000`

역할:

- UART 송수신
- FIFO 상태 확인
- sticky error clear
- baud source / baud selection 제어

| Register | Address | Access | 하드웨어 reset값 | Demo firmware 초기값 | 설명 |
|---|---:|---|---:|---:|---|
| `UART_ID` | `0x2000_4000` | R | `0x5541_5254` | 동일 | UART 식별값 |
| `UART_STATUS` | `0x2000_4004` | R | `0x0000_000A` | 상태 의존 | TX/RX FIFO empty/full, TX busy, overflow, frame error |
| `UART_TXDATA` | `0x2000_4008` | W | `0x00` 취급 | write-only | TX FIFO에 1 byte push |
| `UART_RXDATA` | `0x2000_400C` | R | `0x00` 취급 | RX 상태 의존 | RX FIFO에서 1 byte pop |
| `UART_CONTROL` | `0x2000_4010` | R/W | `0x0000_0000` | `0x0000_0000` | sticky error clear |
| `UART_BAUDCFG` | `0x2000_4014` | R/W | 요청 필드 기준 `0x0000_0005` | `UART_BAUDCFG_INIT` | baud source / APB baud select / active select 표시 |

#### UART_STATUS bit 구성

| Bit | 이름 | reset | 설명 |
|---|---|---:|---|
| 0 | `TX_FULL` | `0` | TX FIFO full |
| 1 | `TX_EMPTY` | `1` | TX FIFO empty |
| 2 | `RX_FULL` | `0` | RX FIFO full |
| 3 | `RX_EMPTY` | `1` | RX FIFO empty |
| 4 | `TX_BUSY` | `0` | TX frame 전송 중 |
| 5 | `RX_OVERFLOW` | `0` | RX FIFO full 상태에서 새 byte 수신 |
| 6 | `FRAME_ERROR` | `0` | stop bit check 실패 |

즉 하드웨어 reset 직후 `UART_STATUS = 0x0000_000A`로 해석됩니다.

#### UART_CONTROL bit 구성

| Bit | 이름 | 설명 |
|---|---|---|
| 0 | `CLR_OVERFLOW` | `1`을 쓰면 overflow sticky clear |
| 1 | `CLR_FRAME` | `1`을 쓰면 frame error sticky clear |

#### UART_BAUDCFG bit 구성

| Bit | 이름 | 설명 |
|---|---|---|
| `[3:0]` | `APB_SEL` | APB가 요청한 baud code |
| `[4]` | `SOURCE_SEL` | `0`이면 외부 switch 값 사용, `1`이면 APB 값 사용 |
| `[11:8]` | `ACTIVE_SEL` | 현재 실제 UART core에 적용된 baud code |

baud code 매핑:

| Code | Baud |
|---:|---:|
| 0 | 9600 |
| 1 | 14400 |
| 2 | 19200 |
| 3 | 38400 |
| 4 | 57600 |
| 5 | 115200 |
| 6 | 230400 |
| 7 | 460800 |
| 8 | 921600 |

소프트웨어 관점 요약:

- `UART_TXDATA`는 TX FIFO가 full이 아닐 때만 써야 합니다.
- `UART_RXDATA`는 RX FIFO가 empty가 아닐 때 읽어야 합니다.
- sticky error는 `UART_CONTROL`로 clear합니다.
- `UART_BAUDCFG`에서 request 값과 active 값이 다를 수 있습니다.
  - 이유: `SOURCE_SEL = 0`이면 최종 baud는 switch 입력이 결정하기 때문입니다.

## 5. Demo Firmware 초기 설정값 요약

현재 `mmio.h` 기준 demo firmware 초기 설정값은 아래와 같습니다.

| 항목 | 값 |
|---|---:|
| `GPO_CTL_INIT` | `0xFFFF` |
| `GPO_ODATA_INIT` | `0x0000` |
| `GPI_CTL_INIT` | `0x07FF` |
| `GPIO_CTL_INIT` | `0x000F` |
| `GPIO_ODATA_INIT` | `0x0005` |
| `FND_RUN_INIT` | `0x0001` |
| `UART_CONTROL_INIT` | `0x0000_0000` |
| `UART_BAUDCFG_INIT` | switch source + APB code `115200` |

주의:

- `UART_BAUDCFG_INIT`는 "APB register 내부 기본 요청값"과 "실제 active baud"를 구분해서 봐야 합니다.
- active baud는 `SOURCE_SEL`과 외부 switch 상태에 따라 달라질 수 있습니다.

## 6. 소프트웨어 사용 순서 예시

### 출력 peripheral 사용

1. `GPO_CTL` 또는 `GPIO_CTL`로 방향/enable 설정
2. `GPO_ODATA` 또는 `GPIO_ODATA`에 데이터 write

### 입력 peripheral 사용

1. `GPI_CTL`로 필요한 bit enable
2. `GPI_IDATA` 또는 `GPIO_IDATA` read

### UART 사용

1. 필요시 `UART_BAUDCFG` 설정
2. `UART_STATUS` 확인
3. TX 시 `UART_TXDATA` write
4. RX 시 `UART_RXDATA` read
5. 오류 발생 시 `UART_CONTROL` write로 sticky flag clear

## 7. 발표용 한 줄 정리

- 이 시스템의 MMIO는 `GPO / GPI / GPIO / FND / UART`의 5개 page로 구성됩니다.
- 각 peripheral은 4 KB page를 차지하고, 소프트웨어는 고정 base address + offset 방식으로 접근합니다.
- UART는 단순 TX/RX register 외에도 status, error clear, baud source selection까지 포함하는 가장 풍부한 register set을 가집니다.
