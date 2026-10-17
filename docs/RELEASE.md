# 빌드·배포

## 출시 정책 (D-038, D-042)

- 공개 경로는 둘: Mac App Store, 그리고 직접 다운로드(일반판, DMG·ZIP). 둘 다 무료. 두 경로의 앱은 같은 AppStore 구성 빌드이고 서명만 다르다(앱스토어판은 Apple 배포 서명, 일반판은 Developer ID 서명·공증). 사용자용 CLI는 없다. 앱 안에 후원 링크는 없다.
- 구성은 project.yml의 Debug와 AppStore 둘.
  - Debug: 개발·QA. App Sandbox OFF, bundle ID com.moongchi.namefix.dev. render·probe·진단 fixture는 이 구성에만 compile된다. 실제 sandbox 검증용으로 eng/build.sh --sandbox-debug가 같은 Debug 앱을 스토어 entitlement로 만든다(식별자 com.moongchi.namefix.sandboxqa).
  - AppStore: 공개 배포. App Sandbox ON, entitlement는 app-sandbox · files.user-selected.read-write · files.bookmarks.app-scope 셋, 디버깅 entitlement 없음, bundle ID com.ailoworks.namefix.
- 버전: MARKETING_VERSION 1.0.1, CURRENT_PROJECT_VERSION 7. 원본은 project.yml 하나이며 build 명령이 바꾸지 않는다.
- macOS 14 이상, Apple Silicon arm64 전용. Hardened Runtime ON.
- 개발사 AILO WORKS, 문의 ailo@ailoworks.com
- 모든 기능 무료. 유료 등급·구매·계정·광고·추적 없음. 앱은 네트워크를 쓰지 않는다.
- 앱에 업데이트 명령이나 자체 updater는 없다. 앱스토어판의 설치와 업데이트는 App Store가, 일반판의 새 버전 안내는 다운로드 페이지가 맡는다.

## 현재 상태

2026-10-17 언어별 앱 이름을 고친 1.0.1 build 7 일반판을 공개하고 이 Mac에 설치했다(T-017, D-044). 같은 AppStore archive에서 만든 앱·DMG의 Developer ID 서명·Apple 공증·스테이플링·Gatekeeper, ZIP·DMG 내부 앱과 세 언어 표시 이름, 공개 파일 여섯 개의 익명 다운로드·SHA-256 일치 확인이 끝났다. 스토어에는 새 빌드를 업로드·연결하고 기존 1.0.0 심사 대기 제출을 철회한 뒤 재제출했다. Apple 상세 화면에서 1.0.1 (7)·제출 항목 1개·심사 대기 중을 확인했다. Apple 승인·스토어 공개와 구분한다. 직전 1.0.0 공개 파일·태그는 바꾸지 않았다. 현재 산출물·근거는 바로 아래 T-017 절과 QA.md다.

## Release Candidate 진입 조건

Final User QA Session(T-010)의 판정은 USER_QA_COMPLETE_WITH_EXTERNAL_PENDING이고 P0·P1은 없다. Release Candidate 단계에 들어갈 수 있으며, 사용자가 승인하기 전에는 후보를 만들지 않는다.

1. 사용자는 2026-10-17에 현재 build 6의 배포 준비 진행을 승인했다. 공개 게시·필수 동의·심사 제출 완료는 각각 실제 결과로 확인한다.
2. 제품 검증은 QA.md의 T-013·T-014 영향 Gate를 재사용한다. 이번 작업은 제품 source를 바꾸지 않아 전체 QA를 반복하지 않았고, 서명·패키지 및 제출 항목만 검증했다.
3. 스토어용으로 서명한 build로 깨끗한 Mac 설치와 실제 macOS 14 Apple Silicon 장비 확인을 한다(TestFlight 또는 서명된 pkg). 서명된 build가 있어야 할 수 있다.

추가 확인으로 남긴 것(external / additional confidence checks, 현재 기록상 P0·P1 blocker 아님, 실제로 하지 않았음): 스토어 build에서 폴더 선택 창을 사람이 직접 누르는 것(‘상위 폴더 선택…’ 포함), 케이블을 실제로 뽑는 것(작업 중 포함), 네트워크 드라이브, iCloud Drive, VoiceOver, 대비 증가·큰 글자, 키보드만으로 전체 조작, 영어·일본어 원어민 확인. 출시 전에 할지 뒤로 미룰지는 사용자가 정한다.

## 1.0.1 현지화 배포 (T-017, D-044)

- 심사 접수: 2026-10-17 20:15 KST, 제출 ID e16e234c-4941-4665-af97-dda0c89cb43c. Apple 상세 화면에서 macOS 1.0.1·빌드 7·제출 항목 1개·심사 대기 중 확인. [심사 상세](https://appstoreconnect.apple.com/apps/6823853405/distribution/reviewsubmissions/details/e16e234c-4941-4665-af97-dda0c89cb43c). 승인 후 자동 출시 설정을 유지했다.
- 앱 이름·언어 선택: D-044, 번역 원본의 AppName. 한국어·일본어 App Store 이름과 설명 저장 후 페이지를 다시 열어 확인했고, 영어 이름·설명은 기존 올바른 표기를 유지했다. 처음 실행하면 시스템 언어를 따르고 기존 사용자의 명시적 언어 선택은 유지한다. 별도의 언어 강제 이관은 없다.
- 제품 source: 07dcc1867569d0e30f4950a8cb97116621585256. 서명 archive: artifacts/store/1.0.1/build7-20261017-localized/MoongchiNameFix.xcarchive. AppStore 구성·arm64·macOS 14 이상·sandbox, bundle ID와 entitlement 셋은 유지했다. signed archive·pkg export·같은 archive의 App Store Connect upload 모두 성공했다. 새 빌드 ID 51cb8584-6b84-49d0-9b32-30595b5e4ba2, Apple에서 제출 준비 완료 확인.
- 일반판: artifacts/direct/1.0.1/build7-20261017-localized. 위 archive의 앱을 복사해 Developer ID로 재서명했으며 다시 컴파일하지 않았다. 앱 공증 0a4c8122-3f4d-4a29-a7bb-2cb983496c9c, DMG 공증 e4d3cd90-7e21-4047-aeaf-d7d621c18a37, 둘 다 Accepted. app·DMG staple validate·Gatekeeper PASS. 공개 ZIP 추출 앱·읽기 전용 DMG 내부 앱의 실행 파일 해시·서명·공증·세 언어 이름도 확인했다.
- 공개 릴리즈: https://github.com/pureakma/moongchi-namefix/releases/tag/v1.0.1. DMG·ZIP·체크섬·LICENSE·ThirdPartyNotices.md·Branding-Notice.txt 여섯 파일. 서버 digest와 로컬 파일 일치 뒤 공개했으며, 인증 없는 실제 다운로드와 내려받은 체크섬 검증 PASS. 1.0.0 태그와 배포 파일은 유지했다.
- 다운로드: [DMG](https://github.com/pureakma/moongchi-namefix/releases/download/v1.0.1/Moongchi_NameFix_1.0.1_build7_arm64.dmg) · [ZIP](https://github.com/pureakma/moongchi-namefix/releases/download/v1.0.1/Moongchi_NameFix_1.0.1_build7_arm64.zip) · [체크섬](https://github.com/pureakma/moongchi-namefix/releases/download/v1.0.1/SHA256SUMS.txt). SHA-256: DMG 331bb56d1a8bd16fbfe0209e5ec1540209d43323d4f6ff4a22cb94bb72aef169, ZIP b818dc9072458063384da216ce2ddff42850f366ea3e199901c8747f335fb56a.
- 설치: 공개 ZIP으로 /Applications/Moongchi NameFix.app을 1.0.1 (7)로 교체하고 실제 메뉴·앱 정보의 한국어 이름을 확인했다. 기존 앱 백업은 사용자 지시대로 남기지 않았다. 설정·작업 기록 파일은 수정하지 않았다. 근거 artifacts/install/github-v1.0.1-20261017.
- 스토어: 기존 1.0.0 제출 제거 뒤 버전 1.0.1과 빌드 7을 저장하고 새 심사 제출을 요청했다. 한국어·영어·일본어 설명은 marketing/appstore.json과 일치 확인. 개인정보·연락처·무료 가격·국가·승인 후 자동 출시 설정은 유지했다. 기능 화면이 바뀌지 않아 이미 저장된 언어별 스크린샷 각 5장(총 15장)은 유지했다. 새 빌드의 15장 캡처는 동등한 기능 화면 확인용으로 생성했으며 재업로드했다고 주장하지 않는다.
- 검증: QA.md, artifacts/evidence/localization-20261017. 공증 비밀번호·인증서 private key·심사 연락처는 새 문서·Git·첨부 파일에 기록하지 않았다. 웹사이트는 별도 저장소이므로 바꾸지 않았다.

## 일반판 만들기 (D-042, T-015)

```sh
eng/package-direct.sh <새 폴더> --notary-profile MoongchiNotaryRC
```

- 하는 일: 커밋된 제품 source로 AppStore 구성 archive를 만들고, 앱을 Developer ID(팀 25373G7846)로 다시 서명한 뒤(Hardened Runtime, secure timestamp, store entitlement 셋), 앱을 공증·스테이플링하고, DMG를 만들어 서명·공증·스테이플링하고, ZIP과 SHA256SUMS.txt, BUILD_INFO.json을 남긴다. 단계마다 arm64 전용, entitlement 셋, 확인용 코드 문자열 0건, Gatekeeper 판정을 확인한다. 제품 source에 커밋하지 않은 변경이 있으면 시작하지 않는다.
- 공증 인증 정보는 개발자가 Terminal에서 한 번 저장한다. 비밀번호는 채팅·문서·Git에 남기지 않는다.

```sh
xcrun notarytool store-credentials MoongchiNotaryRC --apple-id <개발자 Apple ID> --team-id 25373G7846
```

  App 전용 암호는 appleid.apple.com의 ‘로그인 및 보안 › 앱 암호’에서 만들고, 위 명령이 물을 때 입력한다(화면에 표시되지 않음).
- 공증 없이 실행하면 서명까지만 하고 BUILD_INFO의 forDownload가 false다. Gatekeeper는 ‘Unnotarized Developer ID’로 거절한다. 이런 결과는 내려받게 하지 않는다.
- 결과 위치: artifacts/direct/<버전>/build<번호> (Git 제외). build 5의 과거 후보(artifacts/release-candidate)는 건드리지 않는다.
### 최초 1.0.0 일반판과 Xcode 공증 경로

처음 MoongchiNotaryRC history 조회는 HTTP 401이었으나 Xcode 로그인으로 앱 공증은 성공했다. 이후 사용자가 Terminal에서 인증정보를 직접 저장했고 history 조회가 정상화돼 DMG 공증도 마쳤다. Xcode 로그인과 notarytool의 앱 전용 암호 프로필은 별도 인증 경로다. 새 암호를 채팅·문서·로그에 남기지 않았다.

- 배포 archive: artifacts/store/1.0.0/build6-20261017-recovery/MoongchiNameFix.xcarchive. 제품 source commit dcfe247(이번 문구·문서 변경 전).
- Xcode Organizer: 해당 archive → Distribute App → Direct Distribution. 공증 ID F1C30C1A-7455-45D2-8F10-A86AC9F00FD5, Ready to distribute 확인 → Export Notarized App.
- 결과: artifacts/direct/1.0.0/build6-xcode-20261017/Moongchi NameFix.app. 팀 25373G7846의 Developer ID, arm64, 기존 sandbox entitlement 셋, staple validate PASS, Gatekeeper accepted / Notarized Developer ID.
- ZIP: 같은 폴더의 Moongchi_NameFix_1.0.0_build6_arm64.zip. ZIP을 풀어 staple과 Gatekeeper 재확인 PASS. BUILD_INFO.json의 ZIP forDownload true는 로컬 산출물의 상태이며 실제 공개 게시를 뜻하지 않는다.
- DMG: 같은 이름의 .dmg를 notarytool로 제출해 Accepted, 공증 ID 2c4acae3-ac86-4400-9cc4-c8c2e68f486c, Apple 결과 Ready for distribution / statusCode 0 / issues 없음. 스테이플링·validate·서명·Gatekeeper accepted / Notarized Developer ID. 읽기 전용으로 열어 내부 앱의 서명·staple·Gatekeeper·1.0.0 (6)·arm64·기존 앱과 실행 파일 SHA-256 일치·Applications 바로가지를 확인했다. forDownload true.
- SHA-256과 파일별 공개 가능 상태는 해당 폴더의 SHA256SUMS.txt·BUILD_INFO.json이 원본이다.

DMG의 최종 SHA-256·BUILD_INFO를 갱신했다. 앱과 ZIP은 다시 만들지 않았으며 ZIP 해시는 그대로다. DMG 공증·내용 검증 근거는 해당 폴더 evidence와 artifacts/evidence/public-release-20261017/dmg-notarization.json에 있다.

## 최초 Mac App Store 제출 근거 (T-007)

서명 방식은 D-039의 Xcode 자동 서명이다. 기존 cloud-managed 배포 인증서를 사용했고 수동 배포 인증서나 API key를 만들거나 기존 자산을 삭제하지 않았다.

현재 스토어 버전과 재제출 상태는 위 T-017 절이 원본이다. 아래는 최초 1.0.0 제출의 계정·서명 복구 근거다.

### 확인한 Apple 상태 (2026-10-17)

- Developer 계정: 등록 유형 조직, 법인명 LabMeet, 팀 25373G7846. 연결 이메일과 계정 소유자를 화면으로 확인했다. 멤버십 갱신일 2027-09-05. 이전의 멤버십 비활성 안내는 현재 계정 화면에 없다.
- 2026-10-14 Program License Agreement가 2026-10-17에 수락된 것으로 표시됐다. 이번 실행에서 약관을 수락하지 않았다.
- Certificates, Identifiers & Profiles 페이지와 Xcode의 같은 항목 접근이 정상이며 기존 Developer ID·Development·Distribution Managed·Mac Installer Distribution Managed 인증서가 보인다.
- App Store Connect에는 ‘개발자 정보 업데이트 처리 중’ 배너가 남았다. 배너만으로 서명·업로드 불가라고 판단하지 않으며 실제 서명·업로드 성공을 별도로 확인했다.

### 완료한 배포 단계

- eng/archive-store.sh --signed artifacts/store/1.0.0/build6-20261017-recovery: ARCHIVE SUCCEEDED, EXPORT SUCCEEDED.
- export/Moongchi NameFix.pkg: 팀 25373G7846의 3rd Party Mac Developer Installer 서명 체인 확인.
- App ID com.ailoworks.namefix 등록 후 App Store Connect 앱 생성: Apple ID 6823853405, 이름 Moongchi NameFix, 기본 언어 한국어, SKU AILOWORKS-NAMEFIX-MAC-100.
- Xcode Organizer에서 App Store Connect 업로드 완료. Apple 처리 뒤 1.0.0 (6)을 버전 1.0.0에 연결·저장했다. 빌드 ID af0fa9e9-0490-4bd5-ad51-d3a2b08e2b03.
- ko/en/ja 설명·홍보 문구·키워드·부제와 스크린샷 각 5장(15장) 저장. 한국어 설명의 호환 자모 예시는 정규화 지원을 오해하지 않도록 일반 설명으로 바꾸고 marketing/appstore.json에 반영했다.
- 분류 Utilities / Productivity, 연령 질문 저장(글로벌 4+, 대한민국 전체), 타사 콘텐츠 사용 안 함, 로그인 필요 없음, 심사 메모 저장.
- 가격 $0.00 / 무료, 175개 국가·지역에서 출시 후 사용 가능 설정. 별도 예약 판매 없음.
- 개인정보 처리방침 URL을 ko/en/ja에 저장했다. 사용자가 ‘데이터 수집 없음’ 게시 조건에 명시 동의한 뒤 재개했을 때 이미 게시 완료 상태였으며, 이를 화면으로 확인했다. 게시를 중복 실행하지 않았다. 기존 Developer 계정 연락처 사용도 명시 승인받아 심사팀 전용 연락처로 저장했다. 연락처 값은 저장소에 남기지 않는다.
- 지원·제품·개인정보 URL은 HTTP 200을 확인했다. 웹사이트 저장소는 수정하지 않았다.

스토어 작업 화면: https://appstoreconnect.apple.com/apps/6823853405/distribution/macos/version/inflight

### 심사 접수와 남은 배포

- 사용자 승인 뒤 필수 항목 검사를 통과하고 ‘심사에 추가’ → ‘심사를 위해 제출’을 실행했다.
- Apple 상세 화면: macOS 앱 1.0.0, 빌드 1.0.0 (6), 제출 항목 1개, 상태 ‘심사 대기 중’.
- 제출 ID: 77685324-201c-483d-8d23-0d959d824b2b. 화면에 표시된 접수 시각: 2026-10-17 13:40 KST.
- 심사 상세: https://appstoreconnect.apple.com/apps/6823853405/distribution/reviewsubmissions/details/77685324-201c-483d-8d23-0d959d824b2b
- 출시 방식은 기존 명세의 ‘승인 후 자동 출시’ 그대로다. 최초 접수 당시 상태는 심사 대기였으며, 이 1.0.0 제출은 T-017에서 철회했다. 현재 제출은 위 T-017 절을 따른다.
- 일반판 앱·ZIP·DMG는 위 ‘현재 일반판과 Xcode 공증 경로’의 검증을 통과했다. 실제 공개 상태는 아래 GitHub 절을 따른다.

비밀번호, 2FA 코드, 인증서 private key, API key, 개인 심사 연락처를 채팅·저장소·로그에 적지 않는다. 공식 경로는 Apple의 ‘Notarizing macOS software before distribution’ 및 ‘Customizing the notarization workflow’ 문서를 참조한다.

## 웹사이트

웹사이트는 뭉치페이지스 프로젝트가 맡는다(D-025). 이 저장소에서는 웹사이트 저장소를 고치지 않는다. 앱 저장소의 오픈소스 공개는 아래 절의 D-043·T-016에 따른다.

웹사이트의 역할: 제품 소개, 지원, 개인정보처리방침, 공개 후의 Mac App Store 링크 및 일반판 다운로드 안내(D-042). 이번 작업에서는 별도 웹사이트 저장소를 수정·게시하지 않았다. 일반판의 실제 공개 다운로드는 아래 GitHub 릴리즈다.

뭉치페이지스가 참조할 원본:
- 제품이 하는 일과 요구사항: docs/PROJECT.md
- 지원 범위와 하지 않는 것: docs/FILESYSTEM_CAPABILITIES.md
- 배포 채널과 상태: 이 문서
- 이름·개발사·문의 주소·가격·언어·시스템 요구와 ko/en/ja 문구: marketing/appstore.json
- 화면: 아래 ‘마케팅 자료’의 스토어 화면

앱 안의 웹사이트·문의 버튼(설정의 개발자 카드)은 https://moongchi.ailoworks.com 과 ailo@ailoworks.com 을 연다. 스토어에 넣을 제품·지원·개인정보 주소는 marketing/appstore.json의 urls이며, 웹사이트의 실제 경로가 바뀌면 그 값을 맞춘다.

## GitHub 오픈소스·일반판 릴리즈 (D-043, T-016)

- 공개 저장소: https://github.com/pureakma/moongchi-namefix. PUBLIC·MIT 확인. 코드·문서는 루트 LICENSE의 MIT, 브랜딩 자산은 별도 조건, 폰트는 OFL 고지를 유지한다. 사용자가 승인한 기존 이력까지 공개했다.
- 공개 전 점검: 원격 main과 같은 시작점 dcfe247의 136개 커밋, 915개 고유 파일 blob 중 텍스트 893개와 커밋 메타데이터를 인증키·암호 패턴으로 점검했다. 일치 없음. Git 이력의 UI 참조 이미지 9장도 확인했고 계정·연락처 화면은 없었다. 폰트와 제품 아이콘 외 미확인 바이너리 자료는 없었다. 패턴 점검이 모든 형태의 비밀정보 부재를 보장하는 것은 아니다.
- 공개되는 이력: 기존 작성자 이름·이메일, 이전 코드·문서·참조 이미지가 함께 보인다. Actions 실행 이력·Issue/PR·기존 release/tag는 없었다. 사용자는 이력을 포함한 공개 범위와 DMG 공증 후 동시 공개를 승인했다(D-043). 강제 push나 이력 재작성은 하지 않는다.
- 최초 공개 릴리즈: https://github.com/pureakma/moongchi-namefix/releases/tag/v1.0.0, ID 415588827. 태그 v1.0.0은 준비 커밋 48f3ee8, 앱 source는 dcfe247이다. 1.0.0 (build 6), arm64, macOS 14 이상. 공증 DMG·ZIP, 두 패키지를 담은 SHA256SUMS.txt, LICENSE·ThirdPartyNotices.md·Branding-Notice.txt를 제공한다. 비공개 연락처·로컬 검증 화면·로그는 첨부하지 않았다.
- 공개 순서: DMG 공증과 모든 첨부 파일·서버 해시 확인 후 비공개 저장소 안에서 릴리즈를 확정하고, 저장소 공개 전환으로 소스와 릴리즈가 함께 공개되게 했다(D-043). 2026-10-17 15:51 KST에 익명 접근으로 PUBLIC·MIT·릴리즈 페이지 HTTP 200을 확인했다. 첨부 파일 여섯 개를 Authorization 헤더 없이 실제 내려받아 서버 SHA-256과 일치, 내려받은 체크섬으로 DMG·ZIP 재대조 PASS.
- 다운로드: [DMG](https://github.com/pureakma/moongchi-namefix/releases/download/v1.0.0/Moongchi_NameFix_1.0.0_build6_arm64.dmg) · [ZIP](https://github.com/pureakma/moongchi-namefix/releases/download/v1.0.0/Moongchi_NameFix_1.0.0_build6_arm64.zip) · [체크섬](https://github.com/pureakma/moongchi-namefix/releases/download/v1.0.0/SHA256SUMS.txt). 일반판의 남은 사용자 입력은 없다. 웹사이트 수정·App Store 심사 승인은 이번 공개 완료에 포함하지 않는다.
- 로컬 근거: artifacts/evidence/public-release-20261017의 repository-review.json·repository-delta-review.json·dmg-notarization.json·github-release-ready.json·github-publication.json. 제품 전체 QA·새 빌드를 반복하지 않았으며 기존 제품 Gate를 재사용했다. 다운로드 바이트 검증은 실제 새 Mac의 GUI 설치·사용자 QA와 구분한다.

라이선스·공개 설정의 공식 안내: [GitHub 저장소 라이선스](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository), [MIT](https://choosealicense.com/licenses/mit/), [GitHub 공개 범위 변경](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility). 앱 암호는 [Apple 안내](https://support.apple.com/en-us/102654)를 따른다.

## 마케팅 자료

- 스토어 문구 원본: marketing/appstore.json 하나(ko/en/ja의 이름·부제·홍보 문구·설명·키워드, URL, 분류, 연령 등급·수출 규정·App Privacy 답, 심사 메모, 스크린샷 문구). eng/validate-marketing.py가 글자 수 한도와 앱·프로젝트와의 일치를 확인한다.
- 화면: Debug 앱의 --render-marketing(App/MarketingFixtures.swift)이 예시용으로 만든 파일을 앱이 직접 검사·미리보기·이름 변경한 실제 창을 ko/en/ja로 촬영한다. AppStore build에는 들어가지 않는다. --marketing-samples로 경로가 화면에 드러나도 되는 중립 폴더를 넘긴다.
- 합성: eng/marketing-shots.py(Pillow 필요)가 스토어용 2880×1800 PNG 15장(5장면 × 3개 언어)과 manifest를 만든다. 새 1.0.1 검증용 산출물은 artifacts/marketing/namefix/1.0.1-localized(Git 제외)에 있다. 스토어에 저장된 기존 15장은 T-017 절의 재사용 범위를 따른다. Mac App Store 스크린샷 규격(16:10, 1280×800·1440×900·2560×1600·2880×1800 중 하나, 1~10장)은 2026-10-07에 Apple 문서에서 확인했다.

## 과거 직접 배포 후보 (HISTORICAL_DIRECT_RC, NOT_FOR_PUBLIC_RELEASE)

1.0.0 build 5는 직접 배포를 준비하던 때에 Developer ID 서명과 Apple 공증까지 끝낸 후보다. 공개하지 않았고 앞으로도 공개하지 않는다(D-026, D-038). 역사적 Release Engineering 근거로만 보존하며 수정·삭제·재서명·재패키징하지 않는다. 이 과거 후보를 다시 만들거나 공개하지 않는다. 현재 일반판은 위 D-042 경로에서 별도로 만든다.

- 위치: artifacts/release-candidate/1.0.0/build5-final (Git 제외). 계보는 build5-pre-sign → build5-signed-r2 → build5-final.
- DMG Moongchi_NameFix_1.0.0_build5_arm64.dmg, SHA-256 dab6d685d102a3641af28ced97e1c61edff99fdc12e0df4c5daad0fc3c39f4ca
- ZIP Moongchi_NameFix_1.0.0_build5_arm64.zip, SHA-256 7eac6ba04daa4ace33b7cede736e56ebf4d638a7d77693c1e096f9ffaf4657dd
- 함께 들어 있던 CLI namefix, SHA-256 d259d98b35a749895de93787a5e88421730d712cc8407415f34c93b8776043e0
- 제품 source commit 76972c7, 당시 release tooling commit 3e11e18. Developer ID Application: Hyein Kang (25373G7846), entitlement 없음(App Sandbox 밖).
- 공증: 앱 submission 6be4bd10-610a-4c47-adaa-0c2e2b074ff5, DMG submission c63f99e1-e719-4bb3-8855-aeca6f81150d, 둘 다 Accepted. staple과 Gatekeeper 평가 통과.
- 이 후보를 만들고 검증하던 도구(package-candidate, sign-candidate, notarize-candidate, verify-candidate, CLI build·test)와 CLI source는 현재 branch에 없다. Git 이력(711d937의 부모까지)에 있다.
