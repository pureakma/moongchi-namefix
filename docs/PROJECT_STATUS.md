# 개발 상태

## 최신 — macOS 사이드바와 목적별 메뉴

신호등과 이어지는 native split sidebar, 접기/펼치기, 독립 이름 일괄 변경 메뉴를 적용했다. 중복 자소 분리 정리 제목을 제거하고 도구를 목적별 메뉴로 분리했다. 설정은 유지한다. 최신 근거는 [사이드바 개선 기록](NATIVE_SIDEBAR_2026-10-04.md), 최신 Debug 앱은 `artifacts/development/Moongchi NameFix 사이드바 Dev.app`이다. 이전 섹션은 이력이며 Release 준비는 보류한다.

## 최신 — 간편 메인 + 일괄 변경 작업실

자소 분리 중심의 기본 화면과 별도 이름 변경 작업실을 구현했다. 화면 전환·마지막 화면 복원·미적용 규칙 실행 차단을 포함한다. [업그레이드 기록](WORKSPACE_UPGRADE_2026-10-04.md)이 최신 UI 기준이다. 기존 무료/Pro 범위와 최신 아이콘 유지, Release 준비 보류.

## 최신 — 아이콘 재적용 (2026-10-04)

공유 폴더의 최신 원본 `1aa97856…`으로 교체. 10개 슬롯 크기·모서리 투명·번들 ICNS 연결 검증 및 Debug 빌드 통과. 최신 앱: `artifacts/development/Moongchi NameFix 아이콘 업데이트 Dev.app`. 근거: `artifacts/development/icon-1aa97856/`. 기존 앱/원본 보존, Release 미실행.

## 최신 — 투명 배경 아이콘 교체 (2026-10-04)

공유 아이콘 폴더의 새 원본으로 10개 슬롯을 재생성했다. 모든 모서리 투명 검증 및 Debug 빌드 통과. 최신 UI 포함 앱은 `artifacts/development/Moongchi NameFix 투명 아이콘 Dev.app`. 이전 앱은 보존하며 흰 배경 버전과 구분한다. 근거: `artifacts/development/icon-transparent/`. Release 작업 없음.

## 최신 — 전용 아이콘 적용 (2026-10-04)

사용자 제공 네임픽스 원본을 `assets/branding/NameFix-Original.png`에 보존하고 macOS 10개 아이콘 슬롯에 적용했다. 재생성 스크립트도 원본 기반으로 전환했다. 크기/번들 icns 연결 검증 및 Debug 빌드 통과. 최신 UI 포함 앱: `artifacts/development/Moongchi NameFix 전용 아이콘 Dev.app`. 근거: `artifacts/development/icon-update/`. Release·서명·공증은 미실행.

## 최신 — 설정·도구 UI 개선

사용자 추가 요청에 따라 설정/문자 형식/이름 변경 규칙/텍스트 변환/추가 도구를 개선했다. 목적 중심의 ko/en/ja 안내와 기존 기능을 유지한다. [변경·검증 기록](UI_POLISH_2026-10-04.md)을 따른다. Release 및 출시 준비는 계속 보류한다. 아래 대기 판정은 이 추가 요청 전 기록이다.

최종 갱신: 2026-10-04. **macOS 14+ / Apple Silicon arm64 전용**.

## 최신 지시 — 앱 개발 완료 후 대기

2026-10-04: 앱 자체 v1.0 개발 범위는 상용 수준 완성으로 판정한다. 기존 검증에서 확인된 추가 필수 개발 항목은 없다. Store 실제 동작 검증·판매 연결·추가 Release 빌드·배포 서명·공증·출시 QA는 후속 단계로 보류한다. SOURCE_RACE 및 성능 측정 한계는 그대로 공개하며, 실제 구매가 연결됐거나 공개 출시가 완료됐다고 주장하지 않는다. 이번에는 상태 문서만 최신화하고 빌드·테스트·패키징을 반복하지 않았다.

## 현재 — v1.0 출시 후보

**로컬 출시 후보 준비, 공개 출시 대기.** 최신 판정과 명령·증거·산출물은 [V1_RELEASE_STATUS.md](V1_RELEASE_STATUS.md)가 기준이다. 무료/Pro 구현에 macOS 파일 조정·취소/대기 한도·일반 파일의 내용 버전 검사·실제 경합 테스트·복구 Finder 진입을 추가했다. 좁은 일본어 기록 버튼 잘림도 수정했다.

고유 XCTest 91 PASS(중복 제거), 대소문자 구분 APFS 39 PASS, Release 실행 경로 15 PASS, 393키×3언어, 최종 arm64 Release 1.0.0(3) 앱. 최신 경로는 `artifacts/release-candidate/1.0.0/build3/`다. 기존 QA/Debug/이전 후보는 보존했다.

SOURCE_RACE는 완화된 알려진 제한이며 원자 예방 PASS가 아니다. 실제 Pro 판매 연결은 미구성이므로 Release 후보는 무료 기능을 제공한다. 유효한 Developer ID는 확인했고 별도 후보 복사본에 서명한다. 공개 출시에는 팀 소유 bundle ID, 공증 프로필, 실제 판매 방식/상품 정보와 실사용 Gate가 필요하다. 현재 `com.moongchi.namefix.dev`를 임의로 바꾸지 않았다.

사용자 v1.0 상용 출시 요청으로 Release·패키징·서명 작업을 진행했다. 아래는 이전 단계의 이력이며 과거 SOURCE_RACE 영구 blocker/인증서 부재 판정은 위 최신 보고서로 대체한다.

## 무료 사용자 유입 정책 개정

2026-10-04 후속 요청을 반영해 무료 범위를 체감상 넓게 조정했다. 기본 찾기·바꾸기·문자 편집·일반 순번·무료 규칙 조합·기본 결과 export와 같은 CLI 기능은 무료다. 정규식·조건·고급 순번·사용자 프리셋·CSV 가져오기·메타데이터·감시는 Pro로 둔다. 무료 기본 규칙의 단계 수·처리 개수·성능에 인위적인 등급 제한을 두지 않는다. 무료 예제와 마지막 무료 규칙 설정 복원을 제공하되 입력 파일·경로·클립보드를 자동 보존하지 않는다.

계획·작업 목록·실행 지침·README를 동기화했다. 유입 증가와 유료 전환은 아직 가설이며 국내 앱 인기 순위나 전체 기능 우위를 주장하지 않는다. 탐색 사용성 평가와 무료 과제의 불필요한 paywall 검사도 계획에 포함했다. 정책 수립 이후 실제 구현과 관련 Debug 검증을 완료했다. Release는 수행하지 않았다.

## 현재 앱 자체 판정 — 상용 완성도 재검토

**미완성: source 교체 경합 1건이 남음.** 자세한 항목·수정·관련 실행은 [COMMERCIAL_REVIEW.md](COMMERCIAL_REVIEW.md)가 기준이다. 출시 QA·서명·화면 미확인은 이 판정에서 제외한다.

시스템/다크/라이트/올리브 아카이브 주 화면 메뉴, 재검사 선택 유지, 번호 제안 선택, 결과 뒤 대기 입력, 취소 가능한 검색/정렬, 영어 잘림, 실패 결과/복구 위치 표시를 수정했다. 관련 테스트 25개 통과, Debug 빌드 성공, 실제 뷰 20개 렌더. Release/ZIP/DMG는 갱신하지 않았다.

이전 개발 앱: `artifacts/development/Moongchi NameFix 상단바 설정 Dev.app`. 최신 확장 개발 앱은 상단을 참조한다.

## 기본 테마·상단바·설정 및 제품 검토

[PRODUCT_ASSESSMENT_2026-10-04.md](PRODUCT_ASSESSMENT_2026-10-04.md): 최초 기본 테마를 Olive Archive로 변경하고 기존 저장 선택은 보존했다. 테마 선택은 설정으로 옮겼고 네 가지 색상 미리보기, 자동 저장 안내와 설정창 내부 저장 실패 메시지, 정렬된 설정 카드를 추가했다. 앱 이름의 중복 title 표시는 숨기고 macOS unified toolbar 우측에 다시 검사·작업 기록·설정을 배치했다. native traffic lights와 작은 창 overflow는 보존했다.

관련 UI model 9개 PASS, source 교체 경합 재현 1개 PASS(해결 아님), Debug 빌드 및 세 언어 리소스 검증. 실제 native frame/설정 렌더 근거는 `artifacts/development/shell-refinement/`에 보관한다. 앱 자체 판정은 기존 SOURCE_RACE 때문에 **미완성**을 유지한다. AI 활용은 가능성 검토만 했고 모델/다운로드/추론/결제 기능을 추가하지 않았다. 수익화는 일회성 전문 유틸리티/번들 가능성이 있으나 실수요·매출 검증은 아니다.

## 반응형 창 및 마지막 크기 복원

[RESPONSIVE_WINDOW.md](RESPONSIVE_WINDOW.md): 기존 900×640 최소 크기 제한을 해제했다. 넓은 창의 sidebar/표와 네 통계, 좁은 창의 카드·정보·조작을 모두 유지하면서 재배치한다. 낮은 창은 스크롤, sheet는 부모 크기에 대응한다. 첫 실행은 디스플레이의 사용 가능 영역을 기준으로 크기를 정하고 이후 일반 창의 크기·위치·화면을 복원한다. 전체 화면 크기는 저장에서 제외한다. 관련 테스트 13개 통과. Debug와 실제 뷰 렌더 근거는 위 문서와 `artifacts/development/responsive/`에 기록한다.

## 문자 구성 설명 보완

[CHARACTER_EXPLANATION.md](CHARACTER_EXPLANATION.md): 파일명 아래 분리된 문자 칸과 NFC 결과, 분해형/혼합형/조합형 상태, 오류가 아니라는 안내, 전체 구성·scalar 비교를 추가했다. ko/en/ja 반영. 표시 전용 관련 테스트 5개와 Debug 빌드, 리소스 검증, 15개 실제 뷰 렌더로 확인했다. 기존 source 경합 한계는 이 변경과 별개로 유지한다.

## 이전 기준선 — 이번 수정 이전 산출물

MAC-F01~MAC-F21 기능 구현, Phase 0~5 로컬 Gate 및 실행 가능한 자동 QA 완료. 고유 테스트 **28개 PASS / 실패 0** (Core 5, FS·transaction 20, Application UI state 3). 실제 사용자 화면 QA와 공개 출시 승인은 별도다.

- Swift 6 / SwiftUI·AppKit 앱, 독립 NameFixCore package, arm64 Release 앱·ZIP·DMG 생성 완료.
- Preview·충돌 검사·명시 확인 후 no-replace 2단계 Rename, durable journal, fresh Undo 및 Recovery 구현.
- 210키 × ko/en/ja, 4개 테마, 폰트/라이선스, Finder Services 등록, 진단·즉시 설정 구현.
- 기본 APFS와 대소문자 구분 APFS 회귀 통과. 후자는 성능 테스트 1개를 의도적으로 건너뛰며 일반 APFS의 실제 측정 결과를 사용했다.
- 10만 파일 scan: **3.565초**, XCTest 프로세스 최대 **148.8MiB**, 오류 0. Apple M1 Pro / 32GiB / macOS 27.0.1 기준이며 GUI 반응 시간 측정은 아니다.
- 최종 Release 빌드, UI 테스트 target 컴파일, 16개 off-screen 렌더, ZIP 무결성, DMG 읽기전용 mount, ad-hoc 서명 및 리소스 startup 검증 완료.

## 남은 Gate

| 상태 | 내용 |
|---|---|
| NEEDS_MANUAL_QA | 실제 Finder 드롭·Services·Dock, 창/키보드/접근성/TCC, 대량 목록의 실제 UI 반응, sleep/quit |
| NEEDS_REAL_DEVICE_QA | macOS 14, 외장/SMB/클라우드 실기; 미검증 파일시스템 mutation은 제한 |
| BLOCKED_RELEASE_SOURCE_RACE | 외부 프로세스의 마지막 source 확인 이후 교체를 원자적으로 방지할 Darwin expected-inode rename 계약 없음. 실제 경합 fixture로 한계를 확인했으며 지원 계약/위험 해결 전 공개 출시 차단 |
| BLOCKED_RELEASE_SIGNING | 개발용 bundle ID와 ad-hoc 로컬 QA 패키지. 팀 소유 ID, Developer ID, 공증 미완료 |

## 산출물

- `artifacts/qa/Moongchi NameFix.app`
- `artifacts/qa/Moongchi_NameFix_1.0.0_macOS_arm64.zip`
- `artifacts/qa/Moongchi_NameFix_1.0.0_macOS_arm64.dmg`
- `artifacts/qa/ARTIFACT_MANIFEST.json`, `SHA256SUMS.txt`
- `docs/AUTOMATED_QA_REPORT.md`, `MANUAL_QA_CHECKLIST.md`, `FEATURE_COMPLETE_GATE.md`
- `.ai/validation-cache.json`: 실제 내용/테스트/도구/환경 fingerprint와 근거 경로

Git 저장소와 적용되는 AGENTS.md는 없었다. handoff 9개 파일 SHA-256 일치. 기존 자료와 초기 실패 증거는 보존했으며, 실제 Finder나 사용자 창을 조작하지 않았다. 자세한 실행 결과·명령·한계는 자동 QA 보고서가 기준이다.
