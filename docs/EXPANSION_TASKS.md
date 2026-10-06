# Moongchi NameFix 확장 개발 작업 목록

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

기준일: 2026-10-04. [계획](EXPANSION_PLAN.md)과 [실행 지침](EXPANSION_EXECUTION.md)을 함께 적용한다. 독립 기능 구현과 직접 Debug 회귀를 완료했다. 기존 기능의 존재는 해당 확장 작업의 완료를 뜻하지 않는다. 무료 유입 정책 개정으로 기본 일괄 변경·기본 규칙 조합·일반 순번·기본 결과 export를 무료로 확장했다. F/P 기능 ID는 요금제를 의미하지 않으며 실제 capability 표를 따른다.

## 최신 작업 경계 — 대기

2026-10-04 최신 사용자 지시: 앱 자체 개발을 우선하고 Store 실제 동작 검증·판매 연결·Release·서명·공증·배포 준비는 후속 단계로 보류한다. 앱 자체에 확인된 추가 필수 개발 항목이 없어 대기한다. 아래 출시 후보/외부 조건 상태는 이력과 후속 단계 추적용이며 현재 자동 실행할 작업이 아니다.

## v1.0 후속 현재 작업

최신 상태는 [V1_RELEASE_STATUS.md](V1_RELEASE_STATUS.md)를 따른다. E01은 조정·감지·중단·보존/안내 구현과 실제 실행 경합 검증 완료, 비협조 writer 원자 방지는 알려진 제한이다. E24 실제 판매 연결은 여전히 외부 조건이며 E25 로컬 통합/Release 후보 검증 완료와 공개 출시 대기를 구분한다. 아래 표는 확장 Debug 완료 시점 기록이다.

| 후속 항목 | 현재 상태 | 근거 |
|---|---|---|
| E01 동시 변경 대응 | IMPLEMENTED_WITH_KNOWN_LIMITATION | 실제 executor 8 source/2 destination 경합, 조정 대기 취소/timeout, raw/version 검사 |
| E24 실제 판매 | BLOCKED_EXTERNAL | 판매 방식·상품 ID·권한 검증 공급자 미확정; Release Free로 닫힘 |
| E25 로컬 통합/출시 후보 | LOCAL_CANDIDATE_VERIFIED | 91 고유 XCTest, Release 실행 15개, case-sensitive APFS 39개, build3 서명/ZIP/DMG 검증 |
| 공개 출시 | BLOCKED_EXTERNAL_AND_MANUAL | 출시용 ID·공증 프로필·실제 판매 연결·실사용 Gate |

## 이전 확장 작업

- 독립 구현 TODO 없음. E01/E25는 SOURCE_RACE 계약 blocker, E24 실제 판매 연결만 외부 조건이다.
- 신규 확장 검증은 EXPANSION_DEVELOPMENT.md에 증거별로 기록한다. 과거 전체 QA와 합산하지 않는다.
- 알려진 선행 문제: SOURCE_RACE. 해결 또는 근거 있는 blocker를 기록하고 독립적인 작업은 계속한다.
- 외부 조건: 실제 판매 공급자와 상품 ID 미결정. E24의 실판매 연결만 제한하며 다른 개발은 진행 가능하다.

## 순서와 완료 증거

직접 검증 열은 실행 예정 범위다. 실제 명령·결과·근거를 남긴 후에만 상태를 바꾼다. E01의 ‘평가 완료’는 결함 해결을 뜻하지 않으며 최종 판정에서는 잔여 blocker를 별도로 확인한다.

| ID | 단계 | 구현 작업 | 선행 조건 | 상태 | 직접 검증과 완료 증거 |
|---|---|---|---|---|---|
| E00 | P0 | 환경·기존 구현·사용자 데이터 보존 기준선 | 없음 | DONE | environment.txt; 기존 변경 보존, git 없음, 원본 handoff 9 hash 일치 |
| E01 | P0 | SOURCE_RACE 개선 검토·회귀·지원 계약 | E00 | BLOCKED_CONTRACT | final-safety-pairs.txt: SOURCE_RACE_LIMITATION 재현. 해결 아님 |
| E02 | P0 | 범용 적격성·plan 경계·capability·schema | E00, E01 평가 | DONE | Core·AppModel·기존 settings/journal 회귀 PASS; capability/optional schema 공존 |
| E03 | P1 | NFC/NFD 출력 모델·scan·plan·실행 | E02 | DONE | ExpansionTests NFD raw spelling→Undo PASS |
| E04 | P1 | 목표 기반 UI·설명·텍스트 입력과 복사 | E03 | DONE | CharacterPresentation·UTF16 제한·387키×3언어·33뷰 렌더 |
| E05 | P2 | Finder 진입 안내·메뉴바 공유 모델 | E04 | DONE | 공유 model/queued inputs tests, 메뉴바 drop/최근/상태·Finder Services 코드 및 Debug build |
| E06 | P2 | Mac 로그인 시 실행·완료 알림 | E05 | DONE | SMAppService/UNUserNotification adapter 및 오류 안내·Debug compile. OS 승인 실기 별도 |
| E07 | P3 | 무료 기본 문자 규칙·Pro 고급 옵션 경계 | E02, E04 | DONE | core.txt: grapheme/숨김/확장자/무료 조합 PASS |
| E08 | P3 | 정규식·캡처·실행 예산·취소 | E07 | DONE | core.txt + final-safety-pairs.txt: pathological regex 예산·첫 timeout 중단 PASS |
| E09 | P3 | 순번·안정 순서·조건 모델 | E07 | DONE | Core numbering/overflow·고정/수동 순서·group number tests PASS |
| E10 | P3 | swap/cycle·중첩·temp graph·Undo/Recovery | E03, E07 | DONE | final-safety-pairs.txt: swap/3-cycle/중첩/취소/partial recovery/Undo/hardlink PASS |
| E11 | P4 | 무료 기본 조합·Pro 조건 UI·단계별 preview | E08, E09, E10 | DONE | 모델 stale preview/선택/권한 tests·규칙 단계 전후·키보드 순서·렌더 PASS |
| E12 | P4 | 무료 예제/마지막 설정·Pro 프리셋·schema | E11 | DONE | 프리셋 CRUD/import/export·무료 복원·원문 read-only; ui-storage/watch 모델 회귀 PASS |
| E13 | P5 | CSV/TSV parser·열 매핑·모호성 차단 | E10, E12 | DONE | core.txt·ExpansionTests: CSV BOM/quotes/newline/raw/중복/상대 모호성/취소/행 오류 PASS |
| E14 | P5 | 무료 결과 export·수식 처리·round-trip | E13 | DONE | core.txt: 수식 안전/원문 round-trip; 사용자 요청 결과/이유/base64 export 구현 |
| E15 | P6 | 파일/이미지 metadata·날짜·timezone provider | E10, E12 | DONE | final-safety-pairs.txt: attrs/JPEG/TIFF/HEIC/offset/source-zone/version 변경 차단 PASS |
| E16 | P6 | 음악·영상·문서 provider와 지원표 | E15 | DONE | media-formats.txt + final-safety-pairs.txt: MP3/M4A/MOV/MP4/PDF 필드·내용 불변 PASS |
| E17 | P6 | 파일 쌍과 그룹 preview·부분 실패 | E15 | DONE | final-safety-pairs.txt: raw stem·priority·번호·선택/오류 그룹 전파 PASS |
| E18 | P7 | 감시 이벤트·대기열·권한 수명 | E06, E12 | DONE | watch-persistence.txt: FSEvents fixture·IgnoreSelf·대기/쓰기 안정화·schema 보존 PASS |
| E19 | P7 | 감시 preset preview와 승인 snapshot | E18, E10 | DONE | AppModel snapshot + WatchSnapshot baseline round-trip PASS; 신규 유입은 승인에 미포함 |
| E20 | P7 | 사용자용 CLI·구조화 출력·확인·단일 실행 | E04, E12, E14, E16 | DONE | cli.txt: raw JSON/dry-run/TTY 확인/무확인 거부/undo/hash/pro 경계 PASS |
| E21 | P8 | 도움말·ko/en/ja·접근성·무료 유입 과제 설계 | E11~E20 | DONE | resources.txt·model tests·menu/manual-order accessibility 코드 및 render.txt PASS |
| E22 | P8 | 테마·반응형·기존 정보·창 복원 회귀 | E21 | DONE | WindowLayout/Character tests + render.txt 33개·네 테마/세 언어 PASS |
| E23 | P8 | 성능 측정·비교 가능 범위·최적화 | E22 | DONE | performance.txt: 10k×5회 중앙값2.278s/p95총2.416s. preview300ms목표 미달·GUI실측 별도 |
| E24 | P9 | 모든 진입점 권한·공급자 경계·상태 복원 | E19, E20 | BLOCKED_EXTERNAL | Entitlement expiry/revoked/unavailable와 Debug-only 경계 PASS; 실제 상품/provider 미결정 |
| E25 | P9 | 확장 통합 Debug 검증·오류 수정·재판정 | E01~E24 | BLOCKED_CONTRACT | 84개 고유 XCTest + CLI/리소스/Debug/33렌더 통과. SOURCE_RACE 때문에 상용완성 선언 보류 |

E07의 확장자 편집은 파일 형식 변환이 아니며 기본 확장자 보호를 유지한다. E21의 범위 표기 E11~E20은 해당 범위 모든 작업 완료를 뜻한다. E25는 독립 구현이 끝나도 SOURCE_RACE나 필수 구현 blocker가 남으면 DONE이 될 수 없다. E24의 구매 공급자 미연결은 별도 외부 상태로 보고하고 실제 결제 완료를 주장하지 않는다.

## 작업별 기록 형식

각 ID를 시작할 때 아래 기록을 추가하고 종료 때 갱신한다. PASS를 실행 전에 작성하지 않는다.

```text
ID:
상태: IN_PROGRESS / DONE / BLOCKED_CONTRACT / BLOCKED_EXTERNAL
변경 목적과 사용자 동작:
변경 파일:
검증 명령과 적용 scope:
결과: NOT_RUN / PASS / FAIL / FLAKY_TEST / NOT_AVAILABLE
근거 경로와 source fingerprint:
오류·취소·데이터 보존 확인:
번역·문서 갱신:
미확인 조건 또는 blocker:
다음 실행 ID:
```

## 범위 추적

| 계획 기능 | 담당 작업 |
|---|---|
| F01~F05 | E02~E04, E10, E25 |
| F06 | E04 |
| F07 | E05~E06 |
| F08 | E21~E22 |
| F09 | E20 |
| P01~P03 | E07~E10 |
| P04~P05 | E11~E12 |
| P06 | E13~E14 |
| P07~P08 | E15~E17 |
| P09 | E18~E20 |
| 공통 성능·권한·통합 | E23~E25 |

실제 증거 파일은 `artifacts/development/expansion/evidence/` 기준이다. DONE은 명시한 개발 범위/직접 검증을 뜻하며 수동 OS QA·외장/최소 OS·실판매 완료를 뜻하지 않는다. E24의 내부 기능 권한은 구현 완료이며 외부 adapter만 남았다.

## UI-SIDEBAR — 2026-10-04

DONE: native 접이식 사이드바, 독립 일괄 변경, 목적별 도구 안내, 설정 유지. Debug build와 Workspace/WindowLayout 12 tests PASS. 언어/테마/접힘 상태 렌더 및 리소스 증거는 [보고서](NATIVE_SIDEBAR_2026-10-04.md)를 따른다. Core 파일 변경 엔진과 무료/Pro 권한 범위는 변경하지 않았다.
