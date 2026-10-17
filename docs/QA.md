# 검증과 User QA

## 두 종류의 검증

Engineering Verification은 AI/자동화가 수행하는 build, test, runtime fixture, render, performance, security/contract 검사다.

User QA는 사용자가 실제 앱을 조작하고 판단한 결과다. AI가 캡처를 보거나 off-screen render를 확인해도 User QA PASS로 기록하지 않는다.

## 검증 범위 규칙

Task의 검증 범위는 변경 영역 + 변경 계약 + 그 소비자 + 무효화된 기존 PASS 근거에서 결정한다. 작은 변경마다 전체 regression, clean build, package를 반복하지 않는다.

.ai/validation-cache.json은 source/test/dependency/toolchain/environment fingerprint와 evidence path를 기록하는 검증 영수증이다. evidence가 Git에 없거나 해당 fingerprint가 달라졌으면 과거 PASS를 현재 PASS로 확대하지 않는다.

## 현재 source의 Engineering Verification 상태

현재 판정: USER_QA_COMPLETE_WITH_EXTERNAL_PENDING (2026-10-07, Final User QA Session, T-010). P0 0건, P1 0건, P2 2건은 의도적으로 남겼다. R1~R4는 사용자 PASS, R5·R7은 PARTIAL, R6은 사용자 결정으로 AI 전체 검수로 대체했다(원어민 확인 아님). 항목별 결과와 세션에서 고친 것은 아래 ‘User QA’의 ‘남은 확인 일곱 가지’에 있다. Release Candidate 단계에 들어갈 수 있고, 사용자가 승인하기 전에는 후보를 만들지 않는다. 세션 뒤 source의 영수증은 .ai/validation-cache.json의 MAC-USER-QA-SESSION-20261007(로컬 evidence artifacts/evidence/user-qa)이다. 그 뒤 공개 배포를 Mac App Store 하나로 줄였고(D-038, T-012) 현재 source의 Engineering 기준은 바로 아래 ‘App Store Only Gate’다.

추가 확인으로 남긴 것(external / additional confidence checks, 현재 기록상 P0·P1 blocker 아님, 실제로 하지 않았음): 케이블을 실제로 뽑는 것(작업 중 포함), 네트워크 드라이브, iCloud Drive, VoiceOver, 대비 증가·큰 글자, 키보드만으로 전체 조작, 영어·일본어 원어민 확인.

### 일반판 패키징 확인 (2026-10-17, T-015)

eng/package-direct.sh를 source e776f8d로 두 번 실행했다(로컬 evidence artifacts/direct/1.0.0). AI가 실행한 Engineering Verification이다.

| 실행 | 결과 |
|---|---|
| 공증 프로필과 함께 (build6) | archive와 Developer ID 서명 성공(Hardened Runtime, secure timestamp, arm64만, entitlement 셋, 확인용 코드 문자열 0건). 앱 공증 제출이 HTTP 401(인증 정보 거절)로 멈춤 |
| 공증 없이, 나머지 단계 확인용 (check-unnotarized) | DMG(HFS+, 압축)·ZIP·SHA256SUMS·BUILD_INFO 생성, DMG도 Developer ID 서명. Gatekeeper는 앱과 DMG 모두 ‘Unnotarized Developer ID’로 거절(공증 전이라 예상대로), forDownload false |

아직 하지 않은 것: 공증과 스테이플링, 공증된 DMG를 다른 Mac에서 내려받아 여는 것.

### 메뉴 막대 아이콘 제거 (2026-10-13, T-014)

영수증 MAC-MENUBAR-REMOVAL-20261013, 로컬 evidence artifacts/evidence/menubar-removal. 바뀐 것은 App의 세 파일(MacIntegration, Main, Sheets)과 문구 셋의 삭제다(D-041). 영향받는 것만 다시 실행했다. Infrastructure·Application·Core와 그 test는 바뀌지 않아 아래 T-013 Gate의 결과(통합·Core test, 일회용 volume, sandbox 밖 회귀, 스토어 문구)를 그대로 쓴다. AI가 실행한 Engineering Verification이다.

| 항목 | 명령 | 결과 |
|---|---|---|
| UI model test | eng/test.sh --scope ui-model | 16개 실행, 실패 0 (1 skip) |
| 실제 App Sandbox | eng/test-sandbox.py | 18개 PASS(실제 창의 시트·설정·앱 메뉴 시나리오 포함) |
| 리소스 | eng/validate-resources.py | 568 keys × ko/en/ja PASS(문구 셋 삭제) |
| AppStore build·archive preflight | eng/build.sh --configuration AppStore; eng/archive-store.sh --preflight | 둘 다 성공. arm64만, entitlement 셋, 확인용 코드 문자열 0건, 메뉴 막대 항목 API(NSStatusItem) 참조 0건 |
| 대표 화면 | --render-ux, --render-shell, --render-responsive, --render-expansion | 238장(79+51+75+33), assertion PASS. 설정 화면의 ‘Mac 연동’ 구역은 대표 화면에 잡히지 않아 눈으로 보지 못했다 |

하지 않은 것: 실제로 앱을 띄워 메뉴 막대와 설정의 ‘Mac 연동’ 구역을 눈으로 보는 것. 대신 확인한 것: source에 상태 항목과 그 설정 행이 없음, archive의 binary에 NSStatusBar·NSStatusItem 참조와 NameFix.MenuBar 문자열이 없음, bundle의 문구 파일에 삭제한 세 key가 없음.

### 출시 전 코드 리뷰와 그 수정 (2026-10-13, T-013) — 현재 값

영수증 MAC-PRERELEASE-REREVIEW-GATE-20261013(재리뷰 뒤의 현재 값)과 MAC-PRERELEASE-REVIEW-GATE-20261013(첫 리뷰 뒤), 로컬 evidence artifacts/evidence/prerelease-review. 이 대화의 맥락을 모르는 리뷰어 셋이 2026-10-07 이후 바뀐 source를 읽기 전용으로 리뷰했다(폴더 접근 규칙, 작업 기록과 빠른 방식, 결과 목록과 화면 동작). P0는 없었다. 지적된 것을 고친 뒤 그 수정 자체를 새 리뷰어 둘이 다시 리뷰했고(P0·P1 없음, P2만), 그 지적도 고친 뒤 아래 Gate를 현재 source에서 다시 실행했다. 표의 값은 재리뷰 수정 뒤의 값이다. AI가 실행한 Engineering Verification이다.

| 항목 | 명령 | 결과 |
|---|---|---|
| Runtime·UI model·Core test | eng/test.sh --level 3 | 161개 실행, 실패 0 (통합 78 중 11 skip, UI model 54 중 1 skip, Core 29) |
| 일회용 volume | eng/test-volumes.py | APFS, 대소문자 구분 APFS, exFAT, FAT32 PASS |
| 실제 App Sandbox | eng/test-sandbox.py | 18개 PASS. 첫 리뷰 뒤 확인한 것: 이름이 합침형으로 저장된 폴더 안의 파일(경로는 분리형으로 도착함)을 폴더 선택 뒤 이름 변경, exFAT 위의 추가한 폴더는 ‘드라이브 제외’, 목록의 전체 선택과 Return으로 자세히 보기. 재리뷰 뒤 더한 것은 아래 ‘사람 대신 앱 안에서 확인한 것’ |
| sandbox 밖 회귀(제품 gate 아님) | eng/test-sandbox.py --direct | 17개 PASS(실제 폴더 선택 창 시나리오는 sandbox에서만 실행) |
| 리소스·스토어 문구 | eng/validate-resources.py; eng/validate-marketing.py | 571 keys × ko/en/ja PASS, 스토어 문구 PASS |
| AppStore build·archive preflight | eng/build.sh --configuration AppStore; eng/archive-store.sh --preflight | 둘 다 성공. arm64만, entitlement 셋, 확인용 코드 문자열 0건 |
| 대표 화면 | --render-ux, --render-shell, --render-responsive, --render-expansion | 238장(79+51+75+33), assertion PASS. 여러 문자의 이름(emoji, 태국어, 데바나가리, 아랍어, 옛 글자체 한자)이 목록에 그려지는 것과 ‘상위 폴더 선택…’ 버튼을 직접 확인 |

리뷰 지적과 처리(P0 0, P1 2, 나머지 P2):

| 지적 | 처리 |
|---|---|
| P1: 빠른 방식이 작업 기록의 volume을 보지 않음. 파일과 기록이 다른 드라이브면 전원 차단 시 임시 이름으로 남고 기록에 없을 수 있음 | 수정: 내장 드라이브이고 기록과 같은 volume일 때만 빠른 방식(D-036 보완). test 추가 |
| P1: 따로 넘겨받은 파일의 폴더 경로가 허용한 폴더와 글자 표기가 다르면 ‘다른 폴더를 선택했습니다’가 반복됨. 리뷰는 추정으로 냈고, 실제 sandbox에서 경로가 분리형으로 도착하는 것을 확인함 | 수정: 시스템이 알려 주는 경로로 다시 적음. model test와 실제 sandbox 시나리오 추가 |
| 끝이 끊긴 기록 하나가 모든 Undo를 막고 풀 방법이 없음 | 수정: 유실된 끝으로 읽음(D-040). 손상은 이전처럼 차단. test 교체·추가 |
| 다른 안내가 떠 있거나 안내를 닫으면 폴더 선택 버튼이 없음 | 수정: 버튼이 항목의 상태를 따름 |
| 지원하지 않는 드라이브의 폴더가 ‘상위 폴더 선택 필요’로 나옴 | 수정: 드라이브 사유가 먼저. 실제 sandbox의 exFAT 시나리오로 확인 |
| 추가한 폴더를 Finder에서 이름을 바꾸면 ‘폴더 선택 필요’인데 버튼이 무반응. 같은 이름을 이어받은 폴더가 상위 허용으로도 안 열림 | 수정: ‘지금 접근할 수 없음’으로 구분하고, 옮겨진 허용은 건너뜀. test 추가 |
| 되돌리기용 요청에서 다른 폴더를 받아 두고 창이 반복됨 | 수정: 닿지 못하면 받지 않음. test 추가 |
| 기록을 못 읽고 시작하면 남겨 둔 접근이 지워짐 | 수정: 읽은 뒤에만 정리. test 추가 |
| 접근 hold가 늦게 풀리거나 안 풀림(같은 폴더 두 번 추가, 줄 하나씩 제거, 되돌리기 반복, 감시 재시작 사이의 틈, 같은 자리의 다른 폴더) | 수정: 한 번만 잡고, 목록에서 빠지면 돌려주고, 감시는 새로 잡은 뒤 놓음 |
| 확정 실패 뒤 다음 기록의 순번이 겹침 | 수정: 줄을 쓴 시점에 순번을 올림 |
| 목록: ⌘A가 꺼져 있을 수 있음, Return과 키보드 메뉴로 자세히 보기 불가, 빈 곳·열 제목·체크 상자 더블클릭에 자세히 보기가 열림 | 수정. 실제 앱에서 전체 선택과 Return 동작 확인 |
| 목록: 앱 글꼴이 아님, 조각이 옆 칸으로 넘칠 수 있음, 키 큰 문자가 잘릴 수 있음, 설명이 칸 전체에 하나, VoiceOver에 칸으로 안 잡힐 수 있음 | 수정: 앱 글꼴, 칸 안으로 자르기, 줄 높이 여유, 조각별 설명, 칸 역할 유지. 화면으로 확인(VoiceOver 읽기는 미확인) |
| ‘선택한 항목만’에서 체크를 풀면 키보드 위치를 잃음 | 수정: 그 자리의 줄에 남음 |
| 폴더만 넣으면 ‘폴더 이름도 변경’ 안내가 안 나옴, 일본어 입력 중 Tab이 후보 선택을 가로챔 | 수정 |
| 폴더 트리 더블클릭에 필터가 켜졌다 꺼짐 | 수정: 선택된 채로 남음 |
| 빠른 방식 안내가 외장 드라이브 작업 뒤에도 뜨고, 다른 안내에 덮여도 봤다고 기록됨 | 수정 |
| 성능: 100,000줄에서 목록 갱신이 느릴 것이라는 추정 | 수정 없음. 개발용 Mac에서 잰 값이 0.05초이므로 통과 |
| 온전히 쓰였지만 틀린 기록(디스크 손상 등)을 사용자가 치울 방법이 없음 | 수정 없음. 새 기능이 필요하고 드문 경우라 남김(P2) |

재리뷰 지적과 처리(첫 수정을 다시 리뷰. P0 0, P1 0, 모두 P2):

| 지적 | 처리 |
|---|---|
| 남겨 둔 접근(즐겨찾기·감시·최근 폴더)을 다시 쓸 때 글자 표기 보정이 빠져, 이름이 합침형인 폴더 안의 파일은 이미 허용한 폴더를 또 물음 | 수정: 시스템이 알려 주는 표기로도 닿는지 본다. 실제 sandbox의 즐겨찾기 시나리오를 합침형 한글·라틴 이름 폴더로 바꿔 확인 |
| 되돌릴 기록의 폴더가 그 뒤 대소문자·글자 조합만 바뀌었으면, 맞는 폴더를 골라도 받아 두고 같은 창이 끝없이 다시 뜸 | 수정: 기록은 폴더를 바이트 그대로 가리키므로 그 자리가 아니면 받지 않고 ‘지금 접근할 수 없음’으로 한 번 알린다. test 추가 |
| 받지 않기로 한 폴더가, 옮겨진 허용이 남아 있던 자리에서는 돌려줘도 등록부에 남음 | 수정: 원하는 폴더인지 확인한 뒤에만 등록하고, 아니면 그 자리를 이전 그대로 되돌린다. test 추가 |
| 같은 폴더를 다시 허용할 때 죽은 연결(드라이브를 뽑았다 다시 꽂음)을 계속 씀 | 수정: 연결이 더는 그 폴더로 가지 않으면 새로 연 것으로 바꾼다 |
| 옮겨진 허용을 ‘덮고 있는 것’으로 셈: 그 아래 따로 넘겨받은 파일은 폴더를 묻지 않고, 되돌리기는 폴더를 묻지 않고 ‘변경할 것 없음’, 작업 뒤 죽은 허용을 되돌리기용으로 저장 | 수정: 지금 실제로 닿는 허용만 센다(화면의 ‘지금 접근할 수 없음’ 표시는 그대로). test 추가 |
| 기록 한 줄을 쓰다 쓰기가 중간에 실패하면(디스크 가득 참) 뒤따르는 실패 기록이 끊긴 줄에 붙어 기록 전체가 손상으로 읽힘 | 수정: 쓰다 만 줄을 걷어 내고 이어 쓴다. 걷어 내지 못하면 더 쓰지 않는다. 파일 크기 제한으로 실제 중간 실패를 만든 test 추가(수정을 빼면 실패하는 것 확인) |
| 드라이브 자체를 추가했는지 볼 때 mount 지점과 경로를 바이트로만 비교 | 수정: 대소문자·글자 조합을 무시하고 비교 |
| ‘선택한 항목만’에서 포커스 유지가, 방금 체크를 푼 경우가 아니어도(검색, 폴더 변경, 필터를 막 켬) 엉뚱한 줄로 옮겨 감. Space를 누르고 있으면 줄줄이 체크가 풀림 | 수정: 사용자가 그 줄의 체크를 방금 풀었을 때만 그 자리에 남는다. 누르고 있는 Space는 한 번만 동작. 실제 앱에서 키 입력으로 확인 |
| 폴더만 추가했을 때, 규칙이 견본 이름을 바꾸면 견본 예시가 폴더 안내를 가림 | 수정: 폴더만 있으면 견본 대신 안내와 ‘폴더 이름도 변경’ 버튼 |
| 키 큰 문자를 위해 늘린 이름 영역이 효과가 없고, 줄바꿈이 든 이름이 두 줄로 그려져 아래를 덮음 | 수정: 한 줄 높이로 되돌림(키 큰 문자는 원래 잘리지 않음을 재리뷰가 그려서 확인) |
| 한글을 입력하는 중(마지막 글자가 아직 조합 중)에는 Tab이 ‘바꿀 글자’로 가지 않을 수 있음. Caps Lock이 켜져 있어도 같음 | 수정: 조합 중인 글자가 한글뿐이면 Tab이 넘어가고 글자는 남는다. 가나·병음 후보를 고르는 중에는 입력기에 맡긴다. 실제 앱에서 확인(수정 전 판정이었다면 넘어가지 않았을 상황임을 확인) |
| 줄 아래 빈 곳을 우클릭하면 포커스된 줄의 메뉴가 열림. 메뉴가 열린 사이 목록이 바뀌면 다른 줄에 동작 | 수정: 빈 곳에는 메뉴가 없고, 메뉴는 줄 번호가 아니라 항목을 기억 |
| 안내 풍선 안의 폴더 선택 버튼이 작업 중에도 눌림. 남겨 둔 접근으로 이미 닿으면 버튼을 눌러도 변화가 없음 | 수정: 작업 중·확인 창이 열린 동안 비활성, 닿게 되면 다시 검사 |
| Return·키보드 메뉴의 자세히 보기가 이름 변경 중에도 열림 | 수정: 메뉴 명령과 같은 조건을 거침 |
| 조각 줄의 ‘…’, 조각 사이, 첫 조각 왼쪽에 설명이 없음 | 수정: 조각 줄 어디서나 설명이 나옴 |
| 이미 선택된 폴더를 더블클릭하면 두 번의 클릭 사이에 목록이 잠깐 전체로 바뀜 | 수정 없음. 없애려면 폴더 선택 해제를 더블클릭 간격만큼 늦춰야 해서 한 번 클릭이 둔해진다. 끝 상태(선택된 채 펼침·접힘)는 맞다(P2) |
| test가 없는 경로: 그래프 방식·빠른 방식에서의 유실된 끝, 감시 재시작 순서, 줄 하나씩 제거할 때의 반환 | 일부 추가(같은 폴더 두 번 추가 뒤 모두 제거, 내장 volume 둘 사이의 빠른 방식 거부, 자리를 이어받은 허용의 반환 횟수). 나머지는 재리뷰가 코드로 모든 기록·절단 지점을 따져 맞다고 확인했고 test는 추가하지 않음 |

사람 대신 앱 안에서 확인한 것(2026-10-13, 사용자 지시: 필수 요소의 QA를 AI가 대신). 화면 제어(마우스·키보드 조작) 권한은 받지 못했으므로, sandbox 안에서 실행한 Debug 앱이 자기 창을 직접 다루고 보고하는 방식이다. 사람이 누른 것이 아니며 User QA PASS가 아니다.

| 확인 | 방법 | 결과 |
|---|---|---|
| 실제 폴더 선택 창 | sandbox에서 ‘상위 폴더 선택…’과 같은 요청으로 실제 NSOpenPanel을 띄우고 창을 읽은 뒤 취소 | 필요한 폴더에서 열림, 이유 문구와 버튼 이름, 폴더만 선택 가능. 취소 뒤 요청·항목·상태가 그대로. 창 안에서 폴더를 고르는 것은 자동화하지 않음(시스템 창) |
| 목록의 키 | 키 이벤트를 목록의 키 처리에 전달 | Space 체크·해제, 아래 화살표 이동, Return 자세히 보기, 누르고 있는 Space는 한 번, ‘선택한 항목만’에서 체크를 푼 뒤 제자리, 필터를 켜도 포커스 이동 없음 |
| 목록의 접근성 정보 | 보조 앱이 받는 값을 앱 안에서 읽음 | 표(AXTable), 줄 수 = 항목 수, 열 제목, 칸(AXCell)과 그 이름(‘파일, 보고서.txt’)·값(글자 조각), 체크 상자(AXCheckBox)와 그 이름. 첫 리뷰 수정 뒤 칸 역할이 비어 있던 것을 여기서 발견해 고침. VoiceOver로 실제 읽는 것은 하지 않음 |
| 규칙 입력 칸의 Tab | 입력 칸의 편집기에 글자를 넣고 Tab 키 이벤트를 창에 전달 | Tab → 바꿀 글자, Shift-Tab → 찾을 글자, 한글 조합 중 Tab → 바꿀 글자(글자 유지), 가나 조합 중 Tab은 앱이 가로채지 않음. 실제 입력기를 실행한 것은 아니고, 편집기가 ‘확정 전 글자’를 들고 있는 상태를 만든 것 |
| 우클릭 메뉴 | 메뉴 갱신을 직접 호출 | 포커스된 줄이 있으면 두 항목, 없으면 메뉴 없음(포인터로 빈 곳을 누르는 경로는 코드로만 확인) |

### Store Release Phase 1 Gate (2026-10-07)

판정 HUMAN_ACTION_REQUIRED: 제품과 archive는 준비됐고 Apple 계정에서 사용자가 할 일만 남았다(RELEASE.md). 영수증 MAC-STORE-RELEASE-1-GATE-20261007, 로컬 evidence artifacts/evidence/store-release-1. 모든 항목을 현재 source에서 한 번 실행했다. AI가 실행한 Engineering Verification이며 User QA PASS가 아니다.

| 항목 | 명령 | 결과 |
|---|---|---|
| Runtime·UI model·Core test | eng/test.sh --level 3 | 153개 실행, 실패 0 (통합 75 중 11 skip, UI model 49 중 1 skip, Core 29). 파일 안전·transaction·journal·Undo/Recovery·접근 규칙·bookmark·스토어 동등성 test 포함 |
| 일회용 volume | eng/test-volumes.py | APFS, 대소문자 구분 APFS, exFAT, FAT32 모두 PASS(분리·재연결·다른 디스크·읽기 전용 단계 포함, volume UUID 확인). 남은 mount·임시 폴더 0 |
| 실제 App Sandbox | eng/test-sandbox.py | 15개 PASS: 폴더·파일 전달, 추가한 폴더 자체의 이름(상위 폴더 요청·취소·재시도), 파일 하나·여러 파일, 남겨 둔 접근 재사용, 재실행 뒤 Undo, 즐겨찾기, 폴더 감시, 외장 APFS 재연결, 다른 디스크 거부, exFAT 무변경, 실제 창과 메뉴, 여러 언어의 이름 |
| 리소스·스토어 문구 | eng/validate-resources.py; eng/validate-marketing.py | 571 keys × ko/en/ja PASS. 스토어 문구 PASS(이제 Info.plist의 분류·수출 규정 답·최소 macOS·언어와도 대조) |
| AppStore build | eng/build.sh --configuration AppStore --arch arm64 | BUILD SUCCEEDED |
| Archive preflight | eng/archive-store.sh --preflight | ARCHIVE SUCCEEDED. com.ailoworks.namefix, 1.0.0 build 6, arm64만(x86_64 없음), macOS 14.0, entitlement 셋, get-task-allow 없음, Hardened Runtime, ko/en/ja, probe·fixture·업데이트 문자열 0건, 실행 파일은 앱 하나(CLI 없음). 로컬 서명이며 제출용 서명이 아님 |
| 문서 | python3 tools/doccheck.py; git diff --check | PASS |

이 Gate에서 찾아 고친 것:
- 스토어 제출에 필요한 Info.plist 항목이 없었다(LSApplicationCategoryType, ITSAppUsesNonExemptEncryption). 추가했고 검사 도구가 대조한다. 제출 전에만 드러나는 문제라 P1로 분류했다.
- volume 검사에서 test 하나가 실패했다. D-036 때 쓴 test가 ‘fixture는 항상 내장 디스크’라고 가정한 것이 원인이며, disk image를 외장으로 판정한 것은 맞는 동작이다. test를 고쳤다. 제품 문제 아님.

build 번호: 제품 source가 바뀌었지만(Info.plist) build 6은 App Store Connect에 올린 적이 없어 그대로 둔다.

하지 않은 것: 스토어용 서명(자동 서명 archive), App ID·provisioning profile 생성, App Store Connect 기록 확인·생성, 업로드, 심사 제출. 로그인 없이는 App ID와 앱 기록의 상태를 읽을 수 없었다. 대표 화면 render와 성능 측정은 다시 하지 않았다(화면 코드 변경 없음).

### App Store Only Gate (2026-10-07, T-012)

판정 APPSTORE_ONLY_READY. 영수증 MAC-APPSTORE-ONLY-GATE-20261007, 로컬 evidence artifacts/evidence/storeonly. 공개 제품은 Mac App Store build 하나이고(D-038) 이 Gate가 현재 source의 기준이다. 이 아래의 Gate들에 나오는 ‘직접 배포 구성’·‘Release 구성’·CLI 항목은 그때의 사실이며 지금은 없는 구성이다. AI가 실행한 Engineering Verification이며 User QA PASS가 아니다.

| 항목 | 명령 | 결과 |
|---|---|---|
| Runtime·UI model·Core test | eng/test.sh --level 3 | 153개 실행, 실패 0 (통합 75 중 11 skip, UI model 49 중 1 skip, Core 29). CLI target을 지워도 test 수는 같다 |
| 실제 App Sandbox | eng/test-sandbox.py | 15개 PASS. 앱 메뉴에 업데이트 명령 없음 확인 포함 |
| sandbox 밖 회귀(제품 gate 아님) | eng/test-sandbox.py --direct | 15개 PASS. 제한 없는 접근 규칙이 그대로임을 보는 architecture 근거 |
| AppStore build | eng/build.sh --configuration AppStore --arch arm64 | BUILD SUCCEEDED. com.ailoworks.namefix, 1.0.0 build 6, arm64만, macOS 14.0 이상, Hardened Runtime, entitlement 셋(app-sandbox · files.user-selected.read-write · files.bookmarks.app-scope), ko/en/ja, self-test PASS. probe·render fixture 문자열 0건, 업데이트 명령 문자열 0건, 번들 안 CLI 0개. ad-hoc 서명이며 제출용 서명이 아님 |
| 구성 | project.yml, eng/build.sh | Debug와 AppStore 둘. Release 구성은 없고 요청하면 거부한다 |
| 대표 화면 | --render-ux, --render-shell | 129장(78+51), assertion PASS |
| 리소스·스토어 문구 | eng/validate-resources.py; eng/validate-marketing.py | 571 keys × ko/en/ja PASS(‘업데이트 확인’ 문자열 제거), 스토어 문구 PASS. 스토어 문구에 직접 다운로드·CLI 언급 없음 |
| 문서 | python3 tools/doccheck.py; git diff --check | PASS |

이 Gate에서 다시 돌리지 않은 것: 일회용 volume matrix(eng/test-volumes.py), 반응형·확장 화면 render, 성능 측정. Infrastructure의 파일 안전 코드는 이번에 바뀌지 않았고 직전 Gate들의 결과가 근거다.

### App Store Feature Parity Gate (2026-10-07, T-011)

판정 APPSTORE_GUI_PARITY_READY. 영수증 MAC-APPSTORE-PARITY-GATE-20261007, 로컬 evidence artifacts/evidence/parity. AI가 실행한 Engineering Verification이며 User QA PASS가 아니다. 폴더 선택 창을 사람이 누르는 것은 이 Gate에 없다: 실제 sandbox에서 macOS가 이 process에 허용한 폴더로 요청에 답했다.

| 항목 | 명령 | 결과 |
|---|---|---|
| Runtime·UI model·Core test | eng/test.sh --level 3 | 153개 실행, 실패 0 (통합 75 중 11 skip, UI model 49 중 1 skip, Core 29). 새 StoreParityTests 5개 포함 |
| 스토어 구성의 실제 sandbox | eng/test-sandbox.py | 15개 PASS (기존 11 + 새 4) |
| 직접 배포 구성의 실제 실행 | eng/test-sandbox.py --direct | 15개 PASS. 어느 단계에서도 폴더를 요청하지 않음 |
| 대표 화면 | --render-ux, --render-shell, --render-responsive, --render-expansion | 237장(78+51+75+33), assertion PASS. ‘상위 폴더 선택 필요’ 화면을 넓은 창·좁은 창, ko/en으로 직접 확인 |
| 리소스·스토어 문구 | eng/validate-resources.py; eng/validate-marketing.py | 572 keys × ko/en/ja PASS, 스토어 문구 PASS |
| Debug·Release·AppStore build | eng/build.sh | 모두 BUILD SUCCEEDED, build 6 |

새 시나리오(실제 sandbox, 단계마다 새 실행):
- 추가한 폴더의 이름이 분리형: 폴더 안 4개는 바로 대상, 아무것도 묻지 않음 → 사용자가 폴더 이름도 원함 → 상위 폴더만 요청 → 취소하면 변화 0이고 다시 요청 가능 → 상위 폴더를 고르면 폴더까지 5개 이름 변경 → 새 실행에서 Undo 5개, byte 단위로 복원.
- 파일 하나: 폴더 요청 → 취소(변화 0, 항목 유지) → 다시 요청 → 고르면 다시 추가하지 않고 이름 변경 → 새 실행에서 Undo.
- 한 폴더의 파일 셋: 요청 한 번. 두 폴더의 파일: 폴더마다 차례로 요청하고 첫 요청이 하나 더 남았다고 알림.
- 즐겨찾기한 폴더 안의 파일: 요청 없음(남겨 둔 접근 재사용).

GUI 기능 비교(실제 실행 기준, *는 처음 한 번 필요한 폴더를 고르는 것만 다름):

| 기능 | 직접 배포판 | 스토어판 |
|---|---|---|
| 자소 분리 해결 | PASS | PASS |
| 파일 이름 일괄 변경 | PASS | PASS |
| 추가한 폴더 자체의 이름 변경 | PASS | PASS* |
| 파일 하나 | PASS | PASS* |
| 여러 파일(한 폴더, 여러 폴더) | PASS | PASS* |
| 즐겨찾기·최근 폴더 | PASS | PASS |
| 폴더 감시 | PASS | PASS |
| 작업 기록·Undo(재실행 뒤 포함) | PASS | PASS |
| 외장 APFS(재연결 뒤 Undo, 다른 디스크 거부) | PASS | PASS |
| exFAT 안내 | PASS | PASS |

남은 차이: CLI(D-035), 업데이트 방식(D-029). 일괄 변경에서 ‘폴더 이름도 변경’을 켰을 때의 추가한 폴더는 model test로 확인했다(실제 sandbox 시나리오에는 자소 분리 해결 화면의 경우만 있다). Recovery(강제 종료 뒤)는 이 Gate에서 새 흐름으로 다시 만들지 않았고 기존 계약 test가 근거다.

찾은 문제: P0 0, P1 0, P2 0. 이전에 남긴 ‘폴더 선택 필요에서 다시 고르는 버튼이 자세히 보기 안에 있다’(P2)는 안내 옆 버튼으로 해결했다.

아래 표는 세션 직전의 Final QA / Release Candidate Gate(2026-10-07) 결과다. 그때의 판정은 NEEDS_USER_QA였고 영수증은 MAC-FINAL-RC-GATE-20261007, 로컬 evidence는 artifacts/evidence/final-rc다. 세션에서 제품 source가 바뀌었으므로(결과 목록, 빠른 기록 D-036, 일괄 변경 안내, 문구) 세션 뒤에 다시 실행한 것은 MAC-USER-QA-SESSION-20261007의 범위가 현재 값이다. 스토어 구성의 실제 실행 12개 전체는 세션 뒤에 다시 돌리지 않았고 Release Candidate 단계의 통합 Gate에서 다시 실행한다.

이 Gate(세션 직전)에서는 제품 source가 바뀌지 않았다. 바뀐 것은 Debug 전용 확인 코드(App/SandboxFixtures.swift)와 eng/test-sandbox.py뿐이며 Release·AppStore binary에는 들어가지 않는다(probe 문자열 0건). 그래서 volume matrix, CLI, 대표 화면 render, 성능 수치는 아래 Phase 2 Gate의 결과를 그대로 쓴다.

| 항목 | 명령 | 결과 |
|---|---|---|
| 직접 배포 구성의 실제 실행 | eng/test-sandbox.py --direct (sandbox 밖의 Debug 앱, 기록은 실행마다 만든 임시 폴더, 폴더는 open -a로 전달, 단계마다 새 실행, 클릭 없음) | 12개 PASS. 아래 목록 |
| 스토어 구성의 실제 sandbox | eng/test-sandbox.py (스토어 entitlement로 서명한 Debug 앱) | 12개 PASS. 아래 목록 |
| Runtime·UI model·Core test | eng/test.sh --level 3 | 147개 실행, 실패 0 (통합 74 중 opt-in·volume 단계 11 skip, UI model 44 중 1 skip, Core 29). 성능 opt-in은 켜지 않았고 수치는 Phase 2 것을 쓴다 |
| Release·AppStore build | eng/build.sh --configuration Release / AppStore --arch arm64 | 둘 다 BUILD SUCCEEDED. 1.0.0 build 6, arm64, macOS 14 이상. Release는 entitlement 없음·에디션 direct, AppStore는 entitlement 셋·에디션 appstore. 서비스 1개와 문서 유형 1개가 두 구성에 같게 들어 있음. probe 문자열 0건 |
| 접근성 source 점검 | 아이콘만 있는 SwiftUI Button과 toolbar 버튼의 이름 확인 | 이름 없는 control 0개. 실제 VoiceOver 읽기는 사람이 확인(R7) |
| 문서 | python3 tools/doccheck.py; git diff --check | PASS |

두 구성에서 실제 앱으로 확인한 열두 가지(일회용 폴더와 이 도구가 만든 disk image만 사용):

| | 직접 배포 구성 | 스토어 구성(sandbox) |
|---|---|---|
| 넘겨받은 폴더의 검사·이름 변경, link 미추적 | PASS | PASS. 옆 폴더와 그 폴더 자체의 이름 변경은 시스템이 거부 |
| 앱을 다시 실행한 뒤 Undo | PASS | PASS (남겨 둔 bookmark로) |
| 접근 기록을 지운 뒤 Undo | PASS (필요 없음) | PASS (폴더를 요청하고 아무것도 바꾸지 않음) |
| 즐겨찾기·최근 폴더를 재실행 뒤 열기 | PASS | PASS |
| 폴더 감시가 재실행 뒤 새 파일을 알아챔 | PASS | PASS |
| 파일 하나만 넘김 | PASS (바로 대상) | PASS (폴더 요청, 거절하면 그대로이고 다시 고를 수 있음. 폴더 없이는 시스템이 이름 변경을 거부) |
| 외장 APFS image: 분리·재연결 뒤 Undo | PASS | PASS |
| 같은 자리에 다른 디스크 | PASS (건드리지 않음) | PASS (건드리지 않음) |
| exFAT image의 폴더 | PASS (나열·안내만, 제안 0, 변경 0) | PASS (같음) |
| 이름이 분리형인 폴더를 넘김 | PASS (폴더와 안의 4개를 고치고 Undo로 복원) | PASS (폴더 이름은 그대로, 안의 4개를 고치고 Undo로 복원) |
| 실제 창: 확인·결과·작업 기록·설정·사용 방법·소개 sheet가 창에 열림, Windows 이름 필터 3건, 이름 변경과 Undo, 앱 메뉴 | PASS (‘업데이트 확인…’ 있음) | PASS (‘업데이트 확인…’ 없음) |
| 여러 언어의 이름 26개 | PASS | PASS |

여러 언어의 이름: 분리형 14개(한글, 섞인 한글, 라틴, 베트남어, 가나, 그리스, 키릴, 긴 이름)가 byte 단위로 기대한 합침형이 되고, 12개(옛 글자체 한자 U+FA19·U+FA4C·U+F9DC·U+F914·U+2F800, emoji와 ZWJ, 전각·반각, 아랍·태국·데바나가리, 한자, ASCII)는 byte 그대로 남는다. Undo 뒤의 목록은 처음과 byte 단위로 같다. 정규화만으로 생기는 이름 충돌은 APFS에서 만들 수 없어(같은 이름으로 취급) 충돌 처리는 계획 test(Core·통합)가 근거다.

찾은 문제: P0 0건, P1 0건, P2 2건(수정하지 않고 남김).
- P2: 스토어판에서 폴더 선택을 거절한 뒤 다시 고르는 버튼이 아래 한 줄 안내의 자세히 보기 안에 있다. 파일을 다시 놓거나 ‘폴더 추가’로도 되므로 막히지는 않는다.
- P2: SwiftUI 화면의 접근성 정보는 앱 안에서 자동으로 읽어 검사할 수 없다. 이름표 누락은 source 점검으로만 막고 있다.

스토어판과 직접 배포판의 차이를 다시 본 결과, 줄일 수 있는 것이 없었다. 추가한 폴더 자체의 이름과 폴더 없이 넘겨받은 파일의 이름은 sandbox 안에서 시스템이 변경을 거부한다(위 표). 두 경우 모두 화면이 방법(한 단계 위의 폴더 추가, 폴더 선택)을 알려 준다.

자동으로 확인하지 못한 것: 폴더 선택 창을 실제로 눌러 받는 권한, 잠자기·깨우기, 실제 외장 장치, 서비스 메뉴·Dock·메뉴 막대·로그인 시 열기·알림·CSV 저장 창을 손으로 쓰는 것, VoiceOver, macOS 14 장비, 깨끗한 Mac 설치. 키 입력이나 클릭을 흉내 내는 자동화는 쓰지 않았다.

### Phase 2 Gate (2026-10-07, T-009) — 제품 source가 같아 그대로 쓰는 결과

영수증은 .ai/validation-cache.json의 MAC-GLOBAL-HARDENING-2-GATE-20261007, 로컬 evidence는 artifacts/evidence/global-hardening-2다. AI가 실행·렌더로 확인한 Engineering Verification이며 User QA PASS가 아니다. 스토어 제출용 서명·archive·업로드는 이 Gate에 없다.

| 항목 | 명령 | 결과 |
|---|---|---|
| Runtime·UI model·Core test | NAMEFIX_PERFORMANCE=1 NAMEFIX_EXPANSION_PERF=1 eng/test.sh --level 3 | 147개 실행, 실패 0 (통합 74 중 opt-in·volume 단계 9 skip, UI model 44 중 1 skip, Core 29). 접근 규칙 test 8개(AccessRootsTests)와 재시작 뒤 Undo(AppModelTests) 포함 |
| 지원 volume | eng/test-volumes.py | APFS, 대소문자 구분 APFS, exFAT, FAT32 모두 PASS. APFS 두 종류는 계약 test 73개(접근 규칙 포함, opt-in 9 skip) + 분리·재연결·다른 디스크·읽기 전용 단계. 실행 뒤 남은 mount·임시 폴더 0 |
| 실제 App Sandbox | eng/test-sandbox.py (스토어 entitlement로 서명한 Debug 앱, 폴더는 open -a로 전달, 단계마다 새 실행, 클릭 없음) | 8개 PASS: 넘겨받은 폴더의 검사·이름 변경과 link 미추적·옆 폴더는 시스템이 거부 / 재실행 뒤 bookmark로 Undo / 접근이 없을 때 폴더 요청과 무변경 / 즐겨찾기·최근 폴더 재실행 뒤 열기 / 폴더 감시가 재실행 뒤 새 파일 감지 / 파일 하나만 넘기면 폴더 요청 / 외장 APFS 재연결 뒤 Undo / 같은 자리의 다른 디스크 거부 |
| 리소스·스토어 문구 | eng/resources.py; eng/validate-resources.py; eng/validate-marketing.py | 556 keys × ko/en/ja, 재생성 diff 0 PASS. 스토어 문구 PASS |
| 직접 배포 CLI | eng/build-cli.sh debug + eng/test-expansion-cli.py; eng/build-cli.sh release + eng/test-release-cli.py | 둘 다 PASS |
| Debug build | eng/build.sh --configuration Debug --arch arm64 | BUILD SUCCEEDED, build 6 |
| 직접 배포 Release 구성 | eng/build.sh --configuration Release --arch arm64 | BUILD SUCCEEDED. entitlement 없음(App Sandbox OFF), 에디션 direct, build 6, arm64, self-test PASS, fixture·probe 문자열 0건. 후보 생성·서명·패키징은 하지 않음 |
| 스토어 AppStore 구성 | eng/build.sh --configuration AppStore --arch arm64 | BUILD SUCCEEDED. entitlement는 app-sandbox · files.user-selected.read-write · files.bookmarks.app-scope 셋뿐, 디버깅 entitlement 없음, 에디션 appstore, build 6, arm64, macOS 14 이상, ko/en/ja, sandbox 안에서 self-test PASS, fixture·probe 문자열 0건. ad-hoc 서명이며 제출용 서명이 아님 |
| 대표 화면 (Debug) | --render-ux, --render-shell, --render-responsive, --render-expansion | 231장(72+51+75+33), assertion PASS. 폴더 접근 안내 화면(넓은 창·좁은 창)을 ko/en/ja로 직접 보고 잘림 없음 확인 |
| 창 동작 진단 | --diagnose-window | PASS |
| 문서 | python3 tools/doccheck.py; git diff --check | PASS |

성능, 직접 배포판과 sandbox(Debug build, 같은 장비, eng/test-sandbox.py --compare, 초):

| | 시작 | 11,000건 검사 | 필터 | 1,000건 계획 | 1,000건 이름 변경 | Undo 계획 | Undo | 즐겨찾기로 10,000건 다시 열기 |
|---|---|---|---|---|---|---|---|---|
| 직접 배포판 | 0.85 | 0.90 | 0.65 | 0.79 | 30.9 | 4.44 | 29.9 | 0.84 |
| sandbox | 0.65 | 0.98 | 0.68 | 0.79 | 31.2 | 5.03 | 31.1 | 1.12 |

sandbox 때문에 계산이 느려진 곳은 없다. 차이는 폴더를 열 때마다 허용 폴더를 확인하는 비용과 bookmark를 푸는 비용이며 I/O(fsync)가 지배하는 이름 변경은 같다. 직접 배포판의 회귀 확인: 100,000건 검사 3.02초(직전 2.94), 10,000건 scan+rule Preview+plan 단독 실행 중앙값 2.216초 · p95 2.241초(직전 2.214 · 2.235).

이 Phase에서 확인한 내용:
- 직접 배포판: 접근 규칙이 바뀌지 않았다("/"부터 모든 조상 확인). 기존 계약 test 전부 PASS, 성능 같음.
- 스토어판: 허용한 폴더에서 시작하는 walk(D-033), 필요한 곳에만 남기는 bookmark(D-034), 접근이 없을 때의 요청 흐름. 실제 sandbox에서 PASS.
- 즐겨찾기·최근 폴더·폴더 감시·Undo/Recovery·외장 APFS가 두 에디션에서 같은 화면과 같은 동작이다. 차이는 FILESYSTEM_CAPABILITIES.md의 ‘App Sandbox (스토어판)’에 있다.
- 업데이트 확인(D-029): 직접 배포판 앱 메뉴에 추가, 스토어판에는 없음. 메뉴를 실제로 눌러 브라우저가 열리는지는 사람이 확인한다.

### Phase 1 Gate (2026-10-07, T-008)

아래는 Phase 1 시점의 결과다. Phase 2에서 다시 실행한 항목은 위 표가 현재 값이다.

| 항목 | 명령 | 결과 |
|---|---|---|
| Runtime·UI model·Core test | NAMEFIX_PERFORMANCE=1 NAMEFIX_EXPANSION_PERF=1 eng/test.sh --level 3 | 138개 실행, 실패 0 (통합 66 중 opt-in·volume 단계 9 skip, UI model 43 중 1 skip, Core 29) |
| 지원 volume | eng/test-volumes.py (APFS, 대소문자 구분 APFS, exFAT, FAT32 일회용 image) | 4종 PASS. APFS 두 종류: 계약 test 65개(opt-in 9 skip) + 분리·다른 device 번호로 재연결·다른 디스크·읽기 전용 단계. exFAT·FAT: 나열만 하고 계획하지 않음. 실행 뒤 남은 mount·임시 폴더 0 |
| 리소스 | eng/resources.py; eng/validate-resources.py | 545 keys × ko/en/ja, 재생성 diff 0 PASS |
| 스토어 문구 | eng/validate-marketing.py | PASS |
| CLI | eng/build-cli.sh debug + eng/test-expansion-cli.py; eng/build-cli.sh release + eng/test-release-cli.py | 둘 다 PASS |
| Debug build | eng/build.sh --configuration Debug --arch arm64 | BUILD SUCCEEDED |
| 직접 배포 Release 구성 build | eng/build.sh --configuration Release --arch arm64 | BUILD SUCCEEDED, arm64, 리소스 self-test PASS, render·촬영 fixture 문자열 0건. 후보 생성·서명·패키징은 하지 않음 |
| 대표 화면 (Debug) | --render-ux, --render-shell, --render-responsive, --render-expansion | 225장(66+51+75+33), assertion PASS. ko/en/ja 첫 화면·결과 목록·일괄 변경·소개·사용 방법·설정·규칙 추가·확인 창·좁은 창·위치 제외 화면을 직접 보고 잘림 없음 확인 |
| 창 동작 진단 | --diagnose-window | PASS |
| 성능 smoke | 위 test의 profile | scan 100,000건 2.94초(직전 3.18), 10,000건 scan+rule Preview+plan 중앙값 2.214초 · p95 2.235초(직전 2.174 · 2.210). 회귀 없음 |
| 문서 | python3 tools/doccheck.py; git diff --check | PASS |

volume별 성능(Debug, 같은 장비): 내장 APFS와 일회용 APFS image에서 1,000개 scan 0.064초 / 0.064초, 계획 0.146 / 0.180초, 이름 변경 30.7 / 29.0초, Undo 계획 4.6 / 6.0초, Undo 30.3 / 30.3초. 작업 기록은 앱과 같이 내장 디스크에 둔 구성이다. 이름 변경 시간은 항목마다 journal과 폴더를 fsync하는 비용이며 기존 기준선(1,000건 약 31초)과 같다. 성능을 위해 identity 확인·no-replace·journal·fsync를 줄이지 않았다. exFAT·FAT는 지원하지 않으므로 측정하지 않았다.

이 Phase에서 확인한 내용:
- 외장 APFS: 일회용 image에서 모든 계약 PASS → 지원(D-027). 실제 외장 USB APFS 디스크는 2026-10-07 User QA에서 확인했다(R5). 작업 중 케이블을 실제로 뽑는 것은 하지 않았다.
- 다시 연결: device 번호가 바뀌어도 같은 volume이면 Undo가 byte 단위로 복원하고, 다른 디스크는 거부한다(D-028).
- exFAT·FAT: UNSUPPORTED(D-027, FILESYSTEM_CAPABILITIES.md의 실험).
- 글로벌 Unicode: Core test 29개(한글·라틴·가나·그리스·키릴 합치기, 혼합, emoji·ZWJ·피부색·variation selector·BMP 밖, 호환 형태 미적용, 이체자 한자 보존(D-031), 잘못된 UTF-8, grapheme 단위 자르기)와 volume 위 왕복 test.
- Windows에서 쓸 수 없는 이름: read-only 진단과 필터(D-030), Core test.
- 문구: ko 94건, en 159건, ja 198건 수정과 하나일 때의 문구 6건 추가. 원칙은 DESIGN.md의 사용자 용어.

### 이전 Gate (2026-10-06, T-004) — 성능 기준선으로 참조

아래 표와 수치는 그 시점 source의 결과다. 현재 source의 PASS 근거가 아니며 성능 비교 기준으로만 쓴다.

| 항목 | 명령 | 결과 |
|---|---|---|
| Runtime·UI model·Core test | eng/test.sh --level 3 --scope all (성능 프로파일 4종 포함) | 112개 실행, 실패 0 (통합 53, UI model 39, Core 20) |
| 리소스 | eng/resources.py; eng/validate-resources.py | 496 keys × ko/en/ja, 재생성 diff 0 PASS |
| CLI | eng/build-cli.sh debug + eng/test-expansion-cli.py; eng/build-cli.sh release + eng/test-release-cli.py | Debug: dry-run/JSON, non-TTY 거부, TTY 확인 rename/undo PASS. Release: raw JSON/dry-run/freshness, non-TTY 거부, source hash 불변 PASS |
| Debug build | eng/build.sh --configuration Debug --arch arm64 | BUILD SUCCEEDED |
| Release 구성 build | eng/build.sh --configuration Release --arch arm64 | BUILD SUCCEEDED, arm64, 리소스 self-test PASS. render·진단 fixture와 그 실행 flag가 binary에 없음을 확인. 배포 후보 생성·서명·패키징은 하지 않음 |
| 대표 화면·fixture (Debug) | --render-ux, --render-shell, --render-expansion(±--native-sidebar), --render-responsive | 244장 생성, assertion PASS |
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

유휴 상태 확인: 반복 timer·polling·상시 animation이 없다. 1초 주기 갱신은 작업 중 경과 시간 표시뿐이고, 폴더 감시(FSEvents)는 사용자가 ‘폴더 감시’에 등록한 폴더에만 걸린다. 최근 폴더 기록은 감시를 시작하지 않는다.

코드 정리: Swift product source 48개 파일 유지, 6,270 → 6,387줄(아이콘 전용 control의 이름 label 약 +95, 목록 갱신 재구성 약 +45, 제거 약 −50). 제거한 것은 쓰지 않는 문자열 91개(580 → 489 keys), 예전 hero 화면용 테마 값과 button style, 쓰지 않는 model 상태 1개, 화면에서 열 수 없는 sheet 2종과 그 전용 코드, test만 쓰던 layout helper. render·진단 fixture 5개 파일은 Debug build에서만 compile한다. 새 파일·새 의존성은 없다.

재사용한 기존 근거와 한계:
- MAC-V1-APFS-CASE-SENSITIVE(대소문자 구분 APFS 볼륨)는 다시 실행하지 않았다. Infrastructure/Application/Core source는 이번에 바뀌지 않았다.
- UI test bundle(xcodebuild build-for-testing)은 다시 build하지 않았다. 직전 변경은 실행 인자 한 줄이다.
- MAC-V1-SOURCE-RACE-LIMITATION은 KNOWN_LIMITATION이다. MAC-V1-NOTARIZATION은 build3의 기록이며 현재 후보의 공증은 T-006에서 새로 한다. 유료 공급자 관련 영수증(MAC-V1-PAID-PROVIDER 등)은 전 기능 무료 결정(D-014)으로 SUPERSEDED다.
- macOS 14 실기의 대량 목록 성능과 실제 scroll 체감은 User QA R7과 Release Candidate 단계의 macOS 14 확인에서 본다.
- Core의 DevelopmentEntitlementProvider는 쓰이지 않지만 Core 계약 파일이라 이번 정리에서 건드리지 않았다. eng/build-cli.sh는 실행 권한이 없어 bash로 실행했다.

과거 build3 Release 후보의 서명·패키지 검증은 현재 source의 근거가 아니다. 경쟁 제품 대비 속도로 확대하지 않는다.

## Release Preparation 검증

Final Release Automation(2026-10-06)의 진행 상황. 영수증 MAC-RELEASE-SIGN-BUILD5-20261006, evidence artifacts/release-candidate/1.0.0/evidence-build5.

| 단계 | 명령 | 결과 |
|---|---|---|
| 후보 재확인 | eng/verify-candidate.py build5-pre-sign | PASS. 후보 이후 제품 source 변경 없음 |
| 도구 점검·수정 | eng/sign-candidate.py, eng/notarize-candidate.py(신규, sign-notarize.sh 대체), eng/package-candidate.py, eng/verify-candidate.py | 고친 것: 최종 package가 packaging 시점의 HEAD를 source commit으로 찍던 것(서명 전 후보의 값을 계승하도록), 공증 직전에 다시 서명하던 것(한 번만 서명), 서명·공증·staple 상태 표현(PRE_SIGN/SIGNED/ACCEPTED/stapled를 관측한 뒤에만 기록), DMG의 공증·staple·Gatekeeper·hash 기록 |
| Developer ID 서명 | eng/sign-candidate.py --identity "Developer ID Application: Hyein Kang (25373G7846)" | build5-signed-r2. 앱과 CLI 각 1회 서명, 팀 25373G7846, Hardened Runtime, secure timestamp, entitlement 없음, 식별자 com.ailoworks.namefix, arm64. 서명 전 후보와 서명만 다름 |
| 서명된 후보 검증 | eng/verify-candidate.py build5-signed-r2 | PASS(서명 전 후보에서 source commit 계승 확인 포함). 상태 SIGNED / 공증 NOT_RUN / publicRelease false |
| 공증(앱) | eng/notarize-candidate.py --profile NameFix-Notary | Accepted, submission 6be4bd10-610a-4c47-adaa-0c2e2b074ff5, notary log issue 없음. 서명된 binary를 다시 서명하지 않고 그대로 제출 |
| staple·Gatekeeper(앱) | stapler staple / validate, codesign --verify --deep --strict, spctl --assess --type execute | 모두 통과, source=Notarized Developer ID. staple로 바뀐 것은 티켓 파일 하나뿐 |
| 최종 DMG·ZIP | hdiutil create(APFS, UDZO), ditto | Moongchi_NameFix_1.0.0_build5_arm64.dmg(SHA-256 dab6d685d102a3641af28ced97e1c61edff99fdc12e0df4c5daad0fc3c39f4ca), .zip(SHA-256 7eac6ba04daa4ace33b7cede736e56ebf4d638a7d77693c1e096f9ffaf4657dd). hdiutil verify VALID |
| 공증(DMG) | DMG를 Developer ID로 서명 후 제출 | Accepted, submission c63f99e1-e719-4bb3-8855-aeca6f81150d, issue 없음. 티켓에 앱·CLI 포함 |
| staple·Gatekeeper(DMG) | stapler staple / validate, spctl --assess --type open | 통과, source=Notarized Developer ID |
| 최종 산출물 검증 | eng/verify-candidate.py build5-final | PASS: manifest hash, Info.plist(1.0.0 build 5, com.ailoworks.namefix, 최소 14.0), arm64, 아이콘·세 언어·폰트, 서명(팀 25373G7846, Hardened Runtime, timestamp, entitlement 없음), 공증 기록, DMG 무결성·staple·Gatekeeper, DMG 읽기 전용 mount와 내용 목록, ZIP 풀기, self-test, Release CLI 계약, 사용자 안내 문구, source commit 계승 |
| 실행 확인 | 공증된 앱 1회 실행 | 0.63초에 창 표시, 정상 종료. 개발 Mac에서의 확인이며 깨끗한 Mac 확인이 아니다 |

첫 서명 시도(build5-signed)는 도구가 ‘서명을 뗀 실행 파일 전체’를 비교하다 실패해 manifest 없이 멈췄다. 서명을 떼어도 Mach-O header의 한 필드에 서명이 차지하던 크기가 남기 때문이었고, load command 뒤의 코드만 비교하도록 고친 뒤 새 경로에 다시 서명했다. 중단된 디렉터리는 ABORTED.txt를 넣고 그대로 뒀다.

최종 상태: RELEASE_ARTIFACT_READY. 서명 전 후보와 서명된 후보는 최종 단계 뒤에도 각자의 manifest와 일치한다(바뀌지 않음). 아직 하지 않은 것: 깨끗한 Mac 확인(CLEAN_MAC_QA_PENDING, 별도 장비·VM 없음), 공개 배포.

현재 후보는 build 5다(Release Preparation 1.5, 2026-10-06). 영수증 MAC-RELEASE-PREP15-BUILD5-20261006, evidence artifacts/release-candidate/1.0.0/evidence-build5, 후보 artifacts/release-candidate/1.0.0/build5-pre-sign(source commit 76972c7). build 4 뒤에 바뀐 것은 CLI 도움말 문구와 build 번호, 후보 검사에 추가한 도움말 확인뿐이다.

| 항목 | 명령 | 결과 |
|---|---|---|
| CLI 도움말 | bash eng/build-cli.sh release; namefix --help | --include-folders, --include-hidden 설명이 나오고 기존 항목은 그대로. 임시 폴더 dry-run으로 설명과 동작 일치 확인(기본: 보이는 파일만 / 두 옵션: 폴더·숨김 포함 / 규칙 없음: 글자 구성만) |
| CLI 계약 | eng/test-release-cli.py | PASS |
| Debug build | eng/build.sh --configuration Debug --arch arm64 | BUILD SUCCEEDED, com.moongchi.namefix.dev, 1.0.0 (5) |
| Release build | eng/build.sh --clean --configuration Release --arch arm64 | BUILD SUCCEEDED, com.ailoworks.namefix, 1.0.0 (5), arm64, 최소 14.0, Hardened Runtime, entitlement 없음(get-task-allow·sandbox 없음), 개발 fixture·flag 없음, self-test PASS |
| 리소스 | eng/validate-resources.py | 516 keys × ko/en/ja PASS |
| 후보 생성·검증 | eng/package-candidate.py; eng/verify-candidate.py | build5-pre-sign 생성, 검증 PASS(아래 build 4 표와 같은 항목 + CLI 도움말 항목). 서명 PRE_SIGN, Developer ID NOT_RUN, 공증 NOT_RUN, publicRelease false, 유료 모델 필드 없음 |
| 서명 도구 | eng/sign-candidate.py --dry-run | 입력 후보가 manifest와 일치, 아무것도 서명하지 않음 |

build 4 후보(build4-pre-sign)는 대체됐고 파일은 그대로다(CLI hash가 자기 manifest와 일치). 아래는 build 4 때의 기록이다.

2026-10-06. 영수증은 MAC-RELEASE-PREP1-BUILD4-20261006, evidence는 artifacts/release-candidate/1.0.0/evidence-build4, 후보는 artifacts/release-candidate/1.0.0/build4-pre-sign(source commit bd64b03)이다. 이번에 바뀐 것은 Release metadata·bundle ID·build 번호·패키징 도구·문구이며 Core/Application/Infrastructure는 바뀌지 않았다.

| 항목 | 명령 | 결과 |
|---|---|---|
| project 생성 | xcodegen generate | Release = com.ailoworks.namefix, Debug = com.moongchi.namefix.dev, build 4, Release에 디버깅 entitlement 주입 없음 |
| Debug build | eng/build.sh --configuration Debug --arch arm64 | BUILD SUCCEEDED, com.moongchi.namefix.dev, 1.0.0 (4) |
| Release build | eng/build.sh --clean --configuration Release --arch arm64 | BUILD SUCCEEDED, com.ailoworks.namefix, 1.0.0 (4), arm64, 최소 14.0, Hardened Runtime(flags adhoc,runtime), entitlement 없음(sandbox 없음), self-test PASS |
| Release binary | strings 검사 | render·진단 fixture flag, 개발 전용 switch, test 환경 변수, 네트워크 API 이름 없음 |
| 리소스 | eng/resources.py; eng/validate-resources.py | 516 keys × ko/en/ja PASS |
| CLI (Release) | bash eng/build-cli.sh release; eng/test-release-cli.py | arm64, dry-run 기본, non-TTY 실행 거부, 개발 flag 없음, source hash 불변 PASS |
| 후보 생성 | eng/package-candidate.py | 새 경로에 앱·CLI·README·USER_GUIDE·ThirdPartyNotices·BUILD_INFO·manifest. ZIP/DMG 없음. build3 후보는 그대로 |
| 후보 검증 | eng/verify-candidate.py | manifest와 파일 hash 일치, Info.plist(식별자·버전·build·최소 OS), 아이콘·세 언어·폰트 리소스, 서명 상태 PRE_SIGN / Developer ID NOT_RUN / 공증 NOT_RUN / publicRelease false, 무료·직접 배포·AILO WORKS·문의 주소, 유료 모델 필드 없음, 사용자 안내에 옛 문구 없음 PASS |
| 서명 도구 | eng/sign-candidate.py --dry-run | 입력 후보가 manifest와 일치함을 확인하고 아무것도 서명하지 않음 |

실행하지 않은 것: Developer ID 서명, 공증 제출, staple, 최종 DMG, 공개 업로드. 서명·공증 스크립트의 실제 서명 경로는 실행해 보지 않았다.

재사용한 근거: Core/통합/UI model test 116개와 Debug CLI 계약(MAC-FAVORITES-TARGETS-20261006), 성능·시작·유휴 측정(T-004). 이번 변경은 문자열 값 하나와 metadata·도구라서 다시 돌리지 않았다.

build 4의 알려진 차이였던 CLI 도움말 누락은 build 5에서 고쳤다.

## 마케팅 자료 검증 (2026-10-07)

영수증 MAC-MARKETING-20261007, evidence artifacts/marketing/namefix/1.0.0/manifest.json. 직접 배포 산출물의 기존 PASS(서명·공증·staple·Gatekeeper·hash·test)는 제품 source가 바뀌지 않아 그대로 쓴다. 웹사이트 검증은 뭉치페이지스의 일이며 여기에 기록하지 않는다(D-025).

| 항목 | 명령·방법 | 결과 |
|---|---|---|
| 화면 촬영 도구 | eng/build.sh Debug, 앱 --render-marketing --marketing-samples | PASS. 15장면(5 × ko/en/ja), 예시 파일을 앱이 직접 검사·확인·일괄 변경 미리보기·이름 변경·작업 기록 표시 |
| Release에 미포함 | eng/build.sh Release 뒤 실행 파일 문자열 확인 | PASS. render-marketing 관련 문자열 0건 |
| UI model test | eng/test.sh --scope ui-model | PASS (Package.swift 제외 목록 변경의 영향 확인) |
| 스토어 문구 | python3 eng/validate-marketing.py | PASS. ko/en/ja 전 항목이 한도 안, 버전·bundle ID·문의 주소·저작권이 앱과 일치 |
| 화면 합성 | python3 eng/marketing-shots.py | PASS. 스토어 2880×1800 15장과 manifest |

## 즐겨찾기와 일괄 변경 대상 정책 검증 (T-005)

2026-10-06. 영수증은 MAC-FAVORITES-TARGETS-20261006, evidence는 artifacts/development/favorites-targets다. Core(선택 필드 2개)·Application(대상 정책)·Infrastructure(설정)·CLI·App이 바뀌어 직전 MAC-OPTIMIZATION-GATE-20261006을 대체한다. 성능 프로파일과 시작·유휴 측정은 다시 하지 않았다(대상 정책은 항목마다 이름 한 번을 더 보는 정도이고 scan·plan 경로는 그대로다).

| 항목 | 명령 | 결과 |
|---|---|---|
| Runtime·UI model·Core test | eng/test.sh --level 3 --scope all | 116개 실행, 실패 0 (통합 54, UI model 42, Core 20; 성능 프로파일 4종 skip) |
| 리소스 | eng/resources.py; eng/validate-resources.py | 516 keys × ko/en/ja PASS |
| CLI | Debug/Release build + eng/test-expansion-cli.py, eng/test-release-cli.py | PASS |
| Build | eng/build.sh Debug; eng/build.sh Release + --self-test | 둘 다 BUILD SUCCEEDED |
| 화면 | --render-ux(54장: 즐겨찾기 목록과 열 수 없는 항목, 대상 범위 sheet, ‘대상 아님’ 목록 포함), --render-shell, --render-expansion(±--native-sidebar), --render-responsive, --diagnose-window | 249장, assertion PASS |

추가·수정한 test: 대상 정책(기본 제외, 두 옵션, 번호 미차지, Finder 관리 파일 상시 제외, 규칙 없는 글자 합치기는 대상 아님, 옵션의 저장 호환), 폴더를 가리키는 이름 목록 거부, 즐겨찾기(한 번만 고정, 파일은 불가, 저장·재시작 후 유지, 열면 입력 추가와 검사, 감시 미시작, 접근 권한 없음·삭제 시 표시와 알림, 다시 선택, 제거해도 파일 유지), 손상된 즐겨찾기 설정의 원본 보존과 기본값 복구, 구버전 설정 호환, ‘대상 아님’ 상태 문구. 폴더 이름 변경을 전제로 하던 기존 test 3개는 옵션을 켜거나 새 흐름에 맞게 고쳤다.

확인하지 못한 것: 폴더가 옮겨졌을 때 bookmark로 따라가는 동작(test 환경에서는 bookmark 생성 여부가 보장되지 않아 경로 기준으로만 검증), 실제 창에서의 즐겨찾기 추가·다시 선택 panel, 일괄 변경 화면 진입 시 목록이 바뀌는 체감.

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

사용자 지시(2026-10-06, 8차) 처리: 설정 맨 아래 카드를 개발사 소개로 바꿨다. 로고는 AILO, ‘개발’ 문구는 ‘기획 · 설계 · 개발’ 표제와 소개 문장으로, 뭉치 웹사이트(https://moongchi.ailoworks.com) 소개와 링크를 추가했다. 웹사이트 소개 문구는 실제 사이트 내용을 확인해 썼다. 버그 신고·문의 주소는 아직 없어 그 줄은 나오지 않는다. 개발사 이름은 사용자 확인에 따라 AILO WORKS로 적는다. ‘기획 · 설계 · 개발’ 표제는 사용자 지시로 다시 뺐다.

사용자 보고(2026-10-06, 9차) 처리: 소개가 닫힐 때 뒤에 다른 화면이 보인다는 보고. sheet가 닫히는 순간 내용이 기본 화면(사용 방법)으로 바뀌어 닫히는 animation 동안 그 화면이 비쳤다. 모든 sheet가 닫히는 동안 자기 내용을 유지하도록 고쳤고, 소개를 설정·사용 방법에서 열었을 때는 닫으면 그 화면으로 돌아가게 했다. 닫히는 animation 자체는 화면 렌더로 확인할 수 없어 사용자 확인 대상이다.

사용자 지시(2026-10-06, 10차) 처리: 설정 맨 아래 카드를 사용자가 보여 준 다른 뭉치 앱(DiskSuite)의 정보 화면과 합친 구성으로 다시 만들었다(앱 소개 + 개발자 소개). 넓은 sheet와 320pt sheet 렌더로 확인했다. 사용자가 2026-10-06에 실제 화면에서 카드 구성·AILO 로고와 문구·뭉치 웹사이트 열기·사용 방법/소개 다시 보기/폰트 라이선스 열기를 “모두 확인”했다고 알렸다.

사용자 지시(2026-10-06, 11차) 처리: 버그 신고·문의 주소를 넣었다. 사용자가 처음 적은 주소(alio@alioworks.com)가 개발사·웹사이트 철자(ailo)와 달라 확인했고, 사용자가 ailo@ailoworks.com을 골랐다. 설정 카드에 버튼과 주소가 나오는 것을 렌더로 확인했다. 버튼이 실제 메일 앱을 여는지는 사용자 확인 대상이다.


## User QA — 한 번에 확인할 목록

### 지금 확인할 것 (T-005)

사용자가 2026-10-06에 F1~F5를 직접 진행하고 “정상”이라고 알렸다. 항목별 세부 의견은 없었다. AI가 손쉬운 사용(AX) 동작으로 대신 진행하려던 시도는 사용자가 중단시켰고 결과에 쓰지 않았다.

| 번호 | 확인할 것 | 결과 |
|---|---|---|
| F1 | 첫 화면 왼쪽 ‘즐겨찾기’의 +로 폴더를 추가하고, 눌러서 열리고, ×로 제거되는가(폴더는 그대로인가) | PASS (사용자, 2026-10-06) |
| F2 | 즐겨찾기한 폴더의 이름을 바꾸거나 지운 뒤 누르면 ‘찾을 수 없음 · 다시 선택’으로 표시되고 다시 고를 수 있는가 | PASS (사용자, 2026-10-06) |
| F3 | 폴더를 넣은 상태에서 오른쪽 위 + 메뉴와 트리 폴더의 우클릭 메뉴로 즐겨찾기를 쓸 수 있는가 | PASS (사용자, 2026-10-06) |
| F4 | 파일 이름 일괄 변경에서 폴더와 숨김 파일이 ‘대상 아님’으로 나오고 파일만 바뀌는가 | PASS (사용자, 2026-10-06) |
| F5 | ‘+ 규칙 추가’ → 고급 → ‘대상 범위’에서 두 옵션을 켜면 폴더·숨김 파일이 대상에 들어오는가 | PASS (사용자, 2026-10-06) |

### 지금 확인할 다섯 가지 (T-004 종료 시점)

사용자가 2026-10-06에 아래 다섯 가지와 sheet가 닫힐 때 다른 화면이 비치지 않는 것까지 “모두 확인 완료”라고 알렸다. 항목별 세부 의견은 없었다. 자동 검증으로 대신할 수 없는 것만 추렸다. 사용자가 이미 PASS한 레일 hover label과 ‘적용 예시’, band drag는 다시 묻지 않는다.

| 번호 | 확인할 것 | 결과 |
|---|---|---|
| Q1 | 폴더를 넣은 뒤 트리 제목 줄의 ⊗에 pointer를 올리면 ‘모두 닫기’가 바로 옆에 나오는가 | PASS (사용자, 2026-10-06) |
| Q2 | 오른쪽 위 저장·다시 검사·추가 버튼에 pointer를 올리면 각 이름이 나오는가. 세 버튼이 이전처럼 눌리고, 추가(+)는 메뉴가 열리는가 | PASS (사용자, 2026-10-06) |
| Q3 | 그 밖의 아이콘 전용 control(목록 옵션 ⋯, 추가 항목의 ×, 규칙 초기화 휴지통, 규칙 줄 ⋯)에서도 같은 모양의 이름이 나오고, 누르거나 벗어나면 사라지는가 | PASS (사용자, 2026-10-06) |
| Q4 | 실제로 쓰는 큰 폴더에서 검색·필터·정렬·스크롤이 답답하지 않은가 | PASS (사용자, 2026-10-06) |
| Q5 | Dock·⌘Tab의 앱 아이콘 크기와 첫 실행 소개(‘다시 보지 않기’ 포함)가 의도대로인가 | PASS (사용자, 2026-10-06) |


### 남은 확인 일곱 가지 (Final QA Gate, 2026-10-07)

실제 업무 원본이 아닌 복사본 폴더에서 진행한다. 결과는 사용자가 말한 PASS/FAIL을 그대로 기록하고, 실패가 제품 수정의 근원이 되면 STATUS에 bug Task로 올린다. 이전의 화면 S1~S5와 U01~U30은 이 일곱 가지로 묶었다(괄호 안이 묶인 번호). 위에서 사용자가 PASS한 F1~F5, Q1~Q5와 title bar band drag는 그 뒤 해당 화면 source가 바뀌지 않아 다시 묻지 않는다.

사용자 QA 세션(2026-10-07)은 끝났다. 판정 USER_QA_COMPLETE_WITH_EXTERNAL_PENDING. R2부터 시작했고, 사용자는 준비한 폴더를 처음에 찾지 못해 직접 만든 시험 파일로 진행했다. 아래 첫 표는 세션에서 사용자가 말한 것과 그 처리, 둘째 표는 R1~R7의 결과다.

| 사용자가 말한 것 | 분류 | 처리 |
|---|---|---|
| 폴더 트리에서 더블클릭으로 펼침·접힘 | P2 | 수정: 폴더 이름을 더블클릭하면 펼치고 접는다 |
| 약 1,200개 목록을 스크롤하면 한 번씩 끊겼다 내려감(Release build에서도). 수정 뒤 사용자: “엄청 부드러움, 해결”(2026-10-07) | P1 | 수정: 결과 목록을 직접 그리는 AppKit 표로 교체. 앱이 스스로 1,200줄을 끝까지 내렸다 올리는 측정(eng/test-sandbox.py --scroll, Debug)에서 한 단계의 중앙값 42ms → 8ms, 16ms를 넘는 단계 983회 → 2~3회, 가장 긴 멈춤 11.7초 → 0.07초. 사용자의 재확인 대기 |
| 이름 바꾸기와 되돌리기가 느리게 느껴짐 | P2 | 사용자 결정(D-036)으로 설정에 ‘이름을 더 빠르게 바꾸기’를 추가. 기본은 꺼짐(이전과 같은 방식). 실제 앱 측정(eng/test-sandbox.py --speed, Debug, 1,000개): 켠 상태에서 이름 변경 9.7초, 되돌리기 9.5초. 기본 방식은 이전 Gate 값 약 31초·30초. 긴 작업 뒤 한 번 설정을 안내한다. 사용자의 재확인 대기 |
| “자동 선택이 안 되는데” | P2 | 재현: 되돌리기 뒤 다시 고칠 이름이 선택되지 않았다(‘완료 후 선택 해제’가 되돌리기에도 적용됨, 목록 교체 이전부터의 동작). 수정: 선택 해제는 이름 변경 뒤에만 하고, 되돌리기·복구 뒤에는 처음 검사했을 때처럼 선택한다. 사용자가 본 상황이 이것인지 확인 대기 |
| R3: Finder 서비스 메뉴의 항목 이름이 한국어 시스템에서 영어(Inspect Names with NameFix)로 나옴 | P2 | 수정: 서비스 이름을 ServicesMenu.strings로도 만든다(ko/en/ja). 사용자가 한국어 이름을 화면으로 확인(2026-10-07). 같은 항목이 세 개 보인 것은 이 Mac에 예전 후보 사본이 여러 개 있어서이며 제품 문제가 아니다 |
| R3: 메뉴 막대 아이콘에 폴더를 끌어다 놓는 방법을 알 수 없었고, 끌고 올라가니 Mission Control이 열림 | P2 | 정리: 메뉴 막대 아이콘의 설명에서 ‘파일을 놓아 검사’를 빼고 ‘클릭해 메뉴를 여세요’만 남겼다. 놓기 동작 자체는 그대로 두되 기능으로 알리지 않는다. 들어오는 길은 창·Dock에 놓기와 서비스 메뉴다 |
| R3: ‘다음으로 열기’에 NameFix가 없음(폴더에는 메뉴 자체가 없고, 파일에서는 목록에 없음) | P2, 수정 안 함 | macOS는 폴더에 ‘다음으로 열기’를 보여 주지 않고, 모든 파일을 받는다는 선언(public.item, public.data를 추가해 봐도 같음)은 파일의 추천 목록에 올리지 않는다. 폴더는 macOS가 NameFix를 열 수 있는 앱으로 인정한다. 들어오는 길은 창·Dock에 끌어다 놓기와 서비스 메뉴이며 둘 다 사용자가 확인했다. ‘다음으로 열기’는 확인 항목에서 뺀다 |
| “파일 이름 일괄 변경이 동작 안 하는 것 같다”(‘폴’ → ‘테’를 넣었는데 바뀌는 이름 0개) | P2 | 동작은 맞다: ‘폴’은 폴더 이름에만 있었고 폴더는 일괄 변경의 기본 대상이 아니다. 문제는 그 자리에서 이유를 알 수 없었던 것. 수정: 바뀌는 이름이 없고 폴더가 있으면 규칙 아래에 폴더 안내와 ‘폴더 이름도 변경’ 버튼을 보이고, 버튼이 목록을 바로 갱신한다. 사용자 확인: 정상(2026-10-07) |
| 일괄 변경: ‘바꿀 이름’이 진해졌다 연해지는 의미를 모르겠음(0개일 때 눌러 목록이 비었음) | P2 | 수정: 개수가 0인 요약 항목은 눌리지 않는다. pointer를 올리면 ‘누르면 이 항목만 목록에 표시’, 켜진 상태에서는 ‘다시 누르면 전체 표시’가 나온다. 사용자 확인: 정상(2026-10-07) |
| 일괄 변경: 찾을 글자에서 Tab을 누르면 바꿀 글자가 아닌 다른 곳으로 감 | P2 | 수정: 두 칸 사이의 Tab·Shift-Tab 이동을 지정. 사용자 확인: 정상(2026-10-07) |
| 일괄 변경: 종료 후 다시 실행하면 변경 규칙이 남아 있음 | P2 | 사용자 결정(2026-10-07): “비우는 게 낫다, 그대로 실행하면 문제가 생길 수 있다.” 수정: 실행할 때마다 규칙 없이 시작한다. 규칙을 남기는 방법은 프리셋 저장이다. 사용자 확인: 정상(2026-10-07) |
| 일괄 변경: ‘업데이트 필요’에 툴팁을 추가하자 | P2 | 수정: 시스템 툴팁(늦게 뜸) 대신 앱의 즉시 뜨는 이름표로 ‘규칙이 바뀌었습니다. 누르면 바뀐 규칙으로 목록을 다시 계산합니다.’를 보인다. 요약 항목의 설명도 같은 방식으로 맞춤. 사용자 확인: 정상(2026-10-07) |

수정 뒤의 검증: 실제 앱 12개 시나리오(직접 배포 구성) 다시 PASS, test 148개 실패 0(빠른 기록의 순서와 끝이 잘린 기록에서의 복구 test 포함), 문자열 560 keys × ko/en/ja PASS, Debug·Release·AppStore build 성공, 대표 화면 72장 render PASS(목록 모양을 ko/en/ja·어두운 테마에서 직접 확인). 새 목록의 키보드 조작(Space, ⌘A, ⌘Z, 화살표), 우클릭 메뉴, 더블클릭으로 자세히 보기, 열 너비 조절은 사람이 R1·R7에서 확인한다.

| 번호 | 확인할 것 | 결과 |
|---|---|---|
| R1 | 직접 배포판의 기본 흐름과 화면: 폴더 추가(선택 창, 끌어다 놓기) → 검사 → 확인 → 이름 바꾸기 → 결과 → 작업 기록 → 되돌리기. 파일 이름 일괄 변경(규칙 추가·수정, 고급 설정, 프리셋, CSV 목록, 파일 정보), 글자 구성 자세히 보기, 테마 4종, 창 크기 조절과 좁은 창, 재실행 뒤 창 위치. 구매·Pro 표시가 없는지 (S1~S5, U01, U03, U04, U07, U13, U15~U18) | PASS (사용자, 2026-10-07, 목록 교체·빠르게 바꾸기·되돌린 뒤 선택 수정이 들어간 Release build에서) |
| R2 | 스토어판의 권한 흐름: ‘폴더 추가’ 창으로 폴더 선택 → 정리 → 앱 종료 → 다시 실행 → 작업 기록에서 되돌리기. 파일 하나만 끌어다 놓았을 때 뜨는 폴더 선택 창, 취소했을 때의 ‘폴더 선택 필요’ 안내와 다시 고르기. 추가한 폴더 자체가 ‘대상 아님’으로 나올 때 안내가 이해되는지 (U08, U26, U27) | PASS (사용자, 2026-10-07, 직접 만든 시험 파일로 진행) |
| R3 | macOS 연동, 두 에디션 모두(메뉴 막대 아이콘은 그 뒤 제거, D-041): Finder의 다음으로 열기와 서비스 메뉴, Dock·메뉴 막대 아이콘에 끌어다 놓기, 로그인 시 열기, 완료 알림의 허용·거절, 결과 CSV 저장, 설정의 문의 버튼(메일). 직접 배포판 앱 메뉴의 ‘업데이트 확인…’이 브라우저로 제품 페이지를 열고 스토어판에는 없는지 (U12, U19, U29, U30) | PASS, 남은 P2 2건 (사용자, 2026-10-07: Dock에 놓기·서비스 메뉴·메뉴 막대 표시·로그인 시 열기·알림·CSV 저장·문의 메일·업데이트 확인 정상. 메뉴 막대에 끌어다 놓기와 ‘다음으로 열기’는 위 표의 P2) |
| R4 | 오래 쓰는 기능: 즐겨찾기·최근 폴더·폴더 감시가 재실행, 잠자기·깨우기 뒤에도 이어지는지, 폴더를 옮기거나 지웠을 때 ‘다시 선택’이 나오는지. 작업 중 취소, 강제 종료 뒤 다시 열었을 때의 복구 안내, 다른 앱이 같은 파일을 건드릴 때의 중단 안내 (U09, U28) | PASS (사용자, 2026-10-07: 즐겨찾기·최근 폴더·폴더 감시의 재실행, 잠자기, 폴더 이동 뒤 ‘다시 선택’, 작업 중 취소, 강제 종료 뒤 복구를 안내한 일곱 단계로 진행하고 “모두 완료 정상”) |
| R5 | 실제 디스크: 외장 APFS 드라이브에서 정리 → 꺼내기 → 다시 연결 → 되돌리기, 작업 중 케이블을 뽑았을 때. exFAT·FAT USB, 네트워크 드라이브, iCloud Drive 폴더, 읽기 전용 디스크를 넣었을 때 안내가 이해되고 아무것도 바뀌지 않는지 (U21, U22) | PARTIAL (2026-10-07). 사용자가 외장 디스크 ‘HDD 1TB’(USB, APFS)와 USB ‘무제’(exFAT)를 시험용으로 지정하고 AI에게 직접 진행하라고 했다. AI가 실제 앱으로 실행한 결과(Engineering Verification, evidence artifacts/evidence/user-qa/hardware-*.txt): 외장 APFS에서 두 에디션 모두 이름 4개 정리 → volume unmount → 다시 mount → 되돌리기, 이름이 byte 단위로 처음과 같음. exFAT USB에서 두 에디션 모두 나열·안내만 하고 제안 0, 변경 0. 시험 폴더는 지웠다. 같은 외장 디스크를 읽기 전용으로 mount했을 때도 두 에디션 모두 나열·안내만 하고 계획 0, 변경 0(hardware-readonly.txt). 하지 않은 것: 케이블을 실제로 뽑는 것(작업 중 포함), 네트워크 드라이브, iCloud Drive. 이 셋은 AI가 만들 수 없는 환경이라 PASS로 적지 않는다 |
| R6 | 언어: 한국어·영어·일본어 화면(첫 화면, 소개, 사용 방법, 설정, 확인 창, 오류·지원하지 않는 드라이브·폴더 선택 안내)이 그 언어 사용자에게 자연스러운지. ‘Windows에서 쓸 수 없는 이름’ 안내, 일본어 이름의 옛 글자체 한자(神, 隆 등)가 그대로인지, 스토어 문구와 화면 15장 (U02, U20, U23~U25) | AI 검수로 대체 (2026-10-07, 사용자 결정: “일본어·영어는 판단하기 어렵다, 현지에서 쓰는 단어로 검수해서 통과시켜라”). 앱 문자열 563개 × 영어·일본어와 스토어 문구를 한국어 원문과 대조해 전부 읽고 영어 32건, 일본어 54건, 스토어 문구 15곳을 고쳤다(주로 원문에 있는 해결 방법 안내가 빠진 문장, 용어 불일치, 표기 통일). 고친 뒤 화면 231장 render와 스토어 화면 15장을 다시 만들었다. 옛 글자체 한자는 실제 앱 실행에서 5자가 byte 그대로 남는 것을 확인. 원어민이 본 것은 아니다 |
| R7 | 접근성과 큰 목록: VoiceOver로 목록·버튼·상태 읽기, 키보드만으로 조작(Tab, Space, 단축키, 확인 창의 Return·Esc), 대비 증가·큰 글자. 약 100,000개 목록의 검사·스크롤·검색·취소 (U05, U06, U10) | PARTIAL (2026-10-07). 큰 목록은 AI가 실제 앱으로 측정(eng/test-sandbox.py --large, 100,001줄): 검색 0.77초, 필터 0.16초, 목록 전체 다시 그리기 0.05초, 스크롤 한 단계 중앙값 8ms(3,000단계 중 16ms 초과 14회). 사용자는 1,200개 목록의 스크롤과 일괄 변경의 Tab 이동을 직접 확인했다. 하지 않은 것: VoiceOver, 대비 증가·큰 글자, 키보드만으로 전체 조작 |

Release Candidate 단계에서 서명된 후보로만 할 수 있는 확인(지금은 대상이 없다): 공증된 DMG와 스토어 build를 깨끗한 Mac에 설치·실행(이전 U14), 실제 macOS 14 Apple Silicon 장비에서 R1과 R7(이전 U11).

## 문서/도구 검증

문서 변경 후:
~~~sh
python3 tools/doccheck.py
python3 tools/doccheck.py --git
git diff --check
~~~

eng/write-qa-report.py의 오래된 Phase0~5 보고서는 현재 SSOT가 아니라 재현 가능한 로컬 evidence 생성 도구다. 출력은 artifacts/evidence 아래에 두며 docs/를 덮어쓰지 않는다.
