# UI/UX 디자인 계약

## 제품 경험

첫 사용자는 복잡한 규칙 편집보다 자소 분리 문제 해결을 먼저 이해할 수 있어야 한다. 고급 사용자는 같은 앱에서 일괄 변경·프리셋·CSV·메타데이터·감시로 확장할 수 있어야 한다. 안전 상태와 실제 mutation 확인은 화면 단순화를 위해 숨기지 않는다.

주 방향은 Native · Quiet · Utility다. 제품 시그니처는 다음 네 가지다.

- 자소 분리 해결을 첫 화면에서 짧은 흐름으로 끝낸다.
- 실제 변경 전 현재 이름과 변경 후 이름, 제외/충돌 이유를 항상 확인할 수 있다.
- 고급 규칙은 별도 작업실로 격리해 기본 화면의 인지 부하를 낮춘다.
- 기록/Undo/Recovery는 성공 메시지보다 실제 파일 상태와 확인 가능성을 우선한다.

## 정보 구조

native sidebar의 현재 목적별 메뉴:
- 자소 분리 해결
- 이름 일괄 변경
- 텍스트 변환
- 폴더 감시
- 검사 결과 CSV 저장
- 설정 진입

sidebar는 macOS 창 장식/traffic lights와 자연스럽게 이어지고 필요 시 접을 수 있다. 가짜 traffic light나 웹 대시보드형 중첩 카드로 대체하지 않는다.

## 간편 화면

자소 분리 해결은 입력 → 검사/변경 결과 확인 → 선택한 이름 합치기 → 최종 확인 순서다. 간편 화면에서는 NFC 중심 파이프라인을 사용하고, 작업실의 고급 초안을 몰래 실행하지 않는다.

작업실에서 수정한 규칙이 아직 실제 Preview에 적용되지 않았으면 stale 상태를 명확히 표시하고 Rename 진입 자체를 차단한다. 간편 화면으로 돌아갈 때 고급 규칙은 실행 파이프라인에서 제거하지만 현재 세션의 작업실 초안은 보존할 수 있다.

## 일괄 변경 작업실

넓은 창은 규칙 편집과 파일별 결과를 병렬로, 좁은 창은 규칙과 결과를 세로 흐름으로 보여 준다. 사용자가 Preview 갱신을 명시적으로 수행한 뒤만 변경 가능한 상태가 된다.

Free/Pro는 화면 진입을 불필요하게 분리하지 않고 기능별 capability로 표현한다. Pro 권한이 사라졌을 때 Pro 초안이 무료 규칙으로 자동 적용된 것처럼 보이면 안 된다.

## 문자 구성 설명

분해형 이름 자체를 손상/오류로 표현하지 않는다. 원문 이름은 그대로 표시하고, 설명용 칸에서 첫 변경 grapheme의 내부 구성을 친숙한 glyph로 보여 준다. 상세 보기에서는 실제 Unicode scalar와 현재/NFC 구성을 확인할 수 있다.

표시용 자모·결합기호 glyph는 mutation 데이터로 다시 사용하지 않는다. 보이는 이름과 raw Unicode 판정의 책임을 분리한다.

## 테마와 표면

테마는 System, Dark, Light, Olive Archive 네 가지다. 새 설정이 없는 첫 실행의 제품 기본은 Olive Archive이고 저장된 사용자 선택은 보존한다. Olive sidebar의 기준 색은 #DDD8C5다.

macOS native toolbar, menu, sheet, popover, focus, overflow를 우선 사용한다. 장식용 과한 blur/animation과 반복 카드 중첩을 기본값으로 쓰지 않는다.

## 반응형 창

- 넓은 영역은 native sidebar + 결과 Table 중심.
- 좁은 영역은 같은 정보와 동작을 세로 카드/행으로 재배치하며 기능을 삭제하지 않는다.
- 낮은 창은 세로 scroll을 제공하고 극단적으로 좁은 폭에서도 콘텐츠 접근 경로를 남긴다.
- 첫 실행 크기는 화면 visibleFrame을 기준으로 잡고 이후 일반 창 위치·크기·화면을 복원한다.
- 전체 화면/최소화 전환이 일반 window placement를 오염시키지 않는다.
- 크기 변경만으로 scan/selection/settings를 초기화하지 않는다.

수치 breakpoint는 실제 WindowLayout 구현이 원본이며 문서 수치를 고정 계약으로 복제하지 않는다.

## 접근성과 다국어

ko/en/ja를 지원한다. Pretendard/Pretendard JP와 시스템 fallback을 사용한다. 긴 일본어·영어 문구, keyboard focus, Full Keyboard Access, VoiceOver, 큰 글자, 대비/투명도 설정을 고려한다.

자동 렌더와 model test는 Engineering Verification이다. 실제 VoiceOver/키보드/연속 resize/Finder gesture User QA를 대체하지 않는다. 남은 항목은 QA.md에 모은다.

## 변경 원칙

기존 화면은 기본적으로 KEEP이다. 실제 문제 근거가 있는 화면만 CHANGE, 필요한 상태만 ADD, 중복/혼란이 입증된 항목만 REMOVE한다. 새 참고자료나 만능프롬프트 적용만을 이유로 전체 UI를 재설계하지 않는다.
