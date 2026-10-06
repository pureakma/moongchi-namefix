# Moongchi NameFix 프로젝트

## 제품 목표

Moongchi NameFix는 파일과 폴더 이름의 Unicode 정규화 차이와 이름 규칙을 사용자가 이해할 수 있게 보여 주고, 변경 전에 결과를 확인한 뒤 안전하게 이름만 수정하고 되돌릴 수 있게 하는 로컬 macOS 유틸리티다. 한글 자소 분리는 대표 사용 사례지만 엔진은 Unicode 이름 전반을 다룬다.

대상 사용자는 자소 분리·문자 구성 차이 또는 반복적인 파일명 정리가 필요한 일반 사용자와 반복 작업 사용자다. 기본 흐름은 입력 선택 → 검사/Preview → 충돌·제외 확인 → 명시 확인 → Rename → 결과/기록 → 필요 시 Undo/Recovery다.

## 요구사항

- R-001 사용자가 선택한 파일·폴더 이름의 Unicode 구성을 raw 이름 기준으로 진단하고 NFC/NFD 또는 명시한 규칙 결과를 Preview해야 한다.
- R-002 실제 mutation은 사용자 파일 내용을 바꾸거나 기존 대상을 덮어쓰거나 삭제하지 않고, fresh Plan·충돌 검사·명시 확인·영속 Journal·Undo/Recovery 경계를 지켜야 한다.
- R-003 지원 mutation 범위는 검증된 로컬 writable APFS다. symlink/alias, 앱/package, 알려진 cloud/FileProvider 위치, 확인되지 않은 파일시스템은 보호하거나 변경을 차단해야 한다.
- R-004 앱은 macOS 14 이상 Apple Silicon arm64 네이티브 앱이며 Swift 6 strict concurrency와 SwiftUI + AppKit 현재 구조를 유지한다.
- R-005 모든 기능을 무료로 제공한다. 유료 등급, 구매, 계정, 라이선스 인증을 두지 않으며 인위적인 속도/개수 제한도 두지 않는다. 자소 분리 합치기·분리하기, 글자 구성 설명, 일괄 변경 규칙(패턴·조건·고급 번호 포함), 프리셋, CSV/TSV 목록, 지원 파일 정보, 묶음 파일, 폴더 감시, 결과 저장, CLI, Preview/Undo/Recovery가 모두 같은 조건으로 열려 있다.
- R-006 capability 검사 구조(규칙 집합을 access 수준에 대해 검증하는 코드)는 내부에 남기되 앱과 CLI는 항상 전체 access로 동작한다. 화면과 문구에 Pro·유료·구매를 표시하지 않는다. 유료 등급을 다시 도입하려면 사용자 승인과 새 결정이 필요하다.
- R-007 이름 검사와 모든 기능은 계정·서버·텔레메트리 없이 동작해야 한다. 파일 정보는 사용자가 해당 규칙을 선택한 지원 형식에서만 읽기 전용으로 추출하며, AI/OCR/RAG는 현재 제품 범위가 아니다.
- R-008 UI는 간단한 자소 분리 해결 화면과 별도 이름 일괄 변경 작업실을 분리하고, native macOS 상호작용·네 테마·반응형 창·ko/en/ja·키보드/접근성 원칙을 유지해야 한다.
- R-009 성능과 검증은 변경 영향 기반으로 관리한다. 기존 PASS는 source/test/dependency/toolchain/environment 또는 계약이 바뀌면 무효화하며, Engineering Verification과 User QA를 구분한다.
- R-010 Store 실제 동작 검증, 새 Release 후보, 공증, 실제 배포는 현재 자동 개발 범위가 아니다. 사용자가 별도 출시 단계를 승인하고 필요한 외부 입력을 제공해야 시작한다. 무료 제품이므로 판매 공급자 연결은 필요하지 않다.
- R-011 설정·Journal·프리셋·watch 데이터의 기존 호환과 손상 원본 보존을 유지하고, 새 schema를 모르는 구버전이 새 기록을 잘못 Undo하지 않도록 해야 한다.
- R-012 Git/AI 협업은 한 working tree 한 writer, 안전한 Preflight/Finish, 최소 충분 Context, Task 영향 기반 검증을 사용하고 과거 개발 문서는 Git 이력으로 보존한다.
- R-013 자주 쓰는 폴더를 즐겨찾기로 고정해 한 번에 입력에 추가하고 그 시점에 검사할 수 있어야 한다. 즐겨찾기는 로컬 설정에 경로와 접근 정보를 저장하는 shortcut이며, 등록만으로 감시를 시작하지 않고, 제거해도 실제 폴더·파일을 건드리지 않으며, 열 수 없게 된 즐겨찾기는 상태를 표시하고 다시 선택하게 한다.
- R-014 파일 이름 일괄 변경의 기본 대상은 보이는 일반 파일이다(하위 폴더 검사가 켜져 있으면 그 안의 파일 포함). 추가한 폴더 자체·하위 폴더의 이름과 숨김 항목은 기본으로 바꾸지 않고, 고급 설정의 ‘폴더 이름도 변경’·‘숨김 파일 포함’을 켠 경우에만 대상이 된다. Finder 관리 파일은 항상 제외한다.

## 현재 확정 범위

현재 소스에는 Unicode 정리, 기본/고급 일괄 이름 변경, 프리셋/CSV/파일 정보/묶음 파일/감시/CLI, 안전한 Rename·Undo·Recovery, ko/en/ja, 네 테마, 반응형 창, 자소 분리 해결 화면과 파일 이름 일괄 변경 화면, 입력 상태를 따라 펼친 navigation 또는 아이콘 레일 + 폴더 트리로 바뀌는 왼쪽 영역이 구현돼 있다. 즐겨찾기 폴더(R-013)와 일괄 변경의 기본 대상 정책(R-014)도 v1.0 범위로 구현돼 있다. 모든 기능은 무료다.

현재 지원/구현 사실과 세부 책임은 ARCHITECTURE.md, DESIGN.md, FILESYSTEM_CAPABILITIES.md가 원본이다. 제품 완성과 공개 출시 완료는 같은 상태가 아니다.

범위 밖 또는 아직 승인되지 않은 후보:
- 유료 등급 재도입(현재는 전 기능 무료)
- Mac App Store 배포와 그에 따른 sandbox/entitlement 조정(v1.0은 직접 배포로 확정, D-023)
- AI/Apple Foundation Models/OCR/RAG 기반 내용 이름 제안
- Windows/Intel 지원
- 확인되지 않은 외장·SMB·NAS·cloud volume mutation 확대
- cross-volume 이동, 내용 변환, 자동 NFKC/NFKD
- 검증되지 않은 가격·구독·체험 정책
- 읽을 수 없는 작업 기록을 건너뛰는 부분 Undo/Recovery

이 후보들은 백로그 성격이며 현재 실행 계획이 아니다.

## 현재 승인 범위 — Active Plan SSOT

2026-10-06 사용자가 ‘출시 전 제품 완성도 고도화’ Phase를 승인했다. 범위는 UI/UX·사용자 용어·ko/en/ja·접근성·코드·안정성 리뷰와 확인된 문제의 수정, 영향 검증, 앱 자체 기준 Release Candidate Ready 판정, User QA 목록 정리다(T-002). 실제 판매 연결·공증·Store 제출·공개 배포는 이 Phase에 포함하지 않으며 R-010의 사용자 Gate에서 보류한다. 별도 PLAN.md는 만들지 않는다.

T-002의 구현과 Engineering Verification은 끝났고 User QA만 남았다. 같은 날 사용자가 실제 화면을 보고 first-use 복잡도를 지적해 ‘First-use UX 및 전체 UI 구조 단순화’(T-003)를 추가 승인했다. 범위는 화면의 정보 노출 시점·navigation·hierarchy 재설계이며 기능 추가와 안전 엔진 변경은 포함하지 않는다. 사용자가 화면 확인 뒤 추가로 지시한 내용도 T-003에 포함했다: 전 기능 무료(유료 등급 제거), 왼쪽 영역을 입력 상태 기반으로 전환(입력 없음 → 펼친 navigation, 입력 있음 → 아이콘 레일 + 폴더 트리), 창 chrome·앱 이름·band drag 정리, 일괄 변경의 2-pane 재설계. T-003은 구현과 Engineering Verification이 끝났고 사용자의 화면 승인만 남았다. 그 뒤 승인된 다음 제품 구현 Phase는 없다.

2026-10-06 사용자가 제품 결정 두 가지를 추가로 승인했다: 즐겨찾기 폴더를 v1.0에 포함(D-021, R-013), 파일 이름 일괄 변경의 기본 대상 정책(D-022, R-014). 구현과 영향 검증은 T-005에 있다.

2026-10-06 사용자가 ‘Release Preparation 1차’를 승인했다: 직접 배포 정책과 출시 식별자 확정(D-023), 현재 source의 build 4 서명 전 후보 준비까지. 실제 Developer ID 서명·공증·DMG·공개 배포는 포함하지 않으며 사용자가 2차를 따로 승인한 뒤 진행한다(T-006).

다음 개발은 사용자가 새 범위를 승인하면 그 범위의 Milestone/Task를 STATUS에 만들고 진행한다. Release를 승인할 경우 첫 순서는 현재 소스에 대한 영향 검증 → 현재 source 기준 새 Release 후보 → 출시 식별자/공증 입력 연결 → User QA/깨끗한 Mac Gate다.

## 환경과 의존성

- deployment target: macOS 14.0
- architecture: arm64
- language: Swift 6, strict concurrency complete
- UI: SwiftUI + AppKit
- build project: project.yml → MoongchiNameFix.xcodeproj
- bundle ID: Release 구성 com.ailoworks.namefix, Debug 구성 com.moongchi.namefix.dev (D-023)
- app sandbox: 현재 설정 OFF
- hardened runtime: 프로젝트 설정 ON
- local packages: NameFixCore / NameFixRuntime / NameFixApplication
- bundled fonts: Pretendard Variable / Pretendard JP Variable, SIL OFL 1.1
- 외부 네트워크 runtime package dependency는 현재 없다. XcodeGen은 build-time 도구다.

버전·SDK·스토어 정책 같은 변하는 사실은 Release Task 때 실제 설치 환경과 공식 정책으로 다시 확인한다.

## 품질 제약

현재 공통 방어 한계:
- 한 검사 세션 최대 200,000항목. 한계 도달 시 발견된 결과를 보존하고 나머지까지 검사했다고 표시하지 않는다.
- 규칙 파이프라인 최대 1,024단계.
- 한 번에 수만 건이 넘는 연쇄 이름 이동(앞 항목이 비워야 다음 항목이 들어가는 형태)과 대량 충돌 번호 제안은 계획 계산이 항목 수의 제곱에 비례해 느려질 수 있다. 수십만 건의 작업 기록이 쌓이면 Undo와 기록 상세 열기도 느려진다. 현재 수치 목표를 주장하지 않는다.
- clipboard 분석 입력 최대 4,096 UTF-16 code units이며 grapheme/surrogate를 깨뜨리지 않게 자르고 잘림을 알린다.
- CSV/TSV 입력 최대 32MB.
- 최근 폴더는 opt-in이며 최대 10개, off 전환 시 저장 목록을 비운다.

응답성 목표는 로컬 작업 시작 표시 500ms 이내, 일반 UI 상호작용 100ms 이내, 취소 요청 피드백 200ms 이내다. I/O 완료시간은 장비/볼륨에 따라 측정한다. 과거 10k Preview 300ms 내부 목표는 실제 FS 포함 측정에서 미달한 이력이 있으므로 현재 PASS로 주장하지 않는다.

- 정상 제품 경로에서 사용자 파일 내용을 변환하거나 일반 scan을 위해 hash하지 않는다.
- mutation은 동시에 하나의 transaction 흐름으로 제한하고 앱/CLI가 process lock을 공유한다.
- MainActor에서 전체 디렉터리 순회·대형 parse·반복 전체 sort를 수행하지 않는다.
- 데이터 손실, 잘못된 덮어쓰기, 확인 없는 mutation을 성능 개선보다 우선해 막는다.
