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

출시 보류(D-026). APPSTORE_ONLY_READY(T-012): 현재 source 1.0.0 build 6으로 AppStore 구성이 build되고 실제 sandbox 검증을 통과했다. Release Candidate는 만들지 않았고, 스토어 서명·archive·업로드·심사 제출도 하지 않았다.

## Release Candidate 진입 조건

Final User QA Session(T-010)의 판정은 USER_QA_COMPLETE_WITH_EXTERNAL_PENDING이고 P0·P1은 없다. Release Candidate 단계에 들어갈 수 있으며, 사용자가 승인하기 전에는 후보를 만들지 않는다.

1. 사용자가 Release Candidate Phase를 승인하고 아래 ‘Mac App Store 제출’의 외부 입력을 준비한다. build 번호는 그때 정한다(지금은 6).
2. 후보를 만들기 전에 현재 source로 통합 Gate를 다시 실행한다(QA.md: test, 실제 sandbox 15개, AppStore build 확인).
3. 스토어용으로 서명한 build로 깨끗한 Mac 설치와 실제 macOS 14 Apple Silicon 장비 확인을 한다(TestFlight 또는 서명된 pkg). 서명된 build가 있어야 할 수 있다.

추가 확인으로 남긴 것(external / additional confidence checks, 현재 기록상 P0·P1 blocker 아님, 실제로 하지 않았음): 스토어 build에서 폴더 선택 창을 사람이 직접 누르는 것(‘상위 폴더 선택…’ 포함), 케이블을 실제로 뽑는 것(작업 중 포함), 네트워크 드라이브, iCloud Drive, VoiceOver, 대비 증가·큰 글자, 키보드만으로 전체 조작, 영어·일본어 원어민 확인. 출시 전에 할지 뒤로 미룰지는 사용자가 정한다.

## Mac App Store 제출 (T-007, 보류)

준비된 것:
- AppStore 구성: eng/build.sh --configuration AppStore --arch arm64. 확인은 eng/verify-release.sh <앱 경로>(arm64, 서명, self-test).
- 접근 규칙과 권한 흐름: FILESYSTEM_CAPABILITIES.md의 ‘App Sandbox’, DESIGN.md의 ‘폴더 접근 요청’.
- 실제 sandbox 검증 도구: eng/test-sandbox.py.
- 스토어 문구·심사 메모·entitlement 목록·App Privacy 답: marketing/appstore.json. 스크린샷 15장: artifacts/marketing/namefix/1.0.0/store.

사용자가 준비할 외부 입력:
- Apple Distribution, Mac Installer Distribution 인증서(새 private key)와 Mac App Store provisioning profile. 이 Mac의 서명 identity는 Developer ID Application과 Apple Development뿐이다.
- App Store Connect 접근(로그인·2FA 또는 API key)과 필요한 약관 동의.
- App Store Connect의 앱 기록(이름 Moongchi NameFix, bundle ID com.ailoworks.namefix, SKU는 marketing/appstore.json).

그 뒤의 순서: AppStore 구성 archive → 배포 인증서로 서명한 pkg → 검증·업로드 → 메타데이터·스크린샷·App Privacy 입력 → 심사 제출. 비밀번호, 인증서 private key, API key는 저장소 문서·스크립트·로그에 적지 않는다.

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
