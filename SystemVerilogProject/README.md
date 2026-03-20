# SystemVerilogProject
> CPU design and verification projects in SystemVerilog

이 폴더는 SystemVerilog 기반 프로젝트를 모아둔 공간입니다.  
직접 구현한 RV32I CPU 설계와 FIFO/UART 중심 검증 프로젝트를 함께 담고 있습니다.

## 폴더 구성

| 경로 | 설명 |
| --- | --- |
| [SV_Verification](./SV_Verification) | FIFO/UART 중심 SystemVerilog 검증 프로젝트 |
| [RV32I_SingleSycle](./RV32I_SingleSycle) | RV32I single-cycle CPU RTL 및 testbench |

## 1. [SV_Verification](./SV_Verification)

FIFO/UART 계열 모듈을 대상으로 작성한 검증 프로젝트입니다.  
테스트벤치, 시뮬레이션 로그, 시각화 보고서를 함께 정리해 두었습니다.

포함 내용:
- [src](./SV_Verification/src): 검증 대상 RTL
- [tb](./SV_Verification/tb): interface / generator / driver / monitor / scoreboard 기반 TB
- [reports/pdf/systemverilog_python_visual_report_ko.pdf](./SV_Verification/reports/pdf/systemverilog_python_visual_report_ko.pdf): PDF 보고서
- [reports](./SV_Verification/reports): HTML 및 Markdown 보고서
- [evidence](./SV_Verification/evidence): Vivado xsim 로그 및 CSV 결과
- [README.md](./SV_Verification/README.md): 상세 소개 문서

핵심 포인트:
- 역할을 나눈 testbench 구조
- FIFO / UART 대상 self-checking scoreboard 및 coverage 구성
- 보고서와 로그를 함께 정리한 문서 구조

## 2. [RV32I_SingleSycle](./RV32I_SingleSycle)

RV32I 명령어 집합을 대상으로 한 single-cycle CPU 구현 프로젝트입니다.

포함 내용:
- [src](./RV32I_SingleSycle/src): `Top.sv`, `Datapath.sv`, `ControlUnit.sv`, `Alu.sv`, `Regfile.sv` 등 주요 RTL
- [tb](./RV32I_SingleSycle/tb): 테스트벤치 및 어셈블리 예제
- `RV32I CPU 설계 보고서.pdf`: 설계 정리 문서

핵심 포인트:
- PC, Instruction ROM, Control Unit, Datapath, Data RAM으로 구성
- bubble sort 시나리오용 ROM 선택 구조 포함
- single-cycle CPU 데이터 경로와 제어 경로를 분리해 구현

## 읽는 순서

1. 검증 포트폴리오를 보고 싶으면 [SV_Verification](./SV_Verification)
2. CPU 구현을 보고 싶으면 [RV32I_SingleSycle](./RV32I_SingleSycle)
3. 상세 문서는 각 폴더 내부 `README`와 PDF 보고서 확인
