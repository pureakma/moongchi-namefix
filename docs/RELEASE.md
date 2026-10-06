# 빌드·서명·배포

## 출시 정책 (D-023, D-024)

- 배포: 직접 배포. Developer ID Application 서명 + Apple 공증 + DMG. Mac App Store는 별도 트랙이며 아직 시작하지 않았다(아래 ‘Mac App Store 트랙’).
- 버전: MARKETING_VERSION 1.0.0, CURRENT_PROJECT_VERSION 5
- bundle ID: Release 구성 com.ailoworks.namefix, Debug 구성 com.moongchi.namefix.dev. 원본은 project.yml 하나이며 build 명령이나 서명 도구가 바꾸지 않는다.
- 개발사 AILO WORKS, 문의 ailo@ailoworks.com
- 모든 기능 무료. 유료 등급·구매·계정·광고 없음.
- macOS 14 이상, Apple Silicon arm64 전용
- App Sandbox OFF, Hardened Runtime ON. Release 구성은 디버깅 entitlement를 넣지 않는다.

## 현재 Release 상태

RELEASE_ARTIFACT_READY (2026-10-06), WEBSITE_PUBLISHED (2026-10-07). 직접 배포 다운로드는 준비만 하고 열지 않았다(DIRECT_DOWNLOAD_PREPARED). 다운로드 공개와 깨끗한 Mac 확인이 남았다.

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
- 공개 배포: 하지 않음. 웹사이트에 제품 페이지는 공개했지만 DMG 업로드, 다운로드 링크, GitHub Release, App Store 제출은 없다. 산출물 안의 BUILD_INFO(publicRelease false)는 고치지 않으며, 공개 여부는 이 문서와 웹사이트 설정에서 관리한다.
- 깨끗한 Mac 확인: CLEAN_MAC_QA_PENDING. 별도의 깨끗한 Mac이나 VM을 쓸 수 없어 하지 않았다. 개발 Mac에서의 실행은 이 확인을 대신하지 않는다.

계보: build5-pre-sign(서명 전) → build5-signed-r2(Developer ID 서명) → build5-final(공증·staple·패키지). 각 단계는 새 디렉터리에서 했고 앞 단계의 디렉터리는 바뀌지 않았다. build5-signed는 중단된 시도(ABORTED.txt), build4-pre-sign과 build3는 대체된 기록이다.

후보를 다시 만들어야 하면 build 번호를 6 이상으로 올리고 새 output 경로를 쓴다.

## 웹사이트와 다운로드 공개 준비

- 웹사이트 저장소: pureakma/moongchi-website(비공개), main이 Cloudflare Pages 프로젝트 moongchi로 자동 배포된다. NameFix 추가는 PR #6, main 0984460(2026-10-07).
- 공개 주소: 제품 https://moongchi.ailoworks.com/namefix/ , 개인정보처리방침 https://moongchi.ailoworks.com/namefix/privacy/ , 지원 https://moongchi.ailoworks.com/support/ (NameFix 지원 항목 포함). ko/en/ja.
- 다운로드: 열지 않았다. 웹사이트 설정의 NameFix directUrl과 storeUrl은 빈 값이고 DMG는 웹사이트 저장소와 공개 서버에 없다. ‘Mac용 다운로드’ 버튼은 다른 뭉치 앱과 같이 주소 업데이트 예정 안내만 표시한다.
- 여는 방법(사용자가 결정한 뒤): build5-final의 DMG를 수정 없이 웹사이트 저장소 downloads/namefix/에 넣고 directUrl을 설정한다. 웹사이트의 scripts/verify.mjs가 파일 크기와 SHA-256이 위 최종 산출물 기록과 같을 때만 통과한다. 배포 뒤 공개 주소에서 다시 받아 SHA-256, hdiutil verify, Gatekeeper를 확인한다. DMG는 16.5 MiB로 Cloudflare Pages 파일 한도(25 MiB) 안이며 새 저장 서비스가 필요 없다. 절차의 원본은 웹사이트 저장소 README의 ‘NameFix 제품 추가’ 절이다.
- 앱 저장소(pureakma/moongchi-namefix)는 비공개를 유지한다. 웹사이트에는 사용자 문서·화면·문구만 올라간다.

## 마케팅 자료

- 스토어 문구 원본: marketing/appstore.json 하나(ko/en/ja의 이름·부제·홍보 문구·설명·키워드, URL, 분류, 연령 등급·수출 규정·App Privacy 답, 심사 메모, 스크린샷 문구). eng/validate-marketing.py가 글자 수 한도와 앱·프로젝트와의 일치를 확인한다.
- 화면: Debug 앱의 --render-marketing(App/MarketingFixtures.swift)이 예시용으로 만든 파일을 앱이 직접 검사·미리보기·이름 변경한 실제 창을 ko/en/ja로 촬영한다. Release build에는 들어가지 않는다. --marketing-samples로 경로가 화면에 드러나도 되는 중립 폴더를 넘긴다.
- 합성: eng/marketing-shots.py(Pillow 필요)가 스토어용 2880×1800 PNG 15장(5장면 × 3개 언어), 웹용 1600×976 JPEG 15장, 공유 미리보기 1장과 manifest를 만든다. 산출물은 artifacts/marketing/namefix/1.0.0(Git 제외)에 있다. Mac App Store 스크린샷 규격(16:10, 1280×800·1440×900·2560×1600·2880×1800 중 하나, 1~10장)은 2026-10-07에 Apple 문서에서 확인했다.

## Mac App Store 트랙

상태: NOT_STARTED. 제출·업로드·App Store Connect 기록 생성 없음. 직접 배포 build 5와 그 구성은 이 트랙 때문에 바꾸지 않는다.

막힌 것(사용자 입력이 필요):
- 배포 인증서: 이 Mac의 서명 identity는 Developer ID Application과 Apple Development뿐이다. Mac App Store 제출에는 Apple Distribution과 Mac Installer Distribution 인증서(새 private key)와 provisioning profile이 필요하다.
- App Store Connect 인증: API key나 로그인된 업로드 수단이 없다. 앱 기록 생성·메타데이터 입력·제출에는 사용자의 로그인(2FA)과 약관 동의가 필요하다.

sandbox 호환 분석(2026-10-07, 코드 확인):
- 안전 경계의 기준점: Infrastructure/FileSystem.swift는 symlink를 따라가지 않으려고 루트부터 모든 경로 요소를 O_NOFOLLOW로 연다. App Sandbox에서는 허용받은 폴더의 조상 디렉터리를 열 수 없으므로 이 walk를 허용받은 폴더에서 시작하도록 다시 설계하고 safety·transaction 검증을 다시 해야 한다.
- 파일 단위 입력: 끌어다 놓거나 고른 파일 하나는 부모 폴더 쓰기 권한이 없어 이름을 바꿀 수 없다. 폴더 접근을 한 번 더 받는 흐름이 필요하고, Finder 서비스와 ‘다음으로 열기’로 들어온 파일도 같다.
- 다시 실행한 뒤의 Undo/Recovery와 최근 폴더: 작업 기록과 최근 목록에 security-scoped bookmark를 함께 저장해야 한다(Journal·설정 schema 변경). 즐겨찾기와 감시 폴더는 이미 bookmark를 저장한다.
- 그대로 쓸 수 있는 것: 로그인 시 실행(SMAppService), 앱 데이터 폴더(컨테이너로 이동), 네트워크 권한 불필요. CLI는 스토어판에 넣지 않는다.
- 판단: 핵심 기능은 폴더 기준 흐름으로 유지할 수 있어 차단 사유는 아니다. 다만 파일 안전 경계와 저장 구조를 바꾸는 별도 Task이며, 설계 승인과 영향 검증 뒤에 build 6 이상으로 진행한다.

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
