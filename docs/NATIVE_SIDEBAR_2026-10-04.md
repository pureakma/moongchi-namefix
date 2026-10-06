# macOS 사이드바 개선 — 2026-10-04

## 구현

- 중복 ‘자소 분리 정리’ 화면 제목 제거. 왼쪽 메뉴의 ‘자소 분리 해결’로 목적을 안내한다.
- NSSplitViewController/sidebar item과 tracking separator로 신호등 아래까지 연결되는 접이식 사이드바 구현. 네 테마의 배경이 상단까지 이어진다. 창 너비 760pt 미만에서 접고, 상단 버튼/보기 메뉴로 펼친다.
- ‘이름 일괄 변경’을 독립 메뉴로 배치. 치환·번호·날짜 예시와 규칙 추가 안내, 별도 빈 화면을 제공한다. 문자 형식 옵션은 접힌 보조 영역이다.
- 모호한 ‘추가 도구’를 텍스트 변환, 폴더 감시, 검사 결과 CSV 저장으로 분리하고 설명을 붙였다. 파일 이름 변경과 붙여 넣은 텍스트 변환을 구분한다.
- 설정 sheet 유지: 테마·언어 등 앱 전체 환경에 필요하다. 사이드바/상단 버튼/⌘,에서 연다.
- 통계 카드·검사·검색·선택·충돌·확인·기록·무료/Pro 권한을 유지한다. Core mutation engine 변경 없음.

## 검증

근거: `artifacts/development/native-sidebar/`

- `bash eng/build.sh`: Debug arm64 PASS (`build-complete.txt`).
- `bash eng/test.sh --filter 'WorkspaceTests|WindowLayoutTests'`: 12 tests PASS (`tests.txt`). 화면 전환/규칙 미적용 방지 및 창 배치 관련 범위.
- `python3 eng/validate-resources.py`: 426키 × 3언어 PASS (`resources-final.txt`).
- 앱의 `--render-expansion … --native-sidebar`: ko/en/ja × olive/dark/light/system × quick/batch/collapsed 36개 native window render PASS (`render-complete.txt`, `rendered-complete/`). 접힘 상태 assertion 포함.
- 한국어 Olive 일괄 변경/접힌 화면, 일본어 Dark 기본 화면을 이미지로 확인했다. 사용자의 실제 창을 제어하지 않은 독립 fixture이며 비활성 신호등이 회색으로 표시된다. 36개 모두 사람이 확인한 것으로 주장하지 않는다.
- 중간 렌더에서 발견한 sidebar blank/잘못된 fixture 창 크기를 수정했다. 이전 render 디렉터리는 최종 PASS 근거가 아니다.

## 산출물

`artifacts/development/Moongchi NameFix 사이드바 Dev.app`

Executable SHA-256: `2f00272488af002f7fedbb575003f81121eb1dde201d34c44cf1e65e2dc6cead`

기존 앱 복사본 보존. Release 빌드·Store 연결·배포 서명·공증은 수행하지 않았다.
