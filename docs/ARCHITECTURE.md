# 아키텍처

이 문서는 현재 구현된 책임 경계만 설명한다. 미래 설계를 현재 구현처럼 기록하지 않는다.

## 플랫폼 기준

- macOS 14 이상, Apple Silicon arm64
- Swift 6 strict concurrency
- SwiftUI + AppKit
- Foundation/Darwin 파일시스템 API
- 현재 App Sandbox OFF, Hardened Runtime ON
- 제품 version 설정 1.0.0 build 3, development bundle ID com.moongchi.namefix.dev

## 책임 경계

| 경계 | 책임 | 외부에서 쓰는 계약 | 주요 검증 |
|---|---|---|---|
| App | SwiftUI 화면, AppKit 창/toolbar/sidebar/menu, 입력, sheet, 접근성·표시 상태 | AppModel/Application API | UIModelTests, focused render/build |
| Application | fresh Plan, Rule Preview, selection/numbering, Undo/Recovery preview, watch snapshot | NameFixCore 모델 + Infrastructure 서비스 | Integration/UI model |
| Packages/NameFixCore | raw 이름/경로 모델, Unicode 정규화, RulePipeline, entitlement, CSV/name mapping 순수 로직 | Foundation 값 모델 | NameFixCore tests |
| Infrastructure | scan, raw filesystem access, FileCoordination, transaction/graph transaction, journal, metadata, settings, recipe/watch store, diagnostics | Application이 호출하는 저장/실행 API | Integration/Safety/Transaction |
| CLI | dry-run, 구조화 출력, 대화형 실행/Undo | Application/Infrastructure와 동일 safety/capability | CLI fixture |
| Resources | Localizable.xcstrings, ko/en/ja runtime strings, fonts, asset catalog | App UI | validate-resources.py |

의존 방향은 App/CLI → Application → Core와 Infrastructure다. Core는 UI에 의존하지 않는다. 새 기능이 이 경계를 바꾸면 구조 변경 Gate로 취급한다.

## Scan과 Preview

Scanner는 실제 디렉터리 entry의 raw 이름과 identity를 보존한다. Swift String의 canonical equality만으로 NFC/NFD 차이를 판단하지 않는다. 규칙/필터/정렬/대형 parse는 가능한 한 background worker에서 수행하고 generation/cancellation으로 늦은 결과를 버린다.

일반 이름 검사에는 사용자 파일 내용이 필요하지 않다. 메타데이터 규칙을 명시적으로 선택했을 때만 MetadataReader가 지원 형식의 제한된 metadata를 읽기 전용으로 추출한다.

## Mutation

실행은 fresh Plan을 다시 확인하고 사용자의 최종 확인 뒤 시작한다. TransactionCoordinator와 process lock이 동시에 여러 mutation 경로가 실행되지 않게 한다.

기본 이동:
1. Prepared/intent를 durable journal에 기록
2. source와 parent의 raw path/identity/version 재검사
3. source → unique temporary를 no-replace로 이동
4. final intent 확인
5. temporary → final을 no-replace로 이동
6. 이동 뒤 identity/raw 결과 확인
7. verified 결과를 journal에 기록

swap/cycle과 파일 쌍은 GraphTransaction이 그룹 전체 intent를 먼저 기록하고 staging 후 final을 적용한다. 전체 그룹의 원자 성공을 보장하지 않으며 부분 실패는 실제 위치와 journal을 보존해 Recovery 대상으로 넘긴다.

FileCoordination은 협조 writer와 이동을 조정하며 대기 취소/timeout을 지원한다. 비협조 writer 원자 차단 한계는 FILESYSTEM_CAPABILITIES.md가 원본이다.

## Undo와 Recovery

Undo는 과거 문자열을 바로 덮어쓰지 않고 현재 identity/path를 확인한 새 역 Plan이다. verified operation과 이동 기록으로 현재 경로를 추적하고, identity가 불명확한 항목을 추측해 자동 복원하지 않는다.

Journal schema 2는 swap/group 이벤트를 표현한다. schema 1은 읽기 호환을 유지하며, schema 2를 모르는 이전 앱이 새 기록을 안전한 Undo로 오해하지 않도록 한다. 성공 journal은 이후 Undo/경로 해석에 필요하면 일반 보존 한도를 넘어 유지할 수 있다.

## 설정과 로컬 저장

- 설정: serialized atomic save, 손상 원본 보존, 새 schema 안전 처리
- 창 배치: 별도 versioned key로 일반 window frame/screen을 저장
- 프리셋/감시: actor 기반 atomic store, size/schema 제한, 손상 원본 보존
- watch: FSEvents는 발견/대기열 역할이며 이벤트만으로 rename하지 않는다. 사용자 review snapshot 이후 mutation한다.
- 진단 로그와 mutation journal은 별개다. 기본 진단에 경로/clipboard/파일 내용을 넣지 않는다.

## Free/Pro와 CLI

capability 검사는 UI뿐 아니라 Application/CLI/watch/preset 경로에도 적용한다. 실제 구매 공급자가 없으면 Release는 Free로 닫힌다. Pro 만료/철회가 Undo나 기존 데이터 보존을 파괴하지 않는다.

CLI는 기본 dry-run이며 실제 변경은 execute 요청과 터미널 최종 확인을 요구한다. 무인 force mutation 경로를 제공하지 않고 GUI와 process lock/History를 공유한다.

## 리소스 생성

Resources/Localizable.xcstrings가 runtime 번역 원본이다. eng/resources.py는 초기 handoff의 LOCALIZATION_CATALOG.md와 eng/expansion-localizations.json을 입력으로 사용해 ko/en/ja 리소스를 생성하고 bundled font를 복사한다.

Moongchi_NameFix_macOS_Dev_Handoff_v1.0은 이 리소스 생성과 hash 검증에 필요한 provenance package이므로 현재 제품 요구/계획 SSOT로 읽지 않는다.
