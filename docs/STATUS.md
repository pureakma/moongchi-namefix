# STATUS — Moongchi NameFix

<!-- HOT:START -->
## 지금
- 단계: First-use UX 구조 단순화 구현 완료 · 사용자의 화면 확인 대기
- 현재 Task: T-003 (verificationPending), T-002 (verificationPending)
- 다음: 사용자가 docs/QA.md의 화면 S1~S5를 확인 → 지적 사항은 bug/수정 Task, 승인되면 U01~U13 진행 후 T-001 재개
- 위험·막힘: D-003의 비협조 writer source-race 알려진 제한, 출시 입력(배포 채널·bundle ID·공증) 미확정
- 검증 대기: docs/QA.md의 화면 S1~S5와 User QA U01~U13, 새 Release Task의 서명·공증·패키지
- 마지막 갱신: 2026-10-06
<!-- HOT:END -->

## 현재 Milestone

출시 전 제품 완성도 고도화와 그 뒤 사용자가 지적한 first-use 화면 구조 단순화. 구현과 Engineering Verification은 끝났고 사용자 확인만 남았다. 화면 구조는 사용자가 아직 승인하지 않았다. 그 밖의 제품 코드를 자동으로 이어서 개발하지 않는다.

### T-003 First-use UX와 화면 구조 단순화 [verificationPending]
- 근원: R-008
- 범위: 빈 상태를 유일한 입력 화면으로, 결과 control은 입력 뒤에만. 사용자 확인 뒤 추가: 전 기능 무료(D-014), 왼쪽 영역을 입력 상태 기반으로(D-016: 입력 없음 → 펼친 navigation, 입력 있음 → 아이콘 레일 + 폴더 트리), 창 chrome 연결과 앱 이름, band 전체 drag, 일괄 변경을 ‘변경 규칙’/‘미리보기’ 2-pane과 ‘+ 규칙 추가’ popover로 재설계, stale 미리보기를 header 상태로 표시. 기능 삭제 없음. Core는 전체 access provider 추가뿐이고 Application/Infrastructure 변경 없음.
- 완료기준: 빈 화면에 결과용 control 없음, 입력 UI 중복 없음, 왼쪽 영역이 입력 상태를 따라 자동 전환, band 전체 drag, 일괄 변경 두 pane의 시작선 일치와 stale 상태가 layout을 밀지 않음, Pro 표시 없음, 관련 자동 검증 PASS, 사용자 화면 승인
- 대기: 사용자의 화면 확인(docs/QA.md S1~S5). AI가 본 렌더는 Engineering Verification이며 화면 승인이 아니다.
- 검증: docs/QA.md의 First-use UX 구조 단순화 검증 표

### T-002 출시 전 제품 완성도 고도화 [verificationPending]
- 근원: R-008
- 범위: UI/UX·사용자 용어·ko/en/ja·접근성·코드·안정성 리뷰, 확인된 문제 수정, 영향 검증, Release Candidate Ready 판정, User QA 목록 정리
- 완료기준: 확인된 P0/P1 결함 없음, 관련 자동 검증 PASS, User QA 목록이 QA.md 한 곳에 정리됨, 사용자 QA 결과 반영
- 대기: 사용자의 User QA(docs/QA.md U01~U13). AI가 본 렌더와 test는 Engineering Verification이며 User QA PASS가 아니다.
- 검증: docs/QA.md의 현재 Engineering Verification 표

### T-001 출시 단계 입력 확정 [onHold]
- 근원: R-010
- 사유: Store/직접 배포 선택, 출시용 bundle ID, 공증 프로필, User QA 수행 시점이 사용자 결정/외부 입력을 기다린다. 전 기능 무료이므로 판매 방식·상품·구매 공급자 결정은 필요 없다.
- 조건: 사용자가 출시 단계 범위와 배포 방식을 승인하고 필요한 입력을 제공한다.
- 완료기준: 승인된 배포 채널·출시 식별자·공증 방법·User QA Gate가 PROJECT/DECISIONS/RELEASE에 확정되고 실제 Release Task를 별도로 생성할 수 있다.
- 검증: 문서 일치와 사람 Gate 확인. 이 Task 자체는 제품 build/test를 요구하지 않는다.

## 현재 상태 요약

- 구현: 현재 승인된 앱 기능 범위에서 추가 필수 구현 Task 없음. 확인된 P0/P1 결함 없음.
- 알려진 제한: 비협조 외부 writer의 source 교체를 expected-inode 조건으로 원자 차단하지 못한다. 감지·중단·보존·복구 안내는 구현돼 있다. swap/cycle/묶음 파일 그룹은 그룹 도중 취소하면 복구 확인이 필요할 수 있다. 읽을 수 없는 작업 기록이 있으면 Undo/Recovery를 막는다.
- 사용자 결정 대기: 일괄 변경 규칙이 추가한 폴더 자체·하위 폴더·숨김 파일도 기본 대상으로 삼는 현재 동작을 유지할지, 즐겨찾기 폴더 기능을 넣을지(PROJECT.md 백로그 후보).
- 유료 등급: 없음. 모든 기능을 무료로 제공한다(D-014).
- Release: 현재 source의 Release 구성 build는 성공했다. 배포 후보 생성·서명·공증·패키징은 새 Release Task에서 수행한다.
- User QA: QA.md의 화면 S1~S5와 U01~U13이 대기 중이다.

과거 완료 Task와 날짜별 개발 기록은 이 파일에 누적하지 않는다. 필요하면 Git 이력과 .ai/validation-cache.json의 evidence path를 확인한다.
