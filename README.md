# Moongchi NameFix

파일·폴더 이름의 Unicode 문자 구성을 진단하고, Preview와 명시 확인을 거쳐 안전하게 NFC/NFD 변환 및 일괄 이름 변경을 수행하는 macOS 네이티브 앱입니다. 사용자 파일 내용 자체를 변환하거나 덮어쓰는 도구가 아닙니다.

## 현재 기준

- macOS 14 이상, Apple Silicon arm64.
- Swift 6, SwiftUI + AppKit, 로컬 NameFixCore/Application/Infrastructure 구조.
- 기본 이름 검사와 변경은 로컬에서 동작하며 핵심 기능에 네트워크 통신이나 텔레메트리를 요구하지 않습니다.
- 로컬 writable APFS 이름 변경만 지원하며, 링크·앱/package·알려진 클라우드 위치·확인되지 않은 파일시스템은 보수적으로 보호합니다.
- Release 소스는 Free 기능을 제공할 수 있지만 실제 Pro 구매/활성화 공급자는 아직 연결되지 않았습니다.
- 현재 소스는 v1.0 앱 개발 이후 UI/설정 보완이 추가된 상태이며, 과거 build3 Release 후보의 Release/서명/패키지 PASS를 현재 소스 전체 PASS로 재사용하지 않습니다.

## 개발 시작

먼저 AGENTS.md와 docs/STATUS.md의 HOT 구역을 읽습니다. 문서 역할은 docs/README.md가 기준입니다.

~~~sh
eng/doctor.sh
eng/build.sh --configuration Debug --arch arm64
eng/test.sh --scope ui-model
python3 eng/validate-resources.py
python3 tools/doccheck.py
~~~

모든 명령을 매 Task 반복하지 않고 변경 영향에 필요한 검증만 수행합니다.

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
