# SystemVerilogProject
> CPU design and verification portfolio in SystemVerilog

이 폴더는 SystemVerilog 기반 프로젝트를 모아둔 공간입니다.  
직접 구현한 RV32I CPU 설계와, FIFO/UART 중심의 verification portfolio를 함께 담고 있습니다.

## 📂 Folder Layout

| 경로 | 설명 |
| --- | --- |
| [RV32I_SingleSycle](./RV32I_SingleSycle) | RV32I single-cycle CPU RTL 및 testbench |
| [result_portfolio](./result_portfolio) | SystemVerilog verification showcase 최종 정리본 |

## 1. [RV32I_SingleSycle](./RV32I_SingleSycle)

RV32I 명령어 집합을 대상으로 한 single-cycle CPU 구현 프로젝트입니다.

포함 내용:
- [src](./RV32I_SingleSycle/src): `Top.sv`, `Datapath.sv`, `ControlUnit.sv`, `Alu.sv`, `Regfile.sv` 등 주요 RTL
- [tb](./RV32I_SingleSycle/tb): 테스트벤치 및 어셈블리 예제
- `RV32I CPU 설계 보고서.pdf`: 설계 정리 문서

핵심 포인트:
- PC, Instruction ROM, Control Unit, Datapath, Data RAM으로 구성
- bubble sort 시나리오용 ROM 선택 구조 포함
- single-cycle CPU 데이터 경로와 제어 경로를 분리해 구현

## 2. [result_portfolio](./result_portfolio)

FIFO/UART 계열 모듈을 대상으로 구성한 verification 포트폴리오입니다.  
RTL, testbench, evidence, report가 함께 정리되어 있어서 GitHub 공개용 문서 구조가 잘 갖춰져 있습니다.

포함 내용:
- [src](./result_portfolio/src): showcase RTL
- [tb](./result_portfolio/tb): interface / generator / driver / monitor / scoreboard 기반 TB
- [reports](./result_portfolio/reports): HTML 및 Markdown 보고서
- [evidence](./result_portfolio/evidence): Vivado xsim 로그 및 CSV 결과
- [README.md](./result_portfolio/README.md): 상세 소개 문서

## ✅ 추천 확인 순서

1. CPU 구현을 보고 싶으면 [RV32I_SingleSycle](./RV32I_SingleSycle)
2. 검증 포트폴리오를 보고 싶으면 [result_portfolio](./result_portfolio)
3. 상세 문서는 각 폴더 내부 `README`와 PDF 보고서 확인
