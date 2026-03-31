# Digital Design Project Archive

Verilog 기반 FPGA 설계, SystemVerilog 검증, RISC-V CPU 검증 결과를 함께 정리한 저장소입니다.  
각 폴더는 프로젝트 단위로 정리되어 있으며, 문서와 산출물은 폴더 내부에서 바로 확인할 수 있습니다.

## 폴더 구성

| 경로 | 설명 | 주요 내용 |
| --- | --- | --- |
| [VerilogProject](./VerilogProject) | Verilog 기반 FPGA 설계 | 시계/스톱워치, UART, 센서 제어, RTL/TB/XDC/PDF |
| [SystemVerilogProject](./SystemVerilogProject) | FIFO/UART 검증 프로젝트 | 검증 환경, 보고서, 로그, CSV, Python 시각화 |
| [RISC-V_multicycle](./RISC-V_multicycle) | RV32I multicycle CPU와 APB 주변장치 연동 프로젝트 | MMIO register map, UART peripheral 검증, full-top 반복 실행 로그, timing report |
| [RISC-V_pipeline](./RISC-V_pipeline) | RV32I 5-stage pipeline CPU 검증 프로젝트 | Spike 기반 retire compare, 케이스별 보고서, stall/redirect/forwarding 지표, Fmax |

## RISC-V_multicycle

[RISC-V_multicycle](./RISC-V_multicycle)는 RV32I multicycle CPU에 GPI, GPO, GPIO, FND, UART를 APB로 연결한 프로젝트입니다.  
문서 비중은 peripheral/MMIO 연동과 UART 검증에 맞춰져 있으며, full-top 로그 기반 동작 확인 자료까지 함께 정리했습니다.

![UART Jitter Threshold](./RISC-V_multicycle/md/visuals/figures/uart_jitter_threshold_by_baud.png)

주요 문서:
- [README](./RISC-V_multicycle/README.md)
- [START_HERE_ko.md](./RISC-V_multicycle/START_HERE_ko.md)
- [개요 보고서](./RISC-V_multicycle/md/reports/riscv_multicycle_peri_overview_ko.md)
- [UART 주변장치 보고서](./RISC-V_multicycle/md/reports/uart_peripheral_report_ko.md)
- [UART jitter sweep 보고서](./RISC-V_multicycle/md/reports/uart_jitter_sweep_report_ko.md)
- [Peripheral 반복 실행 보고서](./RISC-V_multicycle/md/reports/test_peri_repeat_execution_report_ko.md)

핵심 내용:
- RV32I multicycle CPU + APB peripheral 구조
- MMIO register map 정리
- UART class 기반 directed verification
- full-top ROM 실행 로그와 MMIO 접근 확인
- implementation timing / utilization 정리

## RISC-V_pipeline

[RISC-V_pipeline](./RISC-V_pipeline)는 RV32I 5-stage pipeline CPU를 Spike 기준 결과와 비교해 검증한 프로젝트입니다.  
`test_top`과 `bubble_sort` 두 대표 케이스를 중심으로 pipeline TB, class-based `Top_tb`, 시각화 보고서, 성능 보고서를 함께 정리했습니다.

주요 문서:
- [README](./RISC-V_pipeline/README.md)
- [START_HERE_ko.md](./RISC-V_pipeline/START_HERE_ko.md)
- [Compact 보고서](./RISC-V_pipeline/reports/markdown/overview/rv32i_exec_compact_report_ko.md)
- [시각화 보고서](./RISC-V_pipeline/reports/markdown/overview/rv32i_spike_visual_report_ko.md)
- [성능 보고서](./RISC-V_pipeline/md/performance_metrics_report.md)
- [케이스 인덱스](./RISC-V_pipeline/spike_cases/index.md)

## SystemVerilogProject

[SystemVerilogProject](./SystemVerilogProject)는 FIFO와 UART 계열 RTL을 대상으로 구성한 SystemVerilog 검증 프로젝트입니다.  
검증 환경, 보고서, 시뮬레이션 로그, CSV 결과, Python 시각화 자료를 함께 정리했습니다.

주요 문서:
- [README](./SystemVerilogProject/README.md)
- [START_HERE_ko.md](./SystemVerilogProject/START_HERE_ko.md)
- [Markdown 시각화 보고서](./SystemVerilogProject/reports/markdown/overview/systemverilog_python_visual_report_ko.md)

## VerilogProject

[VerilogProject](./VerilogProject)는 Verilog 기반 FPGA 설계 결과를 정리한 폴더입니다.  
시계/스톱워치, UART, 초음파 센서(HC-SR04), 온습도 센서(DHT11)를 하나의 시스템으로 확장한 내용을 담고 있습니다.

## 디렉터리 구조

```text
Git_SeoulEduRepo/
├─ VerilogProject/
├─ SystemVerilogProject/
│  ├─ src/
│  ├─ tb/
│  ├─ reports/
│  ├─ evidence/
│  └─ tools/
├─ RISC-V_multicycle/
│  ├─ src/
│  ├─ tb/
│  ├─ md/
│  ├─ cpu_test/
│  ├─ output/
│  ├─ README.md
│  └─ START_HERE_ko.md
├─ RISC-V_pipeline/
│  ├─ src/
│  ├─ tb/
│  ├─ reports/
│  ├─ evidence/
│  ├─ spike_cases/
│  ├─ scripts/
│  ├─ tools/
│  ├─ README.md
│  └─ START_HERE_ko.md
└─ README.md
```

## 읽는 순서

1. 저장소 전체 구성은 이 문서에서 확인
2. multicycle CPU와 peripheral 자료는 [RISC-V_multicycle](./RISC-V_multicycle)에서 확인
3. pipeline CPU 검증 자료는 [RISC-V_pipeline](./RISC-V_pipeline)에서 확인
4. FIFO/UART 검증 자료는 [SystemVerilogProject](./SystemVerilogProject)에서 확인
5. FPGA 설계 자료는 [VerilogProject](./VerilogProject)에서 확인

## 기술 스택

`Verilog` `SystemVerilog` `RISC-V` `FPGA` `UART` `APB` `MMIO` `Vivado` `xsim` `Python`
