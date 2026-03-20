# SystemVerilogProject
> CPU design and verification portfolio in SystemVerilog

이 폴더는 SystemVerilog 기반 프로젝트를 모아둔 공간입니다.  
직접 구현한 RV32I CPU 설계와, FIFO/UART 중심의 verification portfolio를 함께 담고 있습니다.

## 📂 Folder Layout

| 경로 | 설명 |
| --- | --- |
| [SV_Verification](./SV_Verification) | 대표 showcase용 SystemVerilog verification 프로젝트 |
| [RV32I_SingleSycle](./RV32I_SingleSycle) | RV32I single-cycle CPU RTL 및 testbench |

## 1. [SV_Verification](./SV_Verification)

이 폴더는 GitHub에서 가장 먼저 보여주기 좋은 대표 검증 포트폴리오입니다.  
FIFO/UART 계열 모듈을 대상으로 self-checking testbench, 증빙 로그, 시각화 보고서를 함께 정리했습니다.

포함 내용:
- [src](./SV_Verification/src): showcase RTL
- [tb](./SV_Verification/tb): interface / generator / driver / monitor / scoreboard 기반 TB
- [reports](./SV_Verification/reports): HTML 및 Markdown 보고서
- [evidence](./SV_Verification/evidence): Vivado xsim 로그 및 CSV 결과
- [README.md](./SV_Verification/README.md): 상세 소개 문서

핵심 포인트:
- UVM 스타일 역할 분리 기반 verification environment
- FIFO / UART 대상 self-checking scoreboard 및 coverage 구성
- 결과를 GitHub에서 바로 보여줄 수 있는 보고서 구조 포함

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

## ✅ 추천 확인 순서

1. 검증 포트폴리오를 보고 싶으면 [SV_Verification](./SV_Verification)
2. CPU 구현을 보고 싶으면 [RV32I_SingleSycle](./RV32I_SingleSycle)
3. 상세 문서는 각 폴더 내부 `README`와 PDF 보고서 확인
