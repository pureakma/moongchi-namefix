# Moongchi NameFix 문서 지도

평상시에는 AGENTS.md와 STATUS의 HOT만 읽고, 현재 Task가 요구하는 문서만 On-demand로 읽는다. 과거 완료 이력과 원시 로그는 Cold이며 Git 또는 로컬 evidence에서 확인한다.

| 역할 | 파일 | 언제 읽나 | 언제 갱신 | Context | SSOT |
|---|---|---|---|---|---|
| 제품 목표·범위·요구·현재 승인 범위 | [PROJECT.md](PROJECT.md) | R-ID, 범위, 지원 조건 판단 | 사용자 요구·제품 범위 변경 | On-demand | requirements |
| 현재 상태·현재/다음 Task·Gate | [STATUS.md](STATUS.md) | 매 세션 HOT | 현재 상태나 Task 변경 | HOT | - |
| 확정 제품·기술·운영 결정 | [DECISIONS.md](DECISIONS.md) | D-ID 근거가 필요할 때 | 확정 결정 변경 | On-demand | decisions |
| 실제 코드 책임 경계와 데이터 흐름 | [ARCHITECTURE.md](ARCHITECTURE.md) | 구조/계약 영향 Task | 실제 구조 변경 | On-demand | - |
| UI/UX와 디자인 계약 | [DESIGN.md](DESIGN.md) | 화면/상호작용 Task | UI 계약 변경 | On-demand | - |
| 파일시스템 안전·권한·개인정보 계약 | [FILESYSTEM_CAPABILITIES.md](FILESYSTEM_CAPABILITIES.md) | mutation/권한/안전 Task | 안전 계약 또는 지원 범위 변경 | On-demand | - |
| Engineering Verification·User QA | [QA.md](QA.md) | 검증 범위·QA 판단 | 검증 상태/QA 항목 변경 | On-demand | - |
| 빌드·서명·공증·배포 | [RELEASE.md](RELEASE.md) | Release Task | 배포 사실/정책 변경 | On-demand | - |
| 사용자 기능 안내·패키징 입력 | [EXPANSION_USER_GUIDE.md](EXPANSION_USER_GUIDE.md) | 사용자 문구/패키징 Task | 사용자 동작 변경 | On-demand | - |

루트 README.md는 프로젝트 진입점, AGENTS.md는 AI 실행 규칙이다. ThirdPartyNotices.md와 Resources의 라이선스는 법적 자산, assets/branding/NameFix-Original.png는 현재 앱 아이콘 원본이다. 과거 Windows→macOS handoff와 이전 아이콘은 Git 이력에서만 조회한다.

현재 Active Plan은 별도 PLAN.md가 아니라 PROJECT.md의 현재 승인 범위 한 곳만 사용한다. 별도 Handoff 문서는 만들지 않는다. Git과 STATUS로 재개할 수 있어야 한다.
