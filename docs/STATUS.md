# STATUS — Moongchi NameFix

<!-- HOT:START -->
## 지금
- 단계: FINAL QA / RELEASE CANDIDATE GATE 완료 — 판정 NEEDS_USER_QA. 출시 보류. build 6 유지, 후보 생성·서명·공증·제출은 하지 않음. build 5는 공개하지 않는 과거 후보(D-026)
- 현재 Task: T-010 (verificationPending)
- 다음: 사용자가 QA.md의 R1~R7 확인 → 결과에 따라 Release Candidate 단계(직접 배포 build 6 후보, Mac App Store 제출)를 사용자가 따로 승인. 스토어 제출에는 T-007의 외부 입력이 필요
- 위험·막힘: 스토어판에서 폴더 선택 창을 눌러 받는 권한은 아직 아무도 확인하지 않았다(R2). 스토어 제출용 인증서와 App Store Connect 접근 없음(T-007). D-003의 비협조 writer source-race 알려진 제한
- 검증 대기: docs/QA.md의 User QA R6·R7. R1~R4는 사용자 PASS(R3에 P2 2건). R5는 PARTIAL: 실제 외장 APFS와 exFAT USB는 AI가 실행해 통과, 케이블 뽑기·네트워크·iCloud·읽기 전용 디스크는 미확인 사용자가 찾은 목록 스크롤 끊김은 고쳤고 사용자가 해결을 확인. 트리 더블클릭과 ‘이름을 더 빠르게 바꾸기’ 설정(D-036)은 재확인 대기
- 마지막 갱신: 2026-10-07
<!-- HOT:END -->

## 현재 Milestone

Global Product Hardening Phase 1·2와 그 최종 QA. 한국·영어권·일본 시장 수준의 제품 품질과, 직접 배포판과 Mac App Store판이 같은 코드로 같은 GUI 기능을 내는 공통 기반. 출시, DMG 공개, 웹사이트 수정, App Store 업로드·제출은 하지 않는다.

### T-010 Global Product Final QA / Release Candidate Gate [verificationPending]
- 근원: R-015, R-016
- 범위: build 6을 글로벌 v1.0 Release Candidate로 만들 수 있는지 판정. 새 기능 없음. 두 에디션을 실제 앱으로 실행해 확인(폴더·파일 전달, 재실행 뒤 Undo, 즐겨찾기·감시, 외장 APFS·exFAT image, 실제 창과 메뉴, 여러 언어의 이름), ko/en/ja 화면 검토, 접근성 source 점검, 스토어판 차이의 필요성 재검토, User QA를 일곱 가지로 정리.
- 완료기준: P0·P1 없음(달성: 0건), 두 에디션의 실제 실행 PASS(달성: 각 12개), 관련 자동 검증 PASS(달성), User QA 7개 이하로 정리(달성), 사용자의 R1~R7 확인(대기)
- 대기: 사용자의 User QA R1~R7(docs/QA.md). 특히 R2(스토어판에서 폴더 선택 창을 눌러 받는 권한)는 자동으로 확인할 수 없었다. AI가 실행·렌더로 확인한 것은 Engineering Verification이며 User QA PASS가 아니다.
- 검증: docs/QA.md의 현재 source의 Engineering Verification 상태

### T-009 Global Product Hardening Phase 2: sandbox 호환 공통 기반 [verificationPending]
- 근원: R-016
- 범위: 구성 셋(Debug / Release / AppStore)과 스토어 entitlement(D-032). 사용자가 허용한 폴더에서 시작하는 접근 규칙(D-033). 즐겨찾기·감시·최근 폴더·작업 기록용 bookmark와 그 수명(D-034). 접근이 없을 때의 폴더 요청 흐름과 ko/en/ja 문구. 스토어판에서 CLI 제외(D-035). 업데이트 확인(D-029). 실제 sandbox 검증 도구. build 6.
- 완료기준: 직접 배포판 회귀 없음(달성), 스토어판이 실제 sandbox에서 검사·이름 변경·재실행 뒤 Undo·즐겨찾기·감시·외장 APFS 동작(달성), 안전 계약 약화 없음(달성), Consolidated Gate PASS(달성), 창을 눌러 받는 권한 흐름의 사용자 확인(대기)
- 대기: QA.md의 R2·R3·R4(T-010에서 묶음). AI가 실제 sandbox에서 실행한 것은 Engineering Verification이며 User QA PASS가 아니다.
- 검증: docs/QA.md의 현재 source의 Engineering Verification 상태

### T-008 Global Product Hardening [verificationPending]
- 근원: R-015
- 범위: 파일시스템 지원 모델을 실험으로 확정하고 코드·화면·문서를 맞춤(D-027). 다시 연결한 volume을 UUID로 확인(D-028). 지원 밖 위치의 상태 문구와 안내. Windows에서 쓸 수 없는 이름의 read-only 진단(D-030). 글로벌 Unicode 검증과 이체자 한자 보존(D-031). 영어·일본어·한국어 문구의 제품 현지화. 일회용 volume 검증 도구. 업데이트 방식(D-029 후보)과 App Store sandbox 구조 방향 검토.
- 완료기준: 지원 판정과 근거가 FILESYSTEM_CAPABILITIES.md에 있고 코드·화면과 일치(달성), 안전 계약 약화 없음(달성), Consolidated Gate PASS(달성), ko/en/ja 대표 화면 확인(달성), 사용자 검토와 실제 장치·원어민 확인(대기)
- 대기: QA.md의 R5(실제 외장 장치)와 R6(영어·일본어 원어민 확인 포함). AI가 본 렌더와 test는 Engineering Verification이며 User QA PASS가 아니다.
- 검증: docs/QA.md의 현재 source의 Engineering Verification 상태

### T-003 First-use UX와 화면 구조 단순화 [verificationPending]
- 근원: R-008
- 범위: 빈 상태를 유일한 입력 화면으로, 결과 control은 입력 뒤에만. 사용자 확인 뒤 추가: 전 기능 무료(D-014), 왼쪽 영역을 입력 상태 기반으로(D-016: 입력 없음 → 펼친 navigation, 입력 있음 → 아이콘 레일 + 폴더 트리), 창 chrome 연결과 앱 이름, band 전체 drag, 일괄 변경을 ‘변경 규칙’/‘미리보기’ 2-pane과 ‘+ 규칙 추가’ popover로 재설계, stale 미리보기를 header 상태로 표시. 2차 확인 뒤 추가: 개수·진행·알림을 맨 아래 줄 왼쪽에(D-018), 첫 실행 소개(D-019), 시작 화면 고정(D-020), 일괄 변경의 시작 규칙과 한 줄 control, 사용 방법 화면 재구성, 설정 맨 아래 개발자 카드, 추가한 항목 닫기, band 아래 hosting view 제거로 drag 영역 복구, 앱 아이콘을 Icon Composer 문서로. 기능 삭제 없음. Core는 전체 access provider 추가뿐이고 Application/Infrastructure 변경 없음.
- 완료기준: 빈 화면에 결과용 control 없음, 입력 UI 중복 없음, 왼쪽 영역이 입력 상태를 따라 자동 전환, band 전체 drag, 일괄 변경 두 pane의 시작선 일치와 stale 상태가 layout을 밀지 않음, Pro 표시 없음, 관련 자동 검증 PASS, 사용자 화면 승인
- 대기: 사용자의 화면 확인(docs/QA.md R1). AI가 본 렌더는 Engineering Verification이며 화면 승인이 아니다.
- 검증: docs/QA.md의 First-use UX 구조 단순화 검증 표

### T-002 출시 전 제품 완성도 고도화 [verificationPending]
- 근원: R-008
- 범위: UI/UX·사용자 용어·ko/en/ja·접근성·코드·안정성 리뷰, 확인된 문제 수정, 영향 검증, Release Candidate Ready 판정, User QA 목록 정리
- 완료기준: 확인된 P0/P1 결함 없음, 관련 자동 검증 PASS, User QA 목록이 QA.md 한 곳에 정리됨, 사용자 QA 결과 반영
- 대기: 사용자의 User QA(docs/QA.md R1~R7). AI가 본 렌더와 test는 Engineering Verification이며 User QA PASS가 아니다.
- 검증: docs/QA.md의 현재 Engineering Verification 표

### T-007 Mac App Store 제출 [onHold]
- 근원: R-010
- 범위: AppStore 구성 archive, 배포 서명, App Store Connect 기록·메타데이터·스크린샷·App Privacy 입력, 업로드와 심사 제출. sandbox 구성과 권한 흐름은 T-009에서 끝났고 스토어 문구는 marketing/appstore.json에 있다.
- 사유: 제출용 배포 인증서(Apple Distribution, Mac Installer Distribution)와 App Store Connect 접근이 이 Mac에 없다. 새 private key 생성과 로그인(2FA), 약관 동의는 사용자가 한다. 출시 자체도 보류 중이다(D-026).
- 조건: 사용자가 Release Phase를 승인하고 docs/RELEASE.md ‘Mac App Store 트랙’의 외부 입력을 준비한다.

## 현재 상태 요약

- 구현: 현재 승인된 앱 기능 범위에서 추가 필수 구현 Task 없음. 확인된 P0/P1 결함 없음. P2 두 건은 QA.md에 남겼다.
- 에디션: 직접 배포판(sandbox 없음, CLI 포함)과 Mac App Store판(App Sandbox)이 같은 코드다(D-032). 스토어판은 사용자가 고른 폴더 안에서만 작업한다.
- 지원 위치: 로컬 writable APFS(내장·외장)에서만 이름을 바꾼다. exFAT·FAT·HFS+·네트워크·cloud 위치는 나열하고 이유를 알린 뒤 그대로 둔다(D-027).
- 알려진 제한: 비협조 외부 writer의 source 교체를 expected-inode 조건으로 원자 차단하지 못한다. 감지·중단·보존·복구 안내는 구현돼 있다. swap/cycle/묶음 파일 그룹은 그룹 도중 취소하면 복구 확인이 필요할 수 있다. 읽을 수 없는 작업 기록이 있으면 Undo/Recovery를 막는다.
- 유료 등급: 없음. 모든 기능을 무료로 제공한다(D-014).
- Release: 출시 보류. 1.0.0 build 5의 공증된 DMG(artifacts/release-candidate/1.0.0/build5-final)는 공개하지 않는 과거 후보로 보존한다(D-026). 현재 source는 build 6이며 후보 생성·서명·공증은 하지 않았다. 웹사이트는 뭉치페이지스가 맡는다(D-025). Mac App Store는 시작하지 않았다(T-007).
- User QA: QA.md의 Q1~Q5와 F1~F5는 사용자가 확인했다. 남은 것은 R1~R7 일곱 가지다. 깨끗한 Mac 설치와 macOS 14 장비 확인은 서명된 후보가 생기는 Release Candidate 단계에서 한다.

과거 완료 Task와 날짜별 개발 기록은 이 파일에 누적하지 않는다. 필요하면 Git 이력과 .ai/validation-cache.json의 evidence path를 확인한다.
