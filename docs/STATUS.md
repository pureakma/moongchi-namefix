# STATUS — Moongchi NameFix

<!-- HOT:START -->
## 지금
- 단계: 제품 개발·일반판 v1.0.0 공개 완료(T-015, T-016). 앱·DMG 공증·스테이플링·Gatekeeper, ZIP 추출 앱 검증, 공개 파일 익명 다운로드·해시 확인 완료. 스토어판 build 6 심사 제출은 별도 단계
- 현재 Task: 없음
- 다음: 일반판의 필수 사용자 작업 없음. Mac App Store 심사 결과는 별도이며 확인된 배포 상태·산출물 원본은 RELEASE.md
- 위험·막힘: 공증 인증정보는 사용자 직접 저장 후 정상화됐고 추가 사용자 입력 없음. D-003의 비협조 writer source-race 알려진 제한 유지. Apple 스토어 심사 결과는 일반판 공개와 별도
- 검증 대기: 제품 blocker는 없다. 추가 확인으로 남긴 것(실제로 하지 않았고 PASS로 적지 않음): 스토어 build에서 폴더 선택 창을 사람이 직접 누르는 것(‘상위 폴더 선택…’ 포함), 케이블을 실제로 뽑는 것(작업 중 포함), 네트워크 드라이브, iCloud Drive, VoiceOver, 대비 증가·큰 글자, 키보드만으로 전체 조작, 영어·일본어 원어민 확인. 상세는 docs/QA.md
- 마지막 갱신: 2026-10-17
<!-- HOT:END -->

## 현재 Milestone

제품 개발·일반판 서명·공증과 GitHub 오픈소스·일반판 릴리즈 완료(T-015, T-016). Mac App Store 심사 제출도 끝났으며 심사 결과는 별도다(T-007). 현재 승인 범위는 PROJECT.md, 실제 배포 상태는 RELEASE.md가 원본이다. 새 기능 개발과 웹사이트 수정은 하지 않는다.

### T-016 오픈소스 공개와 GitHub 일반판 릴리즈 [completed]
- 근원: R-018
- 범위: 사용자 선택 MIT, 브랜딩·폰트 권리 구분, README·배포 안내, 현재 파일과 Git 이력의 공개 전 점검, 일반 commit/push, 릴리즈 설명·공증된 배포 파일·체크섬 준비. 기존 이력 포함 공개의 승인은 완료(D-043). DMG 공증 후 저장소와 릴리즈를 함께 공개한다. 웹사이트 수정 없음.
- 완료기준: 라이선스·안내와 이력 점검, 공개 대상 승인, DMG 공증 후 GitHub 저장소·릴리즈 동시 공개, 익명 다운로드·해시 확인(모두 달성).
- 근거: 저장소 PUBLIC·MIT, v1.0.0 릴리즈 공개. 공증 DMG·ZIP·체크섬·권리 고지 여섯 파일을 로그인 없이 HTTP 200으로 내려받아 서버 해시·체크섬과 일치를 확인했다. 상세 원본은 RELEASE.md·QA.md, 영수증 MAC-RELEASE-PUBLICATION-20261017.

### T-015 일반판(직접 다운로드) 빌드 [completed]
- 근원: R-017
- 범위: 앱스토어판과 같은 빌드를 Developer ID로 서명·공증·스테이플링해 DMG와 ZIP으로 만든다(D-042). 앱의 기능·문구는 바꾸지 않는다. 다운로드 페이지 게시, 저장소 공개, 후원 계정은 포함하지 않는다.
- 근거: 사용자 인증정보 저장 뒤 DMG 공증 Accepted·스테이플링·서명·Gatekeeper, 읽기 전용 내부 앱 검증 PASS. 최종 해시·BUILD_INFO 갱신. 앱과 ZIP은 재생성하지 않았다. 상세는 RELEASE.md·QA.md와 영수증 MAC-RELEASE-DMG-NOTARIZATION-20261017.

### T-014 메뉴 막대 아이콘 제거 [completed]
- 근원: R-008
- 범위: 메뉴 막대 아이콘과 그 메뉴·파일 놓기·설정 스위치·문구를 없앤다(D-041). 로그인 시 열기, 완료 알림, 창을 닫아도 실행되는 동작은 그대로다. 새 기능 없음.
- 완료기준: 아이콘과 설정 항목 없음(달성), 영향 검증 PASS(달성)
- 근거: QA.md의 ‘메뉴 막대 아이콘 제거’, 영수증 MAC-MENUBAR-REMOVAL-20261013, 결정 D-041

### T-013 출시 전 코드 리뷰와 수정 [completed]
- 근원: R-008, R-016
- 범위: 2026-10-07 이후 바뀐 source(폴더 접근 규칙, 작업 기록과 빠른 방식, 결과 목록과 화면 동작)를 독립 리뷰어 셋이 리뷰하고, 지적된 결함과 보완을 모두 반영한 뒤 통합 Gate를 다시 실행. 그 수정을 새 리뷰어 둘이 다시 리뷰하고 같은 방식으로 반영. 사용자 지시로 필수 요소의 QA를 AI가 앱 안에서 대신 수행. 배포 작업은 포함하지 않는다.
- 완료기준: P0·P1 없음(달성: 첫 리뷰의 P1 2건 수정, 재리뷰는 P0·P1 없음), 지적 반영(달성: 첫 리뷰 2건과 재리뷰 1건은 수정 없이 사유 기록), 통합 Gate PASS(달성)
- 근거: QA.md의 ‘출시 전 코드 리뷰와 그 수정’(재리뷰 지적과 처리, 사람 대신 앱 안에서 확인한 것 포함), 영수증 MAC-PRERELEASE-REVIEW-GATE-20261013과 MAC-PRERELEASE-REREVIEW-GATE-20261013, 결정 D-040(보완 포함)과 D-036 보완

### T-012 App Store Only Distribution Simplification [completed]
- 근원: R-017
- 범위: 공개 배포를 Mac App Store 하나로(D-038). 구성을 Debug와 AppStore 둘로 줄이고, 직접 배포 구성·에디션 분기·‘업데이트 확인…’ 메뉴·사용자용 CLI와 그 test·직접 배포 후보 도구를 없앤다. GUI 기능과 파일 안전 계약은 그대로. 문서와 스토어 문구를 한 채널로 통일. Release Candidate 생성은 포함하지 않는다.
- 완료기준: 구성 Debug + AppStore(달성), GUI 기능 유지(달성: 실제 sandbox 15개), CLI·업데이트 메뉴·직접 배포 도구 제거(달성), arm64 전용·macOS 14 이상(달성), P0·P1 없음(달성), 문서·스토어 문구 일치(달성)
- 근거: QA.md의 App Store Only Gate, 영수증 MAC-APPSTORE-ONLY-GATE-20261007. build 5의 과거 후보는 손대지 않았다(RELEASE.md)

### T-011 App Store Feature Parity Polish [completed]
- 근원: R-016
- 범위: 스토어판의 GUI 기능을 직접 배포판과 같게(D-037). 추가한 폴더 자체의 이름 변경(필요한 순간에 상위 폴더 요청), 파일 하나·여러 파일, 필요한 폴더만 요청, 남겨 둔 접근 재사용, 다른 폴더 거부, 재실행 뒤 Undo, ko/en/ja 문구, 심사 메모. Release Candidate 생성은 포함하지 않는다.
- 완료기준: 직접 배포판 회귀 없음(달성), 스토어판에서 추가한 폴더·파일 하나·여러 파일의 이름 변경(달성: 실제 sandbox), 필요한 때만 요청(달성), 취소 안전과 재시도(달성), 남겨 둔 접근 재사용(달성), 재실행 뒤 Undo(달성), P0·P1 없음(달성), 남은 차이는 CLI와 업데이트 방식뿐(달성), 사람이 ‘상위 폴더 선택…’을 직접 누르는 것(하지 않음: 추가 확인 목록)
- 근거: QA.md의 App Store Feature Parity Gate(153 test, 실제 sandbox 15개 PASS). 폴더 선택 창 자체는 사용자가 R2에서 눌러 확인한 같은 창이다(파일 추가 뒤의 폴더 선택, 재실행 뒤 Undo). 새로 생긴 ‘상위 폴더 선택…’ 버튼과 그 창의 문구를 사람이 누르는 것은 하지 않았고, blocker가 아닌 추가 확인 목록에 넣었다
- 검증: docs/QA.md의 App Store Feature Parity Gate

### T-010 Global Product Final QA / Release Candidate Gate [completed]
- 근원: R-015, R-016
- 범위: build 6을 글로벌 v1.0 Release Candidate로 만들 수 있는지 판정. 새 기능 없음. 두 에디션을 실제 앱으로 실행해 확인(폴더·파일 전달, 재실행 뒤 Undo, 즐겨찾기·감시, 외장 APFS·exFAT image, 실제 창과 메뉴, 여러 언어의 이름), ko/en/ja 화면 검토, 접근성 source 점검, 스토어판 차이의 필요성 재검토, User QA를 일곱 가지로 정리.
- 완료기준: P0·P1 없음(달성: 0건), 두 에디션의 실제 실행 PASS(달성: 각 12개), 관련 자동 검증 PASS(달성), User QA 7개 이하로 정리(달성), 사용자 QA 세션(달성: R1~R4 PASS, R5·R7 PARTIAL, R6 AI 검수 대체)
- 근거: Final User QA Session(2026-10-07) 결과가 docs/QA.md ‘남은 확인 일곱 가지’에 있다. R1~R4 사용자 PASS, R5 PARTIAL, R6은 사용자 결정으로 AI 전체 검수로 대체, R7 PARTIAL. 세션에서 나온 P1 1건과 P2 8건을 고쳤고 P2 2건은 의도적으로 남겼다. 판정 USER_QA_COMPLETE_WITH_EXTERNAL_PENDING. 하지 않은 확인은 아래 ‘현재 상태 요약’의 추가 확인 목록에 있으며 이 Task의 남은 작업이 아니다. 영수증 MAC-USER-QA-SESSION-20261007
- 검증: docs/QA.md의 현재 source의 Engineering Verification 상태

### T-009 Global Product Hardening Phase 2: sandbox 호환 공통 기반 [completed]
- 근원: R-016
- 범위: 구성 셋(Debug / Release / AppStore)과 스토어 entitlement(D-032). 사용자가 허용한 폴더에서 시작하는 접근 규칙(D-033). 즐겨찾기·감시·최근 폴더·작업 기록용 bookmark와 그 수명(D-034). 접근이 없을 때의 폴더 요청 흐름과 ko/en/ja 문구. 스토어판에서 CLI 제외(D-035). 업데이트 확인(D-029). 실제 sandbox 검증 도구. build 6.
- 완료기준: 직접 배포판 회귀 없음(달성), 스토어판이 실제 sandbox에서 검사·이름 변경·재실행 뒤 Undo·즐겨찾기·감시·외장 APFS 동작(달성), 안전 계약 약화 없음(달성), Consolidated Gate PASS(달성), 창을 눌러 받는 권한 흐름의 사용자 확인(달성)
- 근거: 창을 눌러 받는 권한 흐름을 사용자가 확인했다(QA.md R2 PASS, R3·R4 PASS, 2026-10-07). Engineering Verification은 QA.md의 Phase 2 Gate와 Final QA Gate
- 검증: docs/QA.md의 현재 source의 Engineering Verification 상태

### T-008 Global Product Hardening [completed]
- 근원: R-015
- 범위: 파일시스템 지원 모델을 실험으로 확정하고 코드·화면·문서를 맞춤(D-027). 다시 연결한 volume을 UUID로 확인(D-028). 지원 밖 위치의 상태 문구와 안내. Windows에서 쓸 수 없는 이름의 read-only 진단(D-030). 글로벌 Unicode 검증과 이체자 한자 보존(D-031). 영어·일본어·한국어 문구의 제품 현지화. 일회용 volume 검증 도구. 업데이트 방식(D-029 후보)과 App Store sandbox 구조 방향 검토.
- 완료기준: 지원 판정과 근거가 FILESYSTEM_CAPABILITIES.md에 있고 코드·화면과 일치(달성), 안전 계약 약화 없음(달성), Consolidated Gate PASS(달성), ko/en/ja 대표 화면 확인(달성), 사용자 검토와 실제 장치 확인(달성: 외장 USB APFS·exFAT USB), 원어민 확인(하지 않음: 사용자 결정으로 AI 검수 대체)
- 근거: 사용자가 지정한 실제 외장 USB APFS 디스크와 exFAT USB에서 AI가 두 에디션을 실행해 통과했고(QA.md R5 PARTIAL), 영어·일본어는 사용자 결정으로 AI 전체 검수로 대체했다(R6, 원어민 확인 아님). 케이블 분리·네트워크·iCloud는 하지 않았고 추가 확인 목록에 있다
- 검증: docs/QA.md의 현재 source의 Engineering Verification 상태

### T-003 First-use UX와 화면 구조 단순화 [completed]
- 근원: R-008
- 범위: 빈 상태를 유일한 입력 화면으로, 결과 control은 입력 뒤에만. 사용자 확인 뒤 추가: 전 기능 무료(D-014), 왼쪽 영역을 입력 상태 기반으로(D-016: 입력 없음 → 펼친 navigation, 입력 있음 → 아이콘 레일 + 폴더 트리), 창 chrome 연결과 앱 이름, band 전체 drag, 일괄 변경을 ‘변경 규칙’/‘미리보기’ 2-pane과 ‘+ 규칙 추가’ popover로 재설계, stale 미리보기를 header 상태로 표시. 2차 확인 뒤 추가: 개수·진행·알림을 맨 아래 줄 왼쪽에(D-018), 첫 실행 소개(D-019), 시작 화면 고정(D-020), 일괄 변경의 시작 규칙과 한 줄 control, 사용 방법 화면 재구성, 설정 맨 아래 개발자 카드, 추가한 항목 닫기, band 아래 hosting view 제거로 drag 영역 복구, 앱 아이콘을 Icon Composer 문서로. 기능 삭제 없음. Core는 전체 access provider 추가뿐이고 Application/Infrastructure 변경 없음.
- 완료기준: 빈 화면에 결과용 control 없음, 입력 UI 중복 없음, 왼쪽 영역이 입력 상태를 따라 자동 전환, band 전체 drag, 일괄 변경 두 pane의 시작선 일치와 stale 상태가 layout을 밀지 않음, Pro 표시 없음, 관련 자동 검증 PASS, 사용자 화면 승인
- 근거: 사용자가 직접 배포판의 화면과 기본 흐름을 확인했다(QA.md R1 PASS, 2026-10-07). 그 세션에서 결과 목록을 AppKit 표로 바꾸고 일괄 변경 안내를 보강했다
- 검증: docs/QA.md의 First-use UX 구조 단순화 검증 표

### T-002 출시 전 제품 완성도 고도화 [completed]
- 근원: R-008
- 범위: UI/UX·사용자 용어·ko/en/ja·접근성·코드·안정성 리뷰, 확인된 문제 수정, 영향 검증, Release Candidate Ready 판정, User QA 목록 정리
- 완료기준: 확인된 P0/P1 결함 없음, 관련 자동 검증 PASS, User QA 목록이 QA.md 한 곳에 정리됨, 사용자 QA 결과 반영
- 근거: User QA 결과를 QA.md에 반영했다(R1~R4 PASS, R5·R7 PARTIAL, R6 AI 검수 대체). 확인된 P0·P1 없음. 하지 않은 확인은 추가 확인 목록에 있다
- 검증: docs/QA.md의 현재 Engineering Verification 표

### T-007 Mac App Store 제출 [completed]
- 근원: R-010
- 범위: AppStore 구성의 자동 서명 archive(D-039), App Store Connect 기록·메타데이터·스크린샷·App Privacy 입력, 업로드와 심사 제출. sandbox 구성과 권한 흐름은 T-009에서 끝났고 스토어 문구는 marketing/appstore.json에 있다.
- 근거: 사용자 승인 뒤 기존 Apple 계정 연락처를 심사팀 전용으로 저장하고 App Privacy ‘데이터 수집 없음’ 게시 상태를 확인했다. 필수 항목 검사 통과 후 1.0.0 build 6을 제출, Apple 상세 화면에서 ‘심사 대기 중’과 제출 항목 1개 확인. 제출 ID·화면·검증 원본은 RELEASE.md·QA.md, 영수증 MAC-RELEASE-STORE-SUBMISSION-20261017. 심사 승인·공개 출시는 아직 아니다.

## 현재 상태 요약

- 구현: 현재 승인된 앱 기능 범위에서 추가 필수 구현 Task 없음. P0 0건, P1 0건(User QA에서 나온 1건은 수정하고 사용자가 확인), P2 2건은 의도적으로 남겼다(QA.md). 작업 기록의 확정 수준은 사용자가 고른다(D-036).
- 제품: Mac App Store와 같은 빌드의 일반판 직접 다운로드를 제공하며 모두 무료다(D-042). App Sandbox 안에서 사용자가 고른 폴더에서만 작업하고, 모자란 폴더는 필요한 순간에 한 번 요청한다(D-037). 사용자용 CLI와 앱 자체 업데이트 확인은 없다. 구성은 Debug와 AppStore 둘.
- 지원 위치: 로컬 writable APFS(내장·외장)에서만 이름을 바꾼다. exFAT·FAT·HFS+·네트워크·cloud 위치는 나열하고 이유를 알린 뒤 그대로 둔다(D-027).
- 알려진 제한: 비협조 외부 writer의 source 교체를 expected-inode 조건으로 원자 차단하지 못한다. 감지·중단·보존·복구 안내는 구현돼 있다. swap/cycle/묶음 파일 그룹은 그룹 도중 취소하면 복구 확인이 필요할 수 있다. 읽을 수 없는 작업 기록이 있으면 Undo/Recovery를 막는다.
- 유료 등급: 없음. 모든 기능을 무료로 제공한다(D-014).
- Release: 사용자 승인으로 서명·공증·스토어 업로드를 진행했다(T-015, T-007). 현재 앱·ZIP과 미공증 DMG, 스토어 심사 접수 상태는 RELEASE.md에 있다. 스토어 심사는 제출했고 공개 배포·승인은 아직 아니다. build 5의 과거 후보는 보존한다. 웹사이트는 별도 저장소 범위다(D-025).
- User QA: Final User QA Session 완료(2026-10-07). Q1~Q5, F1~F5, R1~R4는 사용자 PASS. R5·R7은 PARTIAL, R6은 사용자 결정으로 AI 전체 검수로 대체했다. 판정 USER_QA_COMPLETE_WITH_EXTERNAL_PENDING. Release Candidate 단계에 들어갈 수 있다.
- 추가 확인(external / additional confidence checks, 현재 기록상 P0·P1 blocker 아님, 실제로 하지 않았음): 스토어 build에서 폴더 선택 창을 사람이 직접 누르는 것(‘상위 폴더 선택…’ 포함), 케이블을 실제로 뽑는 것(작업 중 포함), 네트워크 드라이브, iCloud Drive, VoiceOver, 대비 증가·큰 글자, 키보드만으로 전체 조작, 영어·일본어 원어민 확인. 깨끗한 Mac 설치와 실제 macOS 14 Apple Silicon 장비 확인은 스토어용으로 서명한 build가 생긴 뒤에 한다.

과거 완료 Task와 날짜별 개발 기록은 이 파일에 누적하지 않는다. 필요하면 Git 이력과 .ai/validation-cache.json의 evidence path를 확인한다.
