# 빌드 및 배포

## 대상
macOS14+ / Apple Silicon arm64만. Xcode27.0 + Swift6.4 + SDK27.0을 실제 설치 환경에서 확인했다. 이 버전이 모든 사용자 환경에 설치되어 있다고 가정하지 않는다. 제품 1.0.0 (3), 개발용 bundle ID com.moongchi.namefix.dev.

## v1.0 최신 후보

최신 상태는 [V1_RELEASE_STATUS.md](V1_RELEASE_STATUS.md). `artifacts/release-candidate/1.0.0/build3/`에 Release 앱·CLI·ZIP·DMG와 manifest를 둔다. 기존 `artifacts/qa`와 Debug 앱은 보존한다. 후보 앱/CLI는 Developer ID와 hardened runtime, secure timestamp로 서명한다. **서명은 공증이나 공개 출시 승인이 아니다.** 실제 판매 연결이 없어 후보의 실행 가능 범위는 Free다.

```sh
eng/build.sh --configuration Release --arch arm64
bash eng/build-cli.sh release
# 다음 도구는 출력 폴더가 이미 있으면 실패하여 기존 후보를 보존한다.
python3 eng/sign-candidate.py --identity "$NAMEFIX_SIGN_IDENTITY" --output artifacts/release-candidate/NEW/signing
python3 eng/package-candidate.py --developer-id --app "artifacts/release-candidate/NEW/signing/Moongchi NameFix.app" --cli artifacts/release-candidate/NEW/signing/namefix --output artifacts/release-candidate/NEW/package
python3 eng/verify-candidate.py artifacts/release-candidate/NEW/package
```

`NEW`는 새 후보의 고유 경로로 바꾼다. 서명 identity는 키체인에서 확인한 Developer ID Application을 사용하며 비밀키를 내보내지 않는다. 서명 없는 로컬 후보는 `package-candidate.py`에서 `--developer-id`를 생략하고 ad-hoc 빌드 앱을 지정한다. 이때도 Developer ID 서명을 한 것으로 표현하지 않는다.

실제 출시용 bundle ID를 받은 뒤 `eng/build.sh --configuration Release --arch arm64 --bundle-id "$NAMEFIX_RELEASE_BUNDLE_ID"`로 빌드한다. 앱과 CLI의 구매 공급자 연결, 실제 영수증/라이선스 검증 및 Free/Pro 경계 회귀를 마쳐야 유료 판매본으로 표시한다. 사용자로부터 확정되지 않은 식별자/상품 ID/공증 프로필을 임의 생성하지 않는다.

Gatekeeper가 Unnotarized Developer ID로 거부하면 검역/보호를 해제하지 않고 공증을 완료한다. macOS 14/Finder/권한/접근성 등 실사용 체크는 MANUAL_QA_CHECKLIST.md를 따른다.

## 이전 로컬 QA 절차


```sh
eng/build.sh --configuration Release --arch arm64
eng/package.sh --unsigned
eng/verify-release.sh "$PWD/artifacts/qa/Moongchi NameFix.app"
```

`--unsigned`는 Developer ID가 없다는 뜻이며, Apple Silicon에서 실행할 수 있도록 ad-hoc 코드 서명은 한다. Hardened Runtime 설정은 정식 Developer ID 서명 단계에서 활성화하며, Xcode의 ad-hoc 빌드는 이를 비활성화할 수 있다. QA app과 공개 배포 app을 혼동하지 않는다.

ZIP/DMG는 artifacts/qa에 생성한다. 기존 ZIP/DMG는 자동으로 덮어쓰지 않는다. 새 버전 패키지 생성 시 이전 QA 산출물을 별도 보관한 뒤 실행한다. DMG는 Applications 링크를 포함하며 사용자가 직접 복사한다. 앱을 자동으로 /Applications에 설치하지 않는다. 앱 실행 시 bundle/DMG 안에 쓰지 않는다.

## 정식 서명·공증
사용자가 승인한 팀 소유 식별자, Developer ID Application identity, Keychain notarytool profile, 별도의 release app 복사본을 준비한다. 비밀번호를 스크립트/문서에 넣지 않는다.

```sh
# 아래 환경 변수에는 실제 승인된 값을 환경에서 주입한다.
# NAMEFIX_SIGN_IDENTITY / NAMEFIX_NOTARY_PROFILE /
# NAMEFIX_RELEASE_BUNDLE_ID / NAMEFIX_SIGN_INPUT_APP
eng/sign-notarize.sh
```

앱 codesign(runtime,timestamp) → notarytool submit --wait → staple → validate → spctl을 수행한다. 이 앱은 중첩 실행 코드를 번들하지 않으므로 루트 app에 서명한다. 향후 framework/helper가 추가되면 내부부터 정확히 서명한다. `--deep` 재서명은 사용하지 않는다.

stapled app으로 ZIP/DMG를 다시 만들고, DMG도 notarytool에 제출해 성공 확인 후 staple한다. ZIP 자체에는 staple하지 않는다. 스크립트는 실제 인증서 없이 실행/통과했다고 표시하지 않는다. Gatekeeper/SIP/검역 해제 우회 실행법을 사용하지 않는다.

## 출시 허용 조건
자동 검증, 실제 Finder/Services/권한/접근성/최소OS, source race 지원 계약, Developer ID/공증, 깨끗한 Mac에서 다운로드·실행 Gate가 모두 충족되어야 한다. 현재 패키지는 로컬 개발자 QA용이다.
