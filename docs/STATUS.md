# STATUS — Moongchi NameFix

<!-- HOT:START -->
## 지금
- 단계: v1.0 앱 개발 완료 · 출시/판매 단계 보류
- 현재 Task: 없음
- 다음: 사용자 승인 시 T-001 재개
- 위험·막힘: D-003의 비협조 writer source-race 알려진 제한, 실제 Pro 공급자/출시 입력 미확정
- 검증 대기: docs/QA.md의 User QA 묶음, 현재 source 전체 Release Gate
- 마지막 갱신: 2026-10-06
<!-- HOT:END -->

## 현재 Milestone

현재 실행 중인 제품 Milestone은 없다. 제품 코드를 자동으로 이어서 개발하지 않는다.

### T-001 출시 단계 입력 확정 [onHold]
- 근원: R-010
- 사유: Store/직접 배포 선택, 실제 판매 방식·상품 ID·검증 공급자, 출시용 bundle ID, 공증 프로필, User QA 수행 시점이 사용자 결정/외부 입력을 기다린다.
- 조건: 사용자가 출시 단계 범위와 배포/판매 방식을 승인하고 필요한 입력을 제공한다.
- 완료기준: 승인된 배포 채널·판매 경계·출시 식별자·공증 방법·User QA Gate가 PROJECT/DECISIONS/RELEASE에 확정되고 실제 Release Task를 별도로 생성할 수 있다.
- 검증: 문서 일치와 사람 Gate 확인. 이 Task 자체는 제품 build/test를 요구하지 않는다.

## 현재 상태 요약

- 구현: 현재 승인된 앱 기능 범위에서 추가 필수 구현 Task 없음.
- 알려진 제한: 비협조 외부 writer의 source 교체를 expected-inode 조건으로 원자 차단하지 못한다. 감지·중단·보존·복구 안내는 구현돼 있다.
- 유료: Pro 기능 경계는 구현됐지만 실제 구매/활성화 공급자는 미연결이다. Release에서는 fail-closed Free 동작이 기준이다.
- Release: 과거 build3 후보의 Release/서명/패키지 증거는 후속 UI·리소스 변경으로 현재 source 전체 PASS가 아니다. 새 Release 단계에서 다시 만들어야 한다.
- User QA: 실제 Finder/Services/TCC/접근성/sleep·quit/macOS14/깨끗한 Mac 등은 QA 문서에서 대기한다.

과거 완료 Task와 날짜별 개발 기록은 이 파일에 누적하지 않는다. 필요하면 Git 이력과 .ai/validation-cache.json의 evidence path를 확인한다.
