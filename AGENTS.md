# AGENTS.md — Moongchi NameFix

이 파일은 평상시 AI 개발의 최소 실행 규칙 원본이다. 제품 요구와 현재 상태는 docs/PROJECT.md와 docs/STATUS.md가 원본이며, 외부 만능프롬프트 Reference는 Bootstrap 기준일 뿐 평상시 실행 의존성이 아니다.

## 세션 시작과 Context

1. 저장소 루트와 적용 branch를 확인한다.
2. Git 시작 점검을 수행한다. main 기준으로 git status --short, git fetch origin main, git rev-list --left-right --count HEAD...origin/main을 확인한다.
3. 깨끗하고 원격과 같으면 READY. 깨끗하고 원격보다 뒤이며 fast-forward만 가능한 경우에만 git merge --ff-only origin/main을 사용할 수 있다.
4. dirty, ahead, diverged, 예상하지 못한 HEAD/파일 변경, fetch 실패는 임의로 해결하지 말고 중단 보고한다. stash, reset, restore, checkout, rebase, 일반 merge, force push로 정리하지 않는다.
5. AGENTS.md → docs/STATUS.md의 HOT → 현재 Task → Task의 근원 R/D → 주 책임 영역 → 영향 계약 → 필요한 코드와 테스트 순으로 읽는다. 원인을 모르는 조사 외에는 저장소 전체 탐색을 기본값으로 삼지 않는다.
6. 한 working tree에는 한 실행 주체만 쓴다. Preflight는 lock이 아니다.

## 현재 프로젝트 경계

- 제품: macOS용 Moongchi NameFix.
- 대상: macOS 14 이상, Apple Silicon arm64.
- 기술: Swift 6 strict concurrency, SwiftUI + AppKit, NameFixCore/Application/Infrastructure 경계.
- 파일 변경은 로컬 writable APFS의 이름 변경만 지원한다. 사용자 파일 내용 삭제·덮어쓰기·임의 변환을 추가하지 않는다.
- 모든 mutation은 fresh Preview/충돌 검사/명시 확인/영속 Journal/Undo·Recovery 안전 경계를 유지한다.
- 비협조 외부 writer의 source 교체를 원자적으로 막는다고 주장하지 않는다. 상세 계약은 docs/FILESYSTEM_CAPABILITIES.md가 원본이다.
- 가격 정책(전 기능 무료), UI/UX, 배포 상태는 각각 docs/PROJECT.md, docs/DESIGN.md, docs/RELEASE.md를 따른다.
- 현재 제품에 AI/OCR/RAG/클라우드 처리 기능은 없다. 새 도입은 사용자 승인과 별도 요구/결정이 필요하다.
- 뭉치 웹사이트(뭉치페이지스)는 이 저장소의 작업 범위가 아니다. 웹사이트 저장소를 여기서 수정·커밋·배포하지 않는다(D-025). 웹사이트 쪽이 참조할 원본은 docs/RELEASE.md의 ‘웹사이트’ 절에 있다.

## 승인 범위와 변경 규칙

- 승인된 개발 Task의 원본은 docs/STATUS.md다. STATUS에 없는 Release, 결제, Store, AI 기능, 기능 고도화를 임의로 시작하지 않는다.
- 범위·핵심 Architecture·데이터 구조·새 외부 의존성·보안/권한 정책·판매 방식의 큰 변경은 사람 Gate다.
- 비용 발생, 실제 배포/스토어 제출, 비밀·개인정보 외부 전송, 운영 데이터 파괴 작업도 사람 Gate다.
- 제품 코드와 문서가 충돌하면 실제 코드/검증을 우선 관찰하고 문서를 고치거나 충돌을 기록한다. 문서 정리를 이유로 제품 코드를 리팩터링하지 않는다.
- 새 임시 분석 자료는 .devtmp/scratch/ 아래에만 둔다. 원본·사용자 데이터·비밀정보를 넣지 않으며 완료 전 불필요한 임시 자료를 지운다.
- 과거 계획·상태·완료 기록을 archive/backup/old 문서로 만들지 않는다. Git이 과거 이력을 보존한다.

## Engineering Verification

검증은 변경 영향에서 정한다.

변경 영역 + 변경 계약 + 그 계약의 소비자 + 무효화된 기존 PASS 근거 → 필요한 검증 범위.

- 작은 변경마다 전체 build/test/clean/package를 반복하지 않는다.
- 관계없는 PASS는 fingerprint/환경/계약의 무효화 조건에 걸리지 않으면 재사용할 수 있다.
- 현재 검증 영수증은 .ai/validation-cache.json, 검증 정책과 현재 요약은 docs/QA.md를 따른다.
- AI가 실행·테스트·렌더를 확인한 것은 Engineering Verification이다. 사용자 QA PASS로 기록하지 않는다.
- 사용자 QA는 docs/QA.md와 STATUS에 모아 의미 있는 시점에 한 번에 요청한다.

주요 명령 예:
~~~sh
eng/doctor.sh
eng/build.sh --configuration Debug --arch arm64
eng/test.sh --scope core
eng/test.sh --scope ui-model
eng/test.sh --scope filesystem
eng/test.sh --scope transaction
eng/test.sh --scope safety
python3 eng/validate-resources.py
python3 tools/doccheck.py
~~~

실제 Task에는 영향 범위에 필요한 명령만 선택한다. 실행하지 않은 명령을 PASS로 쓰지 않는다.

## 문서 운영

- 요구사항/현재 승인 범위: docs/PROJECT.md
- 현재 상태/현재 Task/User QA 대기: docs/STATUS.md
- 확정 결정: docs/DECISIONS.md
- 현재 구조: docs/ARCHITECTURE.md
- UI/UX 계약: docs/DESIGN.md
- 파일 안전·권한 계약: docs/FILESYSTEM_CAPABILITIES.md
- Engineering Verification/User QA: docs/QA.md
- 빌드·서명·배포: docs/RELEASE.md
- 전체 지도: docs/README.md

사실이 바뀐 원본만 갱신한다. 같은 사실을 여러 문서에 복제하지 말고 다른 문서에서는 링크와 ID로 가리킨다. STATUS는 현재만 유지하고 완료 이력을 누적하지 않는다. 현재 계획 원본은 docs/PROJECT.md의 현재 승인 범위 절 하나다.

## 종료와 Git

1. 영향 검증을 끝낸다.
2. 사실이 바뀐 SSOT와 STATUS만 갱신한다.
3. python3 tools/doccheck.py를 실행한다.
4. 이번 Task 파일만 명시적으로 stage한다.
5. python3 tools/doccheck.py --git, git diff --check를 실행한다.
6. Git 상태와 원격 차이를 다시 확인한다.
7. 현재 사용자 지시가 normal commit/push를 허용한 Task만 일반 commit/push한다.
8. push 거부나 diverged를 임의 merge/rebase/reset/force push로 해결하지 않는다.

종료 보고는 변경, 검증, 재사용한 근거, User QA Pending, blocker, SSOT 갱신, 다음 Gate만 짧게 남긴다.
