# Moongchi NameFix — macOS Project Master v1.0

작성: 2026-10-03 · 상태: macOS 신규 개발용 요구사항 기준선 · 구현/검증 상태: 아직 macOS 구현 및 실기 검증 전

## 0. 문서의 권한과 사용법

이 문서는 macOS 개발 AI가 Windows 저장소 없이 구현을 시작할 수 있도록 제품 기능, UI, UX, 테마, 파일 안전성, 개발 단계, QA, 배포를 통합한 **macOS 프로젝트의 제품 SSOT**다. [실행 프롬프트](Moongchi_NameFix_macOS_DevAI_StartPrompt_v1.0.md)는 실행 정책이며, [문구표](LOCALIZATION_CATALOG.md)는 번역 입력 자료다. 충돌 시 이 Master의 macOS 요구사항이 우선한다.

출처는 Windows `Moongchi_NameFix_Project_Master_v2.0_FINAL.md`, `Moongchi_NameFix_DevAI_StartPrompt_v2.0_FINAL.md`, 현재 구현, 이후 사용자의 명시적 UI 요구사항이다. v1.x/이전 REQUIREMENTS/MASTER_SPEC/START_PROMPT는 개발 기준으로 사용하지 않는다. 이 문서는 **Windows 프로젝트의 SSOT를 교체하지 않는다**. 별도 macOS 프로젝트에 적용한다.

계승하는 제품 결정: 파일명 NFC 복구, 안전한 미리보기/충돌 차단/Undo, 한국어·영어·일본어, 기본 다크, DiskSuite와 동일한 올리브 아카이브, 좌측 패널 구분, 중복 Drop Zone 제거, 간결한 문안, 즉시 적용 설정, 실시간 상태, 설치형/무설치형 제공.

이식 기준선으로 새로 정한 결정: Swift/SwiftUI/AppKit, macOS 14.0 이상, arm64+x86_64, APFS 중심 지원, Developer ID 직접 배포, ZIP+DMG 필수, Finder Services 연동. 실제 SDK/API 가용성은 Mac에서 검증한다. 지원 하한이 불가능하면 근거와 대안을 기록하고 조용히 올리지 않는다.

**문서 작성 완료 ≠ macOS Feature Complete ≠ AUTO-QA PASS ≠ 출시 승인.** Windows의 테스트 통과 수치와 패키지는 macOS 검증 증거로 재사용하지 않는다.

## 1. 제품 정의와 범위

**Moongchi NameFix는 파일과 폴더 이름의 Unicode 정규화 차이를 진단하고, 변경 전후를 확인한 다음 안전하게 NFC로 수정하고 되돌릴 수 있는 로컬 유틸리티다.** 한글 자소 분리는 대표 사례이며 엔진은 모든 Unicode 문자권을 다룬다.

브랜드: Moongchi / 제품: NameFix / 표시명: `Moongchi NameFix` / macOS 프로젝트 폴더 권장: `Moongchi_NameFix_macOS` / 앱: `Moongchi NameFix.app`. 개발용 bundle ID는 `com.moongchi.namefix`로 시작하되 배포 전 실제 팀 소유 식별자로 확정한다. 팀 ID·인증서·비밀번호는 저장소에 넣지 않는다.

핵심 사용 흐름:

```text
실행 → 파일/폴더 추가 → 자동 검사 → 안전한 수정 대상 자동 선택
→ 현재 이름/변경 후 이름 비교 → 수정 버튼 → 최종 확인
→ 실행/검증 → 결과/기록 → 필요하면 Undo 미리보기/확인/실행
```

필수 기능에는 기존 고도화에서 추가한 최근 폴더, 클립보드 Inspector, 자동 번호 충돌 해결, 진단 내보내기까지 포함한다. 범용 패턴/정규식 Renamer, 수동 임의 이름 편집기, 내용 인코딩 복구, 중복 삭제, 파일 변환, 계정/서버/AI, 원격 업로드, 자동 업데이트 엔진, 자동 NFKC/NFKD 변경은 범위 밖이다. NFD 출력 모드는 이번 기본 UI에 넣지 않는다. NFD/NFKC/NFKD는 Inspector 분석만 지원한다.

## 2. 비협상 안전 원칙

1. 사용자가 선택한 파일의 **내용을 읽어서 변환하거나 쓰지 않는다**. 정상 제품 경로에서는 내용 해시도 만들지 않는다. 자동 테스트의 fixture에서만 해시를 검증한다.
2. 사용자 파일/폴더를 삭제하거나 기존 대상을 덮어쓰지 않는다. 실패 처리, Undo, 복구도 동일하다.
3. 스캔, Preview, 설정 변경, 드롭, 클립보드 분석으로 실제 Rename이 발생하지 않는다.
4. 변경은 최신 Plan과 사용자 확인 후에만 수행한다. 확인한 Plan 이후 선택/경로가 바뀌면 다시 검증한다.
5. 자동 복구 형식은 NFC. 언어별 자모 조합 함수를 직접 만들지 않고 Foundation 표준 정규화를 쓴다.
6. 동시에 하나의 Rename/Undo/Recovery transaction만 허용한다. 앱 인스턴스 간 잠금도 필요하다.
7. 변경 전에 영속 Journal을 기록한다. 결과 저장 실패를 숨기고 다음 변경을 계속하지 않는다.
8. 성공은 실제 디렉터리 엔트리의 원시 이름과 파일 식별자를 확인한 결과다. 화면 문자열/경로 존재만 보고 성공 처리하지 않는다.
9. 링크를 따라 외부 경로로 내려가지 않는다. 파일 권한/TCC를 우회하거나 앱을 root로 실행하지 않는다.
10. 자동 검증은 전용 임시 디렉터리/디스크 이미지에서만 한다. 사용자 Desktop/Documents/실데이터로 fixture를 만들지 않는다.

## 3. macOS 기술 기준선

| 항목 | 결정 |
|---|---|
| 지원 OS | macOS 14.0 이상. 하한과 개발 시점 최신 안정 macOS를 각각 검증 |
| 언어 | Swift 6 language mode, strict concurrency. 필요한 Darwin 어댑터만 C interop |
| UI | SwiftUI + AppKit. NSWindow/NSOpenPanel/NSDraggingDestination, 필요하면 NSTableView |
| 엔진 | Foundation Unicode + Darwin 파일 시스템 어댑터. UI 의존 없는 Core |
| 테스트 | Swift Testing 또는 XCTest(Core), XCTest Integration, XCUITest(UI) |
| 빌드 | Xcode 프로젝트 + Core Swift Package. 실제 설치된 안정 Xcode/SDK/Swift 버전 고정 |
| CPU | Apple Silicon arm64, Intel x86_64. universal2 배포 목표. x86 32비트 제외 |
| 저장 | 로컬 JSON 설정, JSON 요약 + append-only JSONL transaction journal. DB 필수 아님 |
| 배포 | Developer ID 직접 배포. 기본 앱은 App Sandbox 비활성, Hardened Runtime 활성 |
| 통신 | 핵심 기능 네트워크 호출 0, 텔레메트리 0. 업데이트 확인도 이번 범위 밖 |

Windows .NET/WinUI/PInvoke 코드를 Mac용으로 그대로 빌드하지 않는다. 도메인 계약과 fixture를 옮기고 플랫폼 계층을 다시 구현한다. 패키지 의존성을 최소화하고 Package.resolved를 고정한다. 현재 최신 버전 번호를 추측해서 문서나 CI에 넣지 않는다.

### 3.1 권한과 외부 입력

- 파일과 폴더 다중 선택은 NSOpenPanel로 받는다. 여러 항목은 `.urls`를 사용한다. [Apple NSOpenPanel](https://developer.apple.com/documentation/appkit/nsopenpanel/allowsmultipleselection)
- Finder 드롭, Dock 아이콘 드롭, Open With/Services, 앱 실행 URL 전달은 하나의 입력 정규화 서비스로 합친다. 허용 입력은 실제 로컬/마운트된 파일 URL뿐이다. HTTP URL이나 문자열을 셸 명령으로 해석하지 않는다.
- 기본 직접 배포 앱도 TCC 보호 폴더 접근은 사용자의 허용을 따른다. 접근 거부는 해당 항목 오류로 표시하고 정상 항목 검사를 계속한다. 기본 실행 시 Full Disk Access를 일괄 요구하지 않는다.
- 향후 sandbox 배포를 위해 AccessLease 인터페이스를 둔다. security-scoped bookmark는 stale 처리와 성공한 start/stop 접근의 균형이 필요하다. 파일 하나를 선택했다고 부모 폴더의 임시/최종 이름 작업 권한까지 있다고 가정하지 않는다. 필요한 경우 부모 폴더 선택으로 권한을 얻는다. [Apple sandbox 파일 접근](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)
- Finder Services는 선택된 파일/폴더를 앱으로 전달하는 선택 가능한 OS 통합 기능이다. 설치가 Finder 확장 실행을 강제하지 않으며 실패해도 직접 드롭은 정상 동작해야 한다. FinderSync 확장은 이번 필수 구현이 아니다.

## 4. Unicode와 macOS 파일 시스템: 가장 먼저 검증할 계약

### 4.1 Swift 문자열의 함정

Swift `String` 비교는 canonical equivalence를 사용한다. `"é" == "e\u{301}"`이 참이므로 `original != nfc`로 수정 필요 여부를 판단하면 안 된다. 원시 이름 동일성은 `Data`/바이트 배열을 사용하고, 표시 문자열과 분리한다. `Set<String>`, `Dictionary<String, …>`, prefix 비교를 파일명 원시 식별에 그대로 사용하지 않는다. [Swift 문자열 비교](https://docs.swift.org/swift-book/LanguageGuide/StringsAndCharacters.html)

```swift
import Foundation

// Unicode 분석 예시다. 디스크 원시 이름 취득/유효성 검사는 별도 어댑터 책임이다.
func nfcPreview(_ input: String) -> (name: String, changed: Bool) {
    let normalized = (input as NSString).precomposedStringWithCanonicalMapping
    return (normalized, !input.utf8.elementsEqual(normalized.utf8))
}
```

구분할 값:

| 용도 | 비교/저장 방식 |
|---|---|
| 이름이 실제 바뀌는가 | 디스크 원시 UTF-8 bytes ↔ NFC UTF-8 bytes |
| 화면 검색 | 사용자가 기대하는 언어별 검색/대소문자 무시 허용 |
| 파일시스템 충돌 | 해당 볼륨의 lookup 규칙 + 실제 디렉터리 엔트리 확인 |
| 같은 작업 항목인가 | 불변 UUID + 부모 식별자 + 원시 leaf name + 파일 식별자 |
| 파일 내용이 같은가 | 제품에서는 판단 안 함. 테스트에서는 SHA-256 |

엔진은 NFC/NFD/NFKC/NFKD 결과와 원시 scalar/UTF-16을 제공한다. Mixed는 단일 Unicode 표준 형식명이 아니라 앱의 진단 분류다. 결정적으로 정의하고 테스트한다. 변경 여부는 항상 NFC 원시 비교가 결정한다. Invalid Unicode를 U+FFFD로 대체하여 그 이름의 다른 파일을 변경해서는 안 된다.

### 4.2 APFS

APFS는 생성 당시 이름의 normalization/case를 보존하면서, 현대 macOS에서 normalization-insensitive lookup을 한다. case-sensitive APFS도 normalization-sensitive라는 뜻은 아니다. 따라서 같은 부모 아래 NFC/NFD 동등 이름을 별도 파일로 만들 수 있다고 가정하면 안 된다. [Apple APFS FAQ](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/APFS_Guide/FAQ/FAQ.html)

필수 구현 결과:

- `destination exists`가 같은 source 엔트리를 가리킬 수 있다. 이것만으로 충돌로 차단하면 안 된다.
- 반대로 inode만 같다고 같은 엔트리라고 판단하면 hardlink 두 개를 합쳐 잘못 처리한다. 부모+raw name까지 확인한다.
- normalization만 바꾸는 Rename은 같은 디렉터리의 유일한 임시 이름을 경유하고 실제 저장된 이름을 재열거하여 확인한다.
- 최종 성공 조건은 **의도한 부모 안에 기대한 원시 이름의 엔트리가 있고, 기대한 파일 식별자와 일치하며, 임시 엔트리가 남지 않는 것**이다. `destExists && !sourceExists`는 APFS 성공 조건으로 사용하지 않는다.
- APFS 실제 collision 테스트와 엔진의 abstract normalization collision 테스트를 분리한다. APFS에 만들 수 없는 fixture를 억지로 만들고 테스트 통과라 쓰지 않는다.

### 4.3 HFS+, 기타 볼륨

HFS+는 고유한 decomposed 저장 규칙을 사용하며 현대 Unicode NFD와 완전히 동일하지 않다. NFC 원시 저장을 유지할 수 없는 볼륨은 “파일시스템에서 이름 형식을 유지할 수 없음”으로 안내한다. 동일 파일을 계속 수정 필요로 보여 주거나 성공으로 속이지 않는다. HFS+ 초기 정책은 분석 허용, 지원되지 않는 NFC 변경 차단이다. [Apple TN1150](https://developer.apple.com/library/archive/technotes/tn/tn1150.html)

APFS(local) 필수 지원, APFS case-sensitive 필수 QA, exFAT/SMB/NAS/외장/클라우드는 capability를 실측하여 지원 범위를 기록한다. 지원 불명 볼륨의 mutation은 fail closed. 볼륨 probe는 자동으로 사용자 폴더에 파일을 생성하는 행위가 아니며, 개발용 임시 fixture에서 수행하거나 승인된 실제 작업의 안전한 검증 결과로 판단한다.

Windows 금지 문자/CON/끝 마침표/MAX_PATH=260을 Mac 규칙으로 강제하지 않는다. macOS leaf의 NUL·`/` 금지, `.`/`..` 금지, 실제 볼륨 이름 길이/경로 한도, 읽기 전용 여부를 검사한다. Windows 호환성 안내는 별도 비차단 경고로만 둘 수 있다. raw UTF-8로 표현할 수 없는 이름은 원시 bytes를 보존하고 Unsupported/InvalidUnicode로 표시한다.

### 4.4 no-overwrite와 경합

POSIX `rename()`은 이미 있는 대상을 교체할 수 있으므로 단순 `exists` 검사 후 `rename()`은 금지한다. [Apple rename 매뉴얼](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/rename.2.html)

Darwin `renameatx_np`와 `RENAME_EXCL`을 사용하는 no-replace 어댑터를 우선 검증한다. 디렉터리 descriptor, `fstatat`/no-follow 확인, 파일 및 부모 identity를 결합한다. 대상 파일시스템에서 지원하지 않으면 무조건 overwrite 가능한 fallback을 쓰지 않는다. 최신 XNU 헤더의 추가 flag를 최소 지원 OS에서 가용성 검증 없이 쓰지 않는다. [Apple XNU 선언](https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/bsd/sys/stdio.h)

**잔여 위험:** directory FD와 변경 직전 identity 검사만으로 외부 프로세스가 leaf를 바꾸는 경쟁 조건이 원자적으로 사라지지 않는다. NSFileCoordinator도 비협조 프로세스를 완전히 잠그지 못한다. Phase 0/1에서 race fixture와 구현 보장을 검토하고 `docs/FILESYSTEM_CAPABILITIES.md`에 보장/제약을 기록한다. 지원할 환경에서 잘못된 대상 Rename을 방지할 계약을 입증하지 못하면 mutation 지원 범위를 좁히거나 출시 blocker로 기록한다. 불가능한 “예상 inode 조건부 원자 rename”을 구현했다고 주장하지 않는다.

copy+delete, cross-volume move, RENAME_SWAP, 덮어쓰기 rollback은 금지다.

## 5. 기능 요구사항 및 수용 기준

| ID | 기능 | 완료 조건 |
|---|---|---|
| MAC-F01 | 입력 | 여러 파일/폴더, 혼합 드롭, 파일·폴더 picker, Finder/Dock 전달을 동일 입력 경로로 처리 |
| MAC-F02 | 재귀 스캔 | 기본 true. false는 선택 폴더 자체+직접 자식까지, 하위 폴더 내부 미진입 |
| MAC-F03 | 대상 보호 | symlink/alias 미추적, 패키지/bundle 기본 제외, 마운트 경계 미횡단, 루트/시스템 보호 |
| MAC-F04 | Unicode | 모든 문자권 NFC Preview, 정상/수정 필요/Mixed/충돌/Invalid/접근 거부/Unavailable/Unsupported |
| MAC-F05 | 선택 | 안전한 수정 필요 항목 자동 선택, 개별/표시 항목/모두 안전 항목 선택, 숨은 선택 표시 |
| MAC-F06 | 검색 | 현재/제안 이름·경로 검색, 180ms debounce, 전체/수정 필요/정상/충돌/오류/선택 필터 |
| MAC-F07 | 정렬 | 이름/상태/경로 정렬, 안정적 tie-break, 검색/언어 변경으로 행 선택 소실 없음 |
| MAC-F08 | 충돌 | 기존 대상/Plan 내부/대소문자/정규화 규칙 충돌, 기본 제외, 덮어쓰기 없음 |
| MAC-F09 | 번호 제안 | `이름 (1).ext`부터 빈 번호, 폴더 전체 leaf 뒤 부착. 미리보기 후 선택/확인 때만 변경 |
| MAC-F10 | Plan/실행 | 하위→상위, 임시 이름, 직전 재검사, 취소 checkpoint, 결과 검증 |
| MAC-F11 | 기록 | 결과 요약/항목/실패 원인/미완료 journal/작업별 상세와 안전한 보존 |
| MAC-F12 | Undo | 최근/선택 기록 미리보기, 충돌 제외/부분 Undo, 재시도는 남은 항목만 |
| MAC-F13 | Recovery | 시작 시 미완료 검사, 안전한 복구/수동 확인, 모호하면 변경 없음 |
| MAC-F14 | Inspector | 현재/제안/전체 경로/이유/scalar/UTF-16/4가지 정규화 형식 |
| MAC-F15 | Clipboard | 명시적으로 붙여넣은 최대 4096 UTF-16 code units, 파일 변경 없는 분석 |
| MAC-F16 | 최근 폴더 | 기본 off, opt-in 최대 10개, off 전환 시 목록 삭제, 없는 경로 안내 |
| MAC-F17 | 진단 | 명시적 내보내기, 기본 경로 마스킹, 파일 내용 없음, 미리 확인 가능 |
| MAC-F18 | 설정 | 모든 설정 즉시 반영/자동 저장, 오류 안내, 재실행 보존 |
| MAC-F19 | UI | 다크 기본, Light/System/Olive, 전체 타이틀바 포함, ko/en/ja, 접근성 |
| MAC-F20 | 패키지 | arm64/x86_64 빌드, ZIP/DMG, 재현 가능한 서명/공증 스크립트, QA 가이드 |
| MAC-F21 | Finder 연동 | macOS Services에서 선택 경로를 검사 앱에 전달, 실제 Finder 검증 |

스캔은 읽기 전용이다. 중복 루트/겹치는 루트로 같은 directory entry를 중복 등록하지 않는다. 단, 서로 다른 hardlink directory entry는 유지한다. 입력 세트마다 generation ID를 사용해 이전 취소된 검사 결과가 새 화면에 늦게 끼어들지 않게 한다. 검사 중 새 입력은 기존 검사 취소 후 입력을 합쳐 재검사한다. Rename/Undo 중에는 드롭·새 입력을 거부하고 이유를 표시한다.

패키지(`.app`, `.photoslibrary` 등)는 자식 탐색과 패키지 자체 Rename을 기본 제외한다. 확장자만 보지 말고 URL resource metadata의 package 여부도 확인한다. 별도 명시적 고급 패키지 처리 기능은 이번 범위 밖이다. 심볼릭 링크와 Finder alias의 대상도 검사하지 않는다. 프로젝트 내부 `.git` 같은 metadata 디렉터리는 기본 제외하고 제외 이유를 확인 가능하게 한다.

번호 제안은 deterministic 순서, 확장자 유지, 볼륨 길이 재검사, 다른 제안 이름 예약을 수행한다. 변경된 입력/필터와 혼동하지 않게 제안 취소/재검사 시 NFC 기본 Preview로 돌아간다. 이름 안 원래 숫자 suffix를 임의 해석해서 제거하지 않는다. `.env`는 extension 없는 단일 이름으로, `archive.tar.gz`는 최종 `.gz` 앞에 번호를 붙이는 정책을 테스트한다.

## 6. 화면 구성

### 6.1 메인 화면

초기 크기 1180×780 pt 권장, 최소 900×640 pt. 작은 화면에서는 상세 pane을 sheet로 전환하거나 sidebar를 접는다. 글자를 지나치게 줄이지 않는다. macOS 표준 창 제어/전체 화면/창 드래그/키보드 메뉴 동작을 보존한다.

```text
┌── native traffic lights ──────────────────────────────────────────────┐
│                    파일 이름 검사       ↻  도움말  작업 기록  설정   │
│ [파일 추가][폴더 추가] ┌────────────────────────────────────────────┐ │
│ ☑ 하위 폴더 포함      │ 전체 항목    수정 가능    이름 충돌    선택됨 │ │
│ 최근 폴더(활성화 시)  └────────────────────────────────────────────┘ │
│ 추가한 위치 3 [비우기] [이름 또는 경로 검색] [필터] [정렬]           │
│ • 입력 위치 / 제거    [정상 항목 숨기기] 표시/전체 · 숨은 선택        │
│ • 입력 위치 / 제거    ┌────────────────────────────────────────────┐ │
│                      │ □ 유형 현재 이름 → 변경 후 이름     상태   │ │
│                      │ ...가상화된 목록...                         │ │
│                      │ 빈 상태: 파일·폴더를 여기에 놓으세요        │ │
│                      └────────────────────────────────────────────┘ │
│                      표시 항목 선택/해제 · 상세 · …    [N개 이름 수정]│
└─────────────────────────────────────────────────────────────────────┘
```

sidebar 232 pt(좁을 때 214), 바깥 여백 12, 영역 간격 16, sidebar 내부 16, 주요 모서리 반경 18, 일반 입력 8–10. 결과 surface border 1pt. 과한 그림자/투명도 대신 명확한 표면 대비를 쓴다.

좌측 상단의 큰 `Aa / MOONGCHI / NameFix` 브랜드 블록과 “항목 추가” 제목을 **복원하지 않는다**. 브랜딩은 앱 아이콘/About/OS 제목에서 충분하다. 안내 문구는 빈 상태 한 문장에 집중한다. “전체 항목”만 별도 박스를 갖지 않으며 4개 통계가 동일한 구조다.

중앙 제목은 **파일 이름 검사**다. “이름 미리보기”를 앱 전체 기능 이름으로 사용하지 않는다. Preview는 표의 현재 이름/변경 후 이름 비교라는 뜻이며 Inspector에도 실제 값을 보인다. 문자 모양이 같으면 “표시는 같지만 문자 구성이 다릅니다”를 상세에서 설명한다.

### 6.2 Drag & Drop: 반드시 실물로 검증

**드롭 안내는 중앙 빈 상태 한 곳만 표시하고, 실제 수신 범위는 전체 작업 창이다.** 좌측과 우측은 각각 입력 목록/검사 결과 역할이며 Drop 동작은 같다. 좌측에도 별도 큰 Drop Zone을 만들지 않는다.

- Finder의 file URL을 네이티브 destination으로 받는다. 혼합 파일/폴더, 한글·영문·일본어 경로를 보존한다.
- drag enter/exit/perform을 구분하고 올바른 file URL일 때만 copy 표시 및 highlight. 이것은 검사 목록에 추가한다는 뜻이며 파일 복사가 아니다.
- overlay는 hit testing을 막지 않는다. List/ScrollView/버튼/빈 공간이 이벤트를 가로채지 않는지 확인한다.
- 앱 busy/modal/Plan 준비 중이면 입력을 거부하고 드롭 후 잠깐 사라진 파일처럼 보이지 않게 상태를 알린다.
- unit에서 drop 함수를 직접 호출한 성공은 **실제 Finder 드롭 PASS가 아니다**. 좌측/중앙/목록 행/스크롤 영역을 대상으로 실제 마우스 드래그를 검증한다. 못하면 NEEDS_MANUAL_QA다.

### 6.3 표, 선택, Inspector

표는 checkbox/type/current/new/status. 전체 경로는 tooltip과 Inspector에서 제공하며 필요하면 경로 column을 켠다. 현재/변경 이름 폭 비율 50:50 기본, 25:75~75:25 조절/저장. 이름은 단일 행 truncation과 전체 tooltip을 병행한다. 긴 경로가 창 전체 폭을 확장하지 않는다.

안전한 NeedsNormalization만 기본 선택. Conflict/Unsupported/권한 오류는 비활성 선택이며 원인을 표시한다. 정상 항목 표시/검색/정렬 변경은 선택 상태를 보존한다. “표시 항목 선택”은 보이는 안전 항목만 대상으로 한다. 전체 안전 항목 선택/해제/표시 선택 반전은 More 메뉴로 제공한다. 숨은 선택 수를 표시하고 최종 확인에 포함한다.

Inspector는 기본 닫힘, 너비 약 390pt. 이름/제안 이름/전체 경로/상태 이유/경로 복사와 고급 Unicode foldout을 제공한다. scalar는 U+XXXXX, UTF-16은 code unit로 명시해 혼동하지 않는다. grapheme/UTF-16 길이/scalar 길이를 구분한다. 이모지 ZWJ/variation selector를 제거하지 않는다.

클립보드는 버튼/붙여넣기 시에만 읽고 자동 감시하지 않는다. 길이 제한은 surrogate나 grapheme를 잘라 깨뜨리지 않게 적용하고 잘림을 알린다. 파일 경로로 오인하여 자동 Rename하지 않는다.

### 6.4 확인, 진행, 결과, 기록

주 버튼: `N개 이름 수정`. 실행 가능 선택 0/busy/modal/입력 준비 중에는 비활성. 확인 sheet는 실행 수, 충돌/제외 수, 숨은 선택, 변경 형식 NFC, 내용 미변경, 동기화 전파 가능성을 간결히 표시한다. 기본/안전 버튼은 취소. 확인 후 Plan 재검사에서 달라진 항목은 건너뛰거나 다시 확인한다.

스캔은 전체 수를 모르면 indeterminate + 발견 수. Rename/Undo는 처리/전체 및 실제 퍼센트, 경과시간, 현재 항목, 취소 버튼. 100ms 안팎으로 UI 알림을 합치며 첫 활동 표시는 500ms 이내 목표. 막연한 가짜 90%/100%는 금지. 취소 요청 이후 안전한 checkpoint까지 “취소 중”으로 표시한다.

결과는 성공/건너뜀/오류, 오류 상세, 기록 보기, 되돌리기, 닫기. Undo 가능 항목 수는 검증된 성공 기록에 근거한다. 실패를 toast 하나로 숨기지 않는다. 완료 후 재검사 및 `ClearSelectionAfterRun`을 적용한다.

기록 창은 최근 작업 요약을 먼저 읽고 선택한 작업의 상세를 lazy-load한다. 항목 수가 많다고 모든 journal을 시작 시 메모리에 읽지 않는다. Undo Preview는 현재 경로/복원 경로/충돌/복원 가능 수를 보여 주며 별도 확인을 요구한다.

### 6.5 설정, 도움말, About, 메뉴

설정은 별도 창 또는 sheet에 일반/표시/기록·개인정보를 배치한다. **저장 버튼 없음**. 변경 즉시 적용하고 직렬화된 저장 큐로 원자적 저장한다. 저장 실패는 “현재 실행에만 적용됨” 등으로 표시하고 조용히 성공 처리하지 않는다. 닫기/종료 시 pending write를 처리한다. 테마 변경이 검사 결과/선택을 초기화하면 안 된다.

도움말은 파일 내용 미변경, NFC, 충돌, Undo, 지원 파일시스템, 단축키를 설명한다. About에는 표시명/버전/빌드/라이선스/폰트 고지를 제공한다. 아직 정해지지 않은 판매 정책/개발사 URL을 만들어 넣지 않는다.

| 단축키 | 동작 |
|---|---|
| ⌘O / ⇧⌘O | 파일 추가 / 폴더 추가 |
| ⌘F / ⌘R | 검색 초점 / 재검사 |
| ⌘, | 설정 |
| ⌘A | 결과 목록에 초점이면 표시 항목 선택. 텍스트 필드에서는 텍스트 전체 선택 |
| ⌘Z | 텍스트 편집에서는 native Undo. 결과 맥락의 파일 Undo는 미리보기/확인을 거침 |
| Esc | 현재 sheet/pane/drag 상태 닫기 또는 취소 요청. 즉시 강제 종료 아님 |
| ⌘Q | 작업 중이면 안전한 중단/완료 경계를 거쳐 종료 |

메뉴 바에 앱/About/설정/종료, 파일/추가, 편집/텍스트 표준 명령, 보기/Inspector·기록, 도움말을 둔다. 창 닫기와 앱 종료를 구분하고 마지막 창을 닫아도 진행 중 transaction을 버리지 않는다. reopen으로 기존 상태를 복원한다.

## 7. 테마: 정확한 색상과 적용 범위

**최초 기본은 Dark. OS가 Light여도 Dark로 시작한다.** 이후 사용자가 저장한 dark/olive/light/system을 존중한다. System만 OS appearance를 따른다. Olive Archive는 “초록 다크 테마”가 아니라 **종이빛 배경 + 약간 진한 sidebar + 짙은 올리브 hero**다.

아래 불투명 값은 sRGB `#RRGGBB`. alpha는 다음 표의 별도 값으로 적용한다. Windows `#AARRGGBB`를 CSS/Swift의 `#RRGGBBAA`로 잘못 해석하지 않는다.

| Token | Dark | Light | Olive Archive |
|---|---|---|---|
| canvas | #101820 | #F3F5F8 | #EAE5D6 |
| sidebar | #141F29 | #E9EEF3 | **#DDD8C5** |
| surface | #19232D | #FFFFFF | #F7F3E8 |
| line/border | #30414F | #DAE2E9 | #CEC7B2 |
| brand/accent | #66D5CD | #087F8C | #4C602E |
| onBrand | #102A2D | #FFFFFF | #FFF9EB |
| brandSoft | #183B40 | #E3F3F2 | #EDE8DA |
| preview | #8AE5DC | #066775 | #4C602E |
| warning | #F0C273 | #925B0A | #97502E |
| heroStart | #173F46 | #E2F5F4 | #39452D |
| heroEnd | #292B49 | #F0EEFF | #555C3B |
| text | #FFFFFF | black α228/255 | #30372B |
| secondary | white α197/255 | black α158/255 | #636750 |
| muted | white α197/255 | black α153/255 | #636750 |
| control | white α15/255 | white α179/255 | #EFEADA |
| controlHover | white α21/255 | white α249/255 | #DED8C3 |
| controlPressed | white α8/255 | white α77/255 | #DED8C3 |
| dialog | #202020 | #F3F3F3 | #F7F3E8 |
| overlay/cardSecondary | #2B2B2B | #FFFFFF | #F7F3E8 |
| accentHover | #8AE5DC | #096D79 | #4C602E α225/255 |
| heroText | #FFFFFF | black α228/255 | #FBF5E5 |
| heroCaption | white α197/255 | black α158/255 | #E0DFC7 |
| heroPreview | #8AE5DC | #066775 | #D6E3AB |
| heroWarning | #F0C273 | #925B0A | #F5C8A0 |

`sidebar #DDD8C5`는 사용자에게 요청받은 종이 배경과의 구분이다. canvas와 같게 되돌리지 않는다. hero gradient는 통계 strip 하나에 한정한다. 모든 통계를 제각기 별도 박스로 둘러싸지 않는다.

적용 범위: 메인 배경, sidebar, 표/선택/hover/focus, scrollbar 주변, 검색/ComboBox, 버튼, 툴팁, popover, sheet, Inspector, 기록/설정 창, 빈 상태, 진행률, toast, native titlebar. 창 타이틀바가 Light로 남는 회귀를 필수 테스트한다. macOS native appearance는 Dark→darkAqua, Light/Olive→aqua, System→effective appearance로 매핑하고 표면 토큰을 별도로 적용한다. traffic lights를 직접 재구현하지 않는다. 비활성 titlebar 텍스트도 대비를 유지한다.

추가 error/success/focus 색은 native semantic color를 기반으로 각 theme 대비를 검증해 보완한다. 원본 팔레트에 없는 색을 “DiskSuite 원본”이라고 표시하지 않는다. Increase Contrast/Reduce Transparency에서는 system semantic 고대비를 우선하며 색상 외 아이콘/문구를 항상 제공한다.

## 8. 폰트, 모션, 접근성

번들 폰트: [assets/fonts](assets/fonts)에 있는 Pretendard Variable(ko/en), Pretendard JP Variable(ja), 각각 OFL 라이선스. 앱 프로세스 범위로 CoreText 등록하고 전체 OS에 설치하지 않는다. 실제 PostScript/family name은 등록 후 조회하여 사용한다. 일본어 UI는 JP를 우선하되 파일명 혼합문자는 시스템 CJK/emoji cascade로 자연스럽게 fallback한다. 코드 정보는 SF Mono 등 native monospaced fallback을 쓴다.

| 요소 | 기준 크기/굵기 |
|---|---|
| 작업 제목 | 20pt Semibold |
| 기본 본문/표/버튼 | 13pt Regular/Medium |
| 보조 라벨 | 11–12pt, 저대비로 읽기 어렵게 만들지 않음 |
| 통계 숫자 | 22pt Semibold, tabular digits |
| Inspector 코드 | 12pt monospaced |

크기는 기본값이며 접근성 큰 글씨/사용자 글꼴 변경을 수용한다. 한국어·일본어 장문 번역과 결합문자/emoji baseline을 검증한다. bitmap으로 글자를 그리지 않는다.

모션: hover/focus 100–150ms, pane/empty→results 220–240ms opacity+최대 12pt 이동, ease-out. 진행률은 실제 상태 사이를 짧게 보간한다. success toast 약 7초와 수동 닫기, 오류/복구 경고는 확인 전 유지. 중요 결과는 기록에 남겨 toast가 사라져도 확인 가능하게 한다. 무한 shimmer/과한 bounce/작업을 지연하는 연출은 금지한다.

Reduce Motion은 이동 효과를 끄고 상태 문구는 유지한다. 키보드-only, VoiceOver, Full Keyboard Access, Retina 1x/2x, 대비/투명도 옵션, 긴 번역, 큰 글자에서 테스트한다. 보통 텍스트 4.5:1, 큰 텍스트/핵심 컨트롤 3:1을 프로젝트 대비 목표로 삼고 실제 배경과 합성한 색으로 측정한다. 상태는 `✓ 정상 / ● 수정 필요 / ⚠ 충돌 / × 오류`처럼 텍스트와 심볼을 병행한다.

## 9. 설정과 로컬 데이터

FileManager의 Application Support/Logs 디렉터리 API를 사용한다. 직접 배포 기준 `~/Library/Application Support/Moongchi/NameFix/`, 로그 `~/Library/Logs/Moongchi/NameFix/`. 샌드박스 버전은 container 경로를 따른다. `.app`, DMG, `/Applications` 아래에 설정/기록을 쓰지 않는다. ZIP 버전도 사용자 Library를 사용하며 이동식 앱 옆 data 폴더 모드는 필수가 아니다.

```json
{
  "schemaVersion": 1,
  "platform": "macOS",
  "language": "system",
  "theme": "dark",
  "recursive": true,
  "hideNormal": false,
  "clearSelectionAfterRun": true,
  "historyLimit": 100,
  "diagnostics": true,
  "rememberRecentFolders": false,
  "recentFolders": [],
  "compactRows": false,
  "nameColumnRatio": 50
}
```

언어 값 system/ko-KR/en-US/ja-JP, theme dark/olive/light/system. 언어 system은 선호 언어 목록의 첫 지원 언어, 없으면 en-US. HistoryLimit은 1..1000, RecentFolders는 최대10, nameColumnRatio는 유한한 25..75. 손상/NaN/잘못된 enum은 검증한다. schema가 더 최신이면 원본을 덮어쓰지 않는 안전 읽기 모드와 안내를 사용한다. Windows 기록을 자동으로 Mac 경로로 변환하거나 실행하지 않는다.

JSON은 앱 소유 임시 파일에 쓰고 flush→atomic replace로 저장한다. 설정 쓰기 순서가 역전되어 옛 값으로 돌아가지 않게 단일 writer를 쓴다. 손상 설정 원본은 별도 보존하고 안전 기본값으로 복구한다. 손상 기록 하나 때문에 전체 앱이 시작 실패하지 않게 한다.

기록 보존 기본 최근 100개는 **완료되고 보존 의존성이 해소된 기록에만** 적용한다. 미완료/복구 대기/다른 Undo 경로 해석에 필요한 기록은 삭제하지 않는다. 일반 로그와 복구 Journal을 구분한다. 로그 rotation 기준은 구현 시 명시(권장 10MiB×3 및 30일), journal은 용량 이유만으로 임의 삭제하지 않는다.

진단 로그는 버전/OS/CPU/오류 코드/transaction ID/집계 위주다. 절대 경로는 기본 마스킹하고 오류 stack에도 경로가 섞이지 않게 한다. 진단 export에는 설정·상태·마스킹된 기록 요약을 넣으며 raw journal 전체를 기본 포함하지 않는다. 전체 경로 포함은 사용자가 명시 선택할 때만 허용한다. 파일 내용/clipboard text는 로그에 남기지 않는다.

## 10. 아키텍처와 데이터 계약

```text
Moongchi_NameFix_macOS/
  MoongchiNameFix.xcodeproj
  App/                         SwiftUI/AppKit shell, menu, lifecycle
  Packages/NameFixCore/
    Sources/NameFixCore/        Unicode, model, planner, path map
    Tests/NameFixCoreTests/
  Application/                 scan/plan/execute/undo orchestration
  Infrastructure/              Darwin FS, volume capabilities, journals
  Resources/                   xcstrings, assets, fonts, licenses
  Tests/IntegrationTests/
  Tests/UITests/
  eng/                         build, tests, fixtures, package, sign
  docs/                        state, architecture, QA, release
  .ai/validation-cache.json
  artifacts/qa/
```

책임 분리: View는 상태 표시, Application은 사용 흐름, Core는 순수 분석과 계획, Infrastructure는 OS 경계를 담당한다. View에서 직접 파일 Rename API를 호출하지 않는다.

| 型/サービス | 必須データ/責務 |
|---|---|
| FileEntry | stableID, raw parent/leaf bytes, display URL, volume/parent/file identity, type, depth, link/package flags |
| NormalizationAnalysis | raw original, NFC preview, changed, status, reason, 필요할 때 scalar/UTF16 정보 계산 |
| RenamePlan | planID, generation, createdAt, NFC, ordered operations, conflicts, executable count, capability snapshot |
| RenameOperation | operationID, entryID, source/temp/dest raw name, parent identity, expected identity, state, error |
| FileSystemGateway | 원시 엔트리 열거, lstat 계열 metadata, 볼륨 규칙, renameNoReplace, raw entry 검증 |
| AccessLease | 명시적 권한의 수명, bookmark resolve/stale, scope release |
| JournalStore | durable append, sequence/checksum, summary, replay, 불완전한 끝부분 원본 보존 |
| TransactionCoordinator | actor serial mutation + OS process lock, 안전한 취소, lifecycle |
| HistoryPathMap | 중첩 Rename과 이후 transaction의 현재 경로 추적, 부분 Undo 추적 |
| DiagnosticsExporter | 개인정보 보호 로그, 마스킹, 명시적 내보내기 |

제품 문자열은 별도 ko/en/ja 리소스를 사용한다. 구현 코드는 일관된 영어 식별자를 쓴다.

raw bytes는 JSON에서 base64로 보존하고 displayPath는 참고용으로만 사용한다. URL 표준화 과정에서 원래 spelling이 없어지지 않게 한다. 파일 identity는 플랫폼 API와 볼륨 특성을 검증하고 단순 inode 값만 장기적으로 신뢰하지 않는다. 재마운트/볼륨 교체/재사용된 inode가 의심되면 Unavailable 또는 ChangedSinceScan으로 재검사한다.

### 10.1 Journal/실행 순서

```text
Plan + 확인 → 실행 직전 재검증 → durable Prepared
→ source→temp no-replace → TemporaryRenamed 기록
→ temp→final no-replace → FinalRenamed 기록
→ raw directory entry + identity 검증 → Verified 기록
→ transaction 요약/화면 반영
```

Crash는 move와 다음 journal 사이에도 발생한다. 각각의 move 전에 intent가 영속화되어 있어야 하며 replay는 journal 마지막 state만 믿지 않고 source/temp/dest 실제 상태와 비교한다. `Prepared / TemporaryRenamed / FinalRenamed / Verified / RollbackStarted / RolledBack / Failed`와 transaction 완료/중단 상태를 저장한다.

sequence/checksum으로 torn tail을 구분하고 손상 원본을 보존한다. durability 전략(`fsync`, 필요 시 macOS full sync 정책)과 성능을 함께 검증한다. flush 실패는 안전 중단이다. append마다 전체 100,000항목 JSON을 재작성하지 않는다. manifest와 요약 compaction은 원자적으로 하고 미완료 복구 자료를 버리지 않는다.

하위 파일/폴더부터 부모로 처리하며 선택 루트 자신도 수정 대상일 수 있다. 중첩 root의 current path는 가장 깊은 매칭 source를 한 번 적용하고 연속 replace로 경로를 두 번 바꾸지 않는다. 부모 Rename이 성공하면 바뀌지 않은 자식 입력 루트/최근 경로/화면 current path도 업데이트한다.

작업 하나의 충돌/권한 오류는 격리할 수 있지만 identity/Journal/Plan 일관성이 깨지면 전체를 안전 중단한다. UI에서 cancel은 다음 안전 경계까지만 진행한다. 강제 종료를 정상 cancel로 처리하지 않는다.

### 10.2 Undo와 복구

Undo는 성공 작업의 역 Plan을 현재 파일시스템에서 새로 만든다. 부모를 되돌리는 순서와 자식의 현재 경로 추적을 검사한다. 이후 작업에서 이름/부모가 바뀐 경우 HistoryPathMap으로 현재 위치를 추적하되 identity 불일치 시 실행하지 않는다.

hardlink를 가진 두 경로 중 하나만 Undo한 경우 다른 경로까지 완료로 표시하지 않는다. **완료한 tracked path + expected identity** 둘 다 일치해야 해당 작업을 완료로 기록한다. 부분 Undo 뒤 충돌을 해결하고 재시도하면 남은 항목만 복원한다.

복구 시 임시 이름을 무조건 삭제하지 않는다. 그것이 사용자의 원본 파일일 수 있다. 세 위치의 상태가 안전하고 유일하게 해석되는 경우만 rollback/완료를 제안한다. 모호한 경우 `상태 확인 필요`와 경로/기록 보존을 제공한다. 재시작만으로 사용자 확인 없는 광범위 Rename을 실행하지 않는다.

## 11. 성능과 응답성

- scanner는 background 작업/AsyncSequence, UI는 MainActor. 동기 FileManager 순회를 Task라는 이름으로 MainActor 안에서 실행하지 않는다.
- 디렉터리 열거 concurrency는 제한하고 mutation은 순서 보장한다. 네트워크 요청 무제한 병렬화 금지.
- 행은 virtualization. 100,000개 NSView/SwiftUI subtree를 동시에 만들지 않는다. 전체 scalar Inspector는 선택 시 계산한다.
- UI batch 업데이트/검색 취소/세대 ID 사용. 모든 입력마다 전체 collection을 MainActor에서 여러 번 재정렬하지 않는다.
- 충돌 검사는 부모별 snapshot/index 재사용으로 O(n²) 재열거를 피한다. 실행 직전 재검증은 생략하지 않는다.
- history summary 먼저 로드, 세부 journal streaming. 여러 대형 history를 한꺼번에 decode하지 않는다.
- 성능 fixture: 1/100/10,000/100,000항목. 100,000은 Full QA 전용 profile 허용. 지연/CPU/메모리 peak/cancel latency/장비·볼륨을 기록한다.
- 현재 제품과 동일하게 한 검사 세션은 200,000항목 안전 한도를 둔다. 도달하면 발견된 항목을 유지하고 폴더를 나누어 검사하도록 안내한다. 누락된 나머지까지 모두 검사했다고 표시하지 않는다. 총 메모리를 이 개수 제한만으로 관리하지 말고 스트리밍/가상화도 구현한다.
- 목표: 로컬 작업 시작 표시 500ms 이내, 일반 UI 조작 지연 100ms 내 목표, 로컬 취소 요청 피드백 200ms 내 목표. 전체 I/O 완료시간은 장비/볼륨에 따라 실측한다. SMB 커널 호출이 즉시 취소된다고 보장하지 않는다.
- sleep/resume/볼륨 제거 후 stale Plan을 재검증한다. 외부 I/O 지연을 UI freeze나 무한 retry로 바꾸지 않는다.

## 12. 다국어와 문구

전체 [LOCALIZATION_CATALOG.md](LOCALIZATION_CATALOG.md)의 기존 157개 키를 출발점으로 삼고 macOS override와 추가 오류 문구를 적용한다. 모든 사용자 표시 문구는 `.xcstrings`로 분리한다. `.NET {0:N0}`를 Swift에서 그대로 format하지 않는다. typed interpolation/복수형/숫자 locale로 변환하고 세 언어 placeholder parity를 검사한다.

핵심 한국어 문구: 제목 `파일 이름 검사`, 빈 상태 `파일·폴더를 여기에 놓으세요`, 보조 `파일 내용은 그대로, 이름만 수정합니다.`, 작업 `N개 이름 수정`, `작업 기록`, `되돌리기`, `설정`. 불필요한 설명을 모든 패널에 반복하지 않는다.

Windows 단축키/Explorer/레지스트리/reparse/MAX_PATH/WinUI 용어는 Mac 문구로 바꾼다. 기본 화면에 inode/UTF-8/Journal/API를 노출하지 않는다. 개발용 상세에만 기술 오류 코드를 제공한다. OS 언어 자동 선택과 파일명 처리 문자권은 독립이다.

## 13. 개발 단계 및 검증 정책

Phase는 내부 Gate이며 사용자 중간 승인 지점이 아니다. Scope 전체를 구현한 뒤 Full QA로 진행한다.

| 단계 | 실제 작업 | Gate 증거 |
|---|---|---|
| 0 Foundation/FS spike | Mac 도구 확인, repo/app shell, 언어/테마/설정, raw Unicode/APFS/no-replace proof, lifecycle | 시작 빌드 + native fixture + FILESYSTEM_CAPABILITIES 초안 |
| 1 Core & Safety | Unicode/validator/scanner/planner/conflict/path identity/link 규칙, journal 최소 계약 | Core tests + APFS 원시 이름 검증 + race/overwrite 계약 |
| 2 End-to-end | 실제 Finder drop/picker/표/선택/확인/실행/검증/cancel, mutation 이전 durable journal | 최소 fixture scan→rename + hash 불변 + 실제 drop 증거 또는 수동 대기 |
| 3 History/Undo/Recovery | 기록 UI, durable replay, 부분Undo, crash/error/settings 손상 | nested/hardlink/중단 복구 fixture |
| 4 Product polish | Inspector/clipboard/번호/최근/진단/Finder Services, ko/en/ja, 테마 전체, 접근성, 100k UI | 기능 parity/리소스/성능/키보드 Gate |
| 5 Packaging | 두 CPU Release, ZIP/DMG, 버전/라이선스, signing/notary hooks, 실행 안내 | unsigned QA package라도 실제 실행 가능 |
| Feature Complete | 모든 필수 구현과 Phase Gate, 핵심 TODO/stub 0 | FEATURE_COMPLETE_GATE.md |
| Level 3 | 전체 자동 QA → 수정 가능 FAIL 수정 → 관련 regression | AUTO-QA PASS + 보고서 + manual 체크리스트 + QA package |

Level 1: 변경 target build + 직접 관련 unit/fixture/integration만. 매 task clean/all-arch/full-suite 반복 금지.

Level 2: Phase 종료 app build + 해당 phase tests + 영향 integration. architecture/패키징 변경이 있을 때 필요한 CPU build.

Level 3: Feature Complete 이후 clean build, 두 architecture, 전체 unit/integration/UI 가능한 부분, Unicode/Rename/Undo/Recovery/content hash, localization/accessibility 자동화, dependency/license/schema/static analysis, ZIP/DMG/startup/설치제거 가능한 smoke.

### 13.1 Validation Cache

`.ai/validation-cache.json`은 validationId/scope/status/architecture/configuration/command/sourceFingerprint/testFingerprint/dependencyFingerprint/toolchainFingerprint/timestamp를 포함한다. macOS 추가로 OS/SDK/파일시스템/case mode/서명 상태/fixture 버전을 기록한다. dirty tree의 실제 파일 SHA-256로 무효화하며 commit hash만 쓰지 않는다. 테스트 코드/공개계약/도구/의존성/FS 환경이 바뀌면 해당 검증 무효화. 실패→원인 수정→실패 테스트→관련 regression. 재시도로 flaky를 숨기지 않는다.

## 14. 필수 QA 매트릭스

| QA ID | 검증 | 증거/기대 |
|---|---|---|
| U01 | 한글/라틴/가나/베트남어/그리스어 NFC·NFD·Mixed | raw scalar/bytes와 기대 NFC 일치 |
| U02 | ASCII/CJK/emoji/surrogate/ZWJ/VS/빈 모델/invalid raw bytes | 손상/불필요 변환 없음, 오류 격리 |
| U03 | Swift canonical equality trap | `String ==`로 같아도 raw differs이면 Preview 대상 |
| F01 | APFS normal/case-sensitive | 저장 raw 이름 보존 확인, lookup 동등성과 성공 판정 분리 |
| F02 | HFS+/exFAT/SMB | capability별 허용/차단, 미검증은 PASS 아님 |
| F03 | 이미 있는 대상/임시 이름/내부충돌/번호제안 | overwrite 0, 확인 전 변경 0 |
| F04 | nested 5단계, parent+child root 중복 | 하위→상위, current roots 정상, 이중 remap 없음 |
| F05 | hardlink 2개 partial Undo/재시도 | 한 경로 성공으로 다른 경로 완료 처리 금지 |
| F06 | symlink/alias/linked ancestor/package/mount | 외부 경로 방문/수정 없음 |
| F07 | source 교체/destination 경합/권한/읽기전용 | identity 재확인, no-replace, 안전 중단 |
| F08 | 긴 이름/경로/외장 제거/네트워크 단절 | 오류 분류, UI 응답, retry 폭주 없음 |
| S01 | rename→undo fixture SHA-256 | 내용 1byte 차이도 P0 |
| S02 | xattrs/resource fork/ACL/Finder tags/hardlinks | 이름 외 메타데이터/연결 보존(검사 가능한 범위) |
| J01 | 모든 intent/move/flush checkpoint crash | 증거 보존, 다른 파일 복원/삭제/덮어쓰기 없음 |
| J02 | torn/corrupt/new schema/history retention | graceful fallback, 원본/복구 의존 기록 보존 |
| J03 | 두 인스턴스/종료/cancel/sleep | mutation 중복 없음, safe boundary |
| UI01 | 실제 Finder drag 좌/우/목록/스크롤/Dock | 파일·폴더·혼합 입력, 하나의 동일 동작 |
| UI02 | 4 themes + OS 변경 + 재시작 | 기본 Dark, Olive sidebar 차이, titlebar/sheet/popup 모두 일치 |
| UI03 | 즉시 설정/저장 실패/빠른 연속 변경 | 마지막 값 보존, 선택/목록 유지, 저장 버튼 없음 |
| UI04 | 검색/필터/숨은 선택/번호/확인 | 화면 수치와 실제 Plan 대상 일치 |
| UI05 | ko/en/ja/VoiceOver/키보드/큰글자 | 누락키/잘림/초점 손실/색상만 상태 없음 |
| P01 | 10k/100k scan/list/history | UI latency·peak memory 실측, O(n²)/무제한 누적 없음 |
| PK01 | arm64/x86_64/universal2 ZIP/DMG | 실제 slice 확인, 두 플랫폼 실행 구분 |
| PK02 | 깨끗한 Mac 서명/공증/설치/제거 | Gatekeeper 정상, 사용자 파일/기록 무단 삭제 없음 |

Unicode fixture는 escape된 scalar와 bytes 기대값으로 생성한다. 편집기의 자동 정규화나 가짜 dotted circle이 들어간 예시를 원본 데이터로 쓰지 않는다. 예: Latin `e\u{0301}.txt`, Japanese `\u{304B}\u{3099}.txt`, Korean `\u{1112}\u{1161}\u{11AB}.txt`. APFS에 NFC 동등 파일을 동시에 생성하지 않는다. 내용/메타데이터 비교는 entry identity별 manifest로 추적한다.

Manual checklist 각 항목: ID/기능/목적/환경/사전조건/절차/기대/로그/결과(PASS, FAIL, NOT_AVAILABLE). Apple Silicon native와 Intel native, Rosetta 실행은 다른 증거로 기록한다. 빌드한 것만으로 그 CPU에서 실행 PASS라 쓰지 않는다. iCloud/Dropbox/OneDrive/FileProvider placeholder·동기화는 실제 계정/기기 사용 가능할 때 별도 검증하며 자동 fixture가 다운로드를 유발하지 않게 한다.

## 15. 빌드, 설치형/무설치형, 출시

개발 AI는 실제로 실행되는 다음 스크립트를 구현한다. 아래 이름은 **만들어야 할 인터페이스**이며 이 문서 패키지에 구현된 Mac 빌드 스크립트가 있다는 뜻이 아니다.

```text
eng/doctor.sh                   도구/SDK/OS/arch 환경 증거
eng/build.sh --configuration Debug|Release --arch arm64|x86_64|universal
eng/test.sh --level 1|2|3 --scope <scope>
eng/create-fixtures.sh --root <explicit-temp-root>
eng/package.sh --unsigned       QA ZIP + DMG
eng/sign-notarize.sh            실제 identity/profile 기반 서명/공증
eng/verify-release.sh           서명/공증/slices/manifest/실행 점검
```

스크립트는 경로 공백/한글을 안전하게 인용하고 실패 시 nonzero exit. fixture cleanup은 resolved 경로가 전용 임시 root 아래임을 확인한 후에만 수행한다. Mac을 자동 재부팅하거나 실데이터 폴더를 정리하지 않는다.

무설치형: `Moongchi_NameFix_<version>_macOS_universal.zip` 안 `.app`, README, ThirdPartyNotices. 설치형 사용자 경험: `Moongchi_NameFix_<version>_macOS_universal.dmg`에서 Applications로 드래그. DMG는 설치 마법사가 아니라 Mac의 일반적인 앱 복사 배포 방식이다. 사용자 Library에 데이터 저장하므로 read-only DMG에서 실행해도 앱 bundle에 쓰기를 시도하지 않는다. Applications 복사는 권장하되 동의 없이 자동 이동하지 않는다.

`.pkg`는 기업 배포가 필요할 때 추가 가능한 선택 산출물이다. 요구되지 않은 관리자 helper/LaunchDaemon을 설치하지 않는다. 구현하면 app 서명(Developer ID Application)과 pkg 서명(Developer ID Installer)을 분리하고 설치/업그레이드/제거 검증을 추가한다. 필수 ZIP/DMG 완료를 선택 PKG 때문에 지연하지 않는다.

배포 .app에는 Info.plist 버전/최소OS/고해상도/AppIcon/localization/Services, 필요한 privacy usage description, 정식 라이선스 고지를 포함한다. 아이콘은 macOS AppIcon asset으로 필요한 크기를 채우며 Windows ICO를 그대로 AppIcon으로 간주하지 않는다. 화면 안 중복 브랜드 블록을 다시 추가할 이유는 아니다.

외부 배포는 Developer ID 서명+Hardened Runtime+secure timestamp, release의 get-task-allow 제거, `notarytool` 제출/성공 확인, `stapler`로 app/DMG에 staple. ZIP 자체에는 staple하지 않고 stapled app을 ZIP으로 만든다. 정확한 CLI 인자는 구현 Mac의 도구 도움말로 확인한다. 비밀은 Keychain/profile/CI secret으로 전달한다. Gatekeeper/SIP/검역 속성 해제를 일반 사용자 실행법으로 제공하지 않는다. [Apple 공증](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [공증 워크플로](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)

검증: `codesign --verify --deep --strict --verbose=2`, `spctl --assess --type execute`, `xcrun stapler validate`, `lipo -archs`, 실제 패키지 SHA-256, 다른 깨끗한 Mac에서 다운로드/실행. 서명 시 `--deep`으로 무분별한 재서명을 하지 말고 중첩 코드부터 정확히 서명한다. 설치/업데이트 전에 실행 중인 이전 버전과 transaction 잠금을 고려한다. 앱 제거는 사용자 입력 파일을 건드리지 않으며 Library 기록 삭제는 별도 명시 동작 없이는 하지 않는다.

인증서가 없으면 unsigned QA 앱/ZIP/DMG까지 만들고 `BLOCKED_RELEASE_SIGNING`을 기록한다. 로컬 QA 가능과 일반 사용자에게 배포 가능한 상태를 구분한다. 판매/무료/구독 정책은 미정이며 활성화 서버를 임의 추가하지 않는다.

## 16. 완료 산출물과 출시 판정

필수 문서: `README.md`, `docs/PROJECT_STATUS.md`, `docs/ARCHITECTURE.md`, `docs/FILESYSTEM_CAPABILITIES.md`, `docs/FEATURE_COMPLETE_GATE.md`, `docs/AUTOMATED_QA_REPORT.md`, `docs/MANUAL_QA_CHECKLIST.md`, `docs/RELEASE.md`, `docs/KNOWN_LIMITATIONS.md`, `ThirdPartyNotices.md`, `.ai/validation-cache.json`.

QA 보고서는 commit/dirty fingerprint, Mac/OS/SDK/Swift/arch, 볼륨/비교 규칙, 테스트 명령/결과/실측/로그 경로, 미실행과 사유, artifact hash를 포함한다. `PASS`, `NEEDS_MANUAL_QA`, `NEEDS_REAL_DEVICE_QA`, `KNOWN_LIMITATION`, `BLOCKED_RELEASE_SIGNING`, `BLOCKED_EXTERNAL_DEPENDENCY`를 구분한다. 자동 수정 가능한 FAIL이 남으면 AUTO-QA PASS를 쓰지 않는다.

P0: 내용 손상/삭제/덮어쓰기/잘못된 경로 수정/위험한 Undo/개인정보 유출. P1: 시작·스캔·Rename·Undo·실제 드롭·핵심 패키지 실패/반복 crash. 공개 출시 조건 P0=0/P1=0, 필수 실제 Finder/파일시스템 QA 및 서명·공증 검증 완료. 미검증이 있으면 “출시 가능”으로 단정하지 않는다.

향후 후보는 별도 backlog: App Store sandbox, PKG 기업 배포, CLI/report mode, 사용자 지정 고급 변환, 자동 업데이트. 이번 필수 기능과 섞어 Feature Complete를 무한히 미루지 않는다.

## 17. Windows에서 반드시 계승할 회귀 방지 사항

1. 부모 이름 변경 후 겹치는 입력 root와 변경되지 않은 자식 root 경로도 갱신한다.
2. 기록 상세 검사에서 같은 디렉터리를 항목마다 재열거하지 않는다.
3. 실행/설치/제거 중 중복 실행이나 transaction 충돌을 막는다.
4. OS 통합 옵션 해제는 앱 소유 등록만 제거한다. 다른 앱의 Services/설정을 지우지 않는다.
5. hardlink 부분 Undo를 inode 하나로 전체 완료 처리하지 않는다.
6. 드롭 callback 테스트와 실제 Finder gesture 테스트를 구분한다.
7. 테마는 titlebar까지, Olive sidebar는 canvas보다 약간 진하게, 설정은 저장 버튼 없이 즉시 적용한다.

이 문서와 동봉 자산만으로 구현을 시작할 수 있다. Windows 저장소가 함께 있으면 코드/fixture를 참고할 수 있지만 Windows 플랫폼 가정을 macOS 안전 계약보다 우선하지 않는다.
