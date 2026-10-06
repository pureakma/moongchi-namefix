# 빌드·서명·배포

## 출시 정책 (D-023)

- 배포: 직접 배포. Developer ID Application 서명 + Apple 공증 + DMG. Mac App Store는 대상이 아니다.
- 버전: MARKETING_VERSION 1.0.0, CURRENT_PROJECT_VERSION 5
- bundle ID: Release 구성 com.ailoworks.namefix, Debug 구성 com.moongchi.namefix.dev. 원본은 project.yml 하나이며 build 명령이나 서명 도구가 바꾸지 않는다.
- 개발사 AILO WORKS, 문의 ailo@ailoworks.com
- 모든 기능 무료. 유료 등급·구매·계정·광고 없음.
- macOS 14 이상, Apple Silicon arm64 전용
- App Sandbox OFF, Hardened Runtime ON. Release 구성은 디버깅 entitlement를 넣지 않는다.

## 현재 Release 상태

- Release Preparation 1차와 1.5: 완료(2026-10-06). 근거는 QA.md의 ‘Release Preparation 검증’.
- 현재 서명 전 후보: artifacts/release-candidate/1.0.0/build5-pre-sign (1.0.0 build 5, source commit 76972c7). 실제 Developer ID 서명의 대상이다. 앱·CLI·사용자 안내·manifest만 있고 ZIP/DMG는 없다. 배포하지 않는다.
- 대체된 후보: artifacts/release-candidate/1.0.0/build4-pre-sign (build 4, source commit bd64b03). CLI 도움말에 두 옵션 설명이 빠져 있어 build 5로 대체했다. 공개 Release에 쓰지 않으며 기록으로 그대로 둔다.
- Developer ID 서명: 미실행.
- 공증·staple: 미실행.
- 최종 DMG, 깨끗한 Mac 확인, 공개 배포: 미실행.
- 과거 build3 후보(artifacts/release-candidate/1.0.0/build3)는 예전 source와 개발용 bundle ID의 기록이며 현재 source의 근거가 아니다. 덮어쓰지 않고 그대로 둔다.

후보를 다시 만들어야 하면 build 번호를 6 이상으로 올리고 새 output 경로를 쓴다.

## 2차(서명·공증)에 필요한 외부 입력

1. 서명 identity: 사용자가 2차의 승인 후보로 지정한 것은 Developer ID Application: Hyein Kang (25373G7846)이다. 로컬 Keychain에 이 identity가 유효하게 있음을 읽기 전용으로 확인했다. 실제 서명은 2차 승인 뒤에만 한다.
2. Apple Team: 위 identity의 팀(25373G7846)
3. notarytool Keychain profile 이름: 아직 정해지지 않았다. 2차 시작 전에 사용자가 알려 준다(여기에 추측해 적지 않는다).
4. com.ailoworks.namefix를 이 팀에서 쓸 수 있는지(직접 배포는 App ID 등록이 필수는 아니지만 식별자 소유는 사용자가 확인한다)

비밀번호, app-specific password, 인증서 private key, API key는 저장소 문서·스크립트·로그에 기록하지 않는다. Gatekeeper/SIP/검역 해제로 미완료 서명·공증을 우회하지 않는다.

## 순서

1차(완료)
1. 현재 source를 commit하고 Release 구성으로 앱과 CLI를 build한다.
2. package-candidate.py로 서명 전 후보를 새 경로에 만든다.
3. verify-candidate.py로 manifest·Info.plist·arm64·리소스·Hardened Runtime·sandbox 없음·개발 fixture 없음·CLI 계약·사용자 안내 문구를 확인한다.

2차(사용자 승인과 외부 입력 뒤)
4. sign-candidate.py로 후보의 사본을 새 경로에서 Developer ID로 서명한다(입력 후보가 manifest와 일치하는지 먼저 확인).
5. 공증 제출·성공 확인, staple, validate, Gatekeeper 평가.
6. 서명된 앱으로 ZIP/DMG를 만들고 DMG도 공증·staple한다.
7. 깨끗한 Mac 설치·실행과 QA.md의 User QA.
8. 그 뒤에만 공개 배포 가능 판정을 기록한다.

## helper

~~~sh
eng/build.sh --configuration Release --arch arm64
bash eng/build-cli.sh release
python3 eng/package-candidate.py --output artifacts/release-candidate/1.0.0/<새 경로> --cli .build/release/namefix
python3 eng/verify-candidate.py artifacts/release-candidate/1.0.0/<경로>
python3 eng/sign-candidate.py --input <서명 전 후보> --dry-run
python3 eng/sign-candidate.py --input <서명 전 후보> --identity "<Developer ID>" --output <새 경로>
python3 eng/package-candidate.py --developer-id --app <서명된 앱> --cli <서명된 CLI> --output <새 경로>
eng/sign-notarize.sh
~~~

실제 옵션과 환경 변수는 helper 자체가 원본이다. 서명 도구는 앱의 bundle ID가 com.ailoworks.namefix가 아니면 멈추며 앱을 고치지 않는다. helper 실행 자체를 성공 근거로 쓰지 않고 결과와 hash/evidence를 확인한다.

패키지에 넣는 사용자 안내는 PACKAGE_README.txt(패키지의 README.txt)와 EXPANSION_USER_GUIDE.md(USER_GUIDE.md)다. 후보 자체의 상태(서명·공증 여부)는 도구가 만드는 CANDIDATE_STATUS.txt, BUILD_INFO.json, ARTIFACT_MANIFEST.json에만 적는다.
