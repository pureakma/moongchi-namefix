# 빌드·서명·배포

## 출시 정책 (D-025, D-026, D-029, D-032, D-035)

- 에디션 둘, 코드 하나. 구성은 project.yml의 Debug / Release / AppStore.
  - Release: 직접 배포. Developer ID Application 서명 + Apple 공증 + DMG. App Sandbox OFF. namefix CLI 포함.
  - AppStore: Mac App Store. App Sandbox ON, entitlement는 app-sandbox · files.user-selected.read-write · files.bookmarks.app-scope 셋. CLI 없음. 제출은 아직 하지 않았다(아래 ‘Mac App Store 트랙’).
- 버전: MARKETING_VERSION 1.0.0, CURRENT_PROJECT_VERSION 6
- bundle ID: Release·AppStore com.ailoworks.namefix, Debug com.moongchi.namefix.dev. 원본은 project.yml 하나이며 build 명령이나 서명 도구가 바꾸지 않는다.
- 개발사 AILO WORKS, 문의 ailo@ailoworks.com
- 모든 기능 무료. 유료 등급·구매·계정·광고 없음. 앱은 네트워크를 쓰지 않는다.
- 업데이트: 직접 배포판은 ‘업데이트 확인…’이 브라우저로 제품 페이지를 연다. 스토어판은 스토어가 업데이트한다. 자동 updater 없음(D-029).
- macOS 14 이상, Apple Silicon arm64 전용
- Hardened Runtime ON. Release·AppStore 구성은 디버깅 entitlement를 넣지 않는다.

## 현재 Release 상태

SUPERSEDED_FOR_PUBLIC_RELEASE (2026-10-07, D-026). 아래 build 5 산출물은 서명·공증까지 끝난 과거 Release 후보로 보존하며 공개 출시에 쓰지 않는다. 수정·삭제·재서명하지 않는다. 다음 공개 후보는 Global Product Hardening(T-008) 뒤에 build 6 이상으로 새로 만들고, 서명·공증·깨끗한 Mac 확인을 그 후보에서 다시 한다. 아래 기록은 build 5에 대한 사실이다.

- 최종 산출물: artifacts/release-candidate/1.0.0/build5-final
  - 배포용 DMG(주 산출물): Moongchi_NameFix_1.0.0_build5_arm64.dmg, SHA-256 dab6d685d102a3641af28ced97e1c61edff99fdc12e0df4c5daad0fc3c39f4ca
  - 보조 ZIP: Moongchi_NameFix_1.0.0_build5_arm64.zip, SHA-256 7eac6ba04daa4ace33b7cede736e56ebf4d638a7d77693c1e096f9ffaf4657dd
  - CLI namefix: SHA-256 d259d98b35a749895de93787a5e88421730d712cc8407415f34c93b8776043e0
  - DMG 내용: Moongchi NameFix.app, Applications 바로가기, namefix, README.txt, USER_GUIDE.md, ThirdPartyNotices.md, BUILD_INFO.json
- 제품: 1.0.0 build 5, com.ailoworks.namefix, arm64, macOS 14 이상. 제품 source commit 76972c7(서명 전 후보에서 계승), release tooling commit 3e11e18.
- Developer ID 서명: 완료. Developer ID Application: Hyein Kang (25373G7846), Hardened Runtime, secure timestamp, entitlement 없음. 앱과 CLI는 한 번만 서명했고 그 binary 그대로 공증했다.
- 공증: 앱 Accepted(submission 6be4bd10-610a-4c47-adaa-0c2e2b074ff5), DMG Accepted(submission c63f99e1-e719-4bb3-8855-aeca6f81150d). 두 notary log 모두 issue 없음. DMG의 티켓에 앱과 CLI가 포함된다. notarytool profile은 NameFix-Notary.
- staple: 앱과 DMG 모두 staple 후 validate 통과.
- Gatekeeper: 앱(execute)과 DMG(open) 모두 accepted, source=Notarized Developer ID.
- 검증: eng/verify-candidate.py 통과(manifest hash, Info.plist, 리소스, 서명, 공증 기록, DMG 무결성·읽기 전용 mount, ZIP 풀기, self-test, CLI 계약). 공증된 앱을 한 번 실행해 창이 뜨는 것을 확인했다.
- 공개 배포: 하지 않음. DMG 업로드, 다운로드 링크, GitHub Release, App Store 제출은 없다. 산출물 안의 BUILD_INFO(publicRelease false)는 고치지 않는다. 다운로드를 열면 그 사실을 이 문서에 적는다.
- 깨끗한 Mac 확인: build 5로는 하지 않는다. 새 후보에서 수행한다(D-026).

계보: build5-pre-sign(서명 전) → build5-signed-r2(Developer ID 서명) → build5-final(공증·staple·패키지). 각 단계는 새 디렉터리에서 했고 앞 단계의 디렉터리는 바뀌지 않았다. build5-signed는 중단된 시도(ABORTED.txt), build4-pre-sign과 build3는 대체된 기록이다.

다음 후보는 build 번호를 6 이상으로 올리고 새 output 경로를 쓴다. build 번호는 Release 단계에서 한 번 정한다.

## 웹사이트

웹사이트는 뭉치페이지스 프로젝트가 맡는다(D-025). 이 저장소에서는 웹사이트 저장소를 고치지 않으며 웹사이트용 이미지와 배포 절차를 두지 않는다. 앱 저장소는 비공개를 유지한다.

뭉치페이지스가 참조할 원본:
- 제품이 하는 일과 요구사항: docs/PROJECT.md
- 지원 범위와 하지 않는 것(내장 APFS만, 외장·네트워크·클라우드 폴더 보호 등): docs/FILESYSTEM_CAPABILITIES.md
- 배포 상태, 최종 산출물의 파일 이름·SHA-256·서명·공증: 이 문서의 ‘현재 Release 상태’. 다운로드로 내보낼 파일은 build5-final의 DMG이며 수정·재서명 없이 그대로 쓴다.
- 이름·개발사·문의 주소·가격·언어·시스템 요구와 ko/en/ja 문구: marketing/appstore.json
- 화면: 앱을 직접 실행하거나, Debug 앱의 --render-marketing으로 예시 파일 장면을 촬영한다(아래 ‘마케팅 자료’).

앱 안의 웹사이트·문의 버튼(설정의 개발자 카드)은 https://moongchi.ailoworks.com 과 ailo@ailoworks.com 을 연다. 스토어에 넣을 제품·지원·개인정보 주소는 marketing/appstore.json의 urls이며, 웹사이트의 실제 경로가 바뀌면 그 값을 맞춘다.

## 마케팅 자료

- 스토어 문구 원본: marketing/appstore.json 하나(ko/en/ja의 이름·부제·홍보 문구·설명·키워드, URL, 분류, 연령 등급·수출 규정·App Privacy 답, 심사 메모, 스크린샷 문구). eng/validate-marketing.py가 글자 수 한도와 앱·프로젝트와의 일치를 확인한다.
- 화면: Debug 앱의 --render-marketing(App/MarketingFixtures.swift)이 예시용으로 만든 파일을 앱이 직접 검사·미리보기·이름 변경한 실제 창을 ko/en/ja로 촬영한다. Release build에는 들어가지 않는다. --marketing-samples로 경로가 화면에 드러나도 되는 중립 폴더를 넘긴다.
- 합성: eng/marketing-shots.py(Pillow 필요)가 스토어용 2880×1800 PNG 15장(5장면 × 3개 언어)과 manifest를 만든다. 산출물은 artifacts/marketing/namefix/1.0.0(Git 제외)에 있다. Mac App Store 스크린샷 규격(16:10, 1280×800·1440×900·2560×1600·2880×1800 중 하나, 1~10장)은 2026-10-07에 Apple 문서에서 확인했다.

## Release Candidate 진입 조건

Final QA Gate(T-010, 2026-10-07)의 판정은 NEEDS_USER_QA다. 자동 검증에서 P0·P1은 없고 build 6을 유지한다. 다음이 끝나면 Release Candidate 단계로 간다.

1. 사용자가 QA.md의 R1~R7을 확인한다. R2(스토어판에서 폴더 선택 창을 눌러 받는 권한)가 가장 먼저다.
2. 사용자가 Release Candidate 단계를 승인한다. 그때 build 번호를 정하고(지금은 6), 직접 배포판은 아래 ‘순서’대로 후보·서명·공증을, 스토어판은 ‘Mac App Store 트랙’의 외부 입력을 준비해 archive·업로드를 한다.
3. 서명된 후보로 깨끗한 Mac 설치와 macOS 14 장비 확인을 한다.

이 Gate에서는 후보 생성, Developer ID 서명, 공증, 스토어 서명·업로드·제출을 하지 않았다.

## Mac App Store 트랙

상태: SANDBOX_READY — 스토어판 구성과 sandbox 안의 동작은 구현·검증됐다(T-009). 제출·업로드·App Store Connect 기록 생성은 하지 않았다. 직접 배포 build 5와 그 구성은 이 트랙 때문에 바뀌지 않았다.

구현된 것:
- AppStore 구성(eng/build.sh --configuration AppStore): App Sandbox ON, entitlement 셋, 디버깅 entitlement 없음, arm64, macOS 14 이상, ko/en/ja, render·probe fixture 없음.
- 접근 규칙과 권한 흐름: FILESYSTEM_CAPABILITIES.md의 ‘App Sandbox (스토어판)’, DESIGN.md의 ‘폴더 접근 요청 (스토어판)’.
- 실제 sandbox 검증 도구: eng/test-sandbox.py(스토어 entitlement로 서명한 Debug 앱, 별도 식별자 com.moongchi.namefix.sandboxqa).
- 스토어 문구·심사 메모·entitlement 목록: marketing/appstore.json.

직접 배포판과 다른 점(심사 메모에도 적었다): 추가한 폴더 자체의 이름은 바꾸지 않음(부모 폴더를 추가하면 가능), 파일만 추가하면 그 폴더를 한 번 고름, CLI 없음, ‘업데이트 확인’ 메뉴 없음.

Store Release Phase에 필요한 외부 입력(사용자가 준비):
- Apple Distribution, Mac Installer Distribution 인증서(새 private key)와 Mac App Store provisioning profile. 이 Mac의 서명 identity는 Developer ID Application과 Apple Development뿐이다.
- App Store Connect 접근(로그인·2FA 또는 API key)과 필요한 약관 동의.
- App Store Connect의 앱 기록(이름 Moongchi NameFix, bundle ID com.ailoworks.namefix, SKU는 marketing/appstore.json).
- 그 뒤에 할 일: AppStore 구성 archive → 배포 인증서로 서명한 pkg → 검증·업로드 → 메타데이터·스크린샷·App Privacy 입력 → 심사 제출. 스크린샷은 스토어판 문구로 다시 촬영한다.

## 공증에 필요한 외부 입력

notarytool Keychain profile 하나가 필요하다. 현재 쓰는 것은 사용자가 만든 NameFix-Notary다(예전 MoongchiNotaryRC는 Apple에서 거부되어 쓰지 않는다). 다시 만들 때는 Apple ID와 앱 전용 암호가 필요하므로 사용자가 로컬 터미널에서 직접 만든다(자격 증명은 채팅·문서·저장소에 남기지 않는다).

~~~sh
xcrun notarytool store-credentials "NameFix-Notary" --apple-id "<Apple ID>" --team-id 25373G7846
~~~

비밀번호, app-specific password, 인증서 private key, API key는 저장소 문서·스크립트·로그에 기록하지 않는다. Gatekeeper/SIP/검역 해제로 미완료 서명·공증을 우회하지 않는다.

## 순서

1. (완료) 현재 source를 commit하고 Release 구성으로 앱과 CLI를 build → package-candidate.py로 서명 전 후보 → verify-candidate.py.
2. (완료) sign-candidate.py로 후보의 사본을 새 경로에서 Developer ID로 한 번 서명. 제품 정보와 source commit은 서명 전 후보의 manifest에서 그대로 가져온다.
3. (완료) notarize-candidate.py: 서명된 binary를 다시 서명하지 않고 그대로 제출 → Apple이 Accepted라고 답한 뒤에만 ACCEPTED 기록 → staple과 validate 뒤에만 stapled 기록 → 앱 Gatekeeper 평가 → DMG와 ZIP 생성 → DMG 서명·공증·staple·Gatekeeper 평가 → 최종 manifest.
4. (완료) verify-candidate.py로 최종 산출물 검증(DMG 읽기 전용 mount, ZIP 풀기 포함).
5. (대기) 깨끗한 Mac 설치·실행과 QA.md의 User QA.
6. (대기) 그 뒤에만 공개 배포 가능 판정을 기록한다. 공개 업로드는 별도의 명시적 단계다.

## helper

~~~sh
eng/build.sh --configuration Release --arch arm64
bash eng/build-cli.sh release
python3 eng/package-candidate.py --output artifacts/release-candidate/1.0.0/<새 경로> --cli .build/release/namefix
python3 eng/verify-candidate.py artifacts/release-candidate/1.0.0/<경로>
python3 eng/sign-candidate.py --input <서명 전 후보> --dry-run
python3 eng/sign-candidate.py --input <서명 전 후보> --identity "<Developer ID>" --output <새 경로>
python3 eng/notarize-candidate.py --input <서명된 후보> --profile <notarytool profile> --output <새 경로>
~~~

실제 옵션은 helper 자체가 원본이다. 어느 도구도 앱의 식별자를 바꾸지 않고, 기존 경로를 덮어쓰지 않으며, 제품 source commit은 서명 전 후보의 것을 끝까지 유지한다(도구의 commit은 releaseToolingCommit으로 따로 적는다). helper 실행 자체를 성공 근거로 쓰지 않고 결과와 hash/evidence를 확인한다.

패키지에 넣는 사용자 안내는 PACKAGE_README.txt(패키지의 README.txt)와 EXPANSION_USER_GUIDE.md(USER_GUIDE.md)다. 후보 자체의 상태(서명·공증 여부)는 도구가 만드는 CANDIDATE_STATUS.txt, BUILD_INFO.json, ARTIFACT_MANIFEST.json에만 적는다.
