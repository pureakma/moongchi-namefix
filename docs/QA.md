# 검증과 User QA

## 두 종류의 검증

Engineering Verification은 AI/자동화가 수행하는 build, test, runtime fixture, render, performance, security/contract 검사다.

User QA는 사용자가 실제 앱을 조작하고 판단한 결과다. AI가 캡처를 보거나 off-screen render를 확인해도 User QA PASS로 기록하지 않는다.

## 검증 범위 규칙

Task의 검증 범위는 변경 영역 + 변경 계약 + 그 소비자 + 무효화된 기존 PASS 근거에서 결정한다. 작은 변경마다 전체 regression, clean build, package를 반복하지 않는다.

.ai/validation-cache.json은 source/test/dependency/toolchain/environment fingerprint와 evidence path를 기록하는 검증 영수증이다. evidence가 Git에 없거나 해당 fingerprint가 달라졌으면 과거 PASS를 현재 PASS로 확대하지 않는다.

## 현재 source의 Engineering Verification 상태

2026-10-06 출시 전 코드 정리·성능 최적화(T-004)의 통합 Engineering Gate 결과다. 영수증은 .ai/validation-cache.json의 MAC-OPTIMIZATION-GATE-20261006, 로컬 evidence는 artifacts/development/optimization이다. 이 Gate가 이전 MAC-RELEASE-READINESS-20261006과 MAC-FIRST-USE-UX-20261006을 대체한다.

| 항목 | 명령 | 결과 |
|---|---|---|
| Runtime·UI model·Core test | eng/test.sh --level 3 --scope all (성능 프로파일 4종 포함) | 112개 실행, 실패 0 (통합 53, UI model 39, Core 20) |
| 리소스 | eng/resources.py; eng/validate-resources.py | 491 keys × ko/en/ja, 재생성 diff 0 PASS |
| CLI | eng/build-cli.sh debug + eng/test-expansion-cli.py; eng/build-cli.sh release + eng/test-release-cli.py | Debug: dry-run/JSON, non-TTY 거부, TTY 확인 rename/undo PASS. Release: raw JSON/dry-run/freshness, non-TTY 거부, source hash 불변 PASS |
| Debug build | eng/build.sh --configuration Debug --arch arm64 | BUILD SUCCEEDED |
| Release 구성 build | eng/build.sh --configuration Release --arch arm64 | BUILD SUCCEEDED, arm64, 리소스 self-test PASS. render·진단 fixture와 그 실행 flag가 binary에 없음을 확인. 배포 후보 생성·서명·패키징은 하지 않음 |
| 대표 화면·fixture (Debug) | --render-ux, --render-shell, --render-expansion(±--native-sidebar), --render-responsive | 242장 생성, assertion PASS |
| 창 동작 진단 | --diagnose-window; Debug 전용 --live-sidebar-check | 상태 전이, band drag 영역, 가로 스크롤 막대 없음 PASS |
| 성능 프로파일 (Debug) | NAMEFIX_PERFORMANCE=1, NAMEFIX_EXPANSION_PERF=1, NAMEFIX_MUTATION_PERF=1 | 10,000건 scan+rule Preview+plan 중앙값 2.174초 · p95 2.210초(직전 2.221 · 2.225), 100,000건 scan 3.02초(직전 3.10), 단독 실행 peak 약 116 MiB, 1,000건 실제 mutation 31.2초(durable journal 유지). 이 경로의 코드는 바꾸지 않았고 수치는 오차 범위 안에서 같다 |
| 대량 목록 조작 (Debug, 100,000행) | NAMEFIX_UI_PERF=1 testLargeListInteractionProfile | 아래 표 |
| 시작·유휴 (Release 구성) | 실행 후 첫 창까지 3회, 그 뒤 30초 관찰 | 첫 창 0.57~0.59초(중앙값 0.575초), 유휴 30초 동안 CPU 시간 0.007초(평균 0.02%), footprint 약 43 MiB |

대량 목록 조작 시간(100,000행, 같은 장비·같은 Debug test build, 최적화 전 → 후). 목록 계산은 main thread 밖에서 돌며, 아래는 조작부터 새 목록이 게시될 때까지다.

| 조작 | 전 | 후 |
|---|---|---|
| 필터 바꾸기(정리할 이름) | 0.29초 | 0.05초 |
| 필터 풀기 | 0.42초 | 0.06초 |
| 검색(입력 지연 0.18초 포함) | 1.57초 | 0.65~0.69초 |
| 검색 지우기(입력 지연 포함) | 0.62초 | 0.27초 |
| 폴더 트리 선택 | 0.10초 | 0.06초 |
| 폴더 선택 풀기 | 0.42초 | 0.06초 |
| 정렬: 이름 | 0.44초 | 0.29초 |
| 정렬: 경로 | 1.08초 | 0.83초 |
| 정렬: 상태 | 1.41초 | 0.70초 |
| 전체 선택(main thread) | 0.064초 | 0.064초 (변화 없음) |
| 선택 200회 | 0.001초 | 0.001초 (변화 없음) |

바꾼 것: 정렬 순서를 목록·정렬 기준이 바뀔 때만 계산해 필터·검색이 재사용한다. 정렬 key를 비교마다가 아니라 한 번만 만든다. 글자 검색은 여러 조각으로 나눠 병렬로 돌리고, 경로에 이미 들어 있는 이름을 따로 한 번 더 검색하지 않는다. Release 구성의 수치와 실제 화면 scroll 체감은 측정하지 않았다.

유휴 상태 확인: 반복 timer·polling·상시 animation이 없다. 1초 주기 갱신은 작업 중 경과 시간 표시뿐이고, 폴더 감시(FSEvents)는 사용자가 ‘폴더 자동 감시’에 등록한 폴더에만 걸린다. 최근 폴더 기록은 감시를 시작하지 않는다.

코드 정리: Swift product source 48개 파일 유지, 6,270 → 6,387줄(아이콘 전용 control의 이름 label 약 +95, 목록 갱신 재구성 약 +45, 제거 약 −50). 제거한 것은 쓰지 않는 문자열 91개(580 → 489 keys), 예전 hero 화면용 테마 값과 button style, 쓰지 않는 model 상태 1개, 화면에서 열 수 없는 sheet 2종과 그 전용 코드, test만 쓰던 layout helper. render·진단 fixture 5개 파일은 Debug build에서만 compile한다. 새 파일·새 의존성은 없다.

재사용한 기존 근거와 한계:
- MAC-V1-APFS-CASE-SENSITIVE(대소문자 구분 APFS 볼륨)는 다시 실행하지 않았다. Infrastructure/Application/Core source는 이번에 바뀌지 않았다.
- UI test bundle(xcodebuild build-for-testing)은 다시 build하지 않았다. 직전 변경은 실행 인자 한 줄이다.
- MAC-V1-SOURCE-RACE-LIMITATION은 KNOWN_LIMITATION, MAC-V1-NOTARIZATION과 MAC-V1-PAID-PROVIDER는 BLOCKED_EXTERNAL로 유지한다.
- macOS 14 실기의 대량 목록 성능과 실제 scroll 체감은 User QA U10/U11에서 확인한다.
- Core의 DevelopmentEntitlementProvider는 쓰이지 않지만 Core 계약 파일이라 이번 정리에서 건드리지 않았다. eng/build-cli.sh는 실행 권한이 없어 bash로 실행했다.

과거 build3 Release 후보의 서명·패키지 검증은 현재 source의 근거가 아니다. 경쟁 제품 대비 속도로 확대하지 않는다.

## First-use UX 구조 단순화 검증 (T-003)

2026-10-06 화면 구조 재설계와 그 뒤 사용자 지시(전 기능 무료, UI 구조 재설계 2차: 입력 상태를 따르는 왼쪽 영역, 창 chrome과 앱 이름, 전체 band drag, 일괄 변경 2-pane)를 반영한 뒤의 Engineering Verification이다. 영수증은 MAC-FIRST-USE-UX-20261006, 로컬 evidence는 artifacts/development/ui-structure-2다.

| 항목 | 명령 | 결과 |
|---|---|---|
| UI model test | swift test --filter UIModelTests | 38개, 실패 0 (sidebar 상태·폭 규칙, 시작 화면, 비어 있는 시작 규칙이 적용·저장에서 빠지는지 포함) |
| Debug build | eng/build.sh --configuration Debug --arch arm64 | BUILD SUCCEEDED |
| UI test bundle | xcodebuild build-for-testing | TEST BUILD SUCCEEDED (실행은 하지 않음) |
| 리소스 | eng/resources.py; eng/validate-resources.py | 521 keys × ko/en/ja, 재생성 diff 0 PASS |
| 창 동작 진단 | --diagnose-window (보이지 않는 창) | 입력 없음 → navigation 208pt, 폴더 추가 → 레일 + 트리 268pt, 모두 닫기 → navigation 복귀, 좁은 창 → 숨김, 다시 넓히면 복귀. band의 왼쪽·가운데·오른쪽 표본이 모두 drag 대상이고, band 아래에 SwiftUI hosting view가 없으며, 결과 목록의 가로 스크롤 막대가 꺼져 있음 PASS |
| 실제 창 확인 | Debug 전용 --live-sidebar-check (키·마우스 입력 합성 없음) | 실제 화면의 창에서 같은 상태 전이와 band 판정 PASS. 수정 전에는 창의 시스템 drag 영역이 비어 있었고(hosting view가 band 밑까지 깔려 창 전체가 ‘이동을 막는 영역’으로 계산됨), 수정 후에는 drag 영역이 설정됨 |
| 대표 화면 | --render-ux | 47장: 입력 없음, 결과, 충돌, 일괄 변경(파일 없음·규칙 없음·규칙 1개·규칙 편집·stale), 규칙 추가 popover, 고급 sheet, 좁은 창, 소개 4쪽(어두운 테마에서도 밝게), 사용 방법, 설정과 개발자 카드, 레일 hover label, 적용 예시 두 상태, ko/en/ja, Olive·Dark·Light |
| 기존 render fixture | --render-shell, --render-expansion(±--native-sidebar), --render-responsive | 195장 생성, assertion PASS |
| 앱 아이콘 | eng/icon.swift → eng/build.sh, 빌드한 앱을 시스템 아이콘 API(NSWorkspace)로 그려 비교 | macOS 27에서 이전 비트맵 아이콘은 회색 판 안에 축소되어 그려졌고, Icon Composer 문서(Resources/AppIcon.icon)로 바꾼 뒤 판 없이 꽉 찬 모양으로 그려짐. Dock 스크린샷에서 아이콘 외곽은 옆 아이콘과 같은 78px였고, 작아 보인 것은 그림의 남색 여백 때문이라 그림을 1.12배로 키움. Dock·Finder의 실제 표시는 U16 |

이번 2차 변경은 App UI와 문구에 한정된다. Core/Application/Infrastructure/CLI는 바꾸지 않았으므로 runtime·transaction·filesystem·CLI test는 다시 실행하지 않았고, 직전 실행(108개 중 runtime 53·core 20 통과, CLI PASS)을 그대로 쓴다.

AI가 직접 본 화면 평가(User QA가 아니다): 입력이 없으면 이름이 있는 navigation과 빈 상태만 보인다. 추가하면 레일과 트리로 바뀌고 표가 중심이 된다. 일괄 변경은 ‘변경 규칙’과 ‘미리보기’ header가 같은 선에서 시작하고, stale 상태에서도 표 위치가 변하지 않는다. popover와 sheet는 별도 창이라 내용만 따로 렌더해 확인했다.

확인하지 못한 것: 실제 마우스로 band를 끌었을 때 창이 움직이는지(클릭이 drag 대상 view에 도달하는지까지만 측정), tooltip 표시, popover가 버튼에 붙어 열리는 모습, 트리 폭 드래그와 기억, 상태 전환 시의 깜빡임 여부. 아래 화면 확인에 넣었다.

사용자 보고(2026-10-06) 처리: “상단 드래그가 되다 말다 함”은 content view가 클릭을 받는 구간 전체에 drag strip을 두어 해결했다. “폴더를 선택하니 사이드 패널이 사라짐”은 재현하지 못했으며, 구분선으로 접히지 않게 하고 render fixture가 저장 상태를 쓰지 않게 한 뒤 왼쪽 영역을 입력 상태 기반으로 다시 만들었다. 사용자의 재확인이 필요하다.

사용자 보고(2026-10-06, 2차) 처리: “band 가운데 구간만 drag가 안 됨”은 위 측정으로 원인을 확인하고 구조를 고쳤다(실제 마우스 확인은 S1). “열고 나서 닫는 방법이 없음”은 트리 제목 줄의 모두 닫기 버튼, 항목별 닫기, 파일 메뉴 항목으로 해결했다. 신호등과 앱 이름 사이 간격을 넓혔고, 결과 목록의 가로 스크롤 막대를 껐고, 하단 상태 표시줄을 도입했다(D-017). 앱 아이콘은 위 ‘앱 아이콘’ 행의 수정으로 해결되며 앱을 다시 실행해야 보인다.

사용자 보고(2026-10-06, 3차) 처리: band drag는 사용자가 잘 된다고 확인했다. 상태 표시줄은 없애고 내용을 맨 아래 줄 왼쪽으로 옮겼다(D-018). 설정 첫 묶음의 ‘표시’ 제목과 아이콘을 지우고 Mac 연동의 switch를 오른쪽 끝으로 맞췄다. 사용 방법 화면을 다시 만들고, 첫 실행 소개(D-019)와 설정 맨 아래 개발자 카드를 추가했다. 개발자 카드의 웹사이트·문의 주소는 값이 정해지지 않아 비어 있다(사용자 입력 대기).

사용자 보고(2026-10-06, 4차) 처리: 앱이 항상 자소 분리 해결 화면에서 시작한다(D-020, 관련 test 2개를 새 동작에 맞게 고침). 파일 이름 일괄 변경은 ‘텍스트 바꾸기’ 규칙이 펼쳐진 채 시작하고, 비어 있는 규칙은 적용에서 빠진다. ‘미리보기’ 제목과 ‘미리보기 갱신’ 버튼을 없애고 ‘업데이트 필요’ chip을 요약 chip 앞에 같은 크기로 두어 그 chip이 갱신 버튼을 겸한다. chip·검색·메뉴는 한 줄이다. 아래 알림은 짧은 요약으로 보이고 누르면 전체 문구가 나온다.

사용자 보고(2026-10-06, 5차) 처리: 규칙 아래 ‘예시’가 바뀌지 않는 이름을 그대로 보여 주던 것을, 실제로 바뀌는 이름만 보여 주도록 고쳤다(겉모양이 같은 자소 합침만 일어난 경우도 예시로 쓰지 않는다). 레일 아이콘의 메뉴 이름이 pointer를 올려도 나오지 않는다는 보고는, 시스템 tooltip이 뜨지 않는 원인을 확인하지 못한 채 이름 label을 직접 그리는 방식으로 바꿨다. 다른 곳의 시스템 tooltip(⊗ 모두 닫기, toolbar 버튼)이 뜨는지는 사용자 확인이 필요하다.

사용자 확인(2026-10-06, 6차): 레일 아이콘 hover label PASS, 이름 일괄 변경의 ‘적용 예시’ PASS. 트리 제목 ⊗의 tooltip FAIL, band 오른쪽 저장·다시 검사·추가 버튼의 tooltip FAIL(둘 다 시스템 tooltip이 나타나지 않음). 조사 결과 toolbar item에는 시스템 tooltip이 정상 등록돼 있었고, 그 위치에 다른 창이 겹쳐 있지 않았으며, 앱이 event를 가로채는 코드도 없었다. pointer를 직접 올려 재현할 수 없어 시스템 tooltip이 뜨지 않는 원인은 확인하지 못했다. 대신 아이콘만 있는 control 전체에 앱이 직접 그리는 이름 label을 적용했다(docs/DESIGN.md ‘아이콘만 있는 control의 이름 표시’). 이 수정의 실제 hover 동작은 사용자 재확인 대상이다.

사용자 보고(2026-10-06, 7차) 처리: 트리가 보이는데도 목록 위에 나오던 ‘… 안의 항목만 표시 중 · 전체 보기’ 줄을 트리가 숨은 좁은 창에서만 나오게 했다. ‘추가한 파일·폴더 N개’ 줄이 주변보다 굵고 커 보이던 것을 같은 글자 크기·굵기로 맞췄다.

사용자 지시(2026-10-06, 8차) 처리: 설정 맨 아래 카드를 개발사 소개로 바꿨다. 로고는 AILO, ‘개발’ 문구는 ‘기획 · 설계 · 개발’ 표제와 소개 문장으로, 뭉치 웹사이트(https://moongchi.ailoworks.com) 소개와 링크를 추가했다. 웹사이트 소개 문구는 실제 사이트 내용을 확인해 썼다. 버그 신고·문의 주소는 아직 없어 그 줄은 나오지 않는다. 개발사 이름은 사용자 확인에 따라 AILO WORKS로 적는다.


## User QA — 한 번에 확인할 목록

### 지금 확인할 다섯 가지 (T-004 종료 시점)

자동 검증으로 대신할 수 없는 것만 추렸다. 사용자가 이미 PASS한 레일 hover label과 ‘적용 예시’, band drag는 다시 묻지 않는다.

| 번호 | 확인할 것 | 결과 |
|---|---|---|
| Q1 | 폴더를 넣은 뒤 트리 제목 줄의 ⊗에 pointer를 올리면 ‘모두 닫기’가 바로 옆에 나오는가 | PENDING |
| Q2 | 오른쪽 위 저장·다시 검사·추가 버튼에 pointer를 올리면 각 이름이 나오는가. 세 버튼이 이전처럼 눌리고, 추가(+)는 메뉴가 열리는가 | PENDING |
| Q3 | 그 밖의 아이콘 전용 control(목록 옵션 ⋯, 추가 항목의 ×, 규칙 초기화 휴지통, 규칙 줄 ⋯)에서도 같은 모양의 이름이 나오고, 누르거나 벗어나면 사라지는가 | PENDING |
| Q4 | 실제로 쓰는 큰 폴더에서 검색·필터·정렬·스크롤이 답답하지 않은가 | PENDING |
| Q5 | Dock·⌘Tab의 앱 아이콘 크기와 첫 실행 소개(‘다시 보지 않기’ 포함)가 의도대로인가 | PENDING |


실제 업무 원본이 아닌 복사본 폴더에서 진행한다. 결과는 사용자가 말한 PASS/FAIL을 그대로 기록하고, 실패가 제품 수정의 근원이 되면 STATUS에 bug Task로 올린다.

먼저 화면 구조를 아래 다섯 화면으로 확인한다. 이 다섯 개가 승인돼야 나머지 항목이 의미가 있다.

| 화면 | 볼 것 |
|---|---|
| S1 입력 없는 첫 화면 | 왼쪽 메뉴가 이름과 함께 읽히는가. 앱 이름 NameFix의 존재감, 신호등과의 간격, 화면 제목 배치가 자연스러운가. band 왼쪽·가운데·오른쪽 어디를 잡아도 창이 움직이는가(2026-10-06 사용자 확인: 잘 됨). 처음 열 때 소개가 나오고 ‘다시 보지 않기’가 동작하는가 |
| S2 폴더를 넣은 뒤 | 메뉴가 아이콘 레일로 줄고 트리가 나오는가. 트리 제목 줄의 ⊗(모두 닫기)로 첫 화면에 돌아오는가. 왼쪽 경계선이 title bar 아래 선과 둥글게 이어져 보이는가. 목록 아래에 가로 스크롤 막대가 없는가. 개수·진행 상황·알림이 실행 버튼 왼쪽에서 읽기 편한가 |
| S3 파일 이름 일괄 변경 — 규칙 없음 | ‘변경 규칙’과 오른쪽 목록 위 한 줄이 같은 선에서 시작하는가. ‘텍스트 바꾸기’가 펼쳐진 채 시작하는 것이 자연스러운가. ‘+ 규칙 추가’ popover에서 기본·고급을 고르기 쉬운가 |
| S4 규칙 추가·수정 후 | 규칙 줄 요약과 펼친 편집이 충분한가. 맨 앞의 ‘업데이트 필요’ chip이 눈에 띄고, 누르면 목록이 갱신된다는 것이 바로 읽히는가. 아래 알림이 짧게 보이고 누르면 전체 문구가 나오는가 |
| S5 고급 설정 sheet와 좁힌 창 | 글자 저장 형식·CSV 목록·프리셋 sheet가 과하지 않은가. 창을 좁혔을 때 정보가 과밀하지 않은가 |

| ID | 확인 항목 | 현재 상태 |
|---|---|---|
| U01 | 기본 흐름: 파일·폴더 추가(선택 창, 창 전체 drag & drop) → 검사 → 변경 전후 이름 확인 → 확인 시트 → 이름 바꾸기 → 결과 → 작업 기록 → 되돌리기 | PENDING |
| U02 | 처음 보는 사용자 기준으로 화면 문구가 설명 없이 이해되는지: 상태(글자 분리됨 등), 확인 시트, 사용 방법, 오류 안내 | PENDING |
| U03 | 테마 4종과 ko/en/ja 전환이 즉시 적용·저장되고 재실행 후 유지되는지, 주요 화면에서 글자가 잘리지 않는지 | PENDING |
| U04 | 창 크기 조절(좁게/넓게/낮게), 좁은 창에서 왼쪽 영역 자동 숨김, 트리 폭 조절과 기억, 전체 화면, 재실행 후 창 위치 복원 | PENDING |
| U05 | 키보드만으로 조작: Tab 이동, Space 선택, ⌘O/⇧⌘O/⌘F/⌘R/⌘1/⌘2/⌘,/⌘W/⌘M/⌘H, 확인 시트의 Return/Esc | PENDING |
| U06 | VoiceOver로 목록·버튼·상태 읽기, 대비 증가·큰 글자 설정에서 가독성 | PENDING |
| U07 | 글자 구성 자세히 보기, 복사한 글자 변환(자동 감시 없음) | PENDING |
| U08 | 데스크탑/문서/다운로드 폴더 권한 안내가 앱 언어로 나오는지, 거절·허용, 읽기 전용 위치·외장/SMB/iCloud 항목의 변경 차단 표시 | PENDING |
| U09 | 중단과 복구: 작업 중 취소(처리 중 항목까지 마치고 멈춤), 강제 종료 후 재실행 안내와 복구, 다른 앱이 같은 파일을 저장·이동할 때 중단 안내, 앱 두 번 실행 시 중복 변경 차단 | PENDING |
| U10 | 대량 목록(약 100,000개) 검사·스크롤·검색·필터·취소 응답성 | PENDING |
| U11 | 실제 macOS 14 Apple Silicon에서 U01과 U10 | PENDING |
| U12 | Finder 서비스, Dock/다음으로 열기, 메뉴바 아이콘 drop·메뉴, 로그인 시 실행, 완료 알림의 실제 OS 승인·거절 | PENDING |
| U13 | 고급 기능 흐름: 패턴·조건 규칙, 프리셋 저장·불러오기, CSV 목록, 파일 정보(실제 사진/음악/영상), 묶음 파일, 폴더 자동 감시(잠자기·재시작·권한 철회 포함) | PENDING |
| U14 | 새 current-source 서명·공증 패키지를 깨끗한 Mac에 설치·실행 | BLOCKED_BY_RELEASE |
| U15 | 화면 어디에도 Pro·구매 표시가 없고 모든 기능이 바로 동작하는지 | PENDING |
| U16 | Dock·Finder·앱 전환기(⌘Tab)에서 앱 아이콘이 회색 판 없이 다른 앱과 같은 크기로 보이는지 | PENDING |
| U17 | 첫 실행 소개: 4쪽 내용과 그림, 어두운 테마에서도 밝게 보이는지, ‘다시 보지 않기’ 후 다시 실행하면 안 나오는지, 설정·도움말 메뉴에서 다시 열리는지 | PENDING |
| U18 | 사용 방법 화면과 설정(제목 없는 첫 묶음, 오른쪽 정렬 switch, 맨 아래 개발자 카드)의 모양 | PENDING |

## 문서/도구 검증

문서 변경 후:
~~~sh
python3 tools/doccheck.py
python3 tools/doccheck.py --git
git diff --check
~~~

eng/write-qa-report.py의 오래된 Phase0~5 보고서는 현재 SSOT가 아니라 재현 가능한 로컬 evidence 생성 도구다. 출력은 artifacts/evidence 아래에 두며 docs/를 덮어쓰지 않는다.
