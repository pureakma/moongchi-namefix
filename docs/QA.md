# 검증과 User QA

## 두 종류의 검증

Engineering Verification은 AI/자동화가 수행하는 build, test, runtime fixture, render, performance, security/contract 검사다.

User QA는 사용자가 실제 앱을 조작하고 판단한 결과다. AI가 캡처를 보거나 off-screen render를 확인해도 User QA PASS로 기록하지 않는다.

## 검증 범위 규칙

Task의 검증 범위는 변경 영역 + 변경 계약 + 그 소비자 + 무효화된 기존 PASS 근거에서 결정한다. 작은 변경마다 전체 regression, clean build, package를 반복하지 않는다.

.ai/validation-cache.json은 source/test/dependency/toolchain/environment fingerprint와 evidence path를 기록하는 검증 영수증이다. evidence가 Git에 없거나 해당 fingerprint가 달라졌으면 과거 PASS를 현재 PASS로 확대하지 않는다.

## 현재 source의 Engineering Verification 상태

2026-10-06 출시 전 제품 완성도 고도화(T-002) 통합 검증 결과다. 영수증은 .ai/validation-cache.json의 MAC-RELEASE-READINESS-20261006, 로컬 evidence는 artifacts/development/release-readiness다.

| 항목 | 명령 | 결과 |
|---|---|---|
| Runtime·UI model·Core test | eng/test.sh --level 3 --scope all | 103개 실행, 실패 0 (통합 53 중 성능 프로파일 3개 skip, UI model 30, Core 20) |
| 리소스 | python3 eng/resources.py; python3 eng/validate-resources.py | 446 keys × ko/en/ja, 재생성 diff 0, placeholder parity, 폰트/라이선스, arm64 Services plist, 네트워크 API 없음 PASS |
| CLI | eng/build-cli.sh debug; eng/test-expansion-cli.py | dry-run/JSON, non-TTY 거부, TTY 확인 rename/undo, Free/Pro 경계 PASS. 끝 슬래시 경로 수동 확인 PASS |
| Debug build | eng/build.sh --configuration Debug --arch arm64 | BUILD SUCCEEDED |
| Release 구성 build | eng/build.sh --configuration Release --arch arm64 | BUILD SUCCEEDED, arm64, 1.0.0 (3), 최소 14.0, 리소스 self-test PASS. 배포 후보 생성·서명·패키징은 하지 않음 |
| Off-screen render | --render-shell, --render-expansion, --render-expansion --native-sidebar, --render-responsive | 219장 생성, toolbar/sidebar/선택 유지 assertion PASS. ko/en/ja × 네 테마 × 넓은/좁은 창의 대표 화면을 AI가 직접 확인 |
| 성능 프로파일 (Debug) | NAMEFIX_PERFORMANCE=1, NAMEFIX_EXPANSION_PERF=1 | 10,000건 scan+rule Preview+plan 중앙값 2.221초 · p95 2.225초(Preview 약 0.70초), 100,000건 scan 3.104초 · peak 약 148 MiB · 오류 0 |

이번 Task가 추가한 회귀 test: 항목 처리 중 취소 시 임시 이름에 남지 않음, metadata 규칙에서 폴더와 하위 항목 동시 변경, Finder 관리 파일 규칙 제외, scan 한도 경계, 와일드카드 바꿀 글자의 literal 처리, RawPath 전체 바이트 해시.

재사용한 기존 근거와 한계:
- MAC-V1-APFS-CASE-SENSITIVE(대소문자 구분 APFS 볼륨)와 MAC-V1-RELEASE-TRANSACTIONS, MAC-V1-CLI(Release 구성 test/CLI)는 이번에 다시 실행하지 않았다. 이번 변경으로 Infrastructure/Application/CLI source가 바뀌었으므로 validation cache에서 STALE로 내렸고, 새 Release Task에서 다시 실행한다.
- 1,000건 실제 mutation 프로파일(과거 Debug 28.3초)은 다시 측정하지 않았다. 항목당 이동·journal 횟수는 바꾸지 않았다.
- MAC-V1-SOURCE-RACE-LIMITATION은 KNOWN_LIMITATION, MAC-V1-NOTARIZATION과 MAC-V1-PAID-PROVIDER는 BLOCKED_EXTERNAL로 유지한다.
- 경로 해시 보강은 Data 해시가 앞부분만 쓰는 macOS 버전을 대비한 방어 변경이다. 개발 장비의 macOS에서는 기존 구현도 선형이었으므로, macOS 14 실기의 대량 목록 성능은 User QA U10/U11에서 확인한다.

과거 build3 Release 후보의 서명·패키지 검증은 현재 source의 근거가 아니다. 경쟁 제품 대비 속도, 실제 UI scroll latency, Release 구성 성능 수치로 확대하지 않는다.

## User QA — 한 번에 확인할 목록

실제 업무 원본이 아닌 복사본 폴더에서 진행한다. 결과는 사용자가 말한 PASS/FAIL을 그대로 기록하고, 실패가 제품 수정의 근원이 되면 STATUS에 bug Task로 올린다.

| ID | 확인 항목 | 현재 상태 |
|---|---|---|
| U01 | 기본 흐름: 파일·폴더 추가(선택 창, 창 전체 drag & drop) → 검사 → 변경 전후 이름 확인 → 확인 시트 → 이름 바꾸기 → 결과 → 작업 기록 → 되돌리기 | PENDING |
| U02 | 처음 보는 사용자 기준으로 화면 문구가 설명 없이 이해되는지: 상태(글자 분리됨 등), 확인 시트, 사용 방법, 오류 안내 | PENDING |
| U03 | 테마 4종과 ko/en/ja 전환이 즉시 적용·저장되고 재실행 후 유지되는지, 주요 화면에서 글자가 잘리지 않는지 | PENDING |
| U04 | 창 크기 조절(좁게/넓게/낮게), 사이드바 접기, 전체 화면, 재실행 후 창 위치 복원 | PENDING |
| U05 | 키보드만으로 조작: Tab 이동, Space 선택, ⌘O/⇧⌘O/⌘F/⌘R/⌘1/⌘2/⌘,/⌘W/⌘M/⌘H, 확인 시트의 Return/Esc | PENDING |
| U06 | VoiceOver로 목록·버튼·상태 읽기, 대비 증가·큰 글자 설정에서 가독성 | PENDING |
| U07 | 글자 구성 자세히 보기, 텍스트 변환, 복사한 글자 분석(자동 감시 없음) | PENDING |
| U08 | 데스크탑/문서/다운로드 폴더 권한 안내가 앱 언어로 나오는지, 거절·허용, 읽기 전용 위치·외장/SMB/iCloud 항목의 변경 차단 표시 | PENDING |
| U09 | 중단과 복구: 작업 중 취소(처리 중 항목까지 마치고 멈춤), 강제 종료 후 재실행 안내와 복구, 다른 앱이 같은 파일을 저장·이동할 때 중단 안내, 앱 두 번 실행 시 중복 변경 차단 | PENDING |
| U10 | 대량 목록(약 100,000개) 검사·스크롤·검색·필터·취소 응답성 | PENDING |
| U11 | 실제 macOS 14 Apple Silicon에서 U01과 U10 | PENDING |
| U12 | Finder 서비스, Dock/다음으로 열기, 메뉴바 아이콘 drop·메뉴, 로그인 시 실행, 완료 알림의 실제 OS 승인·거절 | PENDING |
| U13 | Pro 기능 흐름(개발 빌드의 개발용 Pro 스위치): 규칙·프리셋, CSV 목록, 파일 정보(실제 사진/음악/영상), 묶음 파일, 폴더 감시(잠자기·재시작·권한 철회 포함) | PENDING |
| U14 | 새 current-source 서명·공증 패키지를 깨끗한 Mac에 설치·실행 | BLOCKED_BY_RELEASE |
| U15 | Release 설정의 Free/Pro 표시가 실제 판매 공급자 상태와 일치 | BLOCKED_BY_PAID_PROVIDER |

## 문서/도구 검증

문서 변경 후:
~~~sh
python3 tools/doccheck.py
python3 tools/doccheck.py --git
git diff --check
~~~

eng/write-qa-report.py의 오래된 Phase0~5 보고서는 현재 SSOT가 아니라 재현 가능한 로컬 evidence 생성 도구다. 출력은 artifacts/evidence 아래에 두며 docs/를 덮어쓰지 않는다.
