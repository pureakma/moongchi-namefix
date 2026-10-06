# 앱 자체 상용 완성도 검토 — 2026-10-04

> **최신 v1.0 후보 결과:** [V1_RELEASE_STATUS.md](V1_RELEASE_STATUS.md). 아래 내용은 이전 단계 증거로 보존하며 최신 Release/서명/패키지 상태는 후속 보고서를 따른다.

**재판정: 미완성.** 기능·성능·UX·디자인에서 이번 검토로 확인한 수정 가능한 결함은 반영했다. 실제 재현되는 외부 source 교체 경합 1건은 남는다. 출시 QA, 스모크, 서명·공증, 심사·배포 준비와 화면 미확인은 이 판정의 근거가 아니다.

이 문서의 아래 검토는 기존 Unicode 앱 범위에 대한 기록이다. 이후 정한 무료·Pro 확장 범위는 [EXPANSION_PLAN.md](EXPANSION_PLAN.md)를 따르며 독립 기능 구현 후 [확장 재판정](EXPANSION_COMMERCIAL_REVIEW.md)을 완료했다. 아래 ‘기능 없음’은 새 규칙·NFD 출력·메타데이터 등까지 완성됐다는 뜻이 아니다. 최신 판단은 확장 재판정 문서가 우선한다.

최신 UI 변경·재검토·AI/수익화 판단은 [PRODUCT_ASSESSMENT_2026-10-04.md](PRODUCT_ASSESSMENT_2026-10-04.md)를 참조한다. 아래 첫 구현 이력의 주 화면 테마 메뉴는 이후 사용자 지시로 설정 안으로 이동했다. 현재 개발 앱 경로는 PROJECT_STATUS.md가 기준이다.

범위는 Apple Silicon 전용 Unicode 파일 이름 검사·수정 앱이다. Termius/Tabby의 터미널·SSH·전송 기능을 이 제품의 누락 기능으로 취급하지 않았다. 적용되는 AGENTS.md는 현재 폴더·상위 경로에서 발견되지 않았으며 사용자의 문서 최신화/관련 테스트/Debug 전용 지시를 적용했다.

## 첫 판정에서 확인하고 개발한 항목

| 영역 | 위치 | 실제 문제 | 수정 |
|---|---|---|---|
| 기능 | App/MainView.swift, Sheets.swift, Infrastructure/Settings.swift | 네 테마는 설정 내부에만 있어 주 화면에서 발견하기 어려움 | 이름이 보이는 테마 메뉴 추가. System/Dark/Light/Olive Archive 공통 enum·즉시 저장 사용 |
| 기능 | App/AppModel.swift numberConflicts | 번호 제안으로 충돌이 해결돼도 선택에 포함되지 않아 실행 버튼이 0개 상태 | 새로 해결된 항목을 선택에 합치고 기존 선택 유지 |
| 기능 | App/AppModel.swift dismissResult | 결과창 동안 들어온 Finder 입력을 닫은 뒤 재처리하지 않음 | 닫기 버튼·sheet dismissal 모두 대기 입력을 처리 |
| 성능 | App/AppModel.swift toggle/refreshVisible/scan | 체크마다 10만 행 전체 필터·정렬; 이전 detached 작업은 취소되지 않음; 검사 결과의 선택·집계를 MainActor에서 반복 | 일반 체크는 선택 집합만 변경. 필터에 선택 자체가 영향을 줄 때만 갱신. detached filter/sort 취소 전달. 검사 집계/선택 복원을 background에서 계산 |
| UX·안정성 | App/AppModel.swift scan/changeSettings | 재검사·입력 추가 시 사용자가 해제한 기존 선택이 모두 다시 선택됨 | raw path+identity가 같은 항목의 ID/선택 유지; 새 후보만 자동 선택. 실행 중/확정 preview의 recursive 변경 차단 |
| UX | App/Sheets.swift, eng/resources.py | 복구 확인 버튼이 Undo로 표시; 안전 검사로 모두 제외돼도 일반 NoChanges 문구; 실제 구현과 다른 Home reset 안내 | 복원 동작과 제외 원인 문구 분리, 부정확한 단축키 안내 제거. 3언어 적용 |
| UX·접근성 | App/MainView.swift | 아이콘 버튼의 명시적 접근성 이름 부족, 행 포커스에서 Space 선택 없음 | 다시 검사/도움말/설정/닫기/제거/추가 작업 이름, Space 선택 추가 |
| 디자인 | App/MainView.swift, Main.swift | 900pt 실제 렌더에서 영어 Type 및 정렬 값이 잘림; 최근 폴더 10개가 입력 목록 공간을 잠식; fullSizeContentView가 titlebar 아래 컨텐츠 영역을 침범할 수 있는 구조 | 열/선택기 너비 수정 후 렌더로 잘림 해소 확인. 입력·최근 폴더를 같은 스크롤에 배치. native titlebar content 영역 분리 |
| 안정성·UX | Infrastructure/Transaction.swift, Journal.swift, App/AppModel.swift | 개별 실패가 있어도 Completed로 표시 | CompletedWithErrors 별도 결과 및 보존/복구 분류 |
| 안정성·UX | Application/Planning.swift History.inspect, App/Sheets.swift | 예상 identity와 다른 임시 파일만 발견되면 위치가 UI에서 빠짐; 실제 이동 뒤에도 단순 제외 안내 | 발견한 위치를 표시하고 복사 가능. 원본 확인 안 된 항목은 자동복원 차단. 이동 뒤 source 변경 문구 분리 |

첫 구현 뒤 실제 Debug 뷰를 렌더해 영어 잘림을 확인했고, 두 번째 수정 후 같은 900pt 뷰에서 잘림이 해소됨을 확인했다. 사용자 화면을 조작하지 않았다. 확인하지 않은 화면 상태를 결함으로 등록하지 않았다.

## 재판정 — 남은 개발 항목

- 기능: 없음 — 이번 검토에서 확인한 미해결 항목 없음.
- 성능: 없음 — 이번 검토에서 확인한 미해결 항목 없음. 실제 타자·스크롤 수치를 측정했다고 주장하지 않는다.
- 사용자 경험: 없음 — 이번 검토에서 확인한 미해결 항목 없음.
- 디자인: 없음 — 이번 검토에서 확인한 미해결 항목 없음.
- 안정성: **P1 SOURCE_RACE** — `Infrastructure/Transaction.swift:37`의 마지막 source 검증과 다음 no-replace rename 사이에 다른 프로세스가 source leaf를 바꾸면, 대체 파일이 임시 이름으로 이동한 뒤 identity mismatch가 검출된다. 목적지 덮어쓰기는 차단하지만 사용자가 선택하지 않은 파일의 이름을 일시적으로 바꿀 수 있다. `SafetyTests.testSourceRaceCannotBeAtomicExpectedInodeRename`가 이 순서를 실제 APFS에서 재현한다. 테스트 PASS는 한계의 재현 성공이며 문제 해결을 뜻하지 않는다.

현재 조치는 즉시 중단, 원본 내용/증거 보존, recovery 경로 노출, 동일성 불명 시 자동복원 차단이다. 완전한 해결에는 source identity를 원자적으로 조건으로 걸 수 있는 mutation 방식 또는 다른 writer를 강제로 배제할 수 있는 작업 모델이 필요하다. 현재 사용하는 Darwin renameatx_np는 이 조건을 받지 않는다. 검사 추가/임의 재시도/추측 rollback은 같은 경합을 재발시키므로 해결책으로 적용하지 않았다. 앱의 핵심 Rename을 비활성화하거나 안전 계약을 몰래 약화해 '상용 수준 완성'으로 바꾸지도 않았다.

## 이번 수정에 직접 관련된 실행 근거

근거 폴더: `artifacts/development/commercial-review/`.

- `eng/test.sh --scope ui-model`: 7개 통과. 선택 유지/번호 제안/대기 입력/네 테마 재로딩/세션 상태/이름 변경·Undo.
- `eng/test.sh --scope safety`: 7개 통과, 기존 full scanner 성능 1개 의도적 skip. 실제 no-replace 경합, 임시 충돌, 불일치 recovery 위치 노출 및 복원 차단 포함.
- `eng/test.sh --scope transaction`: 11개 통과. journal·Undo·Recovery·내용/metadata 불변 관련 회귀.
- 고유 실행 테스트 총 **25개 PASS**, 실패 0. 과거 전체 테스트 숫자와 합산하지 않았다.
- 10만 행에서 체크 100회 모델 처리 **0.403ms**, 추가 filter/sort 계산 **0회**. UIModelTests 내 측정이며 화면 렌더·사용자 스크롤 latency 수치가 아니다.
- `eng/build.sh --configuration Debug --arch arm64`: 성공. 처음 제한 환경의 Xcode 패키지 캐시 접근 실패는 권한 범위를 조정한 Debug 실행으로 해결. 소스 컴파일 결함으로 분류하지 않음.
- `python3 eng/validate-resources.py`: 215키×3언어 및 폰트/원본 자료 parity 통과.
- Debug 앱 `--render-review`: 실제 SwiftUI/AppKit **20개** 레이아웃 생성. ko/en/ja, 네 테마, 900pt/1600pt, 설정 포함. 직접 확인한 영어 Olive 900pt와 일본어 Light 900pt에서 제목/정렬 잘림 해소. 시스템 모드는 OS appearance 상속을 유지.

개발 앱: `artifacts/development/Moongchi NameFix Dev.app`. 기존 `artifacts/qa` 앱/ZIP/DMG는 이전 버전 증거이며 이번 수정을 포함하지 않는다. 현재 변경된 scope의 과거 PASS cache는 STALE로 무효화하고 이번 관련 실행을 별도 등록한다.

별도 단계: 출시 QA·스모크·서명·공증·심사·배포는 이번 판정과 개발 범위에서 제외했으며 Release 빌드도 실행하지 않았다.
