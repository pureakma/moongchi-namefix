# 빌드·배포

## 출시 정책 (D-038)

- 공개 제품은 하나: Mac App Store의 Moongchi NameFix. 무료. 직접 배포판(Developer ID 서명·공증·DMG/ZIP·홈페이지 다운로드)과 사용자용 CLI는 없다.
- 구성은 project.yml의 Debug와 AppStore 둘.
  - Debug: 개발·QA. App Sandbox OFF, bundle ID com.moongchi.namefix.dev. render·probe·진단 fixture는 이 구성에만 compile된다. 실제 sandbox 검증용으로 eng/build.sh --sandbox-debug가 같은 Debug 앱을 스토어 entitlement로 만든다(식별자 com.moongchi.namefix.sandboxqa).
  - AppStore: 공개 배포. App Sandbox ON, entitlement는 app-sandbox · files.user-selected.read-write · files.bookmarks.app-scope 셋, 디버깅 entitlement 없음, bundle ID com.ailoworks.namefix.
- 버전: MARKETING_VERSION 1.0.0, CURRENT_PROJECT_VERSION 6. 원본은 project.yml 하나이며 build 명령이 바꾸지 않는다.
- macOS 14 이상, Apple Silicon arm64 전용. Hardened Runtime ON.
- 개발사 AILO WORKS, 문의 ailo@ailoworks.com
- 모든 기능 무료. 유료 등급·구매·계정·광고·추적 없음. 앱은 네트워크를 쓰지 않는다.
- 설치와 업데이트는 App Store가 맡는다. 앱에 업데이트 명령이나 자체 updater는 없다.

## 현재 상태

출시 보류(D-026). Store Release Phase 1(2026-10-07): 현재 source 1.0.0 build 6의 최종 Gate를 통과했고 제출 직전까지 준비했다. 판정 HUMAN_ACTION_REQUIRED — 제품은 준비됐고, Apple 계정에서 사용자가 해야 하는 일만 남았다(아래 ‘Mac App Store 제출’). 스토어용 서명, 업로드, 심사 제출은 하지 않았다.

## Release Candidate 진입 조건

Final User QA Session(T-010)의 판정은 USER_QA_COMPLETE_WITH_EXTERNAL_PENDING이고 P0·P1은 없다. Release Candidate 단계에 들어갈 수 있으며, 사용자가 승인하기 전에는 후보를 만들지 않는다.

1. 사용자가 Release Candidate Phase를 승인하고 아래 ‘Mac App Store 제출’의 외부 입력을 준비한다. build 번호는 그때 정한다(지금은 6).
2. 통합 Gate는 2026-10-07에 현재 source로 통과했다(QA.md의 Store Release Phase 1 Gate). 그 뒤 제품 source가 바뀌면 다시 실행한다.
3. 스토어용으로 서명한 build로 깨끗한 Mac 설치와 실제 macOS 14 Apple Silicon 장비 확인을 한다(TestFlight 또는 서명된 pkg). 서명된 build가 있어야 할 수 있다.

추가 확인으로 남긴 것(external / additional confidence checks, 현재 기록상 P0·P1 blocker 아님, 실제로 하지 않았음): 스토어 build에서 폴더 선택 창을 사람이 직접 누르는 것(‘상위 폴더 선택…’ 포함), 케이블을 실제로 뽑는 것(작업 중 포함), 네트워크 드라이브, iCloud Drive, VoiceOver, 대비 증가·큰 글자, 키보드만으로 전체 조작, 영어·일본어 원어민 확인. 출시 전에 할지 뒤로 미룰지는 사용자가 정한다.

## Mac App Store 제출 (T-007, 보류)

서명 방식: Xcode 자동 서명(D-039). 이 Mac에 배포 인증서를 따로 만들지 않는다.

준비된 것:
- AppStore 구성과 archive: eng/archive-store.sh --preflight <새 폴더>가 로컬 서명으로 archive를 만들고 내용을 확인한다(2026-10-07 통과: com.ailoworks.namefix, 1.0.0 build 6, arm64만, macOS 14.0, entitlement 셋, get-task-allow 없음, Hardened Runtime, ko/en/ja, 확인용 코드 문자열 0건, 실행 파일은 앱 하나). 이 archive는 제출용 서명이 아니다.
- Info.plist의 스토어 항목: 분류 public.app-category.utilities, ITSAppUsesNonExemptEncryption false. eng/validate-marketing.py가 스토어 문구와 대조한다.
- 접근 규칙과 권한 흐름: FILESYSTEM_CAPABILITIES.md의 ‘App Sandbox’, DESIGN.md의 ‘폴더 접근 요청’. 실제 sandbox 검증 도구: eng/test-sandbox.py.
- 스토어 문구·심사 메모·entitlement 목록·App Privacy 답: marketing/appstore.json. 스크린샷 15장: artifacts/marketing/namefix/1.0.0/store(현재 화면과 문구 기준).

이 Mac의 서명 자산(2026-10-07, 이름만 확인):
- Apple Development: AVAILABLE (private key 있음, 2027-09 만료)
- Developer ID Application: AVAILABLE (과거 직접 배포용, 지금은 쓰지 않음)
- Apple Distribution / Mac App Distribution / Mac Installer Distribution: MISSING — 자동 서명에서는 필요 없다
- com.ailoworks.namefix의 provisioning profile: MISSING — 자동 서명이 만든다
- Xcode 계정: AVAILABLE — 사용자가 로그인했다(역할 Admin, 팀 25373G7846). xcodebuild는 이 계정으로 App Store Connect는 읽지만 서명에 필요한 계정 단계에서 ‘No Account for Team’으로 멈춘다(2026-10-07, 사용자 터미널에서도 같음). 그래서 스토어용 서명과 내보내기는 Xcode Organizer에서 한다: archive를 열고 Distribute App › App Store Connect
- App Store Connect 앱 기록: MISSING — 2026-10-07에 Xcode의 조회에서 bundle ID com.ailoworks.namefix의 앱이 0개였다. 사용자가 만든다
- App ID: 확인하지 못했다(자동 서명이 없으면 만든다)

사용자가 해야 하는 일(순서대로):
1. Xcode › Settings › Accounts에서 Apple 계정이 로그인돼 있는지 확인한다(만료됐으면 다시 로그인).
2. App Store Connect(appstoreconnect.apple.com) › 계약에서 필요한 약관이 모두 동의 상태인지 확인한다. 무료 앱이면 무료 앱 계약만 있으면 된다.
3. 서명과 내보내기는 Xcode Organizer에서 한다. eng/archive-store.sh --signed가 만든 archive(artifacts/store/1.0.0/build6-signed/MoongchiNameFix.xcarchive)를 Xcode로 열고 Distribute App › App Store Connect를 고른다. Xcode가 App ID와 스토어용 profile을 만들고 cloud-managed 인증서로 서명한다. 명령줄 export는 계정 단계에서 멈추므로 쓰지 않는다.
4. App Store Connect › 앱 › + › 신규 앱: 플랫폼 macOS, 이름 Moongchi NameFix, 기본 언어 한국어, 번들 ID com.ailoworks.namefix(3번 뒤에 목록에 나온다), SKU AILOWORKS-NAMEFIX-MAC-100.
5. 그 뒤 업로드와 메타데이터·스크린샷·App Privacy 입력, 심사 제출은 다음 단계에서 한다.

비밀번호, 2FA 코드, 인증서 private key, API key는 채팅·저장소 문서·스크립트·로그에 적지 않는다.

알려진 확인 거리: 한국어·일본어 키워드는 글자 수로는 한도 안이지만 byte로는 100을 넘는다(ko 139, ja 117). App Store Connect가 입력을 거부하면 그 자리에서 줄이고 marketing/appstore.json도 맞춘다.

## 웹사이트

웹사이트는 뭉치페이지스 프로젝트가 맡는다(D-025). 이 저장소에서는 웹사이트 저장소를 고치지 않는다. 앱 저장소는 비공개를 유지한다.

웹사이트의 역할: 제품 소개, 지원, 개인정보처리방침, Mac App Store 링크. 직접 내려받는 파일(DMG·ZIP)은 제공하지 않는다(D-038). 스토어 링크는 앱이 공개된 뒤에 생긴다.

뭉치페이지스가 참조할 원본:
- 제품이 하는 일과 요구사항: docs/PROJECT.md
- 지원 범위와 하지 않는 것: docs/FILESYSTEM_CAPABILITIES.md
- 배포 채널과 상태: 이 문서
- 이름·개발사·문의 주소·가격·언어·시스템 요구와 ko/en/ja 문구: marketing/appstore.json
- 화면: 아래 ‘마케팅 자료’의 스토어 화면

앱 안의 웹사이트·문의 버튼(설정의 개발자 카드)은 https://moongchi.ailoworks.com 과 ailo@ailoworks.com 을 연다. 스토어에 넣을 제품·지원·개인정보 주소는 marketing/appstore.json의 urls이며, 웹사이트의 실제 경로가 바뀌면 그 값을 맞춘다.

## 마케팅 자료

- 스토어 문구 원본: marketing/appstore.json 하나(ko/en/ja의 이름·부제·홍보 문구·설명·키워드, URL, 분류, 연령 등급·수출 규정·App Privacy 답, 심사 메모, 스크린샷 문구). eng/validate-marketing.py가 글자 수 한도와 앱·프로젝트와의 일치를 확인한다.
- 화면: Debug 앱의 --render-marketing(App/MarketingFixtures.swift)이 예시용으로 만든 파일을 앱이 직접 검사·미리보기·이름 변경한 실제 창을 ko/en/ja로 촬영한다. AppStore build에는 들어가지 않는다. --marketing-samples로 경로가 화면에 드러나도 되는 중립 폴더를 넘긴다.
- 합성: eng/marketing-shots.py(Pillow 필요)가 스토어용 2880×1800 PNG 15장(5장면 × 3개 언어)과 manifest를 만든다. 산출물은 artifacts/marketing/namefix/1.0.0(Git 제외)에 있다. Mac App Store 스크린샷 규격(16:10, 1280×800·1440×900·2560×1600·2880×1800 중 하나, 1~10장)은 2026-10-07에 Apple 문서에서 확인했다.

## 과거 직접 배포 후보 (HISTORICAL_DIRECT_RC, NOT_FOR_PUBLIC_RELEASE)

1.0.0 build 5는 직접 배포를 준비하던 때에 Developer ID 서명과 Apple 공증까지 끝낸 후보다. 공개하지 않았고 앞으로도 공개하지 않는다(D-026, D-038). 역사적 Release Engineering 근거로만 보존하며 수정·삭제·재서명·재패키징하지 않는다. 새 직접 배포 산출물은 만들지 않는다.

- 위치: artifacts/release-candidate/1.0.0/build5-final (Git 제외). 계보는 build5-pre-sign → build5-signed-r2 → build5-final.
- DMG Moongchi_NameFix_1.0.0_build5_arm64.dmg, SHA-256 dab6d685d102a3641af28ced97e1c61edff99fdc12e0df4c5daad0fc3c39f4ca
- ZIP Moongchi_NameFix_1.0.0_build5_arm64.zip, SHA-256 7eac6ba04daa4ace33b7cede736e56ebf4d638a7d77693c1e096f9ffaf4657dd
- 함께 들어 있던 CLI namefix, SHA-256 d259d98b35a749895de93787a5e88421730d712cc8407415f34c93b8776043e0
- 제품 source commit 76972c7, 당시 release tooling commit 3e11e18. Developer ID Application: Hyein Kang (25373G7846), entitlement 없음(App Sandbox 밖).
- 공증: 앱 submission 6be4bd10-610a-4c47-adaa-0c2e2b074ff5, DMG submission c63f99e1-e719-4bb3-8855-aeca6f81150d, 둘 다 Accepted. staple과 Gatekeeper 평가 통과.
- 이 후보를 만들고 검증하던 도구(package-candidate, sign-candidate, notarize-candidate, verify-candidate, CLI build·test)와 CLI source는 현재 branch에 없다. Git 이력(711d937의 부모까지)에 있다.
