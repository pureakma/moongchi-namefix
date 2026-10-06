# Moongchi NameFix 결정

### D-001 macOS 14+ Apple Silicon arm64 전용 [accepted]
- 날짜: 2026-10-04
- 결정: 현재 제품은 macOS 14 이상 Apple Silicon arm64만 지원한다. Intel/Windows/universal2는 현재 범위가 아니다.
- 이유: 현재 project.yml, 빌드·검증 환경과 사용자가 확정한 플랫폼 override를 일치시킨다.

### D-002 SwiftUI + AppKit와 기존 계층 경계 유지 [accepted]
- 날짜: 2026-10-03
- 결정: UI는 SwiftUI + AppKit, 순수 이름/규칙 모델은 NameFixCore, 실행 조정은 Application, 파일시스템·저장은 Infrastructure가 담당한다.
- 이유: 이미 구현·검증된 책임 경계를 유지하고 문서 정비를 이유로 리팩터링하지 않는다.

### D-003 APFS 안전 mutation과 source-race 한계 공개 [accepted]
- 날짜: 2026-10-04
- 결정: local writable APFS만 mutation 대상으로 삼고, no-replace·durable journal·NSFileCoordinator 협조·identity/raw/version 재검사·post-check·보존/Recovery를 사용한다. 비협조 외부 writer의 source 교체를 원자 예방한다고 주장하지 않는다.
- 이유: Darwin의 현재 사용 계약에는 expected-inode 조건부 atomic rename 보장이 없으며 실제 경합 fixture도 이 한계를 재현했다.

### D-004 Free/Pro capability는 구현하되 실제 공급자 미구성 시 fail-closed [accepted]
- 날짜: 2026-10-04
- 결정: Free 기본 이름 정리와 Pro 고급 반복 작업의 capability 경계를 코드에 유지한다. Unconfigured entitlement는 Pro를 허용하지 않으며 Debug 개발 스위치를 실제 구매로 취급하지 않는다.
- 이유: 기능 구현과 실제 판매/영수증 검증을 분리해 권한 우회를 막는다.

### D-005 기본 제품 경로에 AI/OCR/RAG를 넣지 않음 [accepted]
- 날짜: 2026-10-04
- 결정: Unicode 정규화와 현재 이름 변경 엔진은 결정론적 로컬 로직을 사용한다. AI/OCR/RAG는 승인되지 않은 향후 후보이며 현재 mutation 경로에 연결하지 않는다.
- 이유: 정확한 Unicode 처리에 생성 모델이 필요하지 않고, 내용 접근·모델 용량·지연·개인정보 계약을 새로 만들기 때문이다.

### D-006 간편 자소 분리 화면과 일괄 변경 작업실 분리 [accepted]
- 날짜: 2026-10-04
- 결정: 첫 화면은 자소 분리 해결 중심, 고급 규칙은 별도 이름 일괄 변경 작업실로 제공한다. native sidebar와 목적별 도구 메뉴, Olive 기본 + System/Dark/Light, ko/en/ja, 반응형 창을 유지한다.
- 이유: 기존 기능을 숨기지 않으면서 첫 사용 복잡도를 낮춘다.

### D-007 배포 채널은 아직 확정하지 않음 [accepted]
- 날짜: 2026-10-06
- 결정: 현재 source의 App Sandbox는 OFF이고 직접 배포용 Developer ID 흐름이 준비돼 있지만, 최종 판매/배포 채널을 직접 배포 또는 Mac App Store 중 하나로 아직 확정하지 않는다.
- 이유: App Store 선택은 sandbox/entitlement와 판매 공급자 설계에 영향을 주므로 Release Task에서 사용자 결정과 최신 공식 정책 확인이 필요하다.

### D-008 만능프롬프트 Reference는 Bootstrap 기준으로만 사용 [accepted]
- 날짜: 2026-10-06
- 결정: 문서 체계는 만능프롬프트 v2.8, Core 2.8, 기존 프로젝트 Pack 2.5, UIUX 1.2.1, 플랫폼 1.0의 macOS 구역, Development Operations 1.0, doccheck 1.4를 기준으로 정착한다. 이후 평상시 개발은 이 저장소의 AGENTS/PROJECT/STATUS/코드/테스트/Git만으로 진행한다.
- 이유: 외부 Reference를 매 세션 다시 읽는 의존성을 없애고 프로젝트 자체 SSOT를 유지한다.

### D-009 과거 문서 대신 Git 이력을 사용 [accepted]
- 날짜: 2026-10-06
- 결정: 날짜별 개발 보고서, 옛 계획, StartPrompt, Project Master의 현재 유효 정보는 새 SSOT로 이관하고 중복 파일은 삭제한다. 별도 archive/backup/old 개발문서를 만들지 않는다.
- 이유: 현재 판단 원본을 하나로 줄이고 과거 이력은 Git에서 복구할 수 있다.
