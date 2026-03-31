# `test_peri_repeat.c` 실행/로그 검증 보고서

## 1. 목적

이 보고서는 CPU ROM용 반복 테스트 코드 [test_peri_repeat.c](../../cpu_test/test_peri_repeat.c)가 실제 `program.mem`으로 연결되었는지, 그리고 full-top simulation에서 `GPI -> GPO -> GPIO -> FND -> UART_BAUDCFG -> UART log` 순서의 동작이 확인되었는지를 정리한 문서입니다.

관련 자료:

- C 코드: [test_peri_repeat.c](../../cpu_test/test_peri_repeat.c)
- 흐름 다이어그램: [test_peri_repeat_flow_ko.md](./test_peri_repeat_flow_ko.md)
- 로그 확인 TB: [tb_Top_module_peri_repeat_log.sv](../../tb/tb_Top_module_peri_repeat_log.sv)
- 시뮬 transcript: [sim_transcript.txt](../../output/tmp_verify/top_peri_repeat/sim_transcript.txt)

## 2. `program.mem` 생성 및 반영

실제 프로젝트용 `program.mem`은 `test_peri_repeat.c`를 RV32I용으로 컴파일한 뒤 생성했고, 아래 두 위치에 동일하게 반영했습니다.

- 프로젝트 루트 ROM: [program.mem](../../program.mem)
- CPU ROM 참조 위치: [program.mem](../../src/cpu/program.mem)

생성 결과:

- ELF: [test_peri_repeat.elf](../../output/peri_repeat_release/test_peri_repeat.elf)
- 크기: `text=3288`, `data=0`, `bss=0`
- 생성된 `program.mem` word 수: `822`
- 동기화 SHA-256:
  - `6b9fb88cf7e6f69cbd69981524bd7afac6bb2a082235a5ee78b9b285e836a980`

참고:

- 실제 프로젝트 `program.mem`은 기본 빌드 결과입니다.
- 시뮬레이션 로그 확인은 runtime을 줄이기 위해 가속 빌드(`STEP_DELAY_LOOPS` 축소, UART 고속 고정)를 사용했습니다.
- 가속 빌드 결과의 transcript는 [sim_transcript.txt](../../output/tmp_verify/top_peri_repeat/sim_transcript.txt)로 함께 보관했습니다.

## 3. 다이어그램

다이어그램은 발표용으로 세로로 길게 늘어지지 않도록 가로 배치로 다시 정리했습니다.

- 프로그램 흐름: [test_peri_repeat_flow_ko.md](./test_peri_repeat_flow_ko.md)
- APB 접근 순서: [test_peri_repeat_flow_ko.md](./test_peri_repeat_flow_ko.md)

핵심 의미:

- 초기화 후 UART 배너와 register dump를 출력
- 루프 안에서 `GPI_IDATA` read
- `GPO_ODATA`, `GPIO_CTL`, `GPIO_ODATA`, `FND_RUN`, `UART_BAUDCFG` write/read
- 마지막으로 `ITER ...` 로그를 UART로 출력

## 4. 시뮬레이션 방법

검증은 [tb_Top_module_peri_repeat_log.sv](../../tb/tb_Top_module_peri_repeat_log.sv)로 수행했습니다.

이 TB는 다음 정보를 자동으로 수집합니다.

- UART 문자열 복원
- 완료된 APB/MMIO transaction 로그
- peripheral별 첫 접근 PC
- 첫 `ITER` 로그가 확인되면 자동 종료

즉, 파형만 보지 않아도 transcript만으로 ROM 코드의 진행 상황을 확인할 수 있습니다.

## 5. 주요 로그

아래는 실제 transcript에서 확인한 대표 로그입니다.

```text
[195000][TOP_TB] Reset released
[1695000][PERI_MMIO] pc=0000053c WR addr=20000000 wdata=0000ffff rdata=00000000 err=0
[2035000][PERI_MMIO] pc=00000550 WR addr=20001000 wdata=000007ff rdata=00000000 err=0
[2235000][PERI_MMIO] pc=0000055c WR addr=20002000 wdata=0000000f rdata=00000000 err=0
[2575000][PERI_MMIO] pc=00000570 WR addr=20003000 wdata=00000001 rdata=00000000 err=0
[3175000][PERI_MMIO] pc=00000594 WR addr=20004014 wdata=00000015 rdata=00000505 err=0
[1740455000][TOP_UART] CPU ROM peripheral repeat test boot
[3476505000][TOP_UART] UART_ID=0x55415254
[5212595000][TOP_UART] GPI_CTL=0x000007FF
[6948775000][TOP_UART] GPO_CTL=0x0000FFFF
[8771735000][TOP_UART] GPIO_CTL=0x0000000F
[10507735000][TOP_UART] FND_RUN=0x00000001
[14674355000][TOP_UART] BAUDCFG src=A req=0x05 act=0x05 rate=115200bps
[14678455000][PERI_MMIO] pc=00000700 RD addr=20001004 wdata=00000000 rdata=00000275 err=0
[14682595000][PERI_MMIO] pc=0000072c WR addr=20000004 wdata=00008275 rdata=00000000 err=0
[14686625000][PERI_MMIO] pc=00000750 WR addr=20002000 wdata=0000000f rdata=0000000f err=0
[14690695000][PERI_MMIO] pc=00000774 RD addr=20002008 wdata=00000000 rdata=0000zzz0 err=0
[14698955000][PERI_MMIO] pc=000007c8 WR addr=20004014 wdata=00000018 rdata=00000515 err=0
[14699045000][PERI_MMIO] pc=000007cc RD addr=20004014 wdata=00000000 rdata=00000818 err=0
[15444855000][TOP_UART] ITER 0x00 GPI=0x00000275 GPO=0x00008275 GPIO_IDATA=0x0000 FND=0
[15444855000][TOP_TB] Peripheral repeat loop observed successfully
```

위 로그만으로도 다음을 확인할 수 있습니다.

- ROM 부팅 후 초기화 코드가 실행됨
- UART 초기 배너와 register dump가 정상 출력됨
- 첫 루프에서 `GPI_IDATA`, `GPO_ODATA`, `GPIO_CTL`, `GPIO_ODATA`, `GPIO_IDATA`, `FND_RUN`, `UART_BAUDCFG` 접근이 실제로 발생함
- 최종적으로 `ITER 0x00 ...` 로그까지 도달함

## 6. 첫 접근 PC 요약

TB가 자동으로 수집한 첫 peripheral 접근 PC는 아래와 같습니다.

```text
first_pc GPI_IDATA       = 00000700
first_pc GPO_ODATA       = 00000544
first_pc GPIO_CTL        = 0000055c
first_pc GPIO_ODATA      = 00000564
first_pc GPIO_IDATA      = 00000774
first_pc FND_RUN         = 00000570
first_pc UART_BAUDCFG_WR = 00000594
first_pc UART_BAUDCFG_RD = 00000604
first_pc UART_TXDATA     = 0000003c
```

이 값들은 "매 cycle마다 PC"를 보는 대신, "실제로 어떤 peripheral register를 처음 건드린 instruction PC가 어디인가"를 바로 보여주기 때문에 디버깅 효율이 높습니다.

## 7. 결론

이번 작업으로 아래 세 가지가 모두 정리되었습니다.

- `test_peri_repeat.c` 기반 ROM 코드 작성 완료
- C 코드 흐름/접근 순서 다이어그램 정리 완료
- `program.mem` 생성, full-top log simulation, transcript 기반 동작 확인 완료

즉 현재 상태에서는 ROM 코드 동작을:

- C 코드
- 다이어그램
- UART/APB 로그

이 세 축으로 바로 설명할 수 있고, 꼭 파형만 열지 않아도 동작 검증이 가능합니다.
