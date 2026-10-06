# 확장 개발 실행 기록

> **최신 v1.0 후보 결과:** [V1_RELEASE_STATUS.md](V1_RELEASE_STATUS.md). 아래 내용은 이전 단계 증거로 보존하며 최신 Release/서명/패키지 상태는 후속 보고서를 따른다.

2026-10-04 / macOS 27.0.1 (26A434), Apple Silicon arm64, Swift 6.4, Xcode 27.0 (27A266a), SDK 27.0. 작업 범위는 앱 자체 확장 개발이며 Release·패키징·서명·공증은 실행하지 않는다.

## 계약과 구현

- Free: NFC/NFD/형식 유지, 기본 문자 편집·확장자·순번·조합·예제·마지막 무료 규칙, 텍스트 도구, CSV export, 기본 CLI, 모든 Preview/Undo/Recovery.
- Pro: regex/wildcard/accent·조건·고급 번호, 프리셋 CRUD/import/export, CSV/TSV raw mapping, metadata, pair groups, watched folders.
- CF FSEvents는 opt-in bookmark 폴더의 변경을 coalesce한 폴더 단위 대기열에 넣는다. 재시작/복귀는 전체 재검토. 이벤트 자체로 rename하지 않으며 preview 시점의 입력만 확인 plan에 포함한다.
- source→temporary→final no-replace. 같은 부모에서 swap/cycle은 모든 durable intent 후 staging. 취소·부분 실패는 증거를 남기고 Recovery로 이동한다. 그룹 mutation의 원자성은 주장하지 않는다.
- metadata opt-in은 내용 불변 read. preview의 size/mtime를 Plan과 실행 전 다시 확인한다. 사진은 EXIF timezone offset을 우선 사용하며 없으면 선택 zone; 출력 zone/format은 고정 snapshot.
- APFS getattrlistat ATTR_CMN_NAME으로 실제 raw leaf를 조회한다. NFC/NFD/case alias fixture로 readdir 값과 동일함을 검증했다. 경합을 없애는 API가 아니며 identity 재확인과 no-replace를 유지한다.
- 무료 마지막 설정은 입력 경로/수동 순서 경로를 자동 보존하지 않는다. 손상/새 schema 프리셋·watch 파일은 덮어쓰지 않는다.

## 중간 체크포인트 (아래 최종 결과가 우선)

당시 초기 Core 10 PASS, 초기 Expansion 6 + Transaction 11 PASS. stored-name fixture 1 PASS. FS 변경 후 Expansion/Transaction/Safety 26 실행, 25 PASS와 opt-in 성능 1 SKIP. 이후 신규 항목은 아직 진행 중으로 최종 기록을 갱신한다.

## 실제 잔여 조건

- SOURCE_RACE: Darwin expected-inode atomic rename 없음. 마지막 확인과 rename 사이 외부 source 교체 가능성이 실제 fixture에서 재현된다. 원자성 보장으로 홍보할 수 없다.
- 실제 판매 공급자·상품 식별자 미결정. Debug Pro 토글은 검증용이며 Release에서 제외된다. 실제 구매/복원 연결은 BLOCKED_EXTERNAL.
- 성능/접근성/실기 검증을 구현 완료로 위장하지 않는다. 화면을 직접 보지 못했다는 이유만으로 결함을 만들지 않는다.

## 최종 개발 결과

독립적으로 진행 가능한 E02~E23 기능 구현과 Debug 검증을 완료했다. E01 SOURCE_RACE는 BLOCKED_CONTRACT, E24 실제 판매 adapter는 BLOCKED_EXTERNAL, E25 전체 상용 완료 선언은 BLOCKED_CONTRACT다. 기능 구현과 위험 계약의 해결을 혼동하지 않는다.

개발 앱: `artifacts/development/Moongchi NameFix 확장 Dev.app`
CLI: `artifacts/development/expansion/namefix`
사용자 테스트 자료: `artifacts/development/expansion/직접확인용_테스트파일/`
사용법: [EXPANSION_USER_GUIDE.md](EXPANSION_USER_GUIDE.md)
판정: [EXPANSION_COMMERCIAL_REVIEW.md](EXPANSION_COMMERCIAL_REVIEW.md)

## 검증 근거

`artifacts/development/expansion/evidence/`에 각 명령의 실제 로그와 SHA-256을 보존했다. `test-index.json`은 같은 테스트의 반복 PASS를 중복 합산하지 않은 목록이다. 체크포인트와 실패 수정 이후 관련 회귀의 합집합이며 하나의 Release 전체 QA 실행이라는 뜻이 아니다.

| 범위 | 명령/검증 | 결과 |
|---|---|---|
| Core | `eng/test.sh --scope core` | 18 PASS: Unicode, 규칙, regex budget, CSV raw/취소/행 오류, 권한 만료/철회, fallback |
| FS/확장/Undo/Recovery | `eng/test.sh --filter 'ExpansionTests|TransactionTests|SafetyTests'` | 40 실행 중 39 PASS, 기존 opt-in 100k 성능 1 SKIP. Source-race 재현은 한계 확인 |
| 앱 상태/창/표시 | `eng/test.sh --scope all` 체크포인트 + 최종 AppModel 관련 회귀 | 고유 24 PASS; 최종 모델 12 PASS 재확인 |
| 파일시스템 기초 | 동일 scope all 체크포인트 | 2 PASS |
| 성능 | `NAMEFIX_EXPANSION_PERF=1 eng/test.sh --filter ExpansionPerformanceTests` | 10k × 5회, 전부 10,000개 유효 plan, 오류 0 |
| CLI | `python3 eng/test-expansion-cli.py artifacts/development/expansion/namefix` | dry-run/JSON·TTY 명시 확인·non-TTY 차단·Undo·hash·Pro 경계 PASS |
| 앱 | `eng/build.sh --configuration Debug --arch arm64` | BUILD SUCCEEDED; 실제 산출물 arm64 확인 |
| 리소스 | `python3 eng/validate-resources.py` | 387키 × ko/en/ja, placeholder, 폰트/라이선스, 원본 handoff 9 hash PASS |
| 실제 뷰 | Debug 앱 `--render-expansion artifacts/development/expansion/rendered` | 33 렌더 PASS; 사용자 창 제어 없음 |

기능 검증은 자체 임시 파일에서 실제 rename/undo/recovery/취소/hash/metadata 불변을 확인했다. JPEG/TIFF/HEIC, MP3/M4A, MOV/MP4, PDF는 자체 생성 fixture다. Finder 실제 제스처/외장/클라우드/VoiceOver/최소 OS는 이 테스트로 확인했다고 쓰지 않는다.

발견 후 수정한 실패: 초기 SwiftUI brace와 타입 변환 컴파일 오류, 재사용한 transaction ID fixture의 journal O_EXCL 오류, 도구 sandbox의 FSEvents 접근 차단(임시 fixture에 한해 승인된 환경으로 검증), 부분 graph Recovery와 peer path remap, stale metadata pair plan. 최종 자동 수정 가능한 FAIL 0. 무제한 재시도 없이 원인별 관련 회귀를 수행했다.

## 성능 (Debug, 동일 임시 10k 텍스트 파일)

최적화 전 5회 전체 준비 중앙값 3.679초. 최종 5회는 다른 빌드/뷰 렌더를 동시에 실행하지 않고 측정했다.

| 회차 | scan | 규칙·FS preview | plan | 합계 | CPU 합계 |
|---|---:|---:|---:|---:|---:|
| 1 | 0.521s | 0.709s | 1.186s | 2.416s | 2.363s |
| 2 | 0.371s | 0.727s | 1.227s | 2.325s | 2.265s |
| 3 | 0.349s | 0.673s | 1.193s | 2.215s | 2.198s |
| 4 | 0.348s | 0.674s | 1.174s | 2.196s | 2.185s |
| 5 | 0.363s | 0.702s | 1.214s | 2.278s | 2.257s |

최종 중앙값 **2.278초**, 5표본 nearest-rank p95 **2.416초**, XCTest 프로세스 누적 peak RSS **75.05MiB**. 작은 표본의 개발 측정이며 경쟁 제품 대비 우위/Release 속도/GUI 스크롤 latency를 뜻하지 않는다. preview만의 p95는 0.727초로 계획 목표 0.300초를 초과한다. 파일시스템 확인을 포함한 측정이며 입력/그리기는 worker와 분리했다. 100k metadata, 실사용 타자/스크롤/idle CPU, 경쟁 제품 같은 조건 실측은 미측정이다.

동시 렌더를 실행했던 중간 측정은 교란된 진단 자료(`performance-concurrent-diagnostic.txt`)로 보관하고 최종 비교값에서 제외했다. 버그가 아닌 측정 조건 문제를 FLAKY_TEST로 바꾸거나 좋은 회차만 골라 보고하지 않았다.

## 산출물 및 상태

`artifact-receipt.json`은 Debug 앱 파일별 SHA-256 및 CLI 해시를 기록한다. 기존 `상단바 설정 Dev.app`과 과거 `artifacts/qa` Release 앱·ZIP/DMG는 그대로 두었다. 개발본 갱신은 `eng/publish-development.py`를 사용하며 기존 확장 개발본은 timestamp backup으로 남긴다.

SOURCE_RACE와 PAID_PROVIDER_PENDING만 외부/계약 잔여 항목이다. 상용 완성을 선언하거나 사용자의 안전 요구를 임의로 낮추지 않았다. 출시 QA·스모크·공증·배포는 수행하지 않았다.

새 journal event는 schema 2로 기록하고 기존 schema 1은 변경 없이 읽는다. schema 2를 모르는 이전 앱은 해당 기록을 유효하지 않다고 판단하므로 새 swap/group 기록을 구식 Undo로 해석하지 않는다. 새 기록의 Undo/Recovery에는 최신 확장 개발본을 사용한다.

최종 규칙 조합 회귀에서 빈 중간 본문 뒤에 metadata를 구성할 때 원래 확장자가 유지되도록 수정했고 Core/실제 파일 관련 회귀를 통과했다. 전체 고유 XCTest 84 PASS(성능 1개 포함), 기존 100k opt-in 성능 1개는 별도 미실행이다.
