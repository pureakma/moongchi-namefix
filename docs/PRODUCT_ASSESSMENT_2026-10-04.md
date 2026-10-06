# 제품 완성도·AI 활용·수익화 검토

검토일: 2026-10-04 (Asia/Seoul). 대상: macOS 14+ Apple Silicon 전용 Moongchi NameFix. 출시 QA·스모크·서명·공증·심사·배포를 앱 자체 완성도 판정에서 제외한다.

## 판정: 미완성

요청한 기본 테마·설정·상단바 변경은 구현했다. 남은 제품 개발 항목은 기존 **SOURCE_RACE 1건**이다. 화면을 직접 조작하지 않았다는 이유로 결함을 추가하지 않았다. 이전 전체 QA를 이번 소스의 PASS로 재사용하지 않는다.

| 영역 | 남은 확인된 개발 항목 | 위치·근거·대응 |
|---|---|---|
| 기능 | 없음 | 현재 Unicode 검사/미리보기/명시 확인/충돌·번호/Undo/Recovery/설정 범위에서 추가로 확인한 미해결 누락 없음. AI는 기존 요구 기능이 아니다. |
| 성능 | 없음 | 이번 변경은 native toolbar와 설정 표시. 전체 목록 재검사/정렬을 추가하지 않았다. 기존 UI model의 10만 행 선택 경로 회귀 통과. 사용자 실제 스크롤 지연을 새로 측정한 것은 아니다. |
| 사용자 경험 | 없음 | 설정 저장 실패가 부모 창 메시지에만 남아 설정창에서 즉시 보이지 않던 문제를 설정 안의 경고로 보완했다. 테마 선택도 설정창에 즉시 반영한다. |
| 디자인 | 없음 | 기본 Olive, 테마 선택의 설정 이동, native top toolbar, 설정 카드·작은 창 스크롤을 구현했다. 실제 뷰 렌더 결과는 별도 근거에 기록한다. |
| 안정성 | P1 SOURCE_RACE | Infrastructure/Transaction.swift의 마지막 FS.verify와 FS.noReplace 사이에 외부 writer가 source를 바꾸면 대체 파일이 임시 이름으로 이동할 수 있다. 후속 identity 검사에서 중단·복구 안내하지만 이동 순간은 막지 못한다. |

`SafetyTests.testSourceRaceCannotBeAtomicExpectedInodeRename`를 전용 APFS 임시 fixture에서 다시 실행해 재현했다. 이 테스트의 PASS는 한계가 재현됨을 뜻하며 결함 해결을 뜻하지 않는다. 파일 내용 손상이 이 실행에서 관찰됐다는 주장은 하지 않는다. 목적지 no-replace, 작업 중단, journal과 발견 경로 보존은 계속 적용한다.

해결 방향은 identity를 조건으로 원자적 이동할 수 있는 플랫폼 계약 또는 다른 writer를 강제로 배제할 수 있는 작업 모델이다. 현재 Darwin renameatx_np는 expected inode 인자를 받지 않는다. NSFileCoordinator·advisory lock은 협조하지 않는 외부 writer까지 막는 근거가 될 수 없으며 검사 추가/재시도/추측 rollback을 완전한 해결로 취급하지 않는다. 구현되지 않은 보장을 주장하거나 핵심 Rename을 꺼서 완료로 표시하지 않았다. 이 안전 계약은 UI 수정과 독립적인 남은 설계 제약이다.

## 이번 UI 변경

- 새 설정이 없는 최초 실행 기본 테마는 Olive Archive. 이미 저장된 system/dark/light/olive는 사용자의 선택으로 보존한다.
- 주 화면의 테마 메뉴를 제거하고 설정의 첫 번째 표시 영역에 네 테마 색상 미리보기·선택 표시를 배치했다. 저장 버튼 없이 즉시 적용·저장하며 실패는 같은 창에서 알린다.
- 앱 이름은 메뉴/Dock/앱 정보와 NSWindow의 실제 title 속성에 유지한다. 화면에 중복 표시하던 native title은 숨겼고, 작업 공간의 “파일 이름 검사”는 유지한다.
- AppKit unified toolbar로 기존 얇은 titlebar에 버튼 높이·패딩 공간을 확보한다. 오른쪽 순서: 다시 검사 → 작업 기록 → 설정. native traffic lights와 좁은 창 overflow는 macOS가 관리한다. 도움말은 OS 메뉴와 설정 하단에서 접근한다.
- toolbar의 다시 검사는 입력 없음/작업 중/Preview·결과·sheet 표시 중 비활성화한다. Preview나 결과가 있는 동안 설정·기록으로 확인 절차를 우회하지 않는다. OS 메뉴의 기존 단축키도 유지한다.
- 설정은 표시, 일반, 기록 및 개인정보 카드로 구성한다. 모든 기존 설정과 관련 도움말, 네 테마, 열 너비 비율, 언어, recursive, 기록 보존, 진단을 유지한다. 열 너비는 넓은 표에만 적용된다는 설명을 추가했다.
- SheetRouter는 현재 테마와 colorScheme에서 palette를 다시 계산하므로 이미 열린 설정창에도 변경이 반영된다.

구현: App/WindowChrome.swift, Main.swift, MainView.swift, Sheets.swift, Infrastructure/Settings.swift. 번역: eng/resources.py 및 Resources/Localizable.xcstrings와 세 locale의 .strings.

## 검증 근거

`artifacts/development/shell-refinement/`:

- ui-model.txt: 관련 9개 테스트 PASS. 신규 Olive 기본값/기존 테마 보존 및 설정 저장 실패 시 기존 데이터 보존 테스트 포함.
- source-race.txt: 기존 source 경합 한계 재현 1개 PASS(문제 해결 아님).
- debug-build.txt: Apple Silicon Debug 빌드 PASS. Release 작업 없음.
- resources.txt: 228키 × 3언어, placeholder, 폰트/라이선스, 원본 handoff 무결성.
- render.txt 및 rendered/: 실제 native frame/SwiftUI 렌더 51개 생성 PASS. ko/en/ja, 1180/600/320pt native 창, 네 테마의 640/320pt 설정, 좁은 설정 하단, 열린 설정의 테마 변경 및 저장 실패 상태. toolbar 항목·비활성 상태·설정 action 연결도 fixture에서 assert한다. 대표 이미지에서 상단바·설정 내용·스크롤 하단을 확인했다.

네이티브 titlebar 실측 높이는 이 환경의 세 창 너비 모두 52pt였다. OS가 관리하는 크기이므로 모든 macOS 버전에서 같은 수치라고 주장하지 않는다. 사용자 창을 열거나 제어하지 않았으며, 사용자 실기 입력/접근성 이벤트 전체를 자동 검증한 것으로 주장하지 않는다. 최초 새 renderer의 AppKit 초기화 오류는 NSApplication.shared 초기화로 수정한 뒤 해당 렌더를 재실행했다.

최신 앱: `artifacts/development/Moongchi NameFix 상단바 설정 Dev.app`. 이전 앱은 보존했다. 전체 번들 파일·렌더 SHA-256과 이번 cache 범위는 development-build.json 및 .ai/validation-cache.json에 기록한다.

## AI 활용: 가능하지만 현재 정규화 경로에는 불필요

NFC/NFD 판정은 Unicode 규칙과 실제 filename bytes로 정확히 처리할 수 있다. 생성 모델에 맡기면 결과 변동, 불필요한 지연·메모리 사용과 이름 왜곡 위험을 추가한다. 기존 scanner/executor에 AI를 넣지 않았다. 아래는 구현 완료 기능이 아니라 확장 가능성 검토다.

| 기술 | 가능한 용도 | 이 제품에 대한 판단 |
|---|---|---|
| 로컬 오픈 가중치 모델 | 문서 요약 기반 파일명 후보, 자연어 명명 규칙 해석, 분류 제안 | MLX Swift 기반 로컬 추론 가능. 모델별 라이선스·배포 용량·RAM·다운로드 동의·취소/해제 설계가 필요하다. 기본 NFC 기능에 상주 모델을 추가할 가치는 낮다. |
| Apple Foundation Models | 요약·구조화된 이름 후보 생성, 명명 규칙 해석 | 선택적 AI 확장의 우선 후보. macOS 26+ 및 Apple Intelligence 가용성을 실행 시 확인하고, 지원 안 되는 macOS 14/15에서는 현재 기능이 그대로 동작해야 한다. 언어/지역·모델 준비 상태도 확인한다. |
| Apple Vision | 이미지·스캔 문서의 글자를 인식해 날짜·제목 후보 추출 | 내용 기반 이름 제안으로 확장할 때 가장 직접적이다. 문자 추출이 가능한 PDF는 먼저 직접 텍스트를 사용하고 스캔 이미지에 OCR을 적용하는 설계를 권한다. OCR은 정답 보장이 아니므로 원문/후보 확인 필요. |
| RAG | 사용자가 제공한 조직 명명 규칙·프로젝트 사전·예시에서 근거 검색 | 관련 규칙이 많아졌을 때 선택적으로 유용하다. 현재 NFC 변환·짧은 도움말에는 과하다. 먼저 템플릿/키워드 검색으로 부족함을 측정한 뒤 벡터 검색을 검토한다. |

공식 근거: [MLX Swift LM](https://github.com/ml-explore/mlx-swift-lm)은 Swift의 LLM/VLM/embedding 지원을 제공한다. 현재 문서의 FoundationModels 브리지는 macOS/iOS/visionOS 27 SDK 요구사항을 별도로 명시하므로 기본 macOS 14 경로와 동일시하지 않는다. [Apple Foundation Models 설명](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/)은 온디바이스·오프라인 추론과 macOS 26/Apple Intelligence 조건을 설명한다. [Vision OCR 문서](https://developer.apple.com/documentation/vision/recognizing-text-in-images), [RAG 원 논문](https://arxiv.org/abs/2005.11401)을 참조했다.

확장한다면 “사용자 동의로 선택 문서 읽기 → OCR/텍스트 추출 → 제한된 형식의 후보 생성 → 금지 문자·바이트 길이·확장자·경로 탈출·충돌 검증 → Preview → 명시 확인 → 기존 transaction” 순서가 적절하다. 모델은 rename/삭제 도구를 호출하지 않고 후보만 반환한다. 문서에 들어 있는 지시를 실행 권한으로 해석하지 않는다. RAG 자료도 선택한 범위로 제한하고 전체 디스크를 몰래 인덱싱하지 않는다.

현재 앱은 이름만 분석하며 파일 내용을 읽지 않는 계약이다. 내용 기반 AI는 이 계약과 UI 설명을 명시적으로 확장해야 한다. 성능·정확도·지원 언어를 이 앱에서 실제 벤치마크하지 않았으므로 구현/추론 성공으로 보고하지 않는다.

## 수익화 판단: 가능성은 있으나 작은 전문 유틸리티 시장

유료 Mac 이름 변경 제품 자체는 존재한다. 확인일 기준 [A Better Finder Rename](https://www.publicspace.net/ABetterFinderRename/order.html)의 Single User Standard 표시 가격은 US$29.95이며 여러 라이선스와 번들을 제공한다. 한편 [Transnomino](https://www.transnomino.com/)는 무료로 정규식·번호·속성 기반 변경·미리보기·recipe 등 폭넓은 기능을 제공한다. 이것은 시장/경쟁의 근거이며 NameFix의 판매량이나 수익을 입증하지 않는다.

제 판단은 다음과 같다.

1. 한국어/일본어 파일명의 문자 구성 차이를 쉽게 설명하고, 대량 검사와 변경 기록/Undo를 단순한 흐름으로 제공하는 전문 도구로 포지셔닝할 수 있다. “깨진 파일 복구”라고 과장하지 말고 NFC 표준화의 실제 효용을 보여야 한다.
2. 현재 NFC 중심 기능만으로 높은 가격이나 월 구독을 설득하기는 어렵다. 일이 생길 때 사용하는 특성이 강하고 무료 대안과 비교된다. 일회성 구매나 Moongchi 앱 번들이 더 자연스럽다.
3. 초기 개인용 일회성 9,900~19,900원은 실험할 가격 가설이다. 경쟁 가격 환산이나 수요 검증 결과가 아니다. 실제 사용자의 문제 해결 사례·구매 전환·환불·지원 시간을 측정해야 결정할 수 있다.
4. 현재 로컬 APFS 중심이고 cloud/확인되지 않은 볼륨은 보호하므로 “모든 저장소 해결”을 판매 문구로 쓰면 안 된다. 지원 범위가 구매 이유와 맞는 고객부터 검증해야 한다.
5. 더 큰 제품으로 키우려면 고객이 실제로 반복 사용하는 규칙 preset/일괄 정리 흐름이나 문서 내용 기반 이름 제안을 별도 요구사항으로 검증할 수 있다. AI를 붙였다는 사실만으로 결제 가치가 생기지는 않는다. 이번 작업에서 결제·라이선스·새 AI 기능은 추가하지 않았다.

판매 가능성과 앱 완성도는 별도 판단이다. 현재는 source 교체 경합 제약을 해결하지 못해 “돈을 받아도 될 만큼 앱 자체 완성” 판정은 보류한다. 사용자 인터뷰/실판매 없이 예상 매출·성공률을 제시하지 않는다.

별도 단계: 출시 QA·스모크·서명·공증·심사·배포는 이번 작업에 포함하지 않았다.
