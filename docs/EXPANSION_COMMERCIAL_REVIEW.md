# 확장 개발 후 앱 자체 재판정

> 후속 v1.0 재판정은 [V1_RELEASE_STATUS.md](V1_RELEASE_STATUS.md)가 우선한다. 아래 SOURCE_RACE 단독 미완성 판정은 이전 이력이다. 조정/감지/보존을 보완했으며 현재 공개 출시 대기는 실제 판매 연결·출시 식별자·공증·실사용 Gate와 구분한다.

**미완성 — SOURCE_RACE 1건 때문에 전체 상용 완성을 선언하지 않는다.** 무료·Pro의 독립 기능 구현은 마쳤다. 실제 판매 연결과 출시 QA/서명/공증은 이 판정에서 제외한다. 화면 미확인만으로 결함을 추가하지 않는다.

| 영역 | 남은 실제 개발 결함 | 근거/처리 |
|---|---|---|
| 기능 | 없음(아래 정의한 구현 범위) | Free/Pro 규칙, CSV, metadata, pair, watcher, CLI와 안전 경계 구현. 실제 판매 adapter는 별도 외부 조건 |
| 성능 | 확정된 멈춤/끊김 결함 없음 | worker 격리, 제한된 descriptor cache, 단일 부모 조회 재사용, 정규식 첫 timeout에서 전체 preview 중단. 10k 결과와 내부 목표 미달/미측정 범위는 성능 기록에 명시 |
| 사용자 경험 | 없음(코드/직접 모델/렌더 검토 범위) | 원시 문자 비교, 일반 rename/NFD 상태 구분, 행 오류, 취소, 키보드 수동 순서, 감시 baseline·쓰기 대기·확인 snapshot, 오류 후 원본 보존 |
| 디자인 | 없음(검토한 33개 실제 SwiftUI 렌더 범위) | 기존 카드/목록/정보 보존, ko/en/ja, 네 테마, 320pt/1180pt 및 규칙/감시 sheet. 모든 화면 크기를 수학적으로 보증한다는 뜻은 아님 |
| 안정성 | SOURCE_RACE | `Infrastructure/FileSystem.swift`, `Transaction.swift`, `GraphTransaction.swift`. 마지막 identity 확인 뒤 외부 source 교체 시 다른 항목이 temporary로 옮겨질 가능성. post-check 중단·기록·관찰 위치·자동 추정 복구 차단은 구현했지만 Darwin에 expected-inode rename 계약이 없어 원자 예방을 증명할 수 없음 |

고친 실제 결함: normal 이름의 규칙 변경 누락, 일반 rename의 자소 분리 오표시, NFD 후 문자 칸 불일치, preview 이후 metadata 변경, swap 경로의 연쇄 오해석, cycle 부분 완료 복구 누락, 파일 쌍 일부 source가 빠졌을 때 나머지만 남는 plan, 재시작한 watcher의 반복 제안, 중간 본문을 비운 규칙 조합의 확장자 손실, 큰 CSV의 메인 스레드 처리, 병적 regex를 파일마다 계속 재시도하는 경로.

SOURCE_RACE를 완전히 해소하려면 OS의 expected-inode 조건부 rename 또는 모든 writer가 참여하는 배타 접근 계약이 필요하다. 앱의 advisory lock/NSFileCoordinator/재검사만으로 비협조 writer까지 막는다고 선언하지 않는다. 이 조건을 임의로 약화해 DONE 처리하지 않았다.

구현/직접 검증/실행 앱/fixtures는 [EXPANSION_DEVELOPMENT.md](EXPANSION_DEVELOPMENT.md), 사용법과 실제 지원 범위는 [EXPANSION_USER_GUIDE.md](EXPANSION_USER_GUIDE.md)를 따른다. 과거 NFC-only 판정과 확장 구현을 혼동하지 않는다.

별도 단계: 실제 판매 공급자·상품 ID 연결, 출시 QA·스모크·서명·공증·앱스토어 심사·배포 준비.
