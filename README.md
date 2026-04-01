# Digital Design Portfolio

디지털 회로 설계와 검증 과정을 프로젝트 단위로 정리한 포트폴리오 저장소입니다.  
한 저장소 안에 여러 결과물이 섞여 보이지 않도록, 각 프로젝트를 `소스코드`, `문서`, `검증 산출물` 기준으로 다시 읽기 쉽게 정리했습니다.

## 바로 가기

- [포트폴리오 가이드](./docs/PORTFOLIO_GUIDE_ko.md)
- [VerilogProject](./VerilogProject/README.md)
- [SystemVerilogProject](./SystemVerilogProject/README.md)
- [RISC-V_multicycle](./RISC-V_multicycle/README.md)
- [RISC-V_pipeline](./RISC-V_pipeline/README.md)

## 프로젝트 맵

| 프로젝트 | 핵심 주제 | 먼저 볼 자료 | 소스코드 | 자료/산출물 |
| --- | --- | --- | --- | --- |
| [VerilogProject](./VerilogProject/README.md) | FPGA 통합 설계 | [START_HERE_ko.md](./VerilogProject/START_HERE_ko.md) | `SourceCode/src`, `SourceCode/tb` | `docs/` |
| [SystemVerilogProject](./SystemVerilogProject/README.md) | FIFO/UART class-based verification | [START_HERE_ko.md](./SystemVerilogProject/START_HERE_ko.md) | `src/`, `tb/` | `reports/`, `evidence/` |
| [RISC-V_multicycle](./RISC-V_multicycle/README.md) | RV32I multicycle CPU + APB peripheral | [START_HERE_ko.md](./RISC-V_multicycle/START_HERE_ko.md) | `src/`, `tb/` | `md/`, `output/` |
| [RISC-V_pipeline](./RISC-V_pipeline/README.md) | RV32I 5-stage pipeline + Spike 비교 검증 | [START_HERE_ko.md](./RISC-V_pipeline/START_HERE_ko.md) | `src/`, `tb/` | `reports/`, `evidence/`, `output/` |

## 이 저장소를 읽는 기준

- `src/`, `SourceCode/src/`: RTL과 설계 소스
- `tb/`, `SourceCode/tb/`: testbench와 검증 환경
- `docs/`, `reports/`, `md/`: 설명 문서, 보고서, 발표 자료
- `evidence/`, `output/`: 로그, CSV, 구현 결과, 실행 산출물

## 추천 읽는 순서

1. [포트폴리오 가이드](./docs/PORTFOLIO_GUIDE_ko.md)에서 전체 흐름을 확인합니다.
2. 관심 있는 프로젝트의 `README.md`와 `START_HERE_ko.md`를 먼저 읽습니다.
3. 구조가 궁금하면 `src/`와 `tb/`를 보고, 결과가 궁금하면 `docs/`, `reports/`, `md/`를 봅니다.
4. 재현 근거가 필요하면 `evidence/`와 `output/`을 확인합니다.

## 기술 키워드

`Verilog` `SystemVerilog` `RISC-V` `FPGA` `UART` `FIFO` `APB` `MMIO` `Vivado` `xsim` `Python`
