# Moongchi NameFix v1.0 출시 상태

2026-10-04. Apple Silicon arm64 / macOS 14+ 전용. 최신 사용자 지시에 따라 앱 자체 개발을 우선하며 Store 실제 동작 검증·Release·서명·공증·배포 준비는 후속 단계로 보류한다. 아래 기존 Release/서명/패키징 결과는 이미 수행한 이력이며 추가 실행 지시가 아니다. 과거 Debug 전용 상태보다 이 문서가 우선한다.

## 판정

**앱 자체 v1.0 개발 범위: 상용 수준 완성. 확인된 추가 필수 개발 항목이 없어 대기한다.** 기존 구현·관련 검증 및 아래 다섯 영역 검토 기준의 판정이며, 무결함이나 공개 출시 완료를 보장하는 표현은 아니다. 실제 Pro 판매 연결·Store 동작 검증·출시 식별자·공증 및 실사용 Gate는 사용자 지정 후속 단계로 분리한다. 현재 후보는 무료 기능을 실행할 수 있으며, Pro 엔진 구현과 실제 구매·활성화 제공을 혼동하지 않는다. 앱 설정에서도 이 빌드의 상태를 표시한다.

SOURCE_RACE는 원자적 예방을 달성한 것으로 처리하지 않는다. 이번에는 예방·감지·보존·복구 안내를 추가하고, 외부 프로그램의 동시 변경을 배제하지 못하는 **완화된 알려진 제한**으로 구분했다. 이 한계 하나만으로 영구적인 개발 불가능을 선언하지 않되, 모든 외부 writer에 대한 원자성 보장도 하지 않는다.

## 이번에 구현한 내용

- `Infrastructure/FileCoordination.swift`: 각 source→temporary 및 temporary→final 이동을 macOS NSFileCoordinator로 조정한다. 조정 대기 중 취소와 15초 대기 한도, 대기 중 URL 변경 거부를 지원한다. 파일 조정에 참여하지 않는 writer에는 배타성을 보장하지 않는다.
- `Transaction.swift` / `GraphTransaction.swift`: 조정 접근을 얻은 **뒤** 열린 부모의 identity·raw 경로, 원본 raw 이름·identity·내용 버전을 다시 확인한다. no-replace 이동 직후에도 확인하며 불일치하면 즉시 중단한다. 이동 알림을 전달한다. Rename·Undo·Recovery·swap/cycle·CLI가 동일 경로를 사용한다.
- `Scanner.swift` / `Planning.swift`: 일반 파일에도 크기/mtime 스냅샷을 적용한다. 검사→계획→확인→실행 사이 변경을 보류한다. 하위 항목의 자체 변경으로 mtime이 달라지는 디렉터리는 이 내용 버전 조건에서 제외한다.
- 작업 기록: 확인된 복구 위치의 경로 복사와 Finder 열기. 정체가 다른 파일은 자동 복구 대상에 넣지 않는다. 좁은 창의 긴 일본어 Undo/Recovery 버튼은 세로 배치로 수정하고, 복구 경로 아래 조작 버튼을 둔다.
- 설정: 현재 Free/Pro 상태와 이 후보의 구매·활성화 미제공 상태를 표시한다. 기본 Olive·네 테마·기존 정보·창 복원을 유지한다.
- CLI: 일반 dry-run과 확인 거부는 작업 기록 디렉터리를 만들지 않는다. Release에는 개발용 Pro 활성화와 경합 주입 hook이 없다.
- 새 Release CLI 빌드, 별도 복사본 서명, 덮어쓰기 없는 후보 ZIP/DMG 생성, 해시·압축 해제·읽기 전용 마운트 검증 스크립트를 추가했다.

## 자동 검증 근거

근거 폴더: `artifacts/release-candidate/1.0.0/evidence/`. 고유 XCTest **91 PASS**, 동일 테스트의 Debug/Release/APFS 반복은 중복 합산하지 않는다. 모든 테스트를 단일 명령으로 91개 실행했다는 뜻이 아니다. 기존 opt-in 성능 테스트도 이번에는 별도로 실행했다.

| 범위 | 실제 결과 | 근거 |
|---|---|---|
| Core 전체 | 18 PASS | full-core.txt |
| Runtime/Application/UI 모델 전체 | 69 PASS, opt-in 2 SKIP → 성능 실행에서 둘 다 PASS | full-runtime.txt, performance-and-races.txt |
| 최종 경합/성능 | 8 PASS. 실제 실행 경로의 source 교체 8조합, destination 생성 2조합 포함 | performance-and-races.txt |
| 대소문자 구분 APFS | 39 PASS, 해당 볼륨에서 mutation 성능만 SKIP; 자체 생성 볼륨 분리 완료 | case-sensitive-final.txt |
| 최적화된 Release 실행 경로 | 15 PASS, 실제 Rename·Undo·Recovery·1000건 변경 | release-transaction-tests.txt |
| 최종 UI 모델·복구 | 15 PASS | ui-recovery-final.txt |
| CLI | Debug PTY 실제 확인/변경/Undo/hash, Release dry-run·개발 Pro 차단·무확인 거부 PASS | cli-debug.txt, cli-release-final.txt |
| 리소스 | 393키×3언어, 폰트/라이선스/원본 handoff hash PASS | resources.txt |
| Release UI | 75개 실제 숨겨진 SwiftUI 렌더 후 좁은 기록 화면 수정·관련 6개 재검증 | render-final.txt, render-history-build3.txt |
| 빌드·서명·패키지 | 최종 build 3 결과와 파일별 해시는 manifest/최종 근거가 기준 | release-build3.txt, signing-build3.txt, package-build3-verification.txt |

초기 컴파일의 누락된 `try`/동기 테스트 문맥은 수정했다. 제한된 도구 sandbox는 macOS 파일 조정 서비스와 WindowServer 접근을 막아 테스트 실패/렌더 종료를 일으켰다. 정상 접근이 승인된 격리 fixture 실행으로 재검증했으며 앱에서 sandbox를 우회하는 코드는 추가하지 않았다. 최초 APFS 이미지의 잘못된 filesystem 명칭도 실제 hdiutil 지원 명칭으로 수정했다. macOS 기본 Bash의 빈 배열 처리를 수정했고, 렌더 도구가 가로 scroll view를 세로로 이동하지 않으며 Lazy 목록의 높이 안정화 후 캡처하도록 보완했다. 이전 실패 로그는 삭제하지 않는다.

## 성능

Apple M1 Pro / macOS 27.0.1 / Xcode 27.0 / Swift 6.4 / SDK 27.0. 자체 APFS fixture 측정이며 GUI 스크롤 지연이나 경쟁 제품보다 빠르다는 증거가 아니다.

- 10,000건 검사+규칙 Preview+실행 계획: 5회 중앙값 **2.195초**, nearest-rank p95 **3.080초** (Debug).
- 같은 측정의 Preview 최대 **0.732초**: 기존 내부 목표 0.300초에는 미달한다.
- 100,000건 검사 **3.147초**, 테스트 프로세스 누적 peak RSS **139.6MiB**, 오류 0. 취소 반환 **0.206초**.
- 1,000건 실제 변경: **27.927초** (Release), **28.296초** (Debug). 각 단계의 durable journal/동기화와 macOS 파일 조정을 포함한다. 내용 fixture 비교 통과. 검사 성능과 혼용하지 않는다.
- 미해결 성능 결함으로 측정하지 않은 UI 끊김을 추정하지 않는다. 대량 실제 변경의 기록/조정 비용은 알려진 제약이며 화면은 진행률·취소를 제공한다.

## 다섯 영역 재판정

| 영역 | 남은 항목 |
|---|---|
| 기능 | 실제 Pro 구매/활성화 공급자 미연결. `UnconfiguredEntitlementProvider`는 권한을 부여하지 않는다. 판매 방식/상품 설정을 받은 뒤 검증된 adapter를 연결해야 한다. 그 외 구현 범위에서 확인된 잔여 결함 없음 |
| 성능 | 위 수치와 목표 미달 공개. 확정된 멈춤/데이터 처리 결함 없음 |
| 사용자 경험 | 확인된 잔여 결함 없음. 미지원 Pro 상태·동시 변경 오류·복구 위치를 명시 |
| 디자인 | 실제 발견한 좁은 일본어 기록 버튼 잘림 수정. 검토한 렌더 범위에서 추가 결함 없음 |
| 안정성 | 협조 writer 조정, 비협조 writer 교체 감지/중단/보존 검증. 비협조 writer의 교체 자체와 외부 내용 수정을 막는 원자성은 제공하지 않는 알려진 제한 |

## 사용자/외부 조건과 다음 작업

1. **판매 방식·상품 ID**: 실제 판매 서비스 또는 App Store 선택 필요. 현재 무료 기능만 Release에서 활성화된다. 개발 Pro 스위치나 테스트 성공으로 실제 구매를 대체하지 않는다.
2. **출시용 bundle ID**: 현재 `com.moongchi.namefix.dev` 유지. 임의로 팀 소유 식별자를 확정하지 않았다. 확정 ID로 최종 재빌드 필요.
3. **공증 Keychain 프로필**: 유효한 Developer ID Application 인증서는 확인했고 새 후보 복사본 서명까지 수행했다. 인증서 부재가 blocker라는 초기 결과는 제한 환경 조회 결과였으며 정정한다. 공증 프로필은 제공되지 않았고 제출·공증 성공을 주장하지 않는다.
4. **실사용/최소 OS**: Finder 드롭·Services·TCC·접근성·sleep/quit·macOS 14 실기는 [체크리스트](MANUAL_QA_CHECKLIST.md)로 확인한다. 화면 미확인 자체를 앱 결함으로 부르지는 않지만 공개 출시 Gate의 증거로도 대신하지 않는다.

공개 업로드·판매 게시·App Store 제출은 하지 않았다. Gatekeeper 평가 결과는 `Unnotarized Developer ID`이며 공증 티켓이 없다. 보호 설정 해제나 검역 제거를 안내하지 않는다.

## 최신 산출물

- 앱: `artifacts/release-candidate/1.0.0/build3/Moongchi NameFix.app`
- CLI: 같은 폴더의 `namefix`
- ZIP/DMG: 같은 폴더의 `Moongchi_NameFix_1.0.0_build3_arm64.zip` / `.dmg`
- 파일별 해시·서명 상태: 같은 폴더의 `ARTIFACT_MANIFEST.json`, `SHA256SUMS.txt`
- 직접 확인용 새 fixture: `artifacts/release-candidate/1.0.0/manual-fixtures/` (이전 fixture도 보존)
- 사용법: [EXPANSION_USER_GUIDE.md](EXPANSION_USER_GUIDE.md)

기존 `artifacts/qa`, 기존 Debug 앱, 이전 build 2 후보는 보존한다. 최신 후보 경로는 위 build3이며 이전 후보를 공개 배포하지 않는다.
