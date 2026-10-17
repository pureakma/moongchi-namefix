# Moongchi NameFix

한글 자소 분리처럼 파일 이름의 문자 구성이 달라 생기는 문제를 진단하고 정리하는 macOS 네이티브 앱입니다. 파일·폴더를 추가하고 변경 전후를 확인한 뒤 이름을 바꿉니다. NFC/NFD 변환과 규칙을 조합하는 일괄 이름 변경을 제공합니다. 파일 내용은 수정하지 않습니다.

A free, native macOS app for Unicode filename normalization and batch renaming. Inspect decomposed Hangul and other Unicode names, preview changes, and rename with conflict checks, a durable journal, Undo, and Recovery. File contents are never converted.

## 다운로드와 사용

- [최신 버전 다운로드](https://github.com/pureakma/moongchi-namefix/releases/latest): Developer ID 서명·Apple 공증을 통과한 DMG 또는 ZIP을 받습니다.
- macOS 14 이상, Apple Silicon(M1 이상) 전용입니다.
- DMG를 열고 앱을 Applications로 복사하거나, ZIP을 풀고 앱을 Applications로 옮깁니다. 보안 기능을 끄거나 격리 속성을 제거할 필요가 없습니다.
- 앱에 파일·폴더를 놓고 변경 전후를 확인합니다. 읽기만 하는 검사 뒤, 이름을 바꿀 때 별도 확인을 받습니다. 필요한 경우 macOS 폴더 접근 창이 열립니다.
- [사용 방법](docs/EXPANSION_USER_GUIDE.md) · [지원 범위와 안전 계약](docs/FILESYSTEM_CAPABILITIES.md) · 문의: ailo@ailoworks.com

일부 이름은 화면에서 같아 보여도 내부 Unicode 구성이 다릅니다. 이 앱은 그 차이를 설명하고 정리합니다. 변경 가능한 위치는 로컬의 쓰기 가능한 APFS입니다. 외부 프로그램이 작업 중 원본을 교체하는 경합을 원자적으로 막는다고 보장하지 않습니다. 상세 지원 조건은 위 안전 계약을 확인하세요.

## 현재 기준

- macOS 14 이상, Apple Silicon arm64.
- Swift 6, SwiftUI + AppKit, 로컬 NameFixCore/Application/Infrastructure 구조.
- 기본 이름 검사와 변경은 로컬에서 동작하며 핵심 기능에 네트워크 통신이나 텔레메트리를 요구하지 않습니다.
- 로컬 writable APFS 이름 변경만 지원하며, 링크·앱/package·알려진 클라우드 위치·확인되지 않은 파일시스템은 보수적으로 보호합니다.
- 모든 기능을 무료로 제공합니다. 유료 등급, 구매, 계정이 없습니다.
- 제품 버전은 1.0.0 build 6입니다. 배포 파일의 서명·공증과 실제 공개 상태는 [배포 문서](docs/RELEASE.md)에서 구분해 기록합니다.

## 개발 시작

Apple Silicon Mac과 Xcode, XcodeGen 2.40 이상이 필요합니다. Xcode의 첫 실행 설정과 Command Line Tools 선택을 마친 뒤 실행합니다. 현재 아이콘 문서는 Icon Composer 형식이므로 Xcode 26 이상을 사용합니다. 앱의 실행 대상은 macOS 14 이상입니다. Debug 빌드에는 Apple Developer 멤버십이나 배포 인증서가 필요하지 않습니다.

~~~sh
eng/doctor.sh
eng/build.sh --configuration Debug --arch arm64
eng/test.sh --scope ui-model
python3 eng/validate-resources.py
python3 tools/doccheck.py
~~~

결과 앱은 `.build/xcode/Build/Products/Debug/Moongchi NameFix.app`입니다. Core만 확인할 때는 `eng/test.sh --scope core`를 사용합니다. 외부에서 가져오는 런타임 패키지는 없으며, 폰트도 저장소에 포함되어 있습니다.

개발 작업은 AGENTS.md와 docs/STATUS.md의 HOT 구역부터 읽습니다. 모든 명령을 매 Task 반복하지 않고 변경 영향에 필요한 검증만 수행합니다. 문서 역할은 docs/README.md가 기준입니다.

## 라이선스

코드와 문서는 [MIT](LICENSE)로 제공합니다. 포함된 Pretendard/Pretendard JP 폰트는 SIL OFL 1.1이며 [타사 고지](ThirdPartyNotices.md)를 따릅니다. 앱 이름·로고·아이콘은 MIT 적용 대상에서 제외하며 [브랜딩 안내](assets/branding/README.md)의 조건을 따릅니다. 코드 라이선스는 공식 제품을 사칭하거나 브랜드 사용 권리를 부여하지 않습니다.

## 문서

- 제품 요구와 현재 승인 범위: docs/PROJECT.md
- 현재 상태: docs/STATUS.md
- 구조: docs/ARCHITECTURE.md
- UI/UX: docs/DESIGN.md
- 파일 안전성: docs/FILESYSTEM_CAPABILITIES.md
- 검증과 사용자 QA: docs/QA.md
- 빌드·배포: docs/RELEASE.md
- 사용자 기능 안내: docs/EXPANSION_USER_GUIDE.md

과거 Master, 실행 프롬프트, 확장 계획, 날짜별 개발 보고서는 현재 개발 기준이 아닙니다. 필요한 현재 정보는 위 SSOT로 이관했고 과거 내용은 Git 이력에서 확인합니다.
