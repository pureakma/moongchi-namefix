Moongchi NameFix — local developer QA package

Apple Silicon arm64 / macOS 14+ 대상입니다.
이 문구가 포함된 패키지가 자동으로 공개 배포 승인본이라는 뜻은 아닙니다.
실제 signing/notarization 상태는 함께 생성된 BUILD_INFO/manifest와 current Release evidence를 확인하세요.

처음에는 전용 disposable fixture 또는 복사본으로만 확인하세요.
파일·폴더 추가 → Preview/제외·충돌 확인 → 명시 확인 → Rename 순서입니다.
Undo/Recovery도 작업 기록에서 현재 경로와 identity를 확인한 뒤 수행합니다.
동일 항목을 다른 프로그램에서 동시에 저장·이동·교체하지 마세요.

지원 mutation: 검증된 local writable APFS.
링크·앱/package·알려진 cloud/FileProvider 위치·확인되지 않은 파일시스템은 보호합니다.
앱 제거는 사용자 원본 파일이나 복구 기록을 자동 삭제하지 않습니다.

프로젝트 검증/사용자 QA 기준: docs/QA.md
파일 안전 계약: docs/FILESYSTEM_CAPABILITIES.md
Release 기준: docs/RELEASE.md
폰트 라이선스: ThirdPartyNotices.md와 앱 Resources.
