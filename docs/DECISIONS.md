# Moongchi NameFix 결정

### D-001 macOS 14+ Apple Silicon arm64 전용 [accepted]
- 날짜: 2026-10-04
- 결정: 현재 제품은 macOS 14 이상 Apple Silicon arm64만 지원한다. Intel/Windows/universal2는 현재 범위가 아니다.
- 이유: 현재 project.yml, 빌드·검증 환경과 사용자가 확정한 플랫폼 override를 일치시킨다.

### D-002 SwiftUI + AppKit와 기존 계층 경계 유지 [accepted]
- 날짜: 2026-10-03
- 결정: UI는 SwiftUI + AppKit, 순수 이름/규칙 모델은 NameFixCore, 실행 조정은 Application, 파일시스템·저장은 Infrastructure가 담당한다.
- 이유: 이미 구현·검증된 책임 경계를 유지하고 문서 정비를 이유로 리팩터링하지 않는다.

### D-003 APFS 안전 mutation과 source-race 한계 공개 [accepted]
- 날짜: 2026-10-04
- 결정: local writable APFS만 mutation 대상으로 삼고, no-replace·durable journal·NSFileCoordinator 협조·identity/raw/version 재검사·post-check·보존/Recovery를 사용한다. 비협조 외부 writer의 source 교체를 원자 예방한다고 주장하지 않는다.
- 이유: Darwin의 현재 사용 계약에는 expected-inode 조건부 atomic rename 보장이 없으며 실제 경합 fixture도 이 한계를 재현했다.

### D-004 Free/Pro capability는 구현하되 실제 공급자 미구성 시 fail-closed [superseded by D-014]
- 날짜: 2026-10-04
- 결정: Free 기본 이름 정리와 Pro 고급 반복 작업의 capability 경계를 코드에 유지한다. Unconfigured entitlement는 Pro를 허용하지 않으며 Debug 개발 스위치를 실제 구매로 취급하지 않는다.
- 이유: 기능 구현과 실제 판매/영수증 검증을 분리해 권한 우회를 막는다.

### D-005 기본 제품 경로에 AI/OCR/RAG를 넣지 않음 [accepted]
- 날짜: 2026-10-04
- 결정: Unicode 정규화와 현재 이름 변경 엔진은 결정론적 로컬 로직을 사용한다. AI/OCR/RAG는 승인되지 않은 향후 후보이며 현재 mutation 경로에 연결하지 않는다.
- 이유: 정확한 Unicode 처리에 생성 모델이 필요하지 않고, 내용 접근·모델 용량·지연·개인정보 계약을 새로 만들기 때문이다.

### D-006 간편 자소 분리 화면과 일괄 변경 작업실 분리 [accepted]
- 날짜: 2026-10-04
- 결정: 첫 화면은 자소 분리 해결 중심, 고급 규칙은 별도 이름 일괄 변경 작업실로 제공한다. native sidebar와 목적별 도구 메뉴, Olive 기본 + System/Dark/Light, ko/en/ja, 반응형 창을 유지한다.
- 이유: 기존 기능을 숨기지 않으면서 첫 사용 복잡도를 낮춘다.

### D-007 배포 채널은 아직 확정하지 않음 [accepted]
- 날짜: 2026-10-06
- 결정: 현재 source의 App Sandbox는 OFF이고 직접 배포용 Developer ID 흐름이 준비돼 있지만, 최종 판매/배포 채널을 직접 배포 또는 Mac App Store 중 하나로 아직 확정하지 않는다.
- 이유: App Store 선택은 sandbox/entitlement와 판매 공급자 설계에 영향을 주므로 Release Task에서 사용자 결정과 최신 공식 정책 확인이 필요하다.

### D-008 만능프롬프트 Reference는 Bootstrap 기준으로만 사용 [accepted]
- 날짜: 2026-10-06
- 결정: 문서 체계는 만능프롬프트 v2.8, Core 2.8, 기존 프로젝트 Pack 2.5, UIUX 1.2.1, 플랫폼 1.0의 macOS 구역, Development Operations 1.0, doccheck 1.4를 기준으로 정착한다. 이후 평상시 개발은 이 저장소의 AGENTS/PROJECT/STATUS/코드/테스트/Git만으로 진행한다.
- 이유: 외부 Reference를 매 세션 다시 읽는 의존성을 없애고 프로젝트 자체 SSOT를 유지한다.

### D-009 과거 문서 대신 Git 이력을 사용 [accepted]
- 날짜: 2026-10-06
- 결정: 날짜별 개발 보고서, 옛 계획, StartPrompt, Project Master의 현재 유효 정보는 새 SSOT로 이관하고 중복 파일은 삭제한다. 별도 archive/backup/old 개발문서를 만들지 않는다.
- 이유: 현재 판단 원본을 하나로 줄이고 과거 이력은 Git에서 복구할 수 있다.

### D-010 Windows→macOS handoff는 제품 공통 명세 전달에만 사용 [accepted]
- 날짜: 2026-10-06
- 결정: 현재 macOS 저장소는 Windows 개발 handoff 패키지나 Windows 개발 이력에 실행 의존하지 않는다. 번역은 Resources/Localizable.xcstrings, 폰트는 Resources/, 앱 아이콘은 assets/branding/NameFix-Original.png를 각각 단일 원본으로 사용한다.
- 이유: 동일 제품의 기능·사용자 흐름·안전 요구는 계승하되 Windows 구현/개발 산출물 전체를 macOS 프로젝트의 영구 입력으로 유지하면 중복 SSOT와 불필요한 저장소 비대화를 만든다. 향후 플랫폼 이식도 공통 Product/UI·UX 명세 + 대상 플랫폼 Native Spec 방식으로 한다.

### D-011 화면 문구는 일반 사용자 용어를 우선 [accepted]
- 날짜: 2026-10-06
- 결정: UI에는 NFC/NFD, 정규화, 메타데이터, 정규식 같은 기술 용어를 그대로 내세우지 않고 사용자 목적 중심 표현을 쓴다. 기술명이 꼭 필요하면 ‘쉬운 이름 · 기술명’ 또는 괄호로 덧붙인다. 기술적으로 의미가 달라지는 번역은 하지 않으며, 세부 표기 규칙은 DESIGN.md가 원본이다.
- 이유: 출시 전 리뷰에서 상태 표시·필터·도움말·확인 시트에 개발 용어가 노출돼 처음 쓰는 사용자가 별도 설명 없이 이해하기 어려웠다.

### D-012 사용자 취소는 처리 중인 항목을 마친 뒤 적용 [accepted]
- 날짜: 2026-10-06
- 결정: 단일 항목 이동에서 source → temporary가 끝난 뒤의 취소 요청은 해당 항목을 final까지 마치고 다음 항목 전에 멈춘다. swap/cycle/묶음 파일 그룹은 현재 동작(그룹 도중 취소 시 Recovery)을 유지한다.
- 이유: 화면은 “현재 항목을 마친 뒤 중지”라고 안내하지만 실제로는 취소 시점에 따라 항목이 숨은 임시 이름에 남아 복구가 필요했다. 안전 검사(no-replace, identity 확인, journal 순서)는 바꾸지 않는다.

### D-013 화면은 상태에 필요한 control만 보여 준다 [accepted]
- 날짜: 2026-10-06
- 결정: 입력이 없을 때는 빈 상태 하나가 유일한 입력 화면이며 결과용 control을 두지 않는다. sidebar는 부제 없는 한 줄 navigation, toolbar는 sidebar 접기만 둔다. 이름 일괄 변경은 일상 작업 선택을 먼저 보여 주고 규칙 편집 전체는 ‘고급 규칙’을 펼쳤을 때만 노출한다. 기능은 지우지 않고 처음 보이는 시점만 늦춘다. 세부 계약은 DESIGN.md가 원본이다.
- 이유: 사용자가 실제 화면에서 입력 UI 중복, 빈 상태의 결과용 control 노출, sidebar 부제, 일괄 변경 화면의 복잡함을 지적했다. 이전 화면 구조는 사용자가 승인한 적이 없다.

### D-014 모든 기능을 무료로 제공 [accepted]
- 날짜: 2026-10-06
- 결정: 유료 등급을 두지 않는다. 앱과 CLI는 항상 전체 access로 동작하고 화면·문구에서 Pro·구매 표시를 없앤다. 규칙 집합을 access 수준에 대해 검증하는 내부 구조와 그 test는 남겨 둔다. 다음 실행 때 자동 복원하는 ‘마지막 규칙’은 종전처럼 기본 규칙 조합만 대상이며, 패턴·파일 정보 등을 포함한 규칙은 프리셋으로 저장해 다시 쓴다.
- 이유: 사용자가 “Pro 없음, 무료로 모두 제공”을 지시했다. 구매 공급자·상품 구성·영수증 검증이 필요 없어져 출시 Gate가 줄고, 구매할 수 없는 Pro 표시가 화면에 남는 문제도 사라진다.

### D-015 sidebar는 아이콘 레일과 추가 항목 트리 [superseded by D-016]
- 날짜: 2026-10-06
- 결정: sidebar 왼쪽 끝에 아이콘만 있는 레일(tooltip 제공)로 화면·도구·작업 기록·설정·도움말을 두고, 그 옆 패널에는 추가한 파일·폴더의 트리를 보여 준다. 트리의 폴더를 누르면 목록이 그 안의 항목으로 좁혀진다. sidebar 접기 버튼은 없애고 title bar band에 앱 이름 NameFix를 표시한다. 좁은 창에서는 sidebar가 자동으로 숨는다.
- 이유: 사용자가 이 구조를 직접 제안했다. 트리가 ‘추가한 위치’ 목록과 폴더별 보기를 한곳에서 해결한다. 아이콘만으로는 처음 보는 사용자에게 뜻이 덜 분명할 수 있어 tooltip, 접근성 이름, 상단 band의 화면 제목으로 보완한다.

### D-016 왼쪽 영역은 입력 상태를 따르고, 즐겨찾기는 감시와 분리 [accepted]
- 날짜: 2026-10-06
- 결정: 입력이 없으면 펼친 navigation만 보이고 폴더 트리는 없다. 파일·폴더가 추가되면 navigation이 아이콘 레일로 줄고 그 옆에 폴더 트리가 나오며, 모든 입력을 제거하면 자동으로 되돌아간다. 사용자가 관리하는 toggle은 두지 않는다. 즐겨찾기는 빠른 접근 shortcut일 뿐 background 감시와 결합하지 않으며, 실시간 감시는 ‘폴더 자동 감시’에 명시적으로 등록한 폴더만 수행한다. 세부 계약은 DESIGN.md가 원본이다.
- 이유: 사용자가 ‘항상 레일 + 트리’ 구조(D-015)를 실제 화면에서 본 뒤, 입력이 없을 때는 이름이 보이는 메뉴가 필요하고 트리는 입력이 있을 때만 의미가 있다고 지시했다. 즐겨찾기가 감시를 암묵적으로 켜면 사용자가 모르는 background 동작이 생긴다.
