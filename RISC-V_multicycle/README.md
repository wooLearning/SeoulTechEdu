# RISC-V Multicycle Peripheral Project

RV32I multicycle CPU에 APB 기반 주변장치를 연결한 프로젝트입니다.  
문서는 CPU 전체 설명보다 MMIO 연동, UART peripheral 분석, full-top 실행 검증 흐름을 중심으로 정리했습니다.

## 프로젝트 개요

- 구조: RV32I multicycle CPU + memory controller + APB bridge + peripheral
- 주변장치: `GPI`, `GPO`, `GPIO`, `FND`, `UART`
- 정리 기준: `src = RTL`, `tb = 검증`, `md = 문서`, `output = 실행 산출물`

## 먼저 볼 자료

- [START_HERE_ko.md](START_HERE_ko.md)
- [개요 보고서](md/reports/riscv_multicycle_peri_overview_ko.md)
- [UART 주변장치 보고서](md/reports/uart_peripheral_report_ko.md)
- [UART jitter sweep 보고서](md/reports/uart_jitter_sweep_report_ko.md)
- [Peripheral 반복 실행 보고서](md/reports/test_peri_repeat_execution_report_ko.md)
- [Register configuration](md/reports/register_config.md)
- [발표자료.pdf](발표자료.pdf)

## 소스코드와 자료 위치

| 경로 | 역할 |
| --- | --- |
| [src](src) | CPU, APB, peripheral RTL |
| [tb](tb) | top-level / UART 검증 환경 |
| [md/reports](md/reports) | 핵심 보고서 |
| [md/visuals](md/visuals) | 그림과 다이어그램 |
| [md/build_reports](md/build_reports) | timing / utilization / power report |
| [output](output) | ELF, transcript, 실행 산출물 |

## 대표 결과

| 항목 | 내용 |
| --- | --- |
| UART directed verification | `6 / 6 PASS`, TB assertion `3개`, failed assertion `0개` |
| RX jitter sweep | baud별 최대 PASS 구간 `43% ~ 48%` |
| Full-top ROM 실행 | boot banner, MMIO 접근, `ITER 0x00` 로그 확인 |
| Timing | `100 MHz` 제약 만족, routed `WNS = 0.843 ns` |
| Utilization | Slice LUT `3186`, Register `627`, Block RAM Tile `2` |

## 대표 그림

![UART Jitter Threshold](md/visuals/figures/uart_jitter_threshold_by_baud.png)

## 폴더 구조

```text
RISC-V_multicycle/
├─ src/                         # CPU, APB, peripheral RTL
├─ tb/                          # verification
├─ md/                          # 보고서, 시각 자료, build report
├─ cpu_test/                    # C firmware
├─ output/                      # 실행 산출물
├─ 발표자료.pdf
├─ README.md
└─ START_HERE_ko.md
```

## 메모

- 이 프로젝트는 CPU 설명 전체보다 peripheral/MMIO 동작을 검증 자료와 함께 보여주는 데 초점을 맞췄습니다.
- `test_peri_repeat.c`와 transcript를 같이 보면 ROM 코드와 UART 로그 흐름을 연결해서 볼 수 있습니다.
