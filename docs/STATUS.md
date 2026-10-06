# STATUS — Moongchi NameFix

<!-- HOT:START -->
## 지금
- 단계: 출시 전 제품 완성도 고도화 완료 · 앱 자체 기준 Release Candidate Ready · User QA 대기
- 현재 Task: T-002 (verificationPending)
- 다음: 사용자가 docs/QA.md의 User QA 목록을 확인 → 실패 항목은 bug Task, 통과 시 사용자 승인으로 T-001 재개
- 위험·막힘: D-003의 비협조 writer source-race 알려진 제한, 실제 Pro 공급자/출시 입력 미확정
- 검증 대기: docs/QA.md의 User QA U01~U13, 새 Release Task의 서명·공증·패키지
- 마지막 갱신: 2026-10-06
<!-- HOT:END -->

## 현재 Milestone

출시 전 제품 완성도 고도화. 구현과 Engineering Verification은 끝났고 사용자 확인만 남았다. 그 밖의 제품 코드를 자동으로 이어서 개발하지 않는다.

### T-002 출시 전 제품 완성도 고도화 [verificationPending]
- 근원: R-008
- 범위: UI/UX·사용자 용어·ko/en/ja·접근성·코드·안정성 리뷰, 확인된 문제 수정, 영향 검증, Release Candidate Ready 판정, User QA 목록 정리
- 완료기준: 확인된 P0/P1 결함 없음, 관련 자동 검증 PASS, User QA 목록이 QA.md 한 곳에 정리됨, 사용자 QA 결과 반영
- 대기: 사용자의 User QA(docs/QA.md U01~U13). AI가 본 렌더와 test는 Engineering Verification이며 User QA PASS가 아니다.
- 검증: docs/QA.md의 현재 Engineering Verification 표

### T-001 출시 단계 입력 확정 [onHold]
- 근원: R-010
- 사유: Store/직접 배포 선택, 실제 판매 방식·상품 ID·검증 공급자, 출시용 bundle ID, 공증 프로필, User QA 수행 시점이 사용자 결정/외부 입력을 기다린다.
- 조건: 사용자가 출시 단계 범위와 배포/판매 방식을 승인하고 필요한 입력을 제공한다.
- 완료기준: 승인된 배포 채널·판매 경계·출시 식별자·공증 방법·User QA Gate가 PROJECT/DECISIONS/RELEASE에 확정되고 실제 Release Task를 별도로 생성할 수 있다.
- 검증: 문서 일치와 사람 Gate 확인. 이 Task 자체는 제품 build/test를 요구하지 않는다.

## 현재 상태 요약

- 구현: 현재 승인된 앱 기능 범위에서 추가 필수 구현 Task 없음. 확인된 P0/P1 결함 없음.
- 알려진 제한: 비협조 외부 writer의 source 교체를 expected-inode 조건으로 원자 차단하지 못한다. 감지·중단·보존·복구 안내는 구현돼 있다. swap/cycle/묶음 파일 그룹은 그룹 도중 취소하면 복구 확인이 필요할 수 있다. 읽을 수 없는 작업 기록이 있으면 Undo/Recovery를 막는다.
- 사용자 결정 대기: 일괄 변경 규칙이 추가한 폴더 자체·하위 폴더·숨김 파일도 기본 대상으로 삼는 현재 동작을 유지할지(PROJECT.md 백로그 후보).
- 유료: Pro 기능 경계는 구현됐지만 실제 구매/활성화 공급자는 미연결이다. Release에서는 fail-closed Free 동작이 기준이며 화면에는 Pro 표기가 그대로 보인다.
- Release: 현재 source의 Release 구성 build는 성공했다. 배포 후보 생성·서명·공증·패키징은 새 Release Task에서 수행한다.
- User QA: QA.md의 U01~U13이 대기 중이다.

과거 완료 Task와 날짜별 개발 기록은 이 파일에 누적하지 않는다. 필요하면 Git 이력과 .ai/validation-cache.json의 evidence path를 확인한다.
