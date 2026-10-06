# Feature Complete Gate

> **최신 v1.0 후보 결과:** [V1_RELEASE_STATUS.md](V1_RELEASE_STATUS.md). 아래 내용은 이전 단계 증거로 보존하며 최신 Release/서명/패키지 상태는 후속 보고서를 따른다.

무료·Pro 확장 P0~P9는 [EXPANSION_PLAN.md](EXPANSION_PLAN.md), 구현 상태는 [EXPANSION_TASKS.md](EXPANSION_TASKS.md)가 기준이다. 확장 독립 기능은 구현했으나 SOURCE_RACE가 남아 전체 완료 Gate는 BLOCKED_CONTRACT다. 최신 직접 검증은 EXPANSION_DEVELOPMENT.md를 참조하며 아래 과거 Release 기록은 재사용하지 않는다.

2026-10-04 후속 앱 자체 검토: [COMMERCIAL_REVIEW.md](COMMERCIAL_REVIEW.md). 새 수정본은 Debug 검증만 수행했다. 아래 Release/패키지 Gate는 이전 기준선의 기록이며 현재 수정본 전체의 검증으로 재사용하지 않는다.

판정 대상: macOS 14+ Apple Silicon arm64 전용 1.0.0 (1). 인수인계 Windows/Intel 요구는 사용자 override로 제외한다.

현재 상태(2026-10-04): 기능 구현 및 Phase 0~5 로컬 Gate 완료, 실제 arm64 app/ZIP/DMG 생성. 실행 가능한 자동 범위 AUTO-QA PASS: 고유 테스트 28개 통과, 최종 Release/리소스/패키지 검증 완료. 수동·실기·서명 Gate와 source-race 출시 blocker는 별도이며 공개 출시 승인이 아니다.

| 범위 | 구현 및 근거 | 별도 Gate |
|---|---|---|
| MAC-F01~03 입력·재귀·보호 | NSOpenPanel, 전체 NSHostingView native drop, Dock/Services 단일 입력; no-follow/package/mount 보호; fixture tests | Finder 실제 제스처/TCC 수동 |
| MAC-F04 Unicode | 5문자권 canonical trap, Data raw identity, Mixed/invalid/emoji fixture | 없음 |
| MAC-F05~07 선택·검색·정렬 | generation, 180ms debounce, background filter/sort, hidden selections, stable ID; 앱 모델 테스트 | 100k 실제 화면 latency 수동 |
| MAC-F08~10 충돌·번호·실행 | exclusive destination, 번호 예약, fresh Plan, 명시 확인, 하위→상위, 취소, 실제 raw 검증 | 외부 source 교체 race는 플랫폼 출시 blocker |
| MAC-F11~13 기록·Undo·Recovery | durable hash-chain JSONL, summary lazy detail, current path mapping, 부분 Undo, hardlink 개별 operation, 복구 preview | 실제 프로세스 kill/전원 차단 미검증 |
| MAC-F14~17 Inspector·Clipboard·최근·진단 | 4 forms/scalar/UTF16, grapheme-safe4096, opt-in10개, 경로 없는 로그/마스킹 export preview | clipboard OS 사용 수동 |
| MAC-F18 설정 | serialized atomic save, corrupt backup, newer schema read-only, 최근 off 삭제; 앱 모델 테스트 | 권한/TCC 별도 |
| MAC-F19 UI | SwiftUI/AppKit, Dark 기본/Light/System/Olive, 210키×ko/en/ja, process-local fonts, 16 offscreen render | native titlebar/VoiceOver/키보드/큰글자 수동 |
| MAC-F20 패키지 | arm64 Release, ad-hoc QA app, ZIP/DMG, build/test/sign-notary/verify scripts | Developer ID·공증·macOS14 실기 |
| MAC-F21 Finder Services | Info.plist NSServices + inspectNames provider | 실제 설치된 Finder Services 수동 |

Phase 0/1: 실제 APFS raw lookup/no-replace 및 Core tests. Phase 2/3: 임시 fixture scan→preview→rename→undo/복구와 hash/xattr/중첩/hardlink. Phase 4: UI state tests, resource parity, off-screen renders. Phase 5: Release/패키지 로그.

최종 실행 결과 및 한계는 AUTOMATED_QA_REPORT.md가 기준이다. 구현 완료, 자동 검증 완료, 실제 화면 QA, 공개 출시 가능을 서로 다른 상태로 기록한다.
