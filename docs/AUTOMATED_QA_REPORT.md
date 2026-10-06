# 자동 QA 보고서

> **최신 v1.0 후보 결과:** [V1_RELEASE_STATUS.md](V1_RELEASE_STATUS.md). 아래 내용은 이전 단계 증거로 보존하며 최신 Release/서명/패키지 상태는 후속 보고서를 따른다.

2026-10-04 확장 개발본의 최신 결과는 [EXPANSION_DEVELOPMENT.md](EXPANSION_DEVELOPMENT.md)를 따른다. Debug 관련 검증만 수행했으며 아래 Release/ZIP/DMG는 과거 기준선이다.

이 보고서는 2026-10-04 최초 패키지의 역사적 실행 기록이다. 이후 상용 완성도 수정본의 관련 실행은 [COMMERCIAL_REVIEW.md](COMMERCIAL_REVIEW.md)에 기록했으며, 기존 Release 패키지는 갱신하지 않았다.

검증 완료: 2026-10-04T00:37:50+09:00. 플랫폼 override: **macOS14+ Apple Silicon arm64 전용**. Git 저장소가 없는 초기 폴더에서 기존 소스/문서/증거를 보존하고 개발했다. Windows/Intel/universal2는 대상이 아니다.

## 판정

- 기능 구현 및 로컬 Phase0~5: 완료. 실제 실행 가능한 .app / ZIP / DMG 생성.
- **AUTO-QA PASS — 실행 가능한 자동 범위 28개 테스트, 실패0.** Core5 + FS/transaction20 + Application UI state3. 대소문자 구분 APFS의 반복 테스트는 이 숫자에 중복 합산하지 않았다.
- 실제 Finder 제스처·Services·창/접근성·권한·최소 OS는 NEEDS_MANUAL_QA / NEEDS_REAL_DEVICE_QA.
- **BLOCKED_RELEASE_SOURCE_RACE / BLOCKED_RELEASE_SIGNING**. 공개 출시 가능 판정이 아니다. 자동 테스트의 PASS는 외부 writer 경쟁을 완전히 방지했다는 의미가 아니다.

## 환경

Apple M1 Pro / 10 CPU cores / 32GiB RAM. macOS27.0.1 (26A434), Xcode27.0 (27A266a), Swift6.4, SDK27.0. 제품 Mach-O slice는 arm64 한 개, LC_BUILD_VERSION minos14.0. 서명은 ad-hoc, TeamIdentifier 없음. 실제 macOS14 장비 검증은 미실행.

- 도구·OS: artifacts/evidence/environment-current.txt
- 하드웨어: artifacts/evidence/hardware.txt
- architecture/minOS: architecture.txt, deployment-target.txt
- 서명: signature.txt

## 실행한 검증과 근거

| 검증 | 실제 명령/범위 | 결과·증거 |
|---|---|---|
| 인수인계 | SHA-2569개 파일 확인 | PASS, handoff-current.json |
| Core Unicode | eng/test.sh --level 3의 Core suite | 5 PASS, full-tests.txt |
| 최종 FS/앱 상태 | NAMEFIX_PERFORMANCE=1 eng/test.sh --level 2 --scope all | 23 PASS, fs-final-regression.txt |
| APFS case-sensitive | 임시 Case-sensitive APFS image + NAMEFIX_FIXTURE_ROOT 지정 | case-final.txt; perf만 별도 일반APFS에서 측정 |
| raw 부모 alias 회귀 | NFC/NFD 부모 경로 중복 입력 | 재현 FAIL 후 수정 PASS, raw-parent-regression-before.txt / raw-parent-regression.txt |
| clean Release Gate | eng/build.sh --configuration Release --arch arm64 --clean | PASS, clean-release.txt |
| 수정 후 Release | eng/build.sh --configuration Release --arch arm64 | PASS, final-release.txt |
| UI 테스트 빌드 | xcodebuild build-for-testing | 컴파일 PASS, ui-tests-build.txt; 제스처 실행은 하지 않음 |
| 언어/폰트/리소스 | python3 eng/validate-resources.py | 210키×3언어, placeholder parity, macOS override, OFL/폰트 hash, Resources PASS |
| off-screen UI | QA app --render-fixtures | ko/en/ja×4themes + ko4table =16 PNG, render.txt / rendered/ |
| 패키지 | codesign verify, lipo, unzip -t, DMG CRC/readonly mount, --self-test | PASS, final-package-check.txt / final-dmg-mount.txt / package-final.txt |

Full Gate 후 원시 부모 alias와 성능 수정에는 영향받는 scanner/executor/undo/recovery/UI state 회귀 및 Release 재빌드를 수행했다. Core 등 변경되지 않은 PASS는 재사용했다. clean 재빌드 전후 bundle 전체 hash가 같았던 근거(clean-reproducibility.json)는 그 시점의 버전 증거이며 후속 수정본의 byte-identical 재현으로 확대하지 않는다.

## 파일 안전성 검증

실제 전용 fixture에서 scan→fresh Preview→확인→Rename→Undo, SHA-256 내용 불변, custom xattr/resource fork/Finder tags의 바이트 및 POSIX 권한/실제 ACL 보존을 확인했다. 5단계 중첩/겹친 root, canonical 부모 lookup alias 중복 제거, hardlink2개의 부분 Undo와 재시도, 충돌 번호 예약, symlink/package/Finder alias 보호, source 교체와 destination 경합, 임시 이름 충돌, journal 쓰기 불가, 프로세스 flock, 취소, torn journal/newer schema/손상 설정을 검증했다.

APFS가 invalid UTF-8 생성 자체를 EILSEQ(92)로 거부한 결과를 기록했다. 이 경우를 실제 invalid 파일 생성 성공으로 꾸미지 않고 pure byte 모델 검증과 분리했다. Case-sensitive APFS는 Case.txt와 case.txt의 별도 생성으로 실제 비교 규칙을 확인했다.

복구는 Prepared/temporary/final move gap 상태를 재현한 fixture다. 실제 OS 프로세스 kill/전원 차단의 모든 timing, ACL의 모든 변형, iCloud/SMB/외장 제거는 별도 검증이다. 내용 hash는 테스트 fixture에서만 계산하며 제품 실행 경로에서 사용자 파일 내용을 읽지 않는다.

## 성능

최종 Debug XCTest process 측정. 항목 수는 생성 파일 수이며 root 폴더1개도 검사된다. peak RSS는 해당 XCTest 프로세스 전체 high-water mark로, 실제 GUI 앱 메모리와 같지 않다. 디스크/외부 시스템 부하에 따라 변한다.

| 파일 수 | scan 경과 | process peak RSS | user CPU | system CPU | 오류 |
|---:|---:|---:|---:|---:|---:|
| 1 | 0.005s | 80.7MiB | 0.002s | 0.001s | 0 |
| 100 | 0.008s | 80.7MiB | 0.004s | 0.003s | 0 |
| 10,000 | 0.343s | 86.0MiB | 0.226s | 0.115s | 0 |
| 100,000 | 3.565s | 148.8MiB | 2.315s | 1.226s | 0 |

취소 후 scanner 반환: 0.206s (첫 root 열거/안전 checkpoint 포함). 실제 UI 취소 피드백200ms/상호작용100ms 목표는 수동 측정 대기다. 최초100k 기준선은49.602s / 609.0MiB(full-tests.txt). 일반 파일의 Foundation URL resource 조회를 descriptor 기준 FinderInfo 조회로 바꿔 개선했다. 동시 Xcode build/package 부하가 있던 측정은 fs-optimized-regression.txt에 별도로 보존했으며 최종 표는 해당 작업을 완료한 뒤 수행했다.

## 산출물과 SHA-256

- 실행 앱: artifacts/qa/Moongchi NameFix.app
- ZIP/DMG: artifacts/qa 아래. README 및 ThirdPartyNotices 포함.
- bundle tree SHA-256: `e313173c7a013a48f6e0e156b1f39d1c75268b97a54f45a5ada4e4b2aab608b3`. 산출 방식은 정렬된 relative-path→file-hash JSON에 SHA-256.
- `Moongchi_NameFix_1.0.0_macOS_arm64.dmg`: `68436628f7254e5e061972b70a2bd1a97a66fe630a244935fb18a041673f0c64` (11,432,438 bytes)
- `Moongchi_NameFix_1.0.0_macOS_arm64.zip`: `0451828b76d073ce5c626066e10954764a79fbdf17267f717b48f8f013271e28` (10,556,300 bytes)

개별 bundle 파일 hash는 ARTIFACT_MANIFEST.json, 재현 fixture 원문/hash는 artifacts/evidence/fixture-manifest.json. 검증 cache에는 scope 실제내용/테스트/의존성/도구/환경 fingerprint와 evidence hash를 저장한다. Git commit만으로 PASS를 재사용하지 않는다.

## 이번 실행에서 수정한 문제

/var symlink fixture 경로, 실제 font PostScript 이름, Swift6 actor 초기화/콜백, APFS invalid UTF-8 fixture 가정, 시스템 Bash의 빈 배열 처리, Olive 표/비활성 버튼 대비, 대량 URL metadata 비용, canonical 부모 lookup alias 중복을 수정했다. macOS27 hdiutil이 생성 이미지 연결을 남기는 현상은 정확한 image-path를 새로 대조해 자체 연결만 해제하는 패키징 절차로 처리했다.

고정 device 번호 해제는 자동 승인 검토에서 거부됐다. 이후 현재 image-path 일치를 검증한 안전한 해제는 승인되어 완료했으며, 관련 이미지 외 사용자 볼륨은 변경하지 않았다. 초기 실패 로그는 보존하고 위 최종 결과와 구분했다.

## 남은 Gate

MANUAL_QA_CHECKLIST.md의 실제 Finder/Dock/Services, native titlebar/OS theme, VoiceOver/키보드/큰글자, TCC, sleep/quit, 실제100k UI, macOS14/외장/클라우드 실기. 외부 source 교체 race의 지원 계약과 Developer ID/공증도 출시 blocker로 유지한다. 인증서/profile을 임의 사용하거나 Gatekeeper/SIP/검역을 해제하지 않았다.
