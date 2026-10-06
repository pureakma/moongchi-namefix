# Moongchi NameFix 확장 일괄 개발 실행 지침

> v1.0 후속: 사용자 상용 출시 요청으로 Release·서명·패키지 작업을 진행한다. SOURCE_RACE는 보완 후 알려진 제한과 실제 출시 외부 조건으로 구분하며 최신 판단은 [V1_RELEASE_STATUS.md](V1_RELEASE_STATUS.md)가 우선한다. 이전 확장 단계 정책은 이력으로 보존한다.

이 문서는 개발 AI에게 전달할 실행 지침이다. 전체 요구사항은 [EXPANSION_PLAN.md](EXPANSION_PLAN.md), 작업 순서와 현재 상태는 [EXPANSION_TASKS.md](EXPANSION_TASKS.md)가 기준이다. 계획 작성 요청만으로 아래 구현을 실행했다고 보고하지 않는다. 사용자가 일괄 개발 실행을 지시하면 아래 내용을 수행한다.

## 시작

1. 현재 작업 경로와 적용되는 AGENTS.md, Git 변경 여부, PROJECT_STATUS.md, EXPANSION_TASKS.md를 읽는다. Git이 없어도 개발은 가능하다. 사용자 파일을 reset/clean/stash/delete하지 않는다.
2. EXPANSION_PLAN.md를 읽고 현재 작업 관련 ARCHITECTURE.md, FILESYSTEM_CAPABILITIES.md, KNOWN_LIMITATIONS.md 및 실제 소스를 확인한다. 과거 Feature Complete와 현재 확장 완료를 혼동하지 않는다.
3. 기존 체크포인트가 있으면 이어서 수행한다. 없다면 E00부터 시작한다. 환경은 sw_vers, uname -m, xcode-select -p, xcodebuild -version, swift --version과 실제 SDK로 확인한다. macOS 14 이상 Apple Silicon arm64만 개발한다.
4. 단계별 승인 질문 없이 구현 → 관련 검증 → 수정 → 문서/상태 갱신 → 다음 미완료 작업을 반복한다. 계획 재작성이나 목업만으로 완료하지 않는다.

## 작업 규칙

- 무료는 NFC/NFD·텍스트·Finder/메뉴바·안전/복구·기본 문자 편집·일반 순번·무료 규칙 조합·기본 결과 export·같은 기능의 CLI를 제공한다. Pro는 정규식·조건·고급 순번·사용자 프리셋·CSV 가져오기·메타데이터·파일 쌍·감시/규칙 연계를 제공한다. 자세한 경계는 계획 표를 따르며 F/P 추적 ID로 요금제를 판단하지 않는다. 무료 기본 규칙의 조합에는 단계 수 제한을 두지 않는다.
- 기존 카드·정보·설정·창 복원과 사용자의 저장 데이터를 보존한다. Olive 기본, System/Dark/Light/Olive, ko/en/ja를 모든 새 화면에 적용한다.
- mutation은 공통 fresh Plan과 명시 확인을 거친다. CLI·메뉴바·watch·프리셋에 우회 rename을 만들지 않는다. 실제 사용자 파일 대신 전용 임시 fixture로 검증한다.
- AI·RAG·OCR·서버 업로드·웹판·Windows/Intel·cross-volume 이동·덮어쓰기는 추가하지 않는다. 외부 도구의 코드를 실행하거나 종속성으로 넣기 전에 필요성과 라이선스를 확인한다.
- SOURCE_RACE는 테스트 재현 성공을 해결 PASS로 바꾸지 않는다. 플랫폼상 원자적 보장이 없으면 근거와 blocker를 남기고 독립 개발을 계속한다. 위험 수용 결정을 대신하지 않는다.
- 외부 인증서·판매 상품 ID·키·판매 정책이 필요한 작업만 보류한다. UI·Core·권한 모델·개발 provider·Debug 앱은 계속한다. 개발 provider를 실제 결제 검증으로 표시하지 않는다.
- 사용자 화면을 제어해야 하는 검증은 별도 사용자 확인 항목으로 전달한다. 미확인만으로 결함이라고 쓰지 않는다.
- commit/push·Release·패키징·서명·공증·배포는 별도 명시 지시 없이는 실행하지 않는다.

## 검증과 체크포인트

기존 명령은 다음과 같다. 매 작업 전부 실행하는 목록이 아니며 영향에 맞는 명령만 선택한다.

```sh
eng/test.sh --level 1 --scope unicode
eng/test.sh --level 1 --scope ui-model
eng/test.sh --level 1 --scope filesystem
eng/test.sh --level 1 --scope transaction
eng/test.sh --level 1 --scope safety
python3 eng/validate-resources.py
eng/build.sh --configuration Debug --arch arm64
```

새 suite는 실제 이름을 확인해 --filter로 실행한다. eng/test.sh의 --scope ui-model은 AppModelTests만 선택하므로 WindowLayoutTests 등 다른 suite까지 검증했다고 쓰지 않는다. Phase Gate는 해당 단계 build/tests, 확장 전체 연결 이후에만 통합 Debug 테스트를 수행한다. 문서 변경만으로 앱 빌드를 반복하지 않는다.

각 작업 종료 때 EXPANSION_TASKS.md에 변경 파일·실제 명령·결과·오류 경로·근거를 남기고 PROJECT_STATUS.md의 현재 작업과 다음 작업을 갱신한다. 구조가 바뀌면 ARCHITECTURE.md, 계약이 바뀌면 FILESYSTEM_CAPABILITIES.md를 갱신한다. .ai/validation-cache.json은 실제 영향을 받은 코드·테스트·환경의 fingerprint로 갱신한다.

세션 종료나 컨텍스트 전환 때 현재 ID, 미완료 부분, 실행 중 명령, 다음 ID를 남긴다. blocker가 있어도 독립 작업이 남아 있으면 진행한다. 반복 실패는 원인을 기록하며 무제한 재시도하지 않는다.

## 종료 기준과 보고

E00~E25를 구현·검증하고 다섯 영역으로 재판정한다. 실제 미해결 결함이 있으면 우선순위대로 고치고 관련 회귀를 수행한다. 해결 불가능한 안전 계약이나 외부 조건이 남으면 정확한 상태와 근거를 보고하며 완료라고 꾸미지 않는다.

최종 보고에는 무료/Pro 실제 완료 범위, 검증 결과, 남은 blocker, 실행 가능한 최신 Debug 앱과 보고서의 절대 경로를 제공한다. 가격·매출·경쟁 우위는 검증 없이 확정하지 않는다. 출시 작업은 별도 단계 한 줄로 구분한다.
