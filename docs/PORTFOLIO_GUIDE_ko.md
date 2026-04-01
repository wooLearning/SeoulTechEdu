# 포트폴리오 가이드

이 문서는 저장소 전체를 포트폴리오 관점에서 빠르게 읽기 위한 안내서입니다.  
핵심은 각 프로젝트를 같은 기준으로 보는 것입니다.

## 읽는 기준

- `소스코드`: RTL, 상위 모듈, testbench, 검증 환경
- `문서`: README, 보고서, 발표자료, 시각화 설명
- `산출물`: 로그, CSV, timing report, implementation 결과, 실행 이미지

## 프로젝트별 성격

### VerilogProject

- 초반 FPGA 설계 경험을 묶어 둔 프로젝트입니다.
- 시계/스톱워치, UART, 센서 제어를 하나의 통합 설계 흐름으로 볼 수 있습니다.
- 문서는 `docs/`, 소스는 `SourceCode/` 아래에서 분리해 확인할 수 있습니다.

### SystemVerilogProject

- FIFO와 UART 계열 RTL을 대상으로 한 class-based verification 프로젝트입니다.
- `src/`는 검증 대상 RTL, `tb/`는 환경, `reports/`는 설명, `evidence/`는 근거 자료 역할을 합니다.

### RISC-V_multicycle

- RV32I multicycle CPU에 APB 주변장치를 연결한 프로젝트입니다.
- CPU 전체보다는 MMIO, UART peripheral, full-top 반복 실행 검증이 중심입니다.
- `md/`에 문서와 시각 자료가 모여 있고 `output/`에는 실행 산출물이 있습니다.

### RISC-V_pipeline

- RV32I 5-stage pipeline CPU를 Spike 기준 결과와 비교하며 검증한 프로젝트입니다.
- 대표 케이스별 비교 자료와 성능 리포트를 함께 볼 수 있습니다.
- `reports/`는 정리된 결과, `evidence/`와 `output/`은 세부 근거 자료입니다.

## 추천 탐색 순서

1. 저장소 전체 구조는 [README.md](../README.md)에서 확인합니다.
2. 관심 프로젝트의 `START_HERE_ko.md`를 먼저 읽습니다.
3. 이해가 필요한 경우 `README.md`와 대표 보고서를 봅니다.
4. 세부 구현은 `src/`와 `tb/`에서 확인합니다.
5. 검증 근거는 `evidence/`, `output/`, build report에서 확인합니다.

## 빠른 선택 가이드

| 보고 싶은 내용 | 추천 프로젝트 |
| --- | --- |
| FPGA 통합 설계 흐름 | `VerilogProject` |
| SystemVerilog 검증 구조 | `SystemVerilogProject` |
| CPU + peripheral 연동 | `RISC-V_multicycle` |
| pipeline 검증과 성능 비교 | `RISC-V_pipeline` |
