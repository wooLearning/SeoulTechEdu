# veri1 상세 한글 보고서

## 1. 프로젝트 정리 목적

이 문서는 `veri1` 프로젝트의 정리 범위와 결과를 다룹니다.

정리 목적은 다음과 같습니다.

- 기존에 학습/실습 형태로 작성한 검증 코드를 포트폴리오에서 읽기 쉬운 구조로 정리
- 단순 RTL 구현이 아니라 SystemVerilog 검증 구조까지 포함
- `coverage`, `scoreboard`, `random stimulus`, `environment separation` 같은 검증 키워드가 코드와 문서에 명확히 드러나도록 구성
- 이후 다른 예전 프로젝트에도 같은 방식으로 확장 가능한 템플릿 확보

## 2. 작업 범위

이번 정리는 아래 경로만 대상으로 진행했습니다.

- `FPGA_Auto_Project/Project/veri1`

루트의 `src/`, `tb/`는 참고용으로만 읽었고 직접 수정 대상은 `veri1` 내부로 제한했습니다.

## 3. 기준 소스 탐색 결과

사용자 요청대로 “예전에 거의 최종처럼 쓰던, 길고 클래스가 한 파일에 몰려 있는 형태”를 우선 기준점으로 삼으려고 워크스페이스 전체를 다시 탐색했습니다.

탐색 결과는 다음과 같습니다.

- `fifo` / `sync_fifo`에 대해 명확한 “all-in-one class file” 최종본은 현재 워크스페이스에서 확인되지 않았음
- 대신 학습형/압축형 스타일의 흔적은 `tb/ff/task.sv`, `tb/ff/task_case5.sv`에서 확인됨
- `fifo`, `sync_fifo`의 경우에는 이미 `transaction / generator / driver / monitor / scoreboard / environment`로 분리된 구조가 가장 성숙한 형태로 남아 있었음

정리 기준은 다음과 같습니다.

- “단일 대형 파일을 정확히 복원”하는 것보다는
- 현재 가장 안정적으로 검증이 통과하는 분리 구조를 기준으로
- 문서와 코드 구조를 읽기 쉬운 형태로 재정리

## 4. 최종 정리 방향

이번 `veri1`의 포트폴리오 메시지는 아래처럼 잡았습니다.

- 메인 사례: 비동기 FIFO 검증
- 보조 사례: 동기 FIFO 검증
- UART 확장 사례: UART RX / UART RX+FIFO / UART TX+FIFO / UART+async FIFO
- 추가 사례: SRAM / `ff_en` / `ff`
- 검증 프레임워크 포인트:
  - class 기반 구조
  - mailbox 통신
  - random stimulus
  - self-checking scoreboard
  - functional coverage
  - FPGA_AUTO 툴킷 기반 재현 가능한 실행

정식 UVM 사용보다는 UVM 스타일의 역할 분리를 직접 구성한 환경에 가깝습니다.

## 5. 코드 구조 정리 내용

### 5-1. 폴더 구조

TB는 다음 구조를 유지했습니다.

- `objs/`
  - transaction class 보관
- `components/`
  - generator
  - driver
  - monitor
  - coverage
  - scoreboard
- `env/`
  - environment class
- top TB
  - DUT instantiation
  - clock/reset generation
  - environment 실행

이 구조는 다음 장점이 있습니다.

- 리뷰어가 역할을 빠르게 이해할 수 있음
- 특정 문제 발생 시 어느 계층을 봐야 하는지 명확함
- 다음 프로젝트에도 동일한 패턴을 복사해 재사용 가능

### 5-2. 주석 및 설명 정리

코드 주석은 아래 원칙으로 정리했습니다.

- 너무 당연한 문장은 제거
- 타이밍 의도나 reference model 의도처럼 중요한 부분만 남김
- top TB에서는 “이 테스트가 무엇을 검증하는지”가 바로 보이도록 유지
- generator/monitor/scoreboard는 각자 역할이 한 줄 설명으로 바로 드러나도록 정리

### 5-3. 문서 정리

영문 중심 문서는 한글 기준으로 재작성했습니다.

- `README.md`
  - 프로젝트 소개
  - 검증 항목
  - 대표 DUT
  - 실행 경로
- `reports/markdown/overview/verification_overview.md`
  - 검증 구조 설명
  - 구조 정리
- `reports/markdown/overview/artifact_index.md`
  - 실제 산출물 위치 안내
- `reports/markdown/overview/portfolio_report_ko.md`
  - 이번 상세 보고서

### 5-4. 세부 설명 문서 위치

문서 구성은 아래 항목을 바로 찾을 수 있게 배치했습니다.

- 클래스별 설명
  - `reports/markdown/module_reports/fifo_report_ko.md`
  - `reports/markdown/module_reports/async_fifo_src_report_ko.md`
  - `reports/markdown/module_reports/sync_fifo_report_ko.md`
  - `reports/markdown/module_reports/uart_rx_report_ko.md`
  - `reports/markdown/module_reports/uart_fifo_report_ko.md`
  - `reports/markdown/module_reports/uart_tx_fifo_report_ko.md`
  - `reports/markdown/module_reports/uart_async_fifo_report_ko.md`
- coverage 설정 설명 및 근거
  - `reports/markdown/module_reports/fifo_report_ko.md`
  - `reports/markdown/module_reports/async_fifo_src_report_ko.md`
  - `reports/markdown/module_reports/sync_fifo_report_ko.md`
  - `reports/markdown/module_reports/uart_rx_report_ko.md`
  - `reports/markdown/module_reports/uart_fifo_report_ko.md`
  - `reports/markdown/module_reports/uart_tx_fifo_report_ko.md`
  - `reports/markdown/module_reports/uart_async_fifo_report_ko.md`
  - `reports/markdown/overview/systemverilog_python_visual_report_ko.md`
- 시나리오 상세 설명
  - `reports/markdown/module_reports/fifo_report_ko.md`
  - `reports/markdown/module_reports/async_fifo_src_report_ko.md`
  - `reports/markdown/module_reports/sync_fifo_report_ko.md`
  - `reports/markdown/module_reports/uart_rx_report_ko.md`
  - `reports/markdown/module_reports/uart_fifo_report_ko.md`
  - `reports/markdown/module_reports/uart_tx_fifo_report_ko.md`
  - `reports/markdown/module_reports/uart_async_fifo_report_ko.md`
  - `reports/markdown/overview/systemverilog_python_visual_report_ko.md`
- 시나리오별 커버리지 집계
  - `reports/markdown/module_reports/uart_rx_report_ko.md`
  - `reports/markdown/module_reports/uart_fifo_report_ko.md`
  - `reports/markdown/module_reports/uart_tx_fifo_report_ko.md`
  - `reports/markdown/module_reports/uart_async_fifo_report_ko.md`
  - `reports/markdown/overview/systemverilog_python_visual_report_ko.md`
- assertion 설명
  - `reports/markdown/module_reports/fifo_report_ko.md`
  - `reports/markdown/module_reports/async_fifo_src_report_ko.md`
  - `reports/markdown/module_reports/sync_fifo_report_ko.md`
  - `reports/markdown/module_reports/uart_rx_report_ko.md`
  - `reports/markdown/module_reports/uart_fifo_report_ko.md`
  - `reports/markdown/module_reports/uart_tx_fifo_report_ko.md`
  - `reports/markdown/module_reports/uart_async_fifo_report_ko.md`

overview 문서는 전체 구조를, 모듈별 상세 보고서는 class/coverage/assertion/timing을, Python 시각화 보고서는 시나리오별 수치와 그래프 해석을 다룹니다.

## 5-5. UART 확장 사례 정리

FIFO 정리 이후 UART 계열 통합 검증도 추가했습니다.

- `uart_rx`
  - UART protocol 자체를 task 기반 serial stimulus로 검증
- `uart_rx_fifo_bridge`
  - UART RX 결과가 `sync_fifo`를 지나도 ordering이 유지되는지 검증
- `uart_tx_fifo_bridge`
  - `sync_fifo`에 쌓인 byte가 UART TX launch 경계로 올바르게 전달되는지 검증
- `uart_rx_async_fifo_bridge`
  - UART RX 결과가 async FIFO를 건너 다른 clock domain에서도 ordering을 유지하는지 검증

단일 FIFO 블록 검증에서 끝나지 않고, protocol + buffer 조합까지 확장된 구조입니다.

## 6. Async FIFO 검증 구조 설명

메인 대상은 `fifo`입니다.

- DUT: `src/fifo.sv`
- TB top: `tb/fifo/tb_fifo.sv`

### 6-1. 왜 async FIFO를 메인으로 잡았는가

비동기 FIFO는 단순 조합/순차 로직보다 검증 포인트가 더 풍부합니다.

- write/read clock domain이 다름
- full/empty 판단이 포인터 동기화와 연관됨
- read acceptance 시점과 data sampling 시점을 조심해서 봐야 함
- 단순 데이터 비교만으로는 부족하고, “accepted transaction” 기준의 모델이 필요함

검증 항목이 많은 대상입니다.

### 6-2. Async FIFO TB 흐름

1. `generator`
   - write/read 요청을 랜덤하게 생성
   - 초반에는 채우기 위주, 후반에는 비우기 위주가 되도록 bias를 줌
2. `driver`
   - write clock / read clock에 맞춰 enable과 write data를 인가
3. `monitor`
   - write-domain sample, read-domain sample을 구분해서 수집
   - pre-edge 상태와 post-edge 상태를 scoreboard가 이해할 수 있는 형태로 전달
4. `scoreboard`
   - accepted write만 model queue에 push
   - accepted read 시 expected data와 DUT read data 비교
   - mismatch 발생 시 fail
5. `environment`
   - 전체 컴포넌트 실행 및 종료 제어

### 6-3. Async FIFO scoreboard 포인트

이 부분이 포트폴리오에서 특히 중요합니다.

- 단순히 `iWrEn=1`이면 write가 됐다고 가정하지 않음
- `preFull`, `preEmpty`를 기준으로 실제 수락 여부를 판단
- read-domain에서는 모델 queue에서 pop한 expected data와 `oRData`를 비교

“신호가 올라갔다”와 “DUT가 실제로 수락했다”를 구분하는 검증 구조입니다.

### 6-4. Async FIFO 시나리오 설계

메인 async FIFO 환경은 5개 시나리오를 중심으로 구성했습니다.

- `fill_burst`
  - write 비중을 높여 queue를 빠르게 채움
  - full 상태와 write blocked path 관찰이 목적
- `mixed_stress`
  - read/write가 섞인 일반 운용 구간
  - ordering과 simultaneous activity를 같이 검증
- `drain_burst`
  - read 비중을 높여 queue를 비움
  - empty 직전과 empty 이후의 behavior를 관찰
- `full_pressure`
  - 꽉 찬 상태에서 write를 반복해 backpressure를 강하게 유도
- `empty_pressure`
  - 비어 있는 상태에서 read를 반복해 underflow protection을 관찰

이 시나리오는 단순히 PASS를 얻기 위한 것이 아니라, accepted path와 blocked path를 모두 만들어 scoreboard 요약과 coverage 설명이 의미 있는 숫자를 갖도록 설계했습니다.

### 6-5. Async FIFO coverage 설명

async FIFO coverage는 다음 항목을 기준으로 해석합니다.

- scenario coverage
  - 5개 시나리오가 모두 실행되었는지 확인
- domain coverage
  - write sample과 read sample이 모두 관측되었는지 확인
- write path coverage
  - accepted, blocked가 모두 발생했는지 확인
- read path coverage
  - accepted, blocked가 모두 발생했는지 확인
- flag state coverage
  - normal, full, empty 상태가 모두 관찰되었는지 확인

이 coverage는 퍼센트보다 의도한 경로의 관측 여부를 정리하는 데 초점을 둡니다.
최종 퍼센트는 Vivado XSim covergroup instance의 `get_inst_coverage()`를 그대로 사용합니다.

Async FIFO의 최신 시나리오별 집계는 다음과 같습니다.

| 시나리오 | 샘플 | WR Acc | RD Acc | WR Block | RD Block | 해석 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `fill_burst` | 229 | 23 | 8 | 19 | 1 | fill 구간에서 write accepted와 write blocked가 함께 나타나 full 근처 압박을 확인할 수 있습니다. |
| `mixed_stress` | 231 | 28 | 29 | 6 | 0 | read/write accepted가 균형 있게 나와 ordering 검증이 가장 활발한 구간입니다. |
| `drain_burst` | 231 | 10 | 24 | 0 | 18 | drain 구간에서 read accepted와 read blocked가 함께 나와 empty 근처 동작을 설명합니다. |
| `full_pressure` | 231 | 26 | 11 | 16 | 0 | backpressure를 강하게 걸어 write blocked 경로를 의도적으로 만든 구간입니다. |
| `empty_pressure` | 230 | 9 | 22 | 0 | 20 | read blocked 수치로 underflow 보호 동작을 확인할 수 있습니다. |

이 표의 의미는 “시나리오가 선언만 되어 있는지”가 아니라, 각 시나리오가 자기 목적에 맞는 accepted/blocked 분포를 실제로 남겼는지를 보여준다는 점입니다.

## 7. Sync FIFO 검증 구조 설명

보조 사례는 `sync_fifo`입니다.

- DUT: `src/sync_fifo.sv`
- TB top: `tb/sync_fifo/tb_sync_fifo.sv`

### 7-1. 왜 sync FIFO도 함께 남겼는가

동기 FIFO는 비동기 FIFO보다 구조가 단순하며, 다음 항목을 중심으로 정리했습니다.

- read/write 동시 처리
- queue 기반 reference model
- full/empty flag 정확도 확인
- 간결한 self-checking TB 구성

async FIFO보다 구조가 단순해 읽기 쉬운 보조 사례입니다.

### 7-2. Sync FIFO scoreboard 포인트

sync FIFO scoreboard는 내부 model queue size를 기준으로 다음을 계산합니다.

- write acceptance 여부
- read acceptance 여부
- expected full
- expected empty
- expected read data

그래서 단순 데이터 비교를 넘어서 flag consistency까지 같이 볼 수 있습니다.

### 7-3. Sync FIFO 시나리오 설계

sync FIFO는 단일 클록 구조이며, 시나리오 설계는 정책 검증을 중심으로 구성했습니다.

- `fill_burst`
  - write 위주로 depth를 늘려 full boundary를 만듦
- `simul_stress`
  - read/write 동시 요청 비중을 높여 same-cycle 정책 검증
- `drain_burst`
  - read 위주로 depth를 줄여 empty boundary를 만듦
- `flag_pressure`
  - full/empty 근처를 반복 자극해 blocked path를 강조
- `balanced_stream`
  - 한쪽으로 치우치지 않은 steady-state traffic

sync FIFO에서는 동시 read/write 허용 조건을 scoreboard가 제대로 따라가는지가 핵심입니다.

### 7-4. Sync FIFO coverage 설명

sync FIFO coverage는 아래 항목을 중심으로 봅니다.

- scenario hit
- request mix hit
  - idle, write-only, read-only, both
- write accepted / blocked
- read accepted / blocked
- full / empty / normal

이 구조 덕분에 “동시 read/write가 정말 실행됐는가”, “full/empty 압박이 실제로 있었는가”를 정량적으로 설명할 수 있습니다.

Sync FIFO의 최신 시나리오별 집계는 다음과 같습니다.

| 시나리오 | 샘플 | WR Acc | RD Acc | WR Block | RD Block | 해석 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `fill_burst` | 64 | 31 | 15 | 33 | 1 | fill boundary를 강하게 밀어 WR Block이 크게 발생한 구간입니다. |
| `simul_stress` | 64 | 64 | 64 | 0 | 0 | same-cycle read/write 정책 검증이 가장 강하게 수행된 구간입니다. |
| `drain_burst` | 64 | 19 | 31 | 0 | 33 | drain과 empty 보호가 뚜렷하게 관찰된 구간입니다. |
| `flag_pressure` | 64 | 43 | 46 | 2 | 0 | full/empty 근처를 반복적으로 왕복하며 flag 경계 조건을 두드린 구간입니다. |
| `balanced_stream` | 63 | 45 | 42 | 0 | 6 | steady-state traffic에서 sustained throughput과 경미한 empty pressure를 함께 확인합니다. |

## 8. clocking block 적용과 최종 구조

이번 최종본에서는 `clocking block`을 실제 검증 타이밍 구조의 중심으로 적용했습니다. 다만 처음부터 바로 안정화된 것은 아니었고, XSim에서 sample 시점이 어긋나는 회귀를 확인한 뒤 아래처럼 구조를 재정의했습니다.

- driver clocking block
  - `negedge`에서 request와 data를 인가
  - DUT는 다음 `posedge`에서 안정된 입력을 봄
- pre-sample clocking block
  - `posedge` 기준 `#1step`으로 edge 직전 요청과 flag를 저장
  - acceptance 판정 근거를 transaction에 남김
- post-sample clocking block
  - 다음 `negedge` 기준 `#1step`으로 DUT가 갱신한 결과를 관찰
  - driver가 다음 cycle 값을 다시 세팅하기 전 상태를 안전하게 읽음

이 방식으로 바꾼 이유는 다음과 같습니다.

- async FIFO는 “요청 직전 flag”와 “edge 처리 후 결과”를 동시에 알아야 accepted/blocked 판정이 정확함
- sync FIFO도 same-cycle read/write 정책 때문에 request 시점과 결과 시점을 분리해서 보는 편이 더 명확함
- 단순 `#1` 지연보다 clocking block 자체에 타이밍 의도를 담는 편이 포트폴리오 설명에도 유리함

현재 구조는 drive / pre-sample / post-sample을 분리한 clocking-block-based verification structure입니다.

## 9. FPGA_AUTO 툴킷 활용 방식

사용자 요청대로 build/sim에는 FPGA_AUTO 툴킷 흐름을 그대로 활용했습니다.

권장 흐름은 다음과 같습니다.

1. FPGA_AUTO 실행
2. `NO GUI Vivado Simulation` 선택
3. `tb/fifo` 또는 `tb/sync_fifo` 선택
4. `tb_fifo.sv` 또는 `tb_sync_fifo.sv` 선택
5. 실행 후 `evidence/logs/`에서 결과 확인

이 방식의 장점은 다음과 같습니다.

- 실행 경로가 문서화 가능
- GitHub에 “어떻게 돌렸는지”를 설명하기 쉬움
- 향후 다른 프로젝트에도 같은 툴 흐름을 적용 가능

## 10. 최종 검증 결과

이번 정리 후 Vivado xsim 기준 결과는 다음과 같습니다.

### 10-1. Async FIFO

- 로그: `evidence/logs/async_fifo_vivado.log`
- 결과:
  - `[SCB][SUMMARY] sample=1153 rd_tick=420 pass=190 fail=0 wr_acc=96 rd_acc=94 ...`
  - `[SCB][PASS] Async FIFO scoreboard completed without mismatches`

### 10-2. Sync FIFO

- 로그: `evidence/logs/sync_fifo_vivado.log`
- 결과:
  - `[SCB][SUMMARY] sample=320 pass=838 fail=0 wr_acc=202 rd_acc=198 ...`
  - `[SCB][PASS] Sync FIFO scoreboard completed without mismatches`

두 FIFO 환경 모두 scoreboard 기준으로 clean pass 상태입니다.

## 11. 포트폴리오 관점에서 강조 가능한 역량

이 프로젝트에서 실제로 강조할 수 있는 포인트는 아래와 같습니다.

### 11-1. SystemVerilog 활용

- class 기반 검증 환경 작성
- mailbox/event 사용
- constraint random 사용
- interface 사용
- covergroup 사용

### 11-2. 검증 구조 설계

- generator/driver/monitor/scoreboard/environment 역할 분리
- self-checking 구조
- reference model 기반 판정
- 로그와 종료 조건 명확화
- scenario-driven randomized verification
- coverage와 summary CSV를 통한 결과 구조화

### 11-3. 실무형 정리 능력

- 학습형 코드에서 포트폴리오형 구조로 재정리
- 대상 범위 구분
- 실행 증빙과 문서 경로 정리
- FPGA_AUTO 기반 반복 가능한 실행 흐름 확보

## 12. 남겨둔 참고 자산

`result_portfolio` 패키지는 GitHub 업로드를 기준으로 핵심 코드와 보고서만 남겼습니다.

원본 프로젝트의 학습형/reference 자산 전체를 옮긴 것이 아니라 아래 기준으로 선별했습니다.

- 남긴 것
  - async FIFO, sync FIFO, UART, UART+FIFO 관련 RTL/TB
  - Vivado 검증 로그
  - Python 시각화 보고서
  - 모듈별 상세 보고서
- 제외한 것
  - 연습용 RTL
  - 중간 산출물
  - 자동 생성 참고 문서
  - 발표용 HTML 초안

이렇게 정리한 이유는 저장소 첫 화면에서 메시지가 흐려지지 않게 하고, 리뷰어가 바로 핵심 코드와 증빙에 접근할 수 있게 하기 위함입니다.

## 13. 다음 확장 방향

이 프로젝트가 잘 정리됐기 때문에, 이후 기존 프로젝트를 같은 방식으로 올릴 때는 아래 순서로 확장하면 좋습니다.

1. 원본 RTL/TB 보존
2. 새 portfolio project 폴더 생성
3. DUT 선정
4. compact/legacy TB를 `transaction/components/env` 구조로 분리
5. README/verification_overview/report 작성
6. FPGA_AUTO 기준 증빙 로그 생성

이 흐름이 자리잡으면 이후 프로젝트 정리 속도가 훨씬 빨라질 수 있습니다.
