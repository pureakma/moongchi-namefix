Moongchi NameFix 1.0.0 — Apple Silicon macOS 14+

This is a local Release candidate, not an approved public distribution.
See BUILD_INFO.json for its signing status. Notarization and the real purchase
provider are not configured. The bundle still uses a development identifier.
The Release app provides the Free features. Pro implementation is present but
cannot be purchased or activated in this candidate. The Debug-only Pro switch
does not exist in Release. Do not advertise this package as a paid Pro product.

로컬 출시 후보입니다. Release 구성은 공개 배포 승인·공증 완료를 뜻하지 않습니다.
기존 앱이나 사용자 파일을 자동 설치·덮어쓰기하지 않습니다.
Gatekeeper가 실행을 차단하면 보호 기능을 해제하지 말고 정식 서명본을 사용하세요.

1. Moongchi NameFix.app을 원하는 위치에 복사합니다.
2. 직접 확인용 복사본을 드롭하고 Preview에서 변경 목록을 확인합니다.
3. 명시적으로 확인한 뒤 이름이 바뀝니다. Undo/Recovery는 작업 기록에서 확인합니다.
4. namefix는 별도 CLI입니다. ./namefix --help로 사용법을 확인하세요.
   기본 동작은 dry-run이며 실제 변경에는 --execute와 터미널 확인이 필요합니다.

지원되는 변경 대상은 로컬 writable APFS입니다. 링크·앱/package·알려진 클라우드
위치·확인되지 않은 파일시스템은 보호합니다. 내용을 변환하거나 덮어쓰지 않습니다.
다른 앱이 같은 항목을 저장·이동하는 동안에는 작업을 피하세요. macOS 파일 조정에
참여하지 않는 외부 변경은 완전히 배제할 수 없습니다. 감지하면 중단하고 기록을
보존합니다. 임시 이름에 남은 항목은 작업 기록에서 Finder로 확인할 수 있습니다.
정체가 다른 파일은 자동으로 복원하지 않습니다.

설정/기록: ~/Library/Application Support/Moongchi/NameFix
앱 삭제는 원본 파일이나 복구 기록을 자동 삭제하지 않습니다.
상세 사용법: USER_GUIDE.md / 폰트 라이선스: ThirdPartyNotices.md 및 앱 Resources.
