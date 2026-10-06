# Moongchi NameFix macOS — 개발 AI 실행 프롬프트 v1.0

이 파일은 macOS 개발 AI에게 그대로 전달할 실행 지침이다. 제품 요구사항은 동봉된 [macOS Project Master](Moongchi_NameFix_macOS_Project_Master_v1.0.md)만 사용한다. 아래 지시를 실제 개발 작업으로 수행한다.

## 1. 시작 지시

먼저 다음 파일을 처음부터 끝까지 읽어라.

1. `Moongchi_NameFix_macOS_Project_Master_v1.0.md`
2. 이 `Moongchi_NameFix_macOS_DevAI_StartPrompt_v1.0.md`
3. `LOCALIZATION_CATALOG.md`의 변환 정책/override/전체 키
4. `assets/fonts/`의 두 라이선스와 `HANDOFF_MANIFEST.json`

인수인계 폴더가 프로젝트 내부 `docs/macos/`에 있으면 그 경로에서 읽는다. 별도 ZIP이면 압축 해제한 폴더가 기준이다. Windows 저장소가 없어도 진행할 수 있다. 제공된 manifest SHA-256을 확인하고 다른 파일로 바뀌었다면 차이를 기록한다. manifest는 보안 서명이나 Mac QA 통과 증명이 아니다.

목표는 **macOS 네이티브 Moongchi NameFix를 Feature Complete까지 구현하고, 전체 자동 QA와 수정/회귀검증을 수행한 뒤 개발자 직접 QA가 가능한 실행 앱과 ZIP/DMG를 준비하는 것**이다. 계획 문서나 목업만 작성하고 멈추지 마라.

중간 Phase마다 사용자 승인을 요청하지 마라. 일반적 UI 배치, 코드 구조, 테스트 작성, 안전한 fixture, 빌드/패키징은 스스로 판단하여 계속한다. 다음만 중대한 blocker다: 데이터 손실 위험을 해소할 수 없음, 요구사항 충돌, 플랫폼상 구현 불가능, 실제 기기/인증서/팀 소유 식별자처럼 사용자만 제공할 수 있는 필수 조건. 그런 경우에도 독립적인 개발과 unsigned QA package 준비는 계속한다.

**개발 진행 승인을 생략하는 것과 앱 사용자의 파일 Rename 확인을 생략하는 것은 전혀 다르다.** 앱의 실제 파일 변경은 항상 Preview/충돌 검사/명시 확인을 요구한다.

## 2. 처음 수행할 작업

- 현재 경로/Git 변경/AGENTS.md/설치 도구/기존 구현을 읽고 사용자의 변경을 보존한다. 기존 앱이 있으면 가장 첫 미완료 요구사항부터 시작한다.
- Mac에서 `sw_vers`, `uname -m`, `xcode-select -p`, `xcodebuild -version`, `swift --version`을 확인하고 버전을 기록한다. 최신 안정 SDK를 실제 확인하고 추측한 버전을 핀하지 않는다.
- SwiftUI 앱 프로젝트와 독립 Core package/테스트 target을 만든다. bundle ID는 개발용 값을 사용하며 실제 Developer Team이 없다고 UI/엔진 개발을 멈추지 않는다.
- Master Phase 0의 APFS/Swift 문자열/no-overwrite spike를 먼저 실행한다. 표준 `String ==`로 NFC 차이를 판별하지 않는다.
- 전용 임시 fixture에서 raw bytes를 만들고 디렉터리를 재열거한다. APFS 같은 엔트리의 normalization-insensitive lookup과 raw spelling을 각각 증명한다.
- Foundation/Darwin API 가용성과 no-replace 계약, source race의 실제 한계, TCC/읽기전용/볼륨 규칙을 `docs/FILESYSTEM_CAPABILITIES.md`에 기록한다.
- 기본 다크 창, 정확한 Olive palette, ko/en/ja 구조, 즉시 저장 설정을 실제 실행 가능한 shell로 만든다.
- `docs/PROJECT_STATUS.md`, `.ai/validation-cache.json`, `docs/ARCHITECTURE.md`를 초기화하고 실제 구현을 계속한다.

환경이 Windows/Linux라 Mac 컴파일이 불가능하면 그 사실을 명시한다. 해당 환경에서 작성/검증할 수 있는 pure model/문서/리소스는 진행하되, Mac 실행·APFS mutation·공증 검증을 했다고 쓰지 않는다.

## 3. 구현 원칙

### 3.1 기능

Master MAC-F01..MAC-F21을 모두 추적한다. 파일/폴더 혼합 드롭, picker, recursive, NFC 분석/Preview, 선택/필터/검색/정렬, 충돌/번호 제안, 안전 Rename, 검증, Journal, Undo, Recovery, Inspector/clipboard, 최근 폴더, 진단, 즉시 설정, Finder Services, 세 언어/네 가지 테마, ZIP/DMG가 범위다.

초기 화면은 입력 sidebar + 검사 결과 workspace. **중앙의 단일 드롭 안내, 실제 수신은 창 전체.** 좌우 두 개의 서로 다른 Drop Zone을 만들지 않는다. sidebar 큰 브랜드 블록/“항목 추가” 제목, 전체 항목만 감싼 추가 박스, 저장 버튼을 다시 만들지 않는다. 제목은 “파일 이름 검사”.

Dark가 첫 기본값이며 System은 별도 선택이다. Olive는 Master의 exact sRGB token을 사용하고 sidebar `#DDD8C5`를 유지한다. 타이틀바/설정/기록/sheet/popup까지 적용한다. macOS native traffic lights와 OS 메뉴는 보존한다. 한국어/영어 Pretendard, 일본어 Pretendard JP, 시스템 glyph fallback을 사용한다.

### 3.2 안전

파일 내용 수정/삭제/덮어쓰기/copy-delete fallback/자동 NFKC·NFKD 금지. raw leaf identity/볼륨 lookup identity/화면 문자열을 분리한다. 원시 filename bytes를 JSON에 base64 보존하고 lossy decode로 다른 파일을 선택하지 않는다. symlink/alias/package/mount 규칙을 구현한다.

실제 mutation 전에 durable Prepared/intent를 기록한다. source→temporary→final no-replace, 하위→상위, actual raw entry+identity 검증을 수행한다. 실패하면 안전하게 중단/격리하고 증거를 보존한다. APFS에서 `!sourceExists`를 성공 조건으로 요구하지 않는다.

Undo는 fresh Plan과 확인을 거친다. partial Undo는 path+identity로 완료를 추적하며 hardlink를 inode만으로 합치지 않는다. 경합 테스트로 입증하지 못한 원자성/내용 불변 보장을 문서에 주장하지 않는다.

### 3.3 코드와 성능

UI→Application→Core/Infrastructure 경계를 지킨다. MainActor에서 전체 디렉터리 순회/대형 decode/전체 반복 정렬 금지. bounded concurrency, serial transaction actor+process lock, generation ID, 가상화 목록, lazy Inspector/history, 부모별 directory index를 사용한다.

사용자 표시 오류와 기술 로그를 분리하고 경로/clipboard/내용을 기본 로그에 넣지 않는다. panic/crash/catch-and-ignore로 개별 오류를 숨기지 않는다. 설정은 직렬화된 atomic save, 손상/새 schema 원본 보존. 복구 journal은 일반 로그 retention으로 지우지 않는다.

## 4. 검증 정책 — 반드시 비용을 관리하라

### Level 1 — 각 Task

변경 target build + 직접 관련 unit/fixture/integration을 수행한다. 매 Task 전체 Xcode build/test, clean, 모든 CPU, packaging을 반복하지 않는다. 단순 리소스 변경이면 리소스 완전성/직접 UI 계약을 확인한다. 실행 경로 변경이면 실제 fixture 안전성 검증을 생략하지 않는다.

### Level 2 — Phase Gate

해당 Phase 완료 시 app build, 해당 Phase tests, 영향 integration, 필요한 architecture 검증을 수행한다. Gate 결과와 다음 미완료 항목을 기록하고 다음 Phase로 계속한다.

### Level 3 — Feature Complete 이후에만

전체 scope에 핵심 TODO/stub가 없고 Phase Gate를 통과한 뒤 clean build, 두 CPU build, 전체 tests/fixture, hash invariance, Undo/Recovery/cancel/error, locale/theme/schema/license/dependency/static checks, 패키지/startup을 수행한다. 실패가 나오면 원인을 수정하고 실패 테스트와 관련 regression을 수행한다. 영향 없는 PASS를 이유 없이 전부 재실행하지 않는다.

### Validation Cache

`.ai/validation-cache.json`에 최소 다음을 저장한다. 이 예시의 NOT_RUN을 PASS로 미리 바꾸지 않는다.

```json
{
  "schemaVersion": 1,
  "entries": [
    {
      "validationId": "MAC-CORE-UNICODE",
      "scope": ["Packages/NameFixCore/Sources/**", "Packages/NameFixCore/Tests/**"],
      "status": "NOT_RUN",
      "architecture": "arm64",
      "configuration": "Debug",
      "command": null,
      "sourceFingerprint": null,
      "testFingerprint": null,
      "dependencyFingerprint": null,
      "toolchainFingerprint": null,
      "environment": {"os": null, "sdk": null, "filesystem": null, "caseSensitive": null},
      "timestamp": null,
      "evidencePath": null
    }
  ]
}
```

Cache는 scope 실제 내용과 의존성/테스트/도구/환경으로 판정한다. Git commit만 비교하지 않는다. 영향을 받은 계약만 무효화하되 Core FS 변경이면 scanner/executor/undo/recovery까지 전파한다. 같은 PASS 재실행은 실제 변경/실패수정/Phase/Full/Release Gate/불완전 이전 검증 때만 한다. flaky는 FLAKY_TEST로 남기고 무제한 재시도하지 않는다.

## 5. 작업 완료 조건

개별 Task DONE: 구현, compile, 관련 Level 1 PASS, 오류/안전 경로, 번역, 상태 문서, 미검증 항목 표시까지 완료. UI 목업/TODO/컴파일 안 된 코드/테스트 미실행/오류 무시를 DONE으로 보고하지 않는다.

Feature Complete: Master 필수 기능 구현, Phase 0~5 Gate, 핵심 stub 0, 실제 QA build 생성. 이때부터 FULL_AUTOMATED_QA 상태다. 실제 Finder 드롭, 외장/SMB/클라우드/Intel 장비, 서명 등 자동 실행하지 못한 검증은 각각 별도 상태로 남긴다.

AUTO-QA PASS: 자동 수정 가능한 FAIL 0. 가능한 모든 자동 검증 통과. 불가능한 실기 QA나 인증서 대기를 PASS로 바꾸지 않는다. 공개 출시 가능 판정은 필수 수동/실기/서명 Gate까지 모두 확인한 뒤에만 한다.

## 6. 최종 산출물

- 실행 가능한 macOS 앱 프로젝트, Core/Integration/UI tests, build/test/package scripts.
- `docs/PROJECT_STATUS.md`, `ARCHITECTURE.md`, `FILESYSTEM_CAPABILITIES.md`, `FEATURE_COMPLETE_GATE.md`.
- `docs/AUTOMATED_QA_REPORT.md`: 실행 환경/명령/결과/근거/미검증/fixture/artifact SHA-256.
- `docs/MANUAL_QA_CHECKLIST.md`: ID/목적/환경/준비/절차/기대/로그/PASS·FAIL·NOT_AVAILABLE.
- `docs/RELEASE.md`, `KNOWN_LIMITATIONS.md`, `ThirdPartyNotices.md`, `.ai/validation-cache.json`.
- `artifacts/qa/`의 실행 가능한 `.app`, ZIP, DMG, 버전/architecture/서명 상태/해시/실행법.
- 인증서가 없으면 unsigned local QA까지 끝내고 `BLOCKED_RELEASE_SIGNING`. 사용자가 인증서를 주어야만 가능한 단계만 남긴다.

최종 답변은 실제 완료 범위, QA 결과, 남은 blocker, 실행 앱/패키지/보고서 경로를 간결하게 제시한다. “이제 구현하면 됩니다”, “다음 Phase를 진행할까요?”로 끝내지 않는다.

## 7. 지금 시작하라

위 파일과 현재 프로젝트를 읽고 환경을 확인한 다음, 가장 첫 미완료 항목을 실제로 구현하라. 새로운 기능 아이디어로 scope를 늘리기보다 안전한 완성도와 출시 가능한 근거를 쌓아라.
