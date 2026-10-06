# 알려진 제한과 출시 blocker

현재 판정은 [V1_RELEASE_STATUS.md](V1_RELEASE_STATUS.md)를 따른다. 동시 변경 위험을 완전히 없앴다는 보장은 하지 않는다.

- **KNOWN_LIMITATION_SOURCE_RACE**: macOS 파일 조정·원본/부모 재검사·이동 직후 검사·중단/보존·Finder 복구 위치를 구현했다. 조정에 참여하지 않는 writer가 마지막 검사 후 원본을 교체하면 다른 항목이 이동할 수 있고, 감지 후 자동 추정 복원을 하지 않는다. 실제 Rename/Undo/graph 8조합과 destination 경합 2조합으로 보호 동작을 확인했다. 이 상태를 원자 예방 PASS로 표시하지 않는다.
- **BLOCKED_RELEASE_CONFIGURATION_NOTARIZATION**: 유효한 Developer ID를 확인하고 새 후보 앱/CLI 서명에 사용했다. 출시용 bundle ID와 공증 Keychain 프로필이 제공되지 않아 개발용 ID를 유지하고 공증은 미실행이다. Gatekeeper는 Unnotarized Developer ID로 거부한다.
- **BLOCKED_PAID_PROVIDER**: 실제 판매 방식/상품 ID/검증 공급자 미연결. Release 후보는 무료이며 Pro 구매·활성화를 제공하지 않는다. 설정에 이 상태를 명시한다.
- **NEEDS_MANUAL_QA**: 실제 Finder 드래그/Services/Dock, native 메뉴·타이틀바, VoiceOver·키보드·큰글자, TCC, sleep/quit, 실제100k UI latency는 아직 직접 확인하지 않았다. off-screen 렌더와 앱 상태 테스트는 이 증거를 대체하지 않는다.
- **NEEDS_REAL_DEVICE_QA**: macOS14 하한 OS, 외장/SMB/클라우드 실기. Intel/Windows는 사용자 지시에 따라 대상이 아니다.
- 로컬 writable APFS만 변경한다. 알려진 클라우드/FileProvider, symlink/alias/package, 다른 파일시스템은 보수적으로 차단한다. 알 수 없는 타사 동기화 폴더를 모두 자동 식별한다고 보장하지 않는다.
- 실제 kill/전원 차단·하드웨어 durability는 별도다. 자동 테스트는 journal intent/move gap의 상태를 재현하며 결과를 검증한다.
- 성공 journal은 Undo 및 이후 경로 추적에 필요해 설정한 보존 개수보다 오래 유지될 수 있다. 손상 journal은 보존하며, 안전한 전체 시간순 경로 추적을 입증할 수 없으면 Undo를 제한한다.
- 부모의 raw 이름/identity를 확인하지만 외부 이동을 추측해 광범위 검색하거나 복원하지 않는다. 이동/교체되어 확인할 수 없는 항목은 건너뛴다.
- UI를 통해 100k를 실제 스크롤한 결과와 scanner fixture 성능 측정은 별개다. 매우 큰 단일 디렉터리의 mutation은 안전 검증 및 durable write 비용이 크다.


## 확장 개발본의 범위

- 실제 Pro 판매 공급자/상품 ID 미결정(`PAID_PROVIDER_PENDING`). 기능 경계·만료/철회 상태·Debug 공급자는 구현했지만 실제 구매·복원 성공은 주장하지 않는다.
- 메타데이터는 JPEG/TIFF/HEIC, MP3/M4A, MOV/MP4, PDF의 명시한 필드다. 모든 vendor tag/codec/RAW 해석을 약속하지 않는다. PDF 정보는 Spotlight 없이 읽는다. 작은 자체 fixture의 통과는 모든 외부 파일의 증거가 아니다.
- 감시는 자동 발견·대기열이며 자동 rename이 아니다. 파일만 대상으로 하고 감시 root/하위 폴더 이름은 바꾸지 않는다. 처리 baseline을 저장하며 규칙 갱신 시 재검토한다. 실행 중/확인 이후 새 항목은 plan에 추가하지 않는다.
- 개수·크기·regex 시간·descriptor 등의 공통 방어 예산은 무료/Pro에 동일하다. Pro 만료 후 Undo와 기존 프리셋 백업은 제한하지 않는다.
- 10k 이름 처리의 성능 결과는 Debug worker 측정이다. UI 타자/스크롤 p95, 실제 사용자 접근성, 100k metadata/원격 볼륨 성능으로 대체하지 않는다. 계획의 preview 300ms는 목표이며 현재 FS 포함 preview가 이를 초과한다는 측정도 그대로 기록한다.
