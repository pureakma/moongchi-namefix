# 검증과 User QA

## 두 종류의 검증

Engineering Verification은 AI/자동화가 수행하는 build, test, runtime fixture, render, performance, security/contract 검사다.

User QA는 사용자가 실제 앱을 조작하고 판단한 결과다. AI가 캡처를 보거나 off-screen render를 확인해도 User QA PASS로 기록하지 않는다.

## 검증 범위 규칙

Task의 검증 범위는 변경 영역 + 변경 계약 + 그 소비자 + 무효화된 기존 PASS 근거에서 결정한다. 작은 변경마다 전체 regression, clean build, package를 반복하지 않는다.

.ai/validation-cache.json은 source/test/dependency/toolchain/environment fingerprint와 evidence path를 기록하는 검증 영수증이다. evidence가 Git에 없거나 해당 fingerprint가 달라졌으면 과거 PASS를 현재 PASS로 확대하지 않는다.

## 현재 source의 Engineering Verification 상태

현재 Git 상태에서 가장 최근 focused PASS로 기록된 항목은 다음과 같다.

- MAC-NATIVE-SIDEBAR-20261004: Debug build, WorkspaceTests/WindowLayoutTests 12개, resource validation, native sidebar 관련 36 render와 collapse assertion. 426 keys × 3 locales가 해당 시점 evidence에 기록됨.
- MAC-APP-ICON-1aa97856: 최신 앱 아이콘 source와 10-slot 생성/alpha/bundle 연결 검증 PASS.
- MAC-V1-SOURCE-RACE-LIMITATION: 실제 executor 경합에서 감지/중단 동작은 확인했으나 비협조 writer의 원자 예방은 KNOWN_LIMITATION.
- MAC-V1-NOTARIZATION: BLOCKED_EXTERNAL.
- MAC-V1-PAID-PROVIDER: BLOCKED_EXTERNAL.

과거 build3 Release 후보에서는 91 unique XCTest와 Release 실행 경로/패키지/Developer ID 검증이 기록됐다. 이후 UI/설정/리소스 변경 때문에 validation cache의 MAC-V1-RENDER, MAC-V1-BUILD, MAC-V1-DEVELOPER-ID, MAC-V1-PACKAGES 등 영향받은 범위는 STALE이다. 따라서 91 PASS 또는 build3 패키지 성공을 현재 source의 full Release PASS라고 쓰지 않는다.

현재 문서 migration은 제품 소스를 바꾸지 않으므로 제품 full regression을 다시 실행하지 않는다. 문서/운영 변경에는 doccheck, 링크/SSOT 검사, 문서 소비 helper 경로 검사만 수행한다.

## 알려진 성능 근거

가장 최근 broad candidate에서 기록된 개발 측정은 참고 evidence이며 현재 source GUI 성능을 새로 측정한 값이 아니다.

- 10,000건 scan + rule Preview + 실행 plan: Debug 중앙값 2.195초, 5표본 nearest-rank p95 3.080초.
- 동일 계열 Preview 최대 0.732초로 과거 내부 0.300초 목표를 초과.
- 100,000건 scan: 3.147초, XCTest process 누적 peak RSS 139.6 MiB, 오류 0.
- cancel 반환: 0.206초.
- 1,000건 실제 mutation: Release 27.927초, Debug 28.296초.

경쟁 제품보다 빠르다는 근거, 실제 UI scroll latency, 현재 source Release 수치로 확대하지 않는다.

## User QA 예정

아래는 사용자가 실제로 확인해야 하며 기본적으로 Release 단계에서 한 번에 묶는다.

| ID | 확인 항목 | 현재 상태 |
|---|---|---|
| UI01 | Finder에서 창 전체 위치별 파일/폴더 drag & drop | PENDING |
| UI02 | Olive 기본과 System/Dark/Light/Olive 전환·재시작 | PENDING |
| UI03 | 언어/테마/표시 설정 즉시 적용·저장·재실행 | PENDING |
| UI04 | 선택·검색·숨은 선택·Preview 취소·재확인 | PENDING |
| UI05 | ko/en/ja 긴 문구, keyboard focus, VoiceOver, 큰 글자/대비 | PENDING |
| UI06 | Inspector와 명시적 clipboard 분석, 자동 감시 없음 | PENDING |
| F01 | disposable fixture에서 Rename → History → Undo 실제 흐름 | PENDING |
| F02 | TCC 거절/허용, 읽기 전용 위치 오류 격리 | PENDING |
| F03 | 외장/SMB/FileProvider에서 미지원 mutation 차단 | PENDING |
| J01 | transaction 중 강제 종료 후 Recovery 표시/보존 | PENDING |
| J02 | 종료·sleep/resume·두 인스턴스에서 중복 mutation 차단 | PENDING |
| OS01 | Finder Services, Dock, Open With 입력이 같은 안전 흐름 사용 | PENDING |
| P01 | 실제 100k 목록 scroll/search/filter/cancel 응답성 | PENDING |
| PK01 | 실제 macOS 14 Apple Silicon에서 picker → rename → undo | PENDING |
| PK02 | 새 current-source Developer ID + notarized package를 깨끗한 Mac에서 설치/실행 | BLOCKED_BY_RELEASE |
| EX-M01 | 메뉴바/Finder Services/최근 입력과 상태 | PENDING |
| EX-M02 | 로그인 실행/완료 알림의 실제 OS 승인·거절 | PENDING |
| EX-M03 | 규칙/CSV/감시 UI keyboard·VoiceOver | PENDING |
| EX-M04 | 다양한 창 크기 실제 resize와 정보 접근 | PENDING |
| EX-M05 | 사용자가 허용한 실제 미디어 metadata/timezone | PENDING |
| EX-M06 | sleep/restart/권한 철회/감시 위치 변경 | PENDING |
| V1-01 | Preview 이후 다른 앱 저장/이동 시 중단 안내 | PENDING |
| V1-02 | 복구 위치 Finder 열기/경로 복사와 긴 ko/en/ja 문구 | PENDING |
| V1-03 | Release 설정의 Free/Pro 미제공 상태가 실제 공급자 상태와 일치 | BLOCKED_BY_PAID_PROVIDER |

실제 업무 원본이 아닌 disposable fixture/복사본에서 mutation QA를 먼저 수행한다. User QA 결과는 사용자가 말한 PASS/FAIL을 그대로 기록하고 실패가 제품 수정 Task의 근원이 되면 STATUS에 bug로 올린다.

## 문서/도구 검증

문서 변경 후:
~~~sh
python3 tools/doccheck.py
python3 tools/doccheck.py --git
git diff --check
~~~

eng/write-qa-report.py의 오래된 Phase0~5 보고서는 현재 SSOT가 아니라 재현 가능한 로컬 evidence 생성 도구다. 출력은 artifacts/evidence 아래에 두며 docs/를 덮어쓰지 않는다.
