# 파일시스템 지원과 안전 계약

개발 환경: artifacts/evidence/environment-current.txt. 실제 arm64 macOS에서 실행했다. 과거 evidence의 /var fixture 실패는 no-follow 정책과 임시 경로 symlink 충돌이며 현재 테스트는 /private/tmp를 사용한다.

## 확인된 계약
- APFS는 NFD 생성 시 raw spelling을 보존했다. NFC lookup도 같은 identity를 가리킨다.
- 두 단계 source → unique temporary → NFC final 후 readdir raw bytes와 identity가 일치한다. 과거 spelling의 lookup이 계속 성공하는 것은 APFS 정상 동작이다.
- renameatx_np(RENAME_EXCL)는 기존 destination을 덮어쓰지 않는다. 확인 뒤 destination이 생긴 100개 interleaving fixture도 원본/기존 대상 identity를 보존했다.
- Swift String canonical equality와 raw Data equality는 구분한다. EILSEQ(92)로 APFS가 invalid UTF-8 생성 자체를 거부했으며 invalid 모델 fixture는 별도로 검증했다.
- F_GETPATH로 열린 부모 descriptor의 실제 raw 경로를 보존한다. NFC/NFD 부모 경로로 중복 입력해도 동일 entry를 한 번만 등록하고 입력 root를 현재 경로로 갱신한다. 이 API를 파일 hardlink identity로 사용하지 않는다.
- Finder alias는 directory-FD 기준 getattrlistat(ATTR_CMN_FNDRINFO)의 alias flag로 검사하며 실제 bookmark alias fixture와 대조했다. SF_DATALESS placeholder는 변경 대상에서 제외한다.
- openat(O_NOFOLLOW | O_DIRECTORY)로 모든 조상 component를 확인한다. symlink와 alias, 앱/package, .git, 알려진 FileProvider/iCloud 위치는 제외한다. 정상 파일 내용은 열지 않는다.
- local APFS, writable capability만 mutation 허용한다. 다른 볼륨은 fail closed. 이름 길이는 fpathconf(_PC_NAME_MAX)로 확인하고 NUL, '/', '.', '..'를 차단한다.
- journal write/fsync/fullsync 실패는 mutation을 중단한다. 임시 원본을 삭제하거나 copy-delete/overwrite fallback을 하지 않는다.

## 원본 교체 경합의 플랫폼 한계 — RELEASE BLOCKER
Darwin에는 expected inode 조건부 atomic rename 계약이 없다. directory FD와 변경 직전 lstat 검증 사이에도 외부 프로세스가 leaf를 교체할 수 있다. testSourceRaceCannotBeAtomicExpectedInodeRename가 이 interleaving을 재현했다. post-move 검증은 mismatch를 감지해 더 진행하지 않지만, 교체된 항목이 임시 이름으로 옮겨지는 순간까지 예방하지 못한다. 완전한 source-race 방지나 임의의 외부 writer와의 원자성을 주장하지 않는다.

로컬 QA는 다른 프로그램이 같은 경로를 이동/교체하지 않는 통제된 fixture에서만 검증됐다. 실제 사용자 동시 writer 환경의 무조건적 안전성은 출시 통과가 아니다. 모호한 상태는 파일/기록을 보존하고 수동 검토한다.

## 별도 검증 경계
- APFS case-sensitive 디스크 이미지: 실행 결과는 QA 보고서에 기록.
- HFS+는 NFC raw 유지 보장을 제공하지 않아 변경 차단. exFAT/SMB/NAS/외장/클라우드는 실기 검증 전 차단.
- TCC 허용/거절 및 외장 제거는 실제 사용자 세션의 수동 QA 필요. Full Disk Access/root를 요구하거나 우회하지 않는다.
- 최소 macOS 14 실행은 실제 해당 OS 장비 미검증이다. 배포 target 14.0 컴파일과 최신 개발 장비 실행은 별도 증거이다.
- RENAME_EXCL/파일 durability는 crash/전원 차단의 모든 하드웨어 동작까지 보장하지 않는다. 테스트는 각 intent/move gap의 replay 복구를 검증한다.


## 확장 실행 근거 (2026-10-04)

APFS getattrlistat `ATTR_CMN_NAME` fixture에서 NFC/NFD·case alias로 조회해도 readdir의 실제 raw leaf가 반환됨을 확인했다. FS.verify는 직접 storedName과 identity를 비교하여 매 파일마다 디렉터리를 전체 재열거하던 비용을 줄였다. 메타데이터 이전/이후 size/mtime와 Plan 실행 전 contentVersion을 확인한다. Read session은 32개 descriptor로 제한한다. 이 방식도 expected-inode 원자 rename은 아니다.

source와 destination이 기존 계획의 다른 항목인 swap/cycle은 같은 부모 그룹을 전부 temporary로 옮긴 뒤 final을 적용한다. 모든 Prepared를 먼저 durable 기록한다. cancel 후 일부 final과 나머지 temporary가 섞인 fixture, 3-cycle, nested directory swap, Undo, hardlink partial Undo를 통과했다. Graph 또는 파일 쌍 전체의 원자성은 보장하지 않으며 부분 실패는 실제 journal 상태를 보존한다.

현재 실제 파일 변경 지원은 로컬 writable APFS이다. 여전히 OS/외부 writer의 마지막 확인 이후 source 교체를 원자적으로 막을 수 없으며 SOURCE_RACE 재현은 제한을 입증하는 테스트다. 이 결과를 안전 결함 해결 PASS라고 표현하지 않는다.

## v1.0 파일 조정과 지원 계약 (2026-10-04 후속)

최신 결과는 [V1_RELEASE_STATUS.md](V1_RELEASE_STATUS.md)가 기준이다. NSFileCoordinator의 source `.forMoving`, destination `.forReplacing`를 이용한다. Darwin `RENAME_EXCL`은 계속 사용하므로 조정 옵션이 실제 덮어쓰기를 허용하는 것은 아니다. 접근 획득 뒤 raw parent path/identity·source identity·size/mtime를 검증하고, 실제 syscall 후에도 확인한다. regular file만 contentVersion을 저장해 자체 하위 변경으로 인한 directory mtime 오탐을 피한다.

FileCoordination 대기는 cancellation token callback과 15초 timeout으로 취소 가능하다. 취소/timeout과 accessor 진입은 잠금으로 순서를 정한다. accessor 진입 후 timeout은 적용하지 않고 실행 단계의 cancellation checkpoint를 사용한다. worker actor에서 동기로 수행하므로 MainActor를 대기시키지 않는다. 재진입/다중 실행은 기존 transaction actor/flock으로 제한한다.

DEBUG에만 실제 syscall 직전 외부 교체를 주입하는 테스트 initializer가 있다. Release에는 포함되지 않는다. 8개 source 교체 조합(Rename/Undo × 정상/graph × 임시/최종)과 2개 destination 생성 조합을 실제 executor로 검증했다. 정체 불명 항목은 History에서 위치를 보여 주되 자동 복원하지 않는다. NSFileCoordinator 미참여 writer에 대한 expected-inode 원자 rename은 여전히 제공되지 않는다. 이것을 원자 예방 PASS로 바꾸지 않는다.

근거: 설치 SDK Foundation/NSFileCoordinator.h의 동기 coordination·forMoving/forReplacing·cancel 계약, Apple File System Programming Guide의 File Coordinators 절, 실제 fixture. API만으로 전체 writer의 원자 배타성을 주장하지 않는다.
