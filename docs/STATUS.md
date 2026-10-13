# STATUS — Moongchi NameFix

<!-- HOT:START -->
## 지금
- 단계: 출시 전 코드 리뷰와 그 수정 완료(T-013). 현재 source 1.0.0 build 6이 리뷰 지적을 반영하고 통합 Gate를 다시 통과했다. 출시 보류, 배포 작업(서명·업로드·제출)은 마지막에 따로 한다
- 현재 Task: 없음 (다음 Task는 사용자 승인 대기)
- 다음: 사용자의 개발자 계정 전환(개인 → 조직)이 끝나기를 기다린다. Xcode 재로그인은 이미 수행했지만 포털 접근이 복구되지 않았다. Apple의 조직 전환 정보 입력·처리 및 멤버십 재활성화가 끝나면 Organizer에서 Distribute App › Custom › App Store Connect › Export로 서명·내보내기 → App Store Connect 앱 기록 생성(지금 0개) → 업로드·제출 단계
- 위험·막힘: 확인된 P0·P1 없음. 스토어용 서명이 ‘No Account for Team’으로 멈춘다(명령줄과 Xcode 둘 다). Apple 계정 페이지에서 조직 전환 중 멤버십 혜택이 비활성화된 것을 확인했다. 전환 안내 화면을 사용자에게 열어 두었다. 상세 원본은 RELEASE.md의 Mac App Store 제출 절이다. 전환 뒤 Team ID와 판매자 이름을 확인해야 한다(T-007). D-003의 비협조 writer source-race 알려진 제한
- 검증 대기: 제품 blocker는 없다. 추가 확인으로 남긴 것(실제로 하지 않았고 PASS로 적지 않음): 스토어 build에서 폴더 선택 창을 사람이 직접 누르는 것(‘상위 폴더 선택…’ 포함), 케이블을 실제로 뽑는 것(작업 중 포함), 네트워크 드라이브, iCloud Drive, VoiceOver, 대비 증가·큰 글자, 키보드만으로 전체 조작, 영어·일본어 원어민 확인. 상세는 docs/QA.md
- 마지막 갱신: 2026-10-13
<!-- HOT:END -->

## 현재 Milestone

Global Product Hardening Phase 1·2, 최종 QA, 그리고 공개 배포를 Mac App Store 하나로 정리하는 것까지. 출시, 스토어 업로드·제출, 웹사이트 수정은 하지 않는다. 이 Milestone의 Task는 모두 끝났고, 다음은 사용자가 승인하는 Release Candidate Phase다. 아래 완료된 Task에 나오는 ‘직접 배포판’은 그때의 구성이며 지금은 없다(D-038).

### T-013 출시 전 코드 리뷰와 수정 [completed]
- 근원: R-008, R-016
- 범위: 2026-10-07 이후 바뀐 source(폴더 접근 규칙, 작업 기록과 빠른 방식, 결과 목록과 화면 동작)를 독립 리뷰어 셋이 리뷰하고, 지적된 결함과 보완을 모두 반영한 뒤 통합 Gate를 다시 실행. 배포 작업은 포함하지 않는다.
- 완료기준: P0·P1 없음(달성: 리뷰의 P1 2건 수정), 지적 반영(달성: 두 건은 수정 없이 사유 기록), 통합 Gate PASS(달성)
- 근거: QA.md의 ‘출시 전 코드 리뷰와 그 수정’, 영수증 MAC-PRERELEASE-REVIEW-GATE-20261013, 결정 D-040과 D-036 보완

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

### T-007 Mac App Store 제출 [onHold]
- 근원: R-010
- 범위: AppStore 구성의 자동 서명 archive(D-039), App Store Connect 기록·메타데이터·스크린샷·App Privacy 입력, 업로드와 심사 제출. sandbox 구성과 권한 흐름은 T-009에서 끝났고 스토어 문구는 marketing/appstore.json에 있다.
- 사유: 사용자의 개발자 계정이 개인에서 조직으로 전환 중이다(2026-10-07 신청). 그동안 Xcode의 자동 서명이 ‘No Account for Team’으로 멈추고, 판매자 이름도 전환 뒤에 확정된다. App Store Connect 앱 기록은 아직 없다. 출시 자체도 보류 중이다(D-026).
- 조건: 계정 전환이 끝나고 사용자가 docs/RELEASE.md ‘Mac App Store 제출’의 순서대로 진행한다. 제품 쪽 준비는 Store Release Phase 1 Gate에서 끝났다(QA.md).

## 현재 상태 요약

- 구현: 현재 승인된 앱 기능 범위에서 추가 필수 구현 Task 없음. P0 0건, P1 0건(User QA에서 나온 1건은 수정하고 사용자가 확인), P2 2건은 의도적으로 남겼다(QA.md). 작업 기록의 확정 수준은 사용자가 고른다(D-036).
- 제품: Mac App Store의 앱 하나이며 무료다(D-038). App Sandbox 안에서 사용자가 고른 폴더에서만 작업하고, 모자란 폴더는 필요한 순간에 한 번 요청한다(D-037). 직접 배포판, CLI, 앱 자체의 업데이트 확인은 없다. 구성은 Debug와 AppStore 둘.
- 지원 위치: 로컬 writable APFS(내장·외장)에서만 이름을 바꾼다. exFAT·FAT·HFS+·네트워크·cloud 위치는 나열하고 이유를 알린 뒤 그대로 둔다(D-027).
- 알려진 제한: 비협조 외부 writer의 source 교체를 expected-inode 조건으로 원자 차단하지 못한다. 감지·중단·보존·복구 안내는 구현돼 있다. swap/cycle/묶음 파일 그룹은 그룹 도중 취소하면 복구 확인이 필요할 수 있다. 읽을 수 없는 작업 기록이 있으면 Undo/Recovery를 막는다.
- 유료 등급: 없음. 모든 기능을 무료로 제공한다(D-014).
- Release: 출시 보류. Release Candidate와 스토어 제출은 시작하지 않았다(T-007). 1.0.0 build 5의 서명·공증된 직접 배포 후보(artifacts/release-candidate/1.0.0/build5-final)는 공개하지 않는 역사적 근거로만 보존한다(D-026, D-038). 웹사이트는 뭉치페이지스가 맡는다(D-025).
- User QA: Final User QA Session 완료(2026-10-07). Q1~Q5, F1~F5, R1~R4는 사용자 PASS. R5·R7은 PARTIAL, R6은 사용자 결정으로 AI 전체 검수로 대체했다. 판정 USER_QA_COMPLETE_WITH_EXTERNAL_PENDING. Release Candidate 단계에 들어갈 수 있다.
- 추가 확인(external / additional confidence checks, 현재 기록상 P0·P1 blocker 아님, 실제로 하지 않았음): 스토어 build에서 폴더 선택 창을 사람이 직접 누르는 것(‘상위 폴더 선택…’ 포함), 케이블을 실제로 뽑는 것(작업 중 포함), 네트워크 드라이브, iCloud Drive, VoiceOver, 대비 증가·큰 글자, 키보드만으로 전체 조작, 영어·일본어 원어민 확인. 깨끗한 Mac 설치와 실제 macOS 14 Apple Silicon 장비 확인은 스토어용으로 서명한 build가 생긴 뒤에 한다.

과거 완료 Task와 날짜별 개발 기록은 이 파일에 누적하지 않는다. 필요하면 Git 이력과 .ai/validation-cache.json의 evidence path를 확인한다.
