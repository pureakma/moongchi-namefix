# 아키텍처

이 문서는 현재 구현된 책임 경계만 설명한다. 미래 설계를 현재 구현처럼 기록하지 않는다.

## 플랫폼 기준

- macOS 14 이상, Apple Silicon arm64
- Swift 6 strict concurrency
- SwiftUI + AppKit
- Foundation/Darwin 파일시스템 API
- 현재 App Sandbox OFF, Hardened Runtime ON
- 제품 version 설정 1.0.0 build 4. bundle ID는 Release 구성 com.ailoworks.namefix, Debug 구성 com.moongchi.namefix.dev(project.yml이 원본). 앱 정보 화면과 진단 보고서는 번들의 version/build 값을 읽는다. 설정·작업 기록 폴더는 bundle ID와 무관하게 Application Support/Moongchi/NameFix다.

## 책임 경계

| 경계 | 책임 | 외부에서 쓰는 계약 | 주요 검증 |
|---|---|---|---|
| App | SwiftUI 화면, AppKit 창/toolbar/sidebar/menu, 입력, sheet, 접근성·표시 상태 | AppModel/Application API | UIModelTests, focused render/build |

App의 render·창 진단 fixture(App/*Fixtures.swift)와 그 실행 flag는 Debug build에서만 compile된다. Release binary에는 리소스 self-test(--self-test)만 남는다. 결과 목록의 표시 순서는 목록과 정렬 기준이 바뀔 때만 main thread 밖에서 계산하고, 필터·검색은 그 순서를 재사용한다.
| Application | fresh Plan, Rule Preview, selection/numbering, Undo/Recovery preview, watch snapshot | NameFixCore 모델 + Infrastructure 서비스 | Integration/UI model |
| Packages/NameFixCore | raw 이름/경로 모델, Unicode 정규화, RulePipeline, entitlement, CSV/name mapping 순수 로직 | Foundation 값 모델 | NameFixCore tests |
| Infrastructure | scan, raw filesystem access, FileCoordination, transaction/graph transaction, journal, metadata, settings, recipe/watch store, diagnostics | Application이 호출하는 저장/실행 API | Integration/Safety/Transaction |
| CLI | dry-run, 구조화 출력, 대화형 실행/Undo | Application/Infrastructure와 동일 safety/capability | CLI fixture |
| Resources | Localizable.xcstrings, ko/en/ja runtime strings, fonts, asset catalog | App UI | validate-resources.py |

의존 방향은 App/CLI → Application → Core와 Infrastructure다. Core는 UI에 의존하지 않는다. 새 기능이 이 경계를 바꾸면 구조 변경 Gate로 취급한다.

## 외부 입력

파일/폴더 picker, Finder drag & drop, Dock/Open With/Services 입력은 하나의 입력 정규화 경로로 모은다. 입력은 사용자가 선택한 실제 file URL로 제한하며 HTTP URL이나 임의 문자열을 shell command로 해석하지 않는다. Rename/Undo/Recovery 중 새 mutation 입력은 안전 상태를 우회하지 않는다.

Clipboard는 사용자가 붙여넣기/분석을 명시했을 때만 읽고 자동 감시하지 않으며 파일 경로로 추측해 Rename하지 않는다.

## Scan과 Preview

Scanner는 실제 디렉터리 entry의 raw 이름과 identity를 보존한다. Swift String의 canonical equality만으로 NFC/NFD 차이를 판단하지 않는다. 규칙/필터/정렬/대형 parse는 가능한 한 background worker에서 수행하고 generation/cancellation으로 늦은 결과를 버린다.

경로를 키로 쓰는 집합·사전은 RawPath의 전체 바이트 해시를 사용한다. 같은 폴더의 형제 경로는 앞부분이 같으므로 앞쪽 일부만 해시하는 키를 쓰지 않는다.

규칙 Preview는 Finder 관리 파일(.DS_Store, .localized)을 변경 대상에서 빼고 순번도 배정하지 않는다. 폴더는 하위 항목 이름이 바뀌면 수정 시각이 달라지므로 scan과 규칙 Preview 모두 일반 파일에만 content version을 기록한다.

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

취소는 항목 경계에서 적용한다. 기본 이동에서 source → temporary가 끝난 항목은 취소 요청이 와도 final까지 마친 뒤 다음 항목 전에 멈추므로, 취소만으로 임시 이름에 항목이 남지 않는다. 조정 대기 시간 초과나 외부 변경 감지는 종전대로 중단하고 Recovery로 넘긴다.

swap/cycle과 파일 쌍은 GraphTransaction이 그룹 전체 intent를 먼저 기록하고 staging 후 final을 적용한다. 전체 그룹의 원자 성공을 보장하지 않으며 부분 실패는 실제 위치와 journal을 보존해 Recovery 대상으로 넘긴다. 그룹 staging 도중의 취소도 같은 경로를 따른다. 아무것도 옮기기 전에 그룹이 실패하면 종료 이벤트를 journal에 남겨 앞서 완료된 그룹이 미완료로 보이지 않게 한다.

FileCoordination은 협조 writer와 이동을 조정하며 대기 취소/timeout을 지원한다. 비협조 writer 원자 차단 한계는 FILESYSTEM_CAPABILITIES.md가 원본이다.

## Undo와 Recovery

Undo는 과거 문자열을 바로 덮어쓰지 않고 현재 identity/path를 확인한 새 역 Plan이다. verified operation과 이동 기록으로 현재 경로를 추적하고, identity가 불명확한 항목을 추측해 자동 복원하지 않는다.

Journal schema 2는 swap/group 이벤트를 표현한다. schema 1은 읽기 호환을 유지하며, schema 2를 모르는 이전 앱이 새 기록을 안전한 Undo로 오해하지 않도록 한다. 성공 journal은 이후 Undo/경로 해석에 필요하면 일반 보존 한도를 넘어 유지할 수 있다.

## 설정과 로컬 저장

- 설정: serialized atomic save, 손상 원본 보존, 새 schema 안전 처리
- 창 배치: 별도 versioned key로 일반 window frame/screen을 저장
- 프리셋/감시: actor 기반 atomic store, size/schema 제한, 손상 원본 보존. 저장 시에도 읽기와 같은 크기 한도를 적용하고, 저장하는 규칙에서 현재 세션의 수동 순서 경로는 제거한다.
- watch: FSEvents는 발견/대기열 역할이며 이벤트만으로 rename하지 않는다. 사용자 review snapshot 이후 mutation한다.
- 진단 로그와 mutation journal은 별개다. 기본 진단에 경로/clipboard/파일 내용을 넣지 않는다.

## Access와 CLI

제품에는 유료 등급이 없다. 앱과 CLI는 FullAccessEntitlementProvider로 항상 전체 access를 받는다. 규칙 집합을 access 수준에 대해 검증하는 capability 검사는 Application/CLI/watch/preset 경로에 그대로 남아 있으며, test는 다른 provider를 주입해 이 검사를 확인한다. access가 낮아지는 경우에도 Undo와 기존 데이터 보존은 영향을 받지 않는다.

## sidebar 트리

FolderTree는 scan 결과의 폴더 항목과 추가한 위치로 트리를 만든다. 각 노드는 그 아래의 변경 가능한 항목 수를 가진다. 트리는 scan 결과를 만드는 background 작업에서 함께 계산한다. 노드 선택은 목록 필터(folderFilter)일 뿐이며 선택 집합과 Plan에는 영향을 주지 않는다. 폴더 밖의 선택 항목은 ‘숨은 선택’으로 집계돼 확인 시트에 그대로 경고된다.

CLI는 기본 dry-run이며 실제 변경은 execute 요청과 터미널 최종 확인을 요구한다. 무인 force mutation 경로를 제공하지 않고 GUI와 process lock/History를 공유한다.

## 리소스 생성

Resources/Localizable.xcstrings가 번역의 단일 SSOT다. eng/resources.py는 이 catalog에서 ko/en/ja runtime .strings와 InfoPlist.strings(Finder 서비스 이름, 데스크탑·문서·다운로드 폴더 접근 권한 안내)를 재생성한다.

Pretendard Variable과 Pretendard JP Variable의 실제 앱 자산·라이선스는 Resources/ 한 곳만 유지한다. Windows→macOS 초기 handoff, 별도 localization JSON, 중복 폰트 사본에 빌드나 검증이 의존하지 않는다.
