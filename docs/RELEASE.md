# 빌드·서명·배포

## 현재 대상

- macOS 14 이상
- Apple Silicon arm64
- MARKETING_VERSION 1.0.0
- CURRENT_PROJECT_VERSION 3
- development bundle ID com.moongchi.namefix.dev
- App Sandbox OFF
- Hardened Runtime ON

현재 source는 마지막 build3 Release 후보 뒤에 UI/설정/리소스 변경과 2026-10-06 출시 전 완성도 고도화(문구·메뉴·접근성·transaction 취소 동작 등)가 추가됐다. 따라서 기존 artifacts/release-candidate/1.0.0/build3의 Release build, Developer ID, ZIP/DMG 검증은 과거 source snapshot 근거이며 현재 source 배포 승인이 아니다.

## 현재 Release 상태

- 제품 기능 개발: 현재 승인 범위에서 완료 상태. 앱 자체 기준 Release Candidate Ready(2026-10-06, 근거는 QA.md).
- 현재 source의 Release 구성 build: 성공(arm64, 1.0.0 build 3). 컴파일 확인용이며 배포 후보가 아니다.
- 새 current-source Release 후보: 아직 만들지 않음. build 번호는 새 후보를 만들 때 올린다.
- 판매 공급자: 필요 없음. 전 기능 무료(D-014).
- 출시용 bundle ID: 미확정, development ID 유지.
- Developer ID: 과거 후보에서 유효 identity 사용 기록이 있으나 현재 source에 대한 새 signing evidence는 STALE.
- notarization: 과거 후보에서 notary profile 미제공으로 미실행. 현재 성공 티켓 없음.
- 실제 macOS 14/Finder/TCC/접근성/깨끗한 Mac User QA: 대기(QA.md U01~U15).
- 공개 업로드/판매 게시/App Store 제출: 수행하지 않음.

## 배포 채널 Gate

최종 채널은 아직 결정하지 않았다.

현재 App Sandbox OFF 구성은 직접 배포 흐름과 맞지만, Mac App Store를 선택하면 sandbox/entitlement, 상품/영수증 검증, Store 요구사항을 별도 Task에서 최신 공식 정책으로 다시 확인해야 한다. 문서의 과거 정보만으로 App Store 적합성을 가정하지 않는다.

직접 배포를 선택하더라도 current-source Developer ID signing, notarization, staple/validate, Gatekeeper, 깨끗한 Mac 설치/실행을 새 evidence로 확인해야 한다.

## 새 Release Task 순서

사용자가 Release 단계를 승인한 뒤 다음 순서를 사용한다.

1. 현재 branch/HEAD와 제품 source fingerprint 확정.
2. 현재 source에 영향받은 test/build/resource/render 범위 검증.
3. 배포 채널 확정(무료 제품이므로 상품 ID·구매 공급자는 없음).
4. 팀 소유 release bundle ID 확정.
5. 새 고유 output 경로로 Release app/CLI 생성. 기존 후보 덮어쓰기 금지.
6. Developer ID 또는 선택한 채널에 맞는 signing.
7. notarization이 필요한 채널이면 실제 notary profile로 제출·성공 확인.
8. 새 source 기준 ZIP/DMG 또는 Store artifact 검증.
9. QA.md의 User QA와 깨끗한 Mac Gate.
10. 그 뒤에만 공개 배포/판매 가능 판정을 기록.

비밀번호, 인증서 private key, API key를 저장소 문서나 스크립트에 기록하지 않는다. Gatekeeper/SIP/검역 해제로 미완료 signing/notarization을 우회하지 않는다.

## 현재 helper

~~~sh
eng/build.sh --configuration Release --arch arm64
bash eng/build-cli.sh release
python3 eng/sign-candidate.py
python3 eng/package-candidate.py
python3 eng/verify-candidate.py
eng/sign-notarize.sh
~~~

실제 옵션과 환경 변수는 helper 자체가 원본이다. 기존 candidate 경로를 그대로 재사용하지 않고 항상 새 output을 사용한다. helper 실행 자체를 성공 근거로 쓰지 않고 결과와 hash/evidence를 확인한다.

패키징용 사용자 문구는 V1_CANDIDATE_README.txt와 EXPANSION_USER_GUIDE.md를 사용한다.
