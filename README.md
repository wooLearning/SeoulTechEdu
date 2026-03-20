# Verilog & SystemVerilog Project Archive
> FPGA RTL design, CPU implementation, and verification practice repository

이 저장소는 Verilog / SystemVerilog 기반 디지털 설계 결과물을 폴더별로 정리한 아카이브입니다.  
GitHub에서 바로 구조를 이해할 수 있도록, 상위 폴더를 중심으로 프로젝트 성격과 포함 자료를 한눈에 볼 수 있게 정리했습니다.

## 📂 Repository Overview

| 폴더 | 설명 | 주요 내용 |
| --- | --- | --- |
| [VerilogProject](./VerilogProject) | Verilog 기반 FPGA 통합 설계 모음 | Stopwatch/Clock, UART, Sensor 연동, RTL/TB/XDC/PDF 보고서 |
| [SystemVerilogProject](./SystemVerilogProject) | SystemVerilog 기반 CPU/검증 프로젝트 모음 | RV32I Single-Cycle CPU, verification portfolio, 보고서 |

## 🧩 Folder Guide

### 1. [VerilogProject](./VerilogProject)

기본 Verilog 문법과 FPGA 주변장치 제어를 중심으로 구성된 프로젝트 폴더입니다.  
시계/스톱워치, UART 통신, 초음파 센서(HC-SR04), 온습도 센서(DHT11) 등을 하나의 시스템으로 확장해가는 흐름을 담고 있습니다.

주요 구성:
- [SourceCode](./VerilogProject/SourceCode): 실제 RTL, testbench, 제약 파일
- `FPGA StopWatch & Clock Project.pdf`: 시계/스톱워치 중심 설계 문서
- `FPGA UART Project.pdf`: UART 통신 설계 문서
- `FPGA Seneor 통합 Project.pdf`: 센서 통합 시스템 설계 문서

핵심 포인트:
- `Top.v` 기반 통합형 FPGA top-level 설계
- UART RX/TX + ASCII decoder/sender + FIFO 연동
- `watch_top`, `clock_core`, `stopwatch` 기반 시간 표시 로직
- `sr04_controller`, `dht11_controller` 기반 센서 제어
- 개별 모듈에 대한 testbench 포함

### 2. [SystemVerilogProject](./SystemVerilogProject)

SystemVerilog를 활용한 CPU 설계와 verification 포트폴리오를 함께 정리한 폴더입니다.  
설계(RTL)와 검증(Testbench/Report)을 분리해서 보여줄 수 있도록 두 개의 하위 프로젝트로 구성되어 있습니다.

주요 구성:
- [RV32I_SingleSycle](./SystemVerilogProject/RV32I_SingleSycle): RV32I single-cycle CPU 구현
- [result_portfolio](./SystemVerilogProject/result_portfolio): FIFO/UART 중심 verification portfolio

핵심 포인트:
- `Top.sv`, `Datapath.sv`, `ControlUnit.sv` 기반 RV32I CPU 설계
- 단일 사이클 구조의 PC, ALU, Register File, ROM/RAM 구성
- FIFO / UART 기반 self-checking verification environment
- CSV 로그, HTML/Markdown 보고서, Vivado xsim 실행 결과 정리

## 🌲 Directory Layout

```text
Git_SeoulEduRepo/
├─ VerilogProject/
│  ├─ SourceCode/
│  │  ├─ src/        # Verilog RTL modules
│  │  ├─ tb/         # module-level testbenches
│  │  └─ constrs/    # FPGA constraint file
│  └─ *.pdf          # project documents
├─ SystemVerilogProject/
│  ├─ RV32I_SingleSycle/
│  │  ├─ src/        # RV32I CPU RTL
│  │  └─ tb/         # CPU testbench and sample programs
│  └─ result_portfolio/
│     ├─ src/        # showcase RTL
│     ├─ tb/         # verification environments
│     ├─ reports/    # markdown/html reports
│     ├─ evidence/   # logs and CSV artifacts
│     └─ tools/      # analysis scripts
└─ README.md
```

## 📌 Recommended Reading Order

1. 저장소 전체 구조는 이 문서에서 먼저 확인
2. Verilog 설계는 [VerilogProject](./VerilogProject)부터 확인
3. CPU 구현은 [RV32I_SingleSycle](./SystemVerilogProject/RV32I_SingleSycle) 확인
4. 검증 역량은 [result_portfolio](./SystemVerilogProject/result_portfolio)와 해당 [README](./SystemVerilogProject/result_portfolio/README.md) 확인

## 🛠️ Tech Stack

`Verilog` `SystemVerilog` `FPGA` `UART` `FIFO` `RISC-V` `Vivado` `xsim` `Python`
# SeoulTechEdu
# SeoulTechEdu
