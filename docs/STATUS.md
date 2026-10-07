# STATUS — Moongchi NameFix

<!-- HOT:START -->
## 지금
- 단계: GLOBAL_PRODUCT_HARDENING 구현·검증 완료 — 출시 보류. build 5는 공개하지 않는 과거 후보(D-026)
- 현재 Task: T-008 (verificationPending)
- 다음: 사용자가 결과 검토 → 결정(D-029 업데이트 방식 후보, App Store 트랙 T-007) → 새 Release 후보(build 6 이상) 단계는 사용자가 따로 승인
- 위험·막힘: 실제 외장 APFS 장치 확인 미실행(EXTERNAL_APFS_HARDWARE_QA_PENDING). Mac App Store 트랙 보류(T-007). D-003의 비협조 writer source-race 알려진 제한
- 검증 대기: docs/QA.md의 화면 S1~S5와 User QA U01~U25(새 후보에서 확인)
- 마지막 갱신: 2026-10-07
<!-- HOT:END -->

## 현재 Milestone

Global Product Hardening Phase 1. 한국·영어권·일본 시장에서 경쟁력 있는 수준으로 제품을 올린다. 출시, DMG 공개, 웹사이트 수정, App Store 제출은 하지 않는다. 이전 Milestone의 사용자 확인(T-002, T-003, T-006)은 새 후보에서 다시 본다.

### T-008 Global Product Hardening [verificationPending]
- 근원: R-015
- 범위: 파일시스템 지원 모델을 실험으로 확정하고 코드·화면·문서를 맞춤(D-027). 다시 연결한 volume을 UUID로 확인(D-028). 지원 밖 위치의 상태 문구와 안내. Windows에서 쓸 수 없는 이름의 read-only 진단(D-030). 글로벌 Unicode 검증과 이체자 한자 보존(D-031). 영어·일본어·한국어 문구의 제품 현지화. 일회용 volume 검증 도구. 업데이트 방식(D-029 후보)과 App Store sandbox 구조 방향 검토.
- 완료기준: 지원 판정과 근거가 FILESYSTEM_CAPABILITIES.md에 있고 코드·화면과 일치(달성), 안전 계약 약화 없음(달성), Consolidated Gate PASS(달성), ko/en/ja 대표 화면 확인(달성), 사용자 검토와 실제 장치·원어민 확인(대기)
- 대기: 사용자의 결과 검토, 실제 외장 APFS 장치 확인(U21), 영어·일본어 원어민 확인(U23)과 QA.md의 U22·U24·U25. AI가 본 렌더와 test는 Engineering Verification이며 User QA PASS가 아니다.
- 검증: docs/QA.md의 현재 source의 Engineering Verification 상태

### T-003 First-use UX와 화면 구조 단순화 [verificationPending]
- 근원: R-008
- 범위: 빈 상태를 유일한 입력 화면으로, 결과 control은 입력 뒤에만. 사용자 확인 뒤 추가: 전 기능 무료(D-014), 왼쪽 영역을 입력 상태 기반으로(D-016: 입력 없음 → 펼친 navigation, 입력 있음 → 아이콘 레일 + 폴더 트리), 창 chrome 연결과 앱 이름, band 전체 drag, 일괄 변경을 ‘변경 규칙’/‘미리보기’ 2-pane과 ‘+ 규칙 추가’ popover로 재설계, stale 미리보기를 header 상태로 표시. 2차 확인 뒤 추가: 개수·진행·알림을 맨 아래 줄 왼쪽에(D-018), 첫 실행 소개(D-019), 시작 화면 고정(D-020), 일괄 변경의 시작 규칙과 한 줄 control, 사용 방법 화면 재구성, 설정 맨 아래 개발자 카드, 추가한 항목 닫기, band 아래 hosting view 제거로 drag 영역 복구, 앱 아이콘을 Icon Composer 문서로. 기능 삭제 없음. Core는 전체 access provider 추가뿐이고 Application/Infrastructure 변경 없음.
- 완료기준: 빈 화면에 결과용 control 없음, 입력 UI 중복 없음, 왼쪽 영역이 입력 상태를 따라 자동 전환, band 전체 drag, 일괄 변경 두 pane의 시작선 일치와 stale 상태가 layout을 밀지 않음, Pro 표시 없음, 관련 자동 검증 PASS, 사용자 화면 승인
- 대기: 사용자의 화면 확인(docs/QA.md S1~S5). AI가 본 렌더는 Engineering Verification이며 화면 승인이 아니다.
- 검증: docs/QA.md의 First-use UX 구조 단순화 검증 표

### T-002 출시 전 제품 완성도 고도화 [verificationPending]
- 근원: R-008
- 범위: UI/UX·사용자 용어·ko/en/ja·접근성·코드·안정성 리뷰, 확인된 문제 수정, 영향 검증, Release Candidate Ready 판정, User QA 목록 정리
- 완료기준: 확인된 P0/P1 결함 없음, 관련 자동 검증 PASS, User QA 목록이 QA.md 한 곳에 정리됨, 사용자 QA 결과 반영
- 대기: 사용자의 User QA(docs/QA.md U01~U13). AI가 본 렌더와 test는 Engineering Verification이며 User QA PASS가 아니다.
- 검증: docs/QA.md의 현재 Engineering Verification 표

### T-007 Mac App Store 트랙 [onHold]
- 근원: R-010
- 범위: 직접 배포와 분리된 sandbox 구성, build 6 이상, App Store Connect 기록·메타데이터·스크린샷 입력, 업로드와 심사 제출(D-025). 스토어 문구와 화면은 준비돼 있다(marketing/appstore.json, artifacts/marketing).
- 사유: 제출용 배포 인증서와 App Store Connect 인증이 이 Mac에 없다. sandbox 구성은 파일 안전 경계의 기준점과 Journal·설정 구조를 바꾸는 작업이라 설계 승인이 먼저다.
- 조건: 사용자가 Apple Distribution·Mac Installer Distribution 인증서와 App Store Connect 접근을 준비하고, docs/RELEASE.md ‘Mac App Store 트랙’의 sandbox 설계 방향을 승인한다.

## 현재 상태 요약

- 구현: 현재 승인된 앱 기능 범위에서 추가 필수 구현 Task 없음. 확인된 P0/P1 결함 없음.
- 지원 위치: 로컬 writable APFS(내장·외장)에서만 이름을 바꾼다. exFAT·FAT·HFS+·네트워크·cloud 위치는 나열하고 이유를 알린 뒤 그대로 둔다(D-027).
- 알려진 제한: 비협조 외부 writer의 source 교체를 expected-inode 조건으로 원자 차단하지 못한다. 감지·중단·보존·복구 안내는 구현돼 있다. swap/cycle/묶음 파일 그룹은 그룹 도중 취소하면 복구 확인이 필요할 수 있다. 읽을 수 없는 작업 기록이 있으면 Undo/Recovery를 막는다.
- 유료 등급: 없음. 모든 기능을 무료로 제공한다(D-014).
- Release: 출시 보류. 1.0.0 build 5의 공증된 DMG(artifacts/release-candidate/1.0.0/build5-final)는 공개하지 않는 과거 후보로 보존한다(D-026). 다음 후보는 build 6 이상. 웹사이트는 뭉치페이지스가 맡는다(D-025). Mac App Store는 시작하지 않았다(T-007).
- User QA: QA.md의 Q1~Q5와 F1~F5는 사용자가 확인했다. 화면 S1~S5와 U01~U25가 대기 중이며 서명·공증된 앱으로 진행한다.

과거 완료 Task와 날짜별 개발 기록은 이 파일에 누적하지 않는다. 필요하면 Git 이력과 .ai/validation-cache.json의 evidence path를 확인한다.
