# 파일명 문자 구성 설명 — 2026-10-04

사용자가 보는 파일명과 내부 Unicode 구성이 다를 수 있다는 점을 목록에서 설명한다. 분해형 자체를 손상이나 오류로 표시하지 않는다.

## 적용한 동작

- 현재 이름/변경 후 이름의 원문은 그대로 표시한다. 이름 아래 작은 칸에서 첫 번째 변경 글자의 자모·악센트 구성을 비교한다. 추가 변경 글자는 `+개수`와 도움말로 알린다.
- 한글 예: `ㅎ / ㅏ / ㄴ` → `한`. 칸은 설명용 glyph이며 실제 파일명에 자모·공백·구분자를 추가하지 않는다.
- 악센트 예: `e / ◌́` → `é`. 일본어: `か / ◌゛` → `が`. 일본어 부호는 시스템 폰트 fallback에서 사라지지 않도록 독립 표시형으로 그리되 원래 scalar 코드는 U+3099/U+309A로 보존한다.
- 상태는 분해형 / 혼합형 / 조합형(NFC). 단순 분해형이 아닌 canonical singleton·순서 변경 사례는 다른 문자 구성으로 표시한다. 충돌·접근 오류·미지원 등의 안전 상태는 덮어쓰지 않는다.
- 상단 안내와 도움말/확인창에 분해형은 오류가 아니며 NFC로 통일할 수 있다는 설명을 제공한다.
- 상세 보기에 모든 글자를 순서대로 표시하고 현재/NFC 구성, Unicode scalar 코드를 비교한다. 기존 4가지 정규화 형태와 UTF-16 정보는 확장 영역에서 확인한다.
- ko/en/ja, 시스템·다크·라이트·올리브 아카이브에 적용한다.

## 구현 경계

App/CharacterPresentation.swift는 읽기 전용 표시 모델이다. 원문 grapheme의 bytes와 NFC bytes로 차이를 판단하고, 한글 자모의 친숙한 독립 glyph와 결합 부호의 dotted circle을 표시한다. 표시 glyph는 scanner/plan/executor에 전달하지 않는다. App/CharacterViews.swift는 보이는 행에서만 설명을 계산하며 긴 이름은 첫 변경 글자만 간략히 표시한다. 전체 구성은 Inspector의 lazy 목록에서 제공한다.

Core 정규화 판정, 실제 mutation/Undo/Recovery, 사용자 파일 및 생성된 테스트 자료는 변경하지 않았다.

## 관련 실행

- `eng/test.sh --filter CharacterPresentationTests`: 5개 통과. 한글 원시 byte 불변, 실제 scalar 코드, 일본어/악센트, canonical variant, NFC/호환 문자/emoji 유지, 긴 이름/숨은 문자 검증.
- `eng/build.sh --configuration Debug --arch arm64`: 성공.
- `python3 eng/validate-resources.py`: 226키 × 3언어, placeholder 및 리소스 확인 통과.
- Debug `--render-characters`: 900pt 목록 12개와 상세 보기 3개, 총 15개 실제 SwiftUI/AppKit off-screen 렌더. 사용자 창은 조작하지 않았다.
- 증거: `artifacts/development/character-explanation/`.

현재 앱은 `artifacts/development/Moongchi NameFix 문자구성 Dev.app`이다. 실행 중일 수 있는 이전 Dev 앱은 교체하거나 종료하지 않았다. 이전 앱을 종료한 뒤 이 앱을 열어 확인한다. Release/패키징은 수행하지 않았다.
