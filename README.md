# Moongchi NameFix for Apple Silicon

파일과 폴더 이름의 Unicode 정규화 차이를 검사하고, 미리보기와 확인 후 NFC/NFD 변환 및 일괄 이름 변경을 수행하는 macOS 네이티브 앱입니다. 파일 내용은 변환하지 않습니다.

- **지원 대상: Apple Silicon arm64, macOS 14 이상.** Windows/Intel/universal2는 대상이 아닙니다.
- Swift 6 / SwiftUI + AppKit / 독립 NameFixCore package. 외부 런타임 의존성과 네트워크 통신 없음.
- 배포 전 실제 Finder/권한/접근성/최소 OS QA, Developer ID 서명·공증이 필요합니다.

## 개발

무료·Pro 글로벌 확장의 기준은 [전체 개발 계획](docs/EXPANSION_PLAN.md), [단계별 작업 목록](docs/EXPANSION_TASKS.md), [일괄 개발 실행 지침](docs/EXPANSION_EXECUTION.md)입니다. 독립 확장 기능 구현을 완료했습니다. [개발 결과](docs/EXPANSION_DEVELOPMENT.md)와 [사용법](docs/EXPANSION_USER_GUIDE.md)을 참조하세요. 동시 변경 대응을 보완한 최신 상태는 [v1.0 출시 보고서](docs/V1_RELEASE_STATUS.md)를 따릅니다. 기존 인수인계 Master의 범위 밖 항목 중 NFD 출력·범용 규칙·읽기 전용 메타데이터는 새 계획에 따라 확장합니다.

프로젝트 폴더에서:

```sh
eng/doctor.sh
eng/build.sh --configuration Debug --arch arm64
eng/test.sh --level 1 --scope transaction
```

변경에 관련된 검증만 선택합니다. 전체 검증은 통합 단계에서 수행하며 Release 빌드·ZIP/DMG·서명·공증은 사용자가 별도 요청할 때만 진행합니다.

Xcode 프로젝트: MoongchiNameFix.xcodeproj (project.yml과 XcodeGen으로 재생성 가능).
개발용 bundle ID: com.moongchi.namefix.dev. 서명 팀이 없어도 ad-hoc 로컬 QA까지 가능합니다.

## 무료와 Pro 정책

확장 무료판은 Unicode 정리뿐 아니라 기본 일괄 이름 변경·일반 순번·기본 규칙 조합·결과 목록 내보내기를 제공합니다. Pro는 정규식·조건·프리셋 저장·CSV 가져오기·메타데이터·감시 연계에 집중합니다. 기능 경계는 구현했으며 실제 판매 공급자는 아직 연결하지 않았습니다. [무료 사용자 유입 정책](docs/EXPANSION_PLAN.md#무료-사용자-유입-정책)을 참조하세요.

## 현재 개발본

`artifacts/development/Moongchi NameFix 확장 Dev.app` — 무료/Pro 확장, Olive 기본 테마, 네이티브 상단바, 개선한 설정창, 반응형 창·마지막 크기 복원과 문자 구성 설명을 포함한 Debug 앱. [최신 제품·AI·수익화 검토](docs/PRODUCT_ASSESSMENT_2026-10-04.md). [창 대응](docs/RESPONSIVE_WINDOW.md). [표시 개선](docs/CHARACTER_EXPLANATION.md). 기존 artifacts/qa 패키지는 이전 버전이다.

## 확인 자료

- docs/PROJECT_STATUS.md — 현재 상태와 플랫폼 override
- docs/AUTOMATED_QA_REPORT.md — 실행 결과와 증거
- docs/MANUAL_QA_CHECKLIST.md — 직접 화면/기기 QA
- docs/FILESYSTEM_CAPABILITIES.md — 파일 안전 계약과 source-race 한계
- docs/RELEASE.md — 패키징 및 출시 제한
- artifacts/qa — 실행 앱 및 ZIP/DMG

인수인계 문서는 원본 그대로 보존했습니다. 실제 제품 판단에는 현재 사용자 override 및 검증 보고서를 함께 보세요.

## v1.0 Release 후보

최신 앱·CLI·ZIP·DMG: `artifacts/release-candidate/1.0.0/build3/`. 기존 산출물은 보존합니다. Developer ID 서명 후보이며 공증·출시 식별자·실판매 연결·실사용 Gate가 남았습니다. Release 후보에서는 무료 기능을 사용할 수 있습니다. [출시 상태와 근거](docs/V1_RELEASE_STATUS.md)를 확인하세요.
