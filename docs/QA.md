# 검증과 User QA

## 두 종류의 검증

Engineering Verification은 AI/자동화가 수행하는 build, test, runtime fixture, render, performance, security/contract 검사다.

User QA는 사용자가 실제 앱을 조작하고 판단한 결과다. AI가 캡처를 보거나 off-screen render를 확인해도 User QA PASS로 기록하지 않는다.

## 검증 범위 규칙

Task의 검증 범위는 변경 영역 + 변경 계약 + 그 소비자 + 무효화된 기존 PASS 근거에서 결정한다. 작은 변경마다 전체 regression, clean build, package를 반복하지 않는다.

.ai/validation-cache.json은 source/test/dependency/toolchain/environment fingerprint와 evidence path를 기록하는 검증 영수증이다. evidence가 Git에 없거나 해당 fingerprint가 달라졌으면 과거 PASS를 현재 PASS로 확대하지 않는다.

## 현재 source의 Engineering Verification 상태

현재 source의 통합 Gate는 2026-10-07 Global Product Hardening Phase 2(T-009)의 결과다. 영수증은 .ai/validation-cache.json의 MAC-GLOBAL-HARDENING-2-GATE-20261007, 로컬 evidence는 artifacts/evidence/global-hardening-2다. AI가 실행·렌더로 확인한 Engineering Verification이며 User QA PASS가 아니다. 스토어 제출용 서명·archive·업로드는 이 Gate에 없다.

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
- 외장 APFS: 일회용 image에서 모든 계약 PASS → 지원(D-027). 실제 외장 장치 확인은 EXTERNAL_APFS_HARDWARE_QA_PENDING.
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
- macOS 14 실기의 대량 목록 성능과 실제 scroll 체감은 User QA U10/U11에서 확인한다.
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
| U13 | 고급 기능 흐름: 패턴·조건 규칙, 프리셋 저장·불러오기, CSV 목록, 파일 정보(실제 사진/음악/영상), 묶음 파일, 폴더 감시(잠자기·재시작·권한 철회 포함) | PENDING |
| U14 | 새 Release 후보(build 6 이상, D-026)의 공증된 DMG를 깨끗한 Mac에 설치·실행: Gatekeeper 경고 없이 열리는지, Finder 서비스·다음으로 열기·폴더 접근 권한 요청, 기본 이름 바꾸기 → 되돌리기 | PENDING |
| U15 | 화면 어디에도 Pro·구매 표시가 없고 모든 기능이 바로 동작하는지 | PENDING |
| U16 | Dock·Finder·앱 전환기(⌘Tab)에서 앱 아이콘이 회색 판 없이 다른 앱과 같은 크기로 보이는지 | PENDING |
| U17 | 첫 실행 소개: 4쪽 내용과 그림, 어두운 테마에서도 밝게 보이는지, ‘다시 보지 않기’ 후 다시 실행하면 안 나오는지, 설정·도움말 메뉴에서 다시 열리는지 | PENDING |
| U18 | 사용 방법 화면과 설정(제목 없는 첫 묶음, 오른쪽 정렬 switch, 맨 아래 개발자 카드)의 모양 | PENDING |
| U19 | 설정의 ‘버그 신고 및 문의’ 버튼이 메일 앱에서 ailo@ailoworks.com으로 새 메일을 여는지 | PENDING |
| U20 | 스토어용 화면 15장(artifacts/marketing/namefix/1.0.0/store)과 문구(marketing/appstore.json)의 ko/en/ja 표현과 장면 | PENDING |
| U21 | 실제 외장 APFS 드라이브에서: 폴더 추가 → 정리 → 추출(꺼내기) → 다시 연결 → 작업 기록에서 되돌리기. 작업 중 케이블을 뽑았을 때 안내와 복구 (EXTERNAL_APFS_HARDWARE_QA_PENDING) | PENDING |
| U22 | exFAT·FAT USB, 네트워크 드라이브, iCloud Drive 폴더, 읽기 전용 디스크를 넣었을 때 상태 문구(‘이 드라이브는 제외’ 등)와 아래 한 줄 안내가 이해되는지, 앱이 멈추지 않는지 | PENDING |
| U23 | 영어·일본어 화면(첫 화면, 소개, 사용 방법, 확인 창, 오류 안내)이 그 언어 사용자에게 자연스러운지. 한국어의 바뀐 용어(선택한 N개 이름 정리, 폴더 감시, 분리된 글자 합치기, 변경 완료 등) | PENDING |
| U24 | ‘필터·정렬 → Windows에서 쓸 수 없는 이름’과 자세히 보기의 안내가 쓸모 있는지 | PENDING |
| U25 | 일본어 이름의 옛 글자체 한자(예: 神, 隆)가 정리 뒤에도 그대로인지 | PENDING |
| U26 | 스토어판(sandbox) 실제 조작: ‘폴더 추가’ 창으로 폴더 선택 → 정리 → 앱 종료 → 다시 실행 → 작업 기록에서 되돌리기. 창을 눌러 받은 권한이 재실행 뒤에도 이어지는지 | PENDING |
| U27 | 스토어판에서 파일 하나만 끌어다 놓았을 때 뜨는 폴더 선택 창의 문구와 흐름, 취소했을 때의 ‘폴더 선택 필요’ 안내와 다시 고르기 | PENDING |
| U28 | 스토어판의 즐겨찾기·최근 폴더·폴더 감시: 재실행, 잠자기/깨우기, 폴더를 옮기거나 지웠을 때 ‘다시 선택’, 외장 드라이브를 뺐다 꽂았을 때 | PENDING |
| U29 | 스토어판의 Finder 연동: 다음으로 열기, Dock에 끌어다 놓기, 서비스 메뉴, 메뉴 막대 아이콘에 끌어다 놓기, 로그인 시 열기, 완료 알림, 결과 CSV 저장 | PENDING |
| U30 | 직접 배포판 앱 메뉴의 ‘업데이트 확인…’이 브라우저로 제품 페이지를 여는지, 스토어판에는 그 메뉴가 없는지 | PENDING |

## 문서/도구 검증

문서 변경 후:
~~~sh
python3 tools/doccheck.py
python3 tools/doccheck.py --git
git diff --check
~~~

eng/write-qa-report.py의 오래된 Phase0~5 보고서는 현재 SSOT가 아니라 재현 가능한 로컬 evidence 생성 도구다. 출력은 artifacts/evidence 아래에 두며 docs/를 덮어쓰지 않는다.
