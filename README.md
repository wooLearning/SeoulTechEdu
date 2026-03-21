# Verilog & SystemVerilog Project Archive

이 저장소는 Verilog 기반 FPGA 설계와 SystemVerilog 기반 검증 결과를 함께 정리한 아카이브입니다.  
상위 폴더 기준으로 각 프로젝트의 성격과 포함 자료를 확인할 수 있습니다.

## 폴더 구성

| 경로 | 설명 | 포함 내용 |
| --- | --- | --- |
| [VerilogProject](./VerilogProject) | Verilog 기반 FPGA 통합 설계 | 시계/스톱워치, UART, 센서 제어, RTL/TB/XDC/PDF |
| [SystemVerilogProject](./SystemVerilogProject) | SystemVerilog 검증 프로젝트 | FIFO/UART 검증 환경, 보고서, 로그, CSV, Python 시각화 |

## SystemVerilogProject

[SystemVerilogProject](./SystemVerilogProject)는 FIFO와 UART 계열 RTL을 대상으로 구성한 SystemVerilog 검증 프로젝트입니다.  
검증 환경, 보고서, 시뮬레이션 로그, CSV 결과, Python 시각화 자료를 한 폴더에 정리했습니다.

주요 문서:
- [README](./SystemVerilogProject/README.md)
- [START_HERE_ko.md](./SystemVerilogProject/START_HERE_ko.md)
- [Markdown 시각화 보고서](./SystemVerilogProject/reports/markdown/overview/systemverilog_python_visual_report_ko.md)
- [검증 개요](./SystemVerilogProject/reports/markdown/overview/verification_overview.md)
- [전체 상세 보고서](./SystemVerilogProject/reports/markdown/overview/portfolio_report_ko.md)

포함 항목:
- `src/`: 검증 대상 RTL
- `tb/`: interface, generator, driver, monitor, scoreboard, environment
- `reports/`: Markdown / HTML / PDF 보고서
- `evidence/`: Vivado xsim 로그와 CSV 결과
- `tools/`: Python 분석 스크립트

## VerilogProject

[VerilogProject](./VerilogProject)는 Verilog 기반 FPGA 설계 결과를 모아 둔 폴더입니다.  
시계/스톱워치, UART, 초음파 센서(HC-SR04), 온습도 센서(DHT11)를 하나의 시스템으로 확장한 내용을 담고 있습니다.

주요 구성:
- [SourceCode](./VerilogProject/SourceCode): RTL, testbench, constraint 파일
- `FPGA StopWatch & Clock Project.pdf`
- `FPGA UART Project.pdf`
- `FPGA Seneor 통합 Project.pdf`

## 디렉터리 구조

```text
Git_SeoulEduRepo/
├─ VerilogProject/
│  ├─ SourceCode/
│  │  ├─ src/
│  │  ├─ tb/
│  │  └─ constrs/
│  └─ *.pdf
├─ SystemVerilogProject/
│  ├─ src/
│  ├─ tb/
│  ├─ reports/
│  │  ├─ markdown/
│  │  ├─ html/
│  │  └─ pdf/
│  ├─ evidence/
│  ├─ tools/
│  ├─ README.md
│  └─ START_HERE_ko.md
└─ README.md
```

## 읽는 순서

1. 저장소 전체 구성은 이 문서에서 확인
2. SystemVerilog 검증 자료는 [SystemVerilogProject](./SystemVerilogProject)부터 확인
3. FPGA 설계 자료는 [VerilogProject](./VerilogProject)에서 확인

## 기술 스택

`Verilog` `SystemVerilog` `FPGA` `UART` `FIFO` `Vivado` `xsim` `Python`
