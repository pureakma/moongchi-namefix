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

- 서명 전 후보: artifacts/release-candidate/1.0.0/build5-pre-sign (1.0.0 build 5, 제품 source commit 76972c7). 수정하지 않고 그대로 둔다.
- Developer ID 서명: 완료(2026-10-06). 서명된 후보는 artifacts/release-candidate/1.0.0/build5-signed-r2. identity는 Developer ID Application: Hyein Kang (25373G7846), Hardened Runtime, secure timestamp, entitlement 없음. 서명 전 후보와 달라진 것이 서명뿐임을 확인했다(리소스 hash 동일, 서명을 뗀 실행 코드 동일).
- build5-signed는 도구의 비교 오류로 manifest를 쓰기 전에 멈춘 중단된 시도다(ABORTED.txt). 후보가 아니다.
- 공증: 미실행. Keychain에 저장된 notarytool profile(MoongchiNotaryRC)이 Apple에서 401(자격 증명 오류)로 거부되어 제출하지 못했다. 사용자가 새 profile을 만들면 이어서 진행한다.
- staple, 최종 DMG/ZIP, Gatekeeper(공증 기준) 확인, 깨끗한 Mac 확인, 공개 배포: 미실행. 공증 전의 Gatekeeper 평가는 예상대로 ‘Unnotarized Developer ID’로 거부된다.
- 대체된 후보: build4-pre-sign(build 4), build3(예전 source와 개발용 bundle ID). 공개 Release에 쓰지 않으며 기록으로 둔다.

후보를 다시 만들어야 하면 build 번호를 6 이상으로 올리고 새 output 경로를 쓴다. 제품 binary가 바뀌지 않는 한 build는 5다.

## 공증에 필요한 외부 입력

notarytool Keychain profile 하나가 필요하다. 권장 이름은 NameFix-Notary다. Apple ID와 앱 전용 암호가 필요하므로 사용자가 로컬 터미널에서 직접 만든다(자격 증명은 채팅·문서·저장소에 남기지 않는다).

~~~sh
xcrun notarytool store-credentials "NameFix-Notary" --apple-id "<Apple ID>" --team-id 25373G7846
~~~

비밀번호, app-specific password, 인증서 private key, API key는 저장소 문서·스크립트·로그에 기록하지 않는다. Gatekeeper/SIP/검역 해제로 미완료 서명·공증을 우회하지 않는다.

## 순서

1. (완료) 현재 source를 commit하고 Release 구성으로 앱과 CLI를 build → package-candidate.py로 서명 전 후보 → verify-candidate.py.
2. (완료) sign-candidate.py로 후보의 사본을 새 경로에서 Developer ID로 한 번 서명. 제품 정보와 source commit은 서명 전 후보의 manifest에서 그대로 가져온다.
3. (대기) notarize-candidate.py: 서명된 binary를 다시 서명하지 않고 그대로 제출 → Apple이 Accepted라고 답한 뒤에만 ACCEPTED 기록 → staple과 validate 뒤에만 stapled 기록 → 앱 Gatekeeper 평가 → DMG와 ZIP 생성 → DMG 서명·공증·staple·Gatekeeper 평가 → 최종 manifest.
4. verify-candidate.py로 최종 산출물 검증(DMG 읽기 전용 mount, ZIP 풀기 포함).
5. 깨끗한 Mac 설치·실행과 QA.md의 User QA.
6. 그 뒤에만 공개 배포 가능 판정을 기록한다. 공개 업로드는 별도의 명시적 단계다.

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
