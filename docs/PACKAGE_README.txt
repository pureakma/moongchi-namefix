Moongchi NameFix 1.0.0 — macOS 14 or later, Apple Silicon
Made by AILO WORKS · https://moongchi.ailoworks.com · ailo@ailoworks.com

Every feature is free. There is no paid tier, purchase, account or advertising,
and the app makes no network connections.

Moongchi NameFix는 자소 분리된 파일 이름을 합치고, 규칙으로 여러 파일의 이름을
한 번에 바꾸는 Mac 앱입니다. 모든 기능이 무료이며 계정·구매·광고가 없습니다.

설치와 사용
1. Moongchi NameFix.app을 응용 프로그램 폴더로 옮깁니다.
2. 파일이나 폴더를 창에 끌어다 놓고, 변경 전후 이름을 확인합니다.
3. 확인 창에서 한 번 더 확인한 뒤에만 이름이 바뀝니다. 바꾼 이름은 작업 기록에서
   되돌릴 수 있습니다.
4. namefix는 터미널용 도구입니다. ./namefix --help로 사용법을 확인하세요.
   기본 동작은 미리보기이며, 실제 변경에는 --execute와 터미널에서의 확인이 필요합니다.

안전
- 이름만 바꿉니다. 파일 내용을 바꾸거나 기존 파일을 덮어쓰지 않습니다.
- 이 Mac의 내장 디스크(APFS)에 있는 항목만 바꿉니다. 링크, 앱, 클라우드 폴더,
  확인되지 않은 디스크의 항목은 바꾸지 않고 보호합니다.
- 작업하는 동안 다른 앱에서 같은 항목을 저장하거나 옮기지 마세요. 외부 변경을
  감지하면 멈추고 기록을 남깁니다. 다른 앱이 macOS의 파일 조정에 참여하지 않는
  경우의 변경까지 완전히 막지는 못합니다.
- macOS가 실행을 막으면 보호 기능을 끄지 말고 ailo@ailoworks.com으로 알려 주세요.

설정과 작업 기록: ~/Library/Application Support/Moongchi/NameFix
앱을 지워도 원본 파일과 작업 기록은 자동으로 지워지지 않습니다.

자세한 사용법: USER_GUIDE.md
폰트 라이선스: ThirdPartyNotices.md
문의와 버그 신고: ailo@ailoworks.com
