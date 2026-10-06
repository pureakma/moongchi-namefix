# 아키텍처

아래는 현재 구현된 구조다. 무료·Pro 확장 설계는 [EXPANSION_PLAN.md](EXPANSION_PLAN.md)의 구조와 데이터 모델을 따른다. 신규 규칙·메타데이터·권한·감시·CLI 구조를 아래 확장 구현 절에 기록했다. 메타데이터 규칙의 명시적 읽기 전용 추출은 신규 범위이며 기존 기본 검사의 이름 전용 경로는 유지한다.

## 적용 범위
사용자의 2026-10-03 지시가 인수인계 CPU 요구사항에 우선한다. macOS 14+ Apple Silicon arm64 전용. Swift 6 strict concurrency, SwiftUI + AppKit, Darwin FS. Intel/Windows/universal2는 구현·검증 대상이 아니다.

## 경계
- App: SwiftUI 표/설정/sheet와 AppKit 창·메뉴·NSOpenPanel·전체 창 드롭·Services. 실제 파일 작업은 Application/Infrastructure에 위임한다.
- Application: fresh Plan, 번호 예약, Undo/Recovery preview, 실제 검증된 이력의 경로 추적.
- NameFixCore 독립 Swift package: Data 기반 raw path/name identity, Unicode 정규화, 순수 모델, 번호 규칙.
- Infrastructure: no-follow descriptor 탐색, APFS capability, readdir 원시 이름, exclusive rename, durable journal, 설정 actor, 경로 없는 진단 로그.

## 실행과 성능
Scanner와 검색/정렬, Plan, history decode는 background Task에서 실행한다. Scanner 동시성 1로 I/O 폭주를 제한하고 부모별 directory index를 재사용하고 descriptor cache를 최대64개로 제한한다. F_GETPATH로 raw 부모 spelling을 보존해 canonical lookup alias 입력도 중복 제거한다. 일반 파일의 FinderInfo는 getattrlistat으로 조회해 대량 URL resource cache 생성을 피한다. UI는 generation을 확인한 결과만 받으며 검색은 180ms debounce. SwiftUI Table/List는 native virtualization을 사용한다. Inspector의 scalar/UTF-16은 선택된 항목만 계산한다. 실제 100k 측정은 QA 보고서에 별도 기록한다.

TransactionCoordinator actor의 동기 메서드와 flock 프로세스 잠금을 함께 사용한다. 취소는 항목 사이에서 처리한다. Prepared/FinalIntent를 F_FULLFSYNC까지 기록한 뒤 두 단계 RENAME_EXCL을 사용한다. 검증된 raw spelling + birth time/device/inode를 journal에 기록한다. JSON Data는 base64이다. 기본 검사는 파일 내용을 읽거나 해시하지 않는다. 명시적으로 켠 메타데이터 규칙은 읽기 전용 provider를 사용한다.

## Undo와 보존
Verified operation UUID는 원래 path/identity와 함께 역 Plan에 연결된다. 이후 Verified 이동을 시간순으로 반영한다. 역 Plan은 현재 raw 경로를 해석하고 하위부터 되돌린다. 같은 부모의 교환은 동시 경로 매핑으로 처리한다. 두 hardlink는 서로 다른 operation/path로 추적한다. 손상 journal은 원본 보존 및 Undo 제한으로 처리한다. 새로운 schema 설정은 읽기 전용으로 보존한다.

성공 journal은 Undo 및 경로 해석에 계속 필요하므로 보존 제한을 넘어 유지한다. 오래된 완료/취소 기록 중 mutation을 Prepared하지 않은 기록만 제한에 따라 정리한다. 일반 진단 로그의 10MiB × 3/30일 rotation은 journal과 별도이다.

## 리소스
Localizable.xcstrings가 3개 언어 문구 원본이다. eng/resources.py가 macOS override를 적용하여 초기 catalog와 각 locale의 .strings를 생성한다. UI는 앱 언어 선택에 맞는 bundle을 사용한다. 번들 폰트는 process scope로 등록하고 실제 PostScript 이름 PretendardVariable-Regular/PretendardJPVariable-Regular를 쓴다.

## OS 수명
마지막 창 닫기는 앱 종료와 구분한다. 처리 중 종료는 취소 요청 후 worker와 pending settings 저장을 기다린다. Dock/Finder/Services 요청은 같은 입력 경로이며 busy 중 OS 요청은 최대 1,000개만 보관한다. 드롭은 busy 중 거부한다. 일반 OS 메뉴와 native traffic lights를 보존한다.

## 2026-10-04 상용 완성도 보완

AppTheme의 네 raw value(system/dark/light/olive)는 기존 settings schema와 호환한다. 최초 기본값은 olive이며 이후 사용자 지시로 테마 선택 UI를 설정창으로 통합했다. 일반 선택 변경은 전체 필터/정렬을 실행하지 않으며 SelectedOnly에서만 재계산한다. detached 검색 worker에 취소를 전달하고 generation으로 늦은 응답을 버린다. scan 결과의 raw path+identity가 같은 row는 ID와 선택 상태를 유지하며 집계는 background에서 계산한다.

결과 sheet dismissal은 queued Finder 입력을 처리한다. 오류 포함 완료는 CompletedWithErrors로 분류한다. RecoveryInspection은 identity 불일치 상태에서도 observedLocations를 읽기 전용으로 전달하며 원본을 확인하지 못한 파일의 자동복원은 계속 차단한다.

## 문자 구성 표시

CharacterPresentation은 App 레이어의 읽기 전용 표시 모델이다. 비교는 원문/NFC UTF-8 bytes를 사용하고, standalone Hangul/Kana glyph는 설명용으로만 사용한다. mutation 경로는 이 모델을 참조하지 않는다. 목록은 첫 변경 grapheme과 추가 개수만, Inspector는 전체 grapheme의 전후 scalar를 lazy 렌더한다. 자세한 UI 계약은 CHARACTER_EXPLANATION.md에 기록했다.

## 반응형 창 및 복원

WindowLayout은 Foundation 순수 geometry 정책이며 WindowPlacementStore는 별도 versioned UserDefaults 키에 일반 창 frame/screen ID/visibleFrame을 보관한다. 기존 AppSettings schema를 변경하지 않는다. AppDelegate는 이동·크기 변경 저장을 250ms debounce하고 닫기·종료·live resize 종료 시 반영한다. 전체 화면 전환과 최소화는 일반 frame 저장에서 제외하고 전환 실패도 처리한다. 화면 변경 때 상대 위치를 재투영하고 현재 visibleFrame으로 제한한다.

MainView는 내용 너비 900pt 이상에서 기존 sidebar/Table을 유지한다. 그 미만은 입력·통계·검색·결과를 LazyVStack으로 재배치하며 CompactResultRow는 유형/선택/원명/미리보기/상태/문자 구성/상세/경로 복사를 보존한다. 통계는 가용 너비에 따라 4/2/1열이다. 낮은 창은 세로 스크롤, 280pt 미만의 극소 창은 가로 스크롤로 내용에 접근한다. FlexibleSheet는 부모 크기를 받아 sheet를 축소하고 내용을 스크롤한다. 동일 AppModel과 entry ID를 공유해 크기 변경이 scan/selection/settings reset을 유발하지 않는다.

## 네이티브 상단바·설정

WindowChrome은 AppDelegate가 수명 동안 보유하는 NSToolbarDelegate/NSToolbarItemValidation이다. unified toolbar의 flexibleSpace 뒤에 rescan/history/settings 세 action을 두고, model 변경 후 label/접근성 이름/활성 상태를 갱신한다. title 문자열은 유지하되 titleVisibility를 hidden으로 설정한다. 기본 창 장식과 overflow는 AppKit에 위임하며 contentView에 가짜 traffic lights를 그리지 않는다.

SheetRouter는 관찰 중인 AppModel과 colorScheme에서 palette를 계산하므로 표시 중인 설정의 테마도 즉시 바뀐다. SettingsView는 동일 changeSettings 경로를 사용하며 카드/미리보기/오류 안내는 표시 전용이다. 설정 저장 실패 상태를 창 안에 보여 주며 기존 원자적 settings actor와 손상 원본 보존 계약을 유지한다. Core mutation 경로에 AI·내용 추출·새 파일 API를 추가하지 않았다.

## 2026-10-04 무료·Pro 확장 구현

- Core/RulePipeline: NFC/NFD/유지, grapheme 편집, 무료/Pro capability, 번호/조건/regex 시간 예산, metadata fallback, 확장자 보호. 규칙의 문자열 동등성은 UTF-8 bytes로 구분하여 정규화만 다른 입력도 미리보기를 갱신한다.
- Core/NameMapping: UTF-8 CSV/TSV 스트리밍 scalar parser, 취소·행 번호 오류, raw mapping, 수식 안전 export. Entitlement은 검증된 active/expiry만 Pro로 해석하며 실제 공급자 미구성은 unavailable로 닫는다.
- Application/RulePreview: 고정 순서와 그룹 순번, extension 우선 metadata, opt-in snapshot, 부모별 names/32개 descriptor 캐시, 모든 duplicate 목적지 제외. WatchSnapshot은 파일별 identity/version·안정화·처리 baseline 차이를 계산한다.
- Application/Planning: 선택된 source만 dependency로 허용하고 graph 및 파일 쌍의 제외를 전파한다. 소스 검증에서 그룹 일부가 빠져도 나머지를 혼자 실행하지 않는다. Undo/remap은 같은 부모의 swap을 동시 이동으로 해석하고 깊은 하위부터 처리한다.
- Infrastructure/GraphTransaction: durable intents → 전체 staging → final. 공유 actor/process lock, no-replace, actual raw entry 검증, 중단 및 부분 복구를 사용한다. 부모 그룹을 하위부터 실행하며 완료된 일부와 임시 이름을 함께 새 Recovery plan으로 복구한다.
- MetadataReader: ImageIO 속성, AVFoundation 컨테이너, CGPDF 정보 사전. 외부 dependency와 파일 내용 변경 없음. size/mtime snapshot을 preview와 실행 전에 재검증한다. PDF는 Spotlight 없이 동작하도록 개선했다.
- RecipeStore/WatchStore: 직렬 actor·atomic save·크기/schema 제한·손상 원본 읽기 전용 보존. watch baseline은 raw path hash + identity/version이며 실행을 선택하는 대신 처리된 동일 상태를 건너뛰는 용도다.
- FolderWatcher: FSEvents IgnoreSelf, 0.5초 이벤트 병합, 폴더 ID 집합 대기열. UI가 review 시 snapshot을 만들고, 새 이벤트는 열린 plan을 수정하지 않는다. 메뉴바/Services/GUI/CLI가 같은 model/planning/executor를 사용한다.
- App: RuleEditor, MappingView, WatchView, ResultExport, MacIntegration. 큰 parse/규칙 검증/정렬은 detached worker, 규칙 sample은 stale task를 취소한다. app shutdown은 worker와 설정·프리셋·watch 저장을 기다린다.
- CLI: 별도 SwiftPM executable `namefix`, 기본 dry-run, JSON base64 모델, interactive 확인, shared History/process lock, Debug 전용 권한/격리 fixture 설정. 앱 자동화용 무확인 executor는 없다.

선택되지 않은 규칙/metadata provider는 파일 내용을 읽지 않는다. 실제 구매 공급자는 아직 외부 조건이며 UnconfiguredEntitlementProvider가 구매 성공을 가장하지 않는다. source 교체 경합은 post-check로 감지해 중단하지만 원자 방지는 불가능하다는 기존 한계를 유지한다.

새 journal event는 schema 2로 기록하고 기존 schema 1은 변경 없이 읽는다. schema 2를 모르는 이전 앱은 해당 기록을 유효하지 않다고 판단하므로 새 swap/group 기록을 구식 Undo로 해석하지 않는다. 새 기록의 Undo/Recovery에는 최신 확장 개발본을 사용한다.

## v1.0 파일 조정과 지원 계약 (2026-10-04 후속)

최신 결과는 [V1_RELEASE_STATUS.md](V1_RELEASE_STATUS.md)가 기준이다. NSFileCoordinator의 source `.forMoving`, destination `.forReplacing`를 이용한다. Darwin `RENAME_EXCL`은 계속 사용하므로 조정 옵션이 실제 덮어쓰기를 허용하는 것은 아니다. 접근 획득 뒤 raw parent path/identity·source identity·size/mtime를 검증하고, 실제 syscall 후에도 확인한다. regular file만 contentVersion을 저장해 자체 하위 변경으로 인한 directory mtime 오탐을 피한다.

FileCoordination 대기는 cancellation token callback과 15초 timeout으로 취소 가능하다. 취소/timeout과 accessor 진입은 잠금으로 순서를 정한다. accessor 진입 후 timeout은 적용하지 않고 실행 단계의 cancellation checkpoint를 사용한다. worker actor에서 동기로 수행하므로 MainActor를 대기시키지 않는다. 재진입/다중 실행은 기존 transaction actor/flock으로 제한한다.

DEBUG에만 실제 syscall 직전 외부 교체를 주입하는 테스트 initializer가 있다. Release에는 포함되지 않는다. 8개 source 교체 조합(Rename/Undo × 정상/graph × 임시/최종)과 2개 destination 생성 조합을 실제 executor로 검증했다. 정체 불명 항목은 History에서 위치를 보여 주되 자동 복원하지 않는다. NSFileCoordinator 미참여 writer에 대한 expected-inode 원자 rename은 여전히 제공되지 않는다. 이것을 원자 예방 PASS로 바꾸지 않는다.

근거: 설치 SDK Foundation/NSFileCoordinator.h의 동기 coordination·forMoving/forReplacing·cancel 계약, Apple File System Programming Guide의 File Coordinators 절, 실제 fixture. API만으로 전체 writer의 원자 배타성을 주장하지 않는다.


## 2026-10-04 작업 화면 분리

MainView는 settings.workbenchEnabled에 따라 NFC 전용 메인과 전체 창 작업실을 제공한다. AppModel의 workbenchDraft는 실행용 pipeline과 분리하며 draftRevision/appliedDraftRevision으로 미적용 상태를 판정한다. prepare(rename)는 미적용 초안을 차단한다. 화면 복귀는 NFC pipeline을 새로 만들고 초안을 유지한다. Settings의 optional 필드로 기존 schema-1을 호환한다. RuleEditor는 모델의 초안을 편집하며 적용 중 잠긴다. 파일 mutation 엔진은 변경하지 않는다.
