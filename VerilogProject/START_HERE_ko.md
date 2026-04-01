# 시작 안내

Verilog 기반 FPGA 통합 설계 자료를 빠르게 따라가기 위한 안내 문서입니다.

## 먼저 볼 자료

- [README.md](README.md)
- [문서 인덱스](docs/README.md)
- [StopWatch / Clock 문서](docs/FPGA%20StopWatch%20%26%20Clock%20Project.pdf)
- [UART 문서](docs/FPGA%20UART%20Project.pdf)
- [센서 통합 문서](docs/FPGA%20Seneor%20%ED%86%B5%ED%95%A9%20Project.pdf)

## 읽는 순서

1. `README.md`에서 전체 구성과 대표 모듈을 확인합니다.
2. `docs/README.md`에서 어떤 PDF가 어떤 내용을 담는지 확인합니다.
3. `docs/` 아래 PDF로 기능별 설계 흐름을 읽습니다.
4. `SourceCode/src/Top.v`부터 상위 통합 구조를 확인합니다.
5. 필요하면 `SourceCode/tb/`에서 개별 검증 파일을 확인합니다.

## 주요 경로

- RTL: `SourceCode/src/`
- Testbench: `SourceCode/tb/`
- Constraint: `SourceCode/constrs/`
- 문서/PDF: `docs/`
