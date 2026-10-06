# STATUS — Moongchi NameFix

<!-- HOT:START -->
## 지금
- 단계: 1.0.0 build 5 Developer ID 서명 완료 · 공증은 notarytool profile 생성 대기(NEEDS_CREDENTIAL_SETUP)
- 현재 Task: T-003 (verificationPending), T-002 (verificationPending)
- 다음: 사용자가 로컬 터미널에서 notarytool profile(권장 이름 NameFix-Notary)을 만들면 T-006을 이어서 진행: 공증 → staple → DMG/ZIP → DMG 공증 → Gatekeeper → 최종 검증
- 위험·막힘: 공증용 자격 증명 없음(저장된 profile MoongchiNotaryRC는 Apple에서 401로 거부됨). D-003의 비협조 writer source-race 알려진 제한
- 검증 대기: 공증·staple·Gatekeeper·DMG의 새 evidence, 깨끗한 Mac 설치, docs/QA.md의 화면 S1~S5와 User QA U01~U19
- 마지막 갱신: 2026-10-06
<!-- HOT:END -->

## 현재 Milestone

출시 전 제품 완성도 고도화와 그 뒤 사용자가 지적한 first-use 화면 구조 단순화. 구현과 Engineering Verification은 끝났고 사용자 확인만 남았다. 화면 구조는 사용자가 아직 승인하지 않았다. 그 밖의 제품 코드를 자동으로 이어서 개발하지 않는다.

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

### T-006 Release 2차: Developer ID 서명·공증·DMG [onHold]
- 근원: R-010
- 사유: Developer ID 서명은 끝났다(build5-signed-r2). 공증에 쓸 notarytool Keychain profile이 없다. 저장돼 있던 profile은 Apple에서 자격 증명 오류로 거부된다.
- 조건: 사용자가 로컬 터미널에서 notarytool profile을 만들고 계속 진행을 알린다(자격 증명은 채팅에 보내지 않는다).
- 완료기준: build5 서명 전 후보의 사본을 Developer ID로 서명, 공증 성공과 staple, 서명된 앱의 DMG 공증, Gatekeeper 평가, 깨끗한 Mac 설치·실행, QA.md의 User QA 반영
- 검증: docs/RELEASE.md의 2차 순서와 새 evidence

### T-001 출시 단계 입력 확정 [completed]
- 근원: R-010
- 범위: 배포 채널, 출시 식별자, Release 구성 확정과 현재 source의 서명 전 후보 준비(Release Preparation 1차)
- 완료기준: 승인된 배포 채널·출시 식별자가 PROJECT/DECISIONS/RELEASE에 확정되고 실제 Release Task를 별도로 생성할 수 있다.
- 근거: D-023, artifacts/release-candidate/1.0.0/build5-pre-sign, MAC-RELEASE-PREP15-BUILD5-20261006(docs/QA.md). 공증 방법의 남은 입력은 T-006으로 넘김
- 검증: docs/QA.md의 Release Preparation 1차 검증

## 현재 상태 요약

- 구현: 현재 승인된 앱 기능 범위에서 추가 필수 구현 Task 없음. 확인된 P0/P1 결함 없음.
- 알려진 제한: 비협조 외부 writer의 source 교체를 expected-inode 조건으로 원자 차단하지 못한다. 감지·중단·보존·복구 안내는 구현돼 있다. swap/cycle/묶음 파일 그룹은 그룹 도중 취소하면 복구 확인이 필요할 수 있다. 읽을 수 없는 작업 기록이 있으면 Undo/Recovery를 막는다.
- 유료 등급: 없음. 모든 기능을 무료로 제공한다(D-014).
- Release: 1.0.0 build 5를 Developer ID로 서명했다(com.ailoworks.namefix, 팀 25373G7846). 공증·staple·DMG·공개 배포는 하지 않았다(T-006, 자격 증명 대기).
- User QA: QA.md의 Q1~Q5와 F1~F5는 사용자가 확인했다. 화면 S1~S5와 U01~U19가 대기 중이며 서명·공증된 앱으로 진행한다.

과거 완료 Task와 날짜별 개발 기록은 이 파일에 누적하지 않는다. 필요하면 Git 이력과 .ai/validation-cache.json의 evidence path를 확인한다.
