# 파일시스템 안전·권한 계약

## 지원 범위

실제 이름 mutation 지원 범위는 검증된 local writable APFS다. 기본 scan은 사용자가 명시적으로 선택한 로컬/마운트 파일 URL을 대상으로 하며, mutation 지원 여부와 단순 읽기/분석 가능 여부를 구분한다.

보수적으로 보호하거나 mutation을 차단하는 대상:
- symlink와 Finder alias
- 앱/package와 보호된 특수 경로
- 알려진 cloud/FileProvider 위치
- HFS+, exFAT, SMB/NAS, 외장 등 현재 mutation 계약을 검증하지 않은 파일시스템
- 접근 권한을 얻지 못했거나 identity를 안전하게 확인할 수 없는 항목

미지원 대상을 자동으로 우회하기 위해 root나 Full Disk Access를 요구하지 않는다.

## 비협상 안전 규칙

- 사용자 파일 내용을 이름 변경을 위해 변환·덮어쓰기·삭제하지 않는다.
- 기존 destination을 덮어쓰지 않는다.
- 실행 전에 fresh Plan, 충돌/제외 검사, 명시 확인을 거친다.
- mutation 전에 durable intent를 기록한다.
- source → unique temporary → final의 no-replace 흐름을 사용한다.
- 실제 directory entry raw 이름과 identity를 기준으로 확인한다.
- 실패/취소/경합 시 성공을 추정하지 않고 실제 위치와 journal을 보존한다.
- identity가 불명확한 파일을 이름만 보고 자동 복원하지 않는다.
- 테스트 mutation은 전용 disposable fixture에서 수행하고 사용자 실데이터를 자동 fixture로 사용하지 않는다.

## APFS와 Unicode

APFS의 lookup 동등성과 실제 저장된 raw spelling을 같은 것으로 취급하지 않는다. Swift String의 canonical equality 역시 파일 이름의 raw bytes 동일성을 뜻하지 않는다.

Scanner와 transaction 경로는 실제 directory entry의 raw name과 identity를 보존하고, 정규화만 다른 이름을 Preview/검증에서 놓치지 않도록 한다.

## 동시 변경과 알려진 제한

NSFileCoordinator를 사용해 조정에 참여하는 프로그램과 이동을 협의하고, 접근을 얻은 뒤 source/parent raw path·identity·일반 파일의 version 정보를 다시 확인한다. 실제 이동 직후에도 결과를 확인하며 mismatch가 나오면 후속 작업을 중단한다.

그러나 macOS에서 사용하는 현재 rename 계약은 비협조 외부 writer에 대해 expected inode를 원자 조건으로 걸어 source 교체 자체를 완전히 막는 보장을 제공하지 않는다. 마지막 확인 뒤 다른 프로세스가 source leaf를 교체하면 다른 identity가 temporary 위치로 이동할 수 있다.

사용자 취소는 처리 중인 항목을 마친 뒤 적용한다. 단일 항목 이동은 취소 때문에 임시 이름에 남지 않는다. swap/cycle/묶음 파일 그룹은 그룹 도중 취소하면 일부가 임시 이름에 남을 수 있으며 Recovery로 확인·복원한다.

현재 대응은 감지·즉시 중단·journal/관찰 위치 보존·Finder에서 확인 가능한 Recovery 안내다. 이 한계를 원자 예방 PASS라고 표현하지 않는다. 작업 중 같은 항목을 다른 앱에서 동시에 저장·이동하지 않는 것이 지원 조건이다.

## 기록 손상 시 동작

Undo와 Recovery는 전체 작업 기록으로 현재 경로를 추적한다. 읽을 수 없는 journal(쓰기 도중 전원 차단, 더 새 버전의 기록 등)이 하나라도 있으면 원본을 보존하고 Undo/Recovery 계획 생성을 막는다. 잘못된 경로 추적으로 다른 항목을 건드리지 않기 위한 보수적 차단이며, 손상 기록을 건너뛰는 부분 복구는 현재 제공하지 않는다.

## 권한과 개인정보

- Desktop/Documents/Downloads 등 TCC 보호 위치는 macOS의 사용자 허용을 따른다. 권한 안내 문구는 ko/en/ja로 제공한다.
- 권한 거절은 항목 오류로 격리하고 권한을 우회하지 않는다.
- 기본 scan은 사용자 파일 내용을 열어 hash하지 않는다.
- 사용자가 metadata 규칙을 선택했을 때만 지원 형식의 제한된 metadata를 읽기 전용으로 추출한다.
- 진단 정보에는 경로, clipboard 원문, 파일 내용을 기본값으로 기록하지 않는다.
- 핵심 기능에 원격 업로드나 텔레메트리가 없다.

## 별도 실기 검증

자동 fixture가 대체하지 못하는 항목:
- 실제 TCC 허용/거절
- Finder Services/Dock/Open With
- 실제 process kill/전원 차단의 모든 timing
- macOS 14 실제 하한 OS
- 외장/SMB/cloud 환경
- 깨끗한 Mac에서 서명·공증 패키지

현재 대기 항목은 QA.md가 원본이다.
