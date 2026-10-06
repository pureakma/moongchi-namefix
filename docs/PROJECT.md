# Moongchi NameFix 프로젝트

## 제품 목표

Moongchi NameFix는 파일과 폴더 이름의 Unicode 정규화 차이와 이름 규칙을 사용자가 이해할 수 있게 보여 주고, 변경 전에 결과를 확인한 뒤 안전하게 이름만 수정하고 되돌릴 수 있게 하는 로컬 macOS 유틸리티다. 한글 자소 분리는 대표 사용 사례지만 엔진은 Unicode 이름 전반을 다룬다.

대상 사용자는 자소 분리·문자 구성 차이 또는 반복적인 파일명 정리가 필요한 일반 사용자와 반복 작업 사용자다. 기본 흐름은 입력 선택 → 검사/Preview → 충돌·제외 확인 → 명시 확인 → Rename → 결과/기록 → 필요 시 Undo/Recovery다.

## 요구사항

- R-001 사용자가 선택한 파일·폴더 이름의 Unicode 구성을 raw 이름 기준으로 진단하고 NFC/NFD 또는 명시한 규칙 결과를 Preview해야 한다.
- R-002 실제 mutation은 사용자 파일 내용을 바꾸거나 기존 대상을 덮어쓰거나 삭제하지 않고, fresh Plan·충돌 검사·명시 확인·영속 Journal·Undo/Recovery 경계를 지켜야 한다.
- R-003 지원 mutation 범위는 검증된 로컬 writable APFS다. symlink/alias, 앱/package, 알려진 cloud/FileProvider 위치, 확인되지 않은 파일시스템은 보호하거나 변경을 차단해야 한다.
- R-004 앱은 macOS 14 이상 Apple Silicon arm64 네이티브 앱이며 Swift 6 strict concurrency와 SwiftUI + AppKit 현재 구조를 유지한다.
- R-005 Free는 NFC/NFD·문자 설명·기본 문자 편집·literal 규칙·일반 순번·무료 규칙 조합·기본 결과 export·기본 CLI·Preview/Undo/Recovery를 제공하고, 인위적인 속도/개수 등급 제한을 두지 않는다.
- R-006 Pro는 정규식/조건/고급 순번, 프리셋, CSV/TSV 가져오기, 지원 메타데이터, 파일 쌍, 폴더 감시 연계를 담당한다. 실제 구매 권한이 미구성이면 fail-closed로 Free 상태를 유지해야 한다.
- R-007 기본 이름 검사와 Free 사용은 계정·서버·텔레메트리 없이 동작해야 한다. 메타데이터는 사용자가 해당 규칙을 선택한 지원 형식에서만 읽기 전용으로 추출하며, AI/OCR/RAG는 현재 제품 범위가 아니다.
- R-008 UI는 간단한 자소 분리 해결 화면과 별도 이름 일괄 변경 작업실을 분리하고, native macOS 상호작용·네 테마·반응형 창·ko/en/ja·키보드/접근성 원칙을 유지해야 한다.
- R-009 성능과 검증은 변경 영향 기반으로 관리한다. 기존 PASS는 source/test/dependency/toolchain/environment 또는 계약이 바뀌면 무효화하며, Engineering Verification과 User QA를 구분한다.
- R-010 Store 실제 동작 검증, 판매 공급자 연결, 새 Release 후보, 공증, 실제 배포는 현재 자동 개발 범위가 아니다. 사용자가 별도 출시 단계를 승인하고 필요한 외부 입력을 제공해야 시작한다.
- R-011 설정·Journal·프리셋·watch 데이터의 기존 호환과 손상 원본 보존을 유지하고, 새 schema를 모르는 구버전이 새 기록을 잘못 Undo하지 않도록 해야 한다.
- R-012 Git/AI 협업은 한 working tree 한 writer, 안전한 Preflight/Finish, 최소 충분 Context, Task 영향 기반 검증을 사용하고 과거 개발 문서는 Git 이력으로 보존한다.

## 현재 확정 범위

현재 소스에는 Unicode 정리, 기본/고급 일괄 이름 변경, Free/Pro capability 경계, 프리셋/CSV/메타데이터/파일 쌍/감시/CLI, 안전한 Rename·Undo·Recovery, ko/en/ja, 네 테마, 반응형 창, 자소 분리 중심 간편 화면과 일괄 변경 작업실, native sidebar가 구현돼 있다.

현재 지원/구현 사실과 세부 책임은 ARCHITECTURE.md, DESIGN.md, FILESYSTEM_CAPABILITIES.md가 원본이다. 제품 완성과 공개 출시 완료는 같은 상태가 아니다.

범위 밖 또는 아직 승인되지 않은 후보:
- 실제 Pro 판매/복원 공급자와 상품 구성
- App Store 또는 직접 배포 채널의 최종 선택과 그에 따른 sandbox/entitlement 조정
- AI/Apple Foundation Models/OCR/RAG 기반 내용 이름 제안
- Windows/Intel 지원
- 확인되지 않은 외장·SMB·NAS·cloud volume mutation 확대
- cross-volume 이동, 내용 변환, 자동 NFKC/NFKD
- 검증되지 않은 가격·구독·체험 정책
- 일괄 변경 규칙의 적용 대상 조정(추가한 폴더 자체·하위 폴더·숨김 파일을 기본 대상에서 뺄지)
- 읽을 수 없는 작업 기록을 건너뛰는 부분 Undo/Recovery

이 후보들은 백로그 성격이며 현재 실행 계획이 아니다.

## 현재 승인 범위 — Active Plan SSOT

2026-10-06 사용자가 ‘출시 전 제품 완성도 고도화’ Phase를 승인했다. 범위는 UI/UX·사용자 용어·ko/en/ja·접근성·코드·안정성 리뷰와 확인된 문제의 수정, 영향 검증, 앱 자체 기준 Release Candidate Ready 판정, User QA 목록 정리다(T-002). 실제 판매 연결·공증·Store 제출·공개 배포는 이 Phase에 포함하지 않으며 R-010의 사용자 Gate에서 보류한다. 별도 PLAN.md는 만들지 않는다.

T-002의 구현과 Engineering Verification은 끝났고 User QA만 남았다. 같은 날 사용자가 실제 화면을 보고 first-use 복잡도를 지적해 ‘First-use UX 및 전체 UI 구조 단순화’(T-003)를 추가 승인했다. 범위는 화면의 정보 노출 시점·navigation·hierarchy 재설계이며 기능 추가와 안전 엔진 변경은 포함하지 않는다. T-003도 구현과 Engineering Verification이 끝났고 사용자의 화면 승인만 남았다. 그 뒤 승인된 다음 제품 구현 Phase는 없다.

다음 개발은 사용자가 새 범위를 승인하면 그 범위의 Milestone/Task를 STATUS에 만들고 진행한다. Release를 승인할 경우 첫 순서는 현재 소스에 대한 영향 검증 → 현재 source 기준 새 Release 후보 → 실제 판매/식별자/공증 입력 연결 → User QA/깨끗한 Mac Gate다.

## 환경과 의존성

- deployment target: macOS 14.0
- architecture: arm64
- language: Swift 6, strict concurrency complete
- UI: SwiftUI + AppKit
- build project: project.yml → MoongchiNameFix.xcodeproj
- current development bundle ID: com.moongchi.namefix.dev
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
