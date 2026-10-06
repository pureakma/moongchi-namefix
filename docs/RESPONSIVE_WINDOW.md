# 반응형 창과 마지막 크기 복원

2026-10-04 · macOS 14+ · Apple Silicon arm64 · Debug 개발 변경.

## 동작

- 앱이 지정했던 900×640 최소 창 크기를 제거했다. NSHostingView의 암묵적 content minimum도 해제했다. macOS 창 장식 자체의 제약은 OS에 따른다.
- 최초 실행은 현재 화면의 visibleFrame(메뉴 막대·Dock 제외, 논리 pt)의 85% 안에서 최대 1180×808pt 외곽 frame으로 중앙 배치한다. 픽셀 해상도로 판단하지 않는다.
- 이후 일반 창의 크기·위치·화면을 저장하고 복원한다. 같은 화면의 해상도·배치 변경은 상대 위치를 반영한다. 외장 화면이 없으면 현재 화면 안으로 이동·축소한다.
- 저장은 이동/크기 변경 250ms debounce, live resize 종료/닫기/종료 시 즉시 반영한다. 전체 화면 및 전환 중 크기, 최소화 상태는 일반 창 크기에 덮어쓰지 않는다.
- 너비 900pt 이상: 기존 sidebar, 네 통계, 검색/정렬/필터, 결과 표, 하단 작업 영역 유지. 높이 620pt 미만은 전체 내용 세로 스크롤.
- 너비 900pt 미만: 같은 정보·기능을 세로 배치. 통계 네 항목은 가용 너비에 따라 4/2/1열. 현재/변경 후 이름, 유형, 선택, 상태, 문자 구성 설명, 상세와 경로 복사 모두 유지한다.
- 높이 300pt 이상 좁은 창에서는 작업 버튼을 하단에 유지한다. 더 낮으면 작업 버튼도 내용과 함께 스크롤한다. 내용 최소 폭 280pt보다 좁은 극소 창은 가로 스크롤로 접근한다.
- 설정/기록/Inspector/도움말/클립보드/진단/정보/변경 확인/결과 sheet는 부모 크기에 맞춰 줄이고 내부 내용을 스크롤한다.
- 같은 AppModel과 항목 ID를 사용한다. 창 크기 변경만으로 다시 검사하거나 선택/검색/설정을 초기화하지 않는다. 표의 native virtualization과 좁은 목록의 LazyVStack을 유지한다.
- 좁은 결과 행은 Tab 포커스, Space 선택, Return 상세, ⌘A 표시 항목 선택, ⌘Z 최근 되돌리기를 지원한다. 검색 입력 자체의 기본 편집 동작은 유지한다.

## 변경 경계

App/Main.swift, MainView.swift, Sheets.swift, CharacterViews.swift, ResponsiveViews.swift, WindowLayout.swift가 구현 범위다. WindowPlacementStore는 `NameFix.windowPlacement.v1` 독립 키를 사용하며 기존 AppSettings schema를 바꾸지 않는다. Core/파일 변경 엔진/Undo/Recovery 안전 계약과 사용자 테스트 자료는 변경하지 않았다. 실제 파일 변경은 기존 Preview 및 명시 확인을 계속 요구한다.

## 관련 검증

근거는 `artifacts/development/responsive/`에 보관한다.

| 검증 | 명령/근거 | 결과 |
|---|---|---|
| 초기·복원·화면 변경·손상 값·sheet 크기·독립 저장 | `eng/test.sh --filter WindowLayoutTests`, window-tests.txt | 6개 PASS |
| 선택·검색 등 기존 UI model 회귀 | `eng/test.sh --scope ui-model`, tests.txt | 7개 PASS |
| Apple Silicon Debug | `eng/build.sh --configuration Debug --arch arm64`, debug-build.txt | PASS |
| 세 언어 리소스·placeholder·폰트·라이선스 | `python3 eng/validate-resources.py`, resources.txt | 226키 × 3언어 PASS |
| 실제 SwiftUI/AppKit offscreen layout | Debug 앱 `--render-responsive`, render.txt, rendered/ | 75개 생성 PASS; 대표 크기·세 언어 sheet·하단 렌더 육안 확인 |

렌더 행렬: ko/en/ja, 시스템/다크/라이트/올리브 테마를 순환 적용한 320×600, 600×720, 899×500, 900×640, 1180×780, 1600×1000, 1180×320, 240×200pt. 작은/낮은 창의 하단 스크롤과 320×260pt sheet, 작업 중 오류, 가상 작업 기록, 확인창 마지막 항목도 포함한다. 각 크기에서 선택 집합·항목 ID·현재 항목이 유지됨을 assert한다. 실제 사용자 창을 열거나 제어하지 않는다. 가상 journal은 렌더 산출물 폴더 안에만 생성하며 실제 파일을 변경하지 않는다.

`development-build.json`에 Debug 앱의 전체 파일 SHA-256과 렌더 이미지 SHA-256을 기록했다. 게시한 개발 앱과 Xcode Debug 산출물의 파일 집합·해시 일치를 확인했다. `.ai/validation-cache.json`에 이번 5개 검증 범위를 기록하고 소스 변경에 영향을 받은 이전 PASS는 STALE로 보존했다.

이 근거는 실제 뷰의 정적 렌더와 geometry/model 검증이다. 화면의 모든 연속 크기·실제 드래그·모니터 분리·전체 화면 전환 이벤트·VoiceOver를 직접 검증했다는 뜻은 아니다. 가능한 모든 환경의 “100% 완벽”을 주장하지 않는다. 화면을 직접 조작하지 않은 사실 자체를 앱 결함으로 분류하지 않는다.

## 실행

`artifacts/development/Moongchi NameFix 반응형 Dev.app`을 실행한다. 기존 개발 앱을 종료한 뒤 새 앱을 열면 버전을 구분하기 쉽다. 이전 개발 앱은 보존했다.

직접 확인할 때는 테스트 입력·선택·검색을 유지한 채 창을 넓고 좁게 변경하고 네 통계와 현재/변경 후 이름을 확인한다. 작은 상태에서 설정·기록·확인을 열어 스크롤하고, 일반 창 크기를 바꾼 뒤 종료·재실행해 복원 여부를 확인한다. 실제 파일 변경 확인은 테스트 복사본에서만 수행한다.

기존 source 교체 경합 한계는 이번 UI 작업과 별개로 유지한다. Release 빌드·ZIP/DMG·공개 배포 작업은 수행하지 않았다.
