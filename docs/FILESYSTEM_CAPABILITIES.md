# 파일시스템 안전·권한 계약

## 지원 범위

이름을 바꿀 수 있는 곳은 로컬 writable APFS다. 내장 디스크와 외장 APFS 드라이브, 대소문자 구분 여부를 가리지 않는다. 그 밖의 위치는 목록에 보여 주고 이유를 알린 뒤 그대로 둔다. 앱은 지원 밖의 위치 때문에 실패하지 않는다.

지원 수준은 Infrastructure의 FS.support 하나가 판정하고(VolumeSupport), 검사·계획·실행·화면이 같은 답을 쓴다. 모든 mutation 경로는 FS.capability를 통과해야 하며 이 gate는 supported가 아니면 그 volume의 이유를 던진다.

| 위치 | 수준 | 화면에 보이는 이유(key) | 근거 |
|---|---|---|---|
| APFS, 로컬, 쓰기 가능(내장·외장, 대소문자 구분/미구분) | supported | 없음 | 저장된 raw 이름을 그대로 돌려준다. RENAME_EXCL이 있다. mount된 동안 identity가 유지된다. 아래 ‘volume 검증’의 모든 계약 PASS |
| APFS, 로컬, 읽기 전용 | previewOnly | VolumeReadOnly | raw 이름은 신뢰할 수 있어 바뀔 이름을 보여 주지만 바꿀 수 없다 |
| exFAT, FAT(msdos) | unsupported | VolumeFATUnsupported | macOS가 저장된 이름과 무관하게 항상 분리형으로 보여 줘서 저장된 spelling을 관찰할 수 없다. exFAT은 RENAME_EXCL이 없고 identity가 remount마다 바뀐다. 아래 ‘exFAT·FAT 실험’ |
| HFS+ | unsupported | VolumeNormalizationUnsupported | 모든 이름을 분리형으로 저장해서 합친 이름이 유지되지 않는다 |
| 네트워크(SMB/NAS/NFS 등 MNT_LOCAL이 아닌 volume) | unsupported | VolumeNetworkUnsupported | raw 이름·identity·no-replace·복구 계약을 검증하지 않았다 |
| 그 밖의 형식(NTFS 등) | unsupported | VolumeFormatUnsupported | 검증하지 않았다 |
| iCloud Drive·CloudStorage·FileProvider 위치, dataless 항목 | 제외 | CloudLocationExcluded | 동기화 상태가 작업 중에 바뀔 수 있다(placeholder, eviction, 원격 경합). 폴더 내용은 읽지 않아 cloud에서 내려받지 않는다 |
| 추가한 디스크 자체(mount point) | 이름 제외 | VolumeRootExcluded | mount point 이름은 바꾸지 않는다. 안의 항목은 그 volume의 수준에 따라 검사한다 |
| 검사 도중 만난 다른 volume | 제외 | MountBoundaryExcluded | 사용자가 직접 추가한 volume만 검사한다 |

그 밖에 보호하거나 mutation을 차단하는 대상:
- symlink와 Finder alias
- 앱/package와 보호된 시스템 경로
- 접근 권한을 얻지 못했거나 identity를 안전하게 확인할 수 없는 항목

미지원 대상을 자동으로 우회하기 위해 root나 Full Disk Access를 요구하지 않는다. 지원 수준을 경쟁력 때문에 올리지 않는다. 수준을 올리려면 아래 volume 검증의 모든 계약을 그 형식에서 통과시키고 이 표를 고친다.

## volume 검증

eng/test-volumes.py가 새 임시 폴더에 일회용 sparse image를 만들어(-nobrowse) 검증하고 detach·삭제한다. 자기가 붙인 image만 detach하며 사용자의 디스크를 포맷하거나 쓰지 않는다. 대상은 APFS, 대소문자 구분 APFS, exFAT, FAT32다.

APFS 두 종류에서 통과하는 계약(2026-10-07, macOS 27.0.1):
- scan, raw 저장 이름, 합침형/분리형 진단, Preview(VolumeMatrixTests, FilesystemTests)
- 이름 변경: source → 임시 이름 → 최종 이름, RENAME_EXCL, 이미 있는 대상·canonical-equivalent 대상·대소문자만 다른 대상·폴더/파일 충돌·hardlink를 덮어쓰지 않음(VolumeMatrixTests, SafetyTests, CoordinatedTransactionTests)
- 폴더와 그 안의 항목을 함께 변경, 취소, Undo, 모든 이동 지점에서의 Recovery, journal(TransactionTests, ExpansionTests)
- 조정에 참여하는 writer와의 조정, 경합 주입에서의 중단(CoordinatedTransactionTests)
- volume을 뗀 뒤: 계획이 비고 아무것도 추정하지 않으며 기록은 읽힌다
- 다른 device 번호로 다시 붙인 뒤: 같은 volume임을 UUID로 확인하고 Undo가 raw 이름을 byte 단위로 복원한다
- 같은 자리에 다른 디스크를 붙인 경우: 폴더·이름·생성 시각을 기록과 똑같이 맞춰도 계획하지 않는다
- 읽기 전용으로 붙인 경우: previewOnly, 계획 없음, rename 실패, 이름 불변

대소문자 구분 volume에서는 대소문자만 다른 이름이 서로 다른 이름이라 충돌이 아니고, 미구분 volume에서는 충돌이다. 합침형과 분리형은 두 종류 모두에서 같은 이름이다(둘이 함께 존재할 수 없다). 계획의 중복 대상 판정은 두 종류 모두에서 대소문자를 무시해 보수적으로 제외한다.

disk image는 macOS에 External·Removable volume으로 보이지만 실제 외장 장치는 아니다. 실제 외장 APFS 장치에서의 확인은 EXTERNAL_APFS_HARDWARE_QA_PENDING이다(전원·케이블 분리 timing, 장치별 flush 동작은 image로 재현되지 않는다).

## volume identity와 다시 연결

device 번호(st_dev)는 mount할 때마다 새로 정해진다. 실험에서 같은 APFS image를 다른 순서로 다시 붙이자 번호가 바뀌었다. 그래서 계획한 작업마다 volume UUID를 함께 기록하고(RenameOperation.volume), Undo와 Recovery는 기록의 UUID와 지금 그 자리에 mount된 volume의 UUID가 같을 때만 device 번호를 현재 값으로 바꿔 확인한다. 파일 번호와 생성 시각은 그대로 정확히 일치해야 한다. UUID가 다르면 번호가 우연히 같아도 기록을 쓰지 않는다. UUID가 없는 예전 기록은 device 번호까지 일치해야 하며, 다시 연결해서 맞지 않으면 UndoAfterReconnect로 이유를 알리고 그대로 둔다.

## App Sandbox (스토어판)

스토어판은 App Sandbox 안에서 돈다. 지원 범위(로컬 writable APFS)와 비협상 안전 규칙은 직접 배포판과 같다. 달라지는 것은 walk의 시작점이다(D-033).

- 직접 배포판은 "/"부터 모든 조상을 O_NOFOLLOW로 연다. 스토어판은 조상을 열 수 없어, 사용자가 허용한 폴더에서 시작해 그 아래를 같은 방식으로 연다. 그 아래로 link를 따라가지 않고, 허용한 폴더 밖은 열지 않는다.
- 허용한 폴더가 옮겨지거나 같은 경로에 다른 폴더가 놓이면 그 허용은 쓰지 않는다.
- 다시 실행한 뒤의 접근은 bookmark로 얻되, bookmark가 연 폴더의 volume UUID와 identity가 기록과 같을 때만 쓴다(D-034). bookmark, volume UUID, 파일 identity의 역할: bookmark는 macOS에서 접근을 다시 받는 열쇠, volume UUID는 그 디스크가 기록의 디스크인지, 파일 identity(파일 번호와 생성 시각)는 그 항목이 기록의 항목인지를 확인한다. 셋이 모두 맞아야 Undo가 진행된다.
- 접근이 없으면 계획하지 않고 그 폴더를 고르게 한다. 추정으로 실패 처리하거나 다른 항목을 건드리지 않는다.

직접 배포판과의 차이:
- 추가한 폴더 자체의 이름은 바꾸지 않는다(그 이름은 앱이 열 수 없는 부모 폴더에 있다). 부모 폴더를 추가하면 바꿀 수 있다.
- 파일만 추가하면 그 파일이 든 폴더를 한 번 골라야 검사와 변경이 된다.
- 위 두 가지는 줄일 수 없는 차이다. 실제 sandbox에서 넘겨받은 폴더 자체와, 폴더 없이 넘겨받은 파일의 이름을 바꾸려는 rename을 시스템이 거부하는 것을 확인했다(2026-10-07, eng/test-sandbox.py). 충돌 검사·raw 이름 확인·폴더 fsync도 부모 폴더를 열어야 할 수 있다.
- 허용한 폴더보다 위의 package·앱 여부는 속성을 읽을 수 없어 이름(확장자)으로 판단한다.
- CLI가 없다(D-035).

검증(eng/test-sandbox.py, 2026-10-07, macOS 27.0.1): 스토어 entitlement로 서명한 Debug 앱을 실제 sandbox에서 실행하고 폴더를 `open -a`(Finder의 ‘다음으로 열기’와 같은 경로)로 넘긴다. 단계마다 새로 실행하며 클릭은 없다. 통과한 것: 넘겨받은 폴더의 검사·이름 변경, 폴더 안의 link를 따라가지 않음, 옆 폴더는 시스템이 거부, 재실행 뒤 남겨 둔 bookmark로 Undo(byte 단위 복원), 남겨 둔 접근이 없을 때 폴더 요청과 무변경, 즐겨찾기·최근 폴더의 재실행 뒤 열기, 폴더 감시가 재실행 뒤 bookmark로 시작해 새 파일을 알아챔, 파일 하나만 넘겼을 때 폴더 요청, 외장 APFS image를 다른 device 번호로 다시 붙인 뒤 Undo, 같은 자리에 다른 디스크를 붙였을 때 거부. 파일 선택 창을 눌러서 받는 권한과 잠자기/깨우기는 사람이 확인한다(QA.md).

## exFAT·FAT 실험

일회용 image에서 확인한 사실(2026-10-07, macOS 27.0.1, 두 형식 모두 FSKit driver):
- 합침형으로 만든 이름(한글, é, が)이 목록에는 분리형으로 나온다. image의 raw bytes를 직접 읽어 보면 디스크에는 합침형(UTF-16)으로 저장돼 있고 분리형으로 만든 이름도 합침형으로 저장된다. 즉 macOS는 이 형식에 합침형으로 저장하고 분리형으로 보여 준다. 여기서 보이는 ‘분리된 글자’는 저장된 모습이 아니며, 다른 OS가 쓴 이름이 실제로 어떤 형태인지도 macOS에서 구분할 수 없다. 이름 진단 자체가 성립하지 않는다.
- exFAT: renameatx_np(RENAME_EXCL)이 ENOTSUP이다. 덮어쓰지 않는 rename을 보장할 수 없다. 파일 번호가 remount 뒤에 바뀐다.
- FAT32: RENAME_EXCL은 동작했지만 이름을 바꿀 때 파일 번호가 바뀌는 것을 관찰했다.
- 두 형식 모두 hardlink가 없고 확장 속성이 ._ 파일로 따로 생긴다.
- macOS 14·15의 kernel driver에서는 확인하지 않았다. driver가 달라도 위 첫 항목(저장된 spelling을 관찰할 수 없음)이 바뀌지 않는 한 판정은 같다.

판정: UNSUPPORTED. PREVIEW_ONLY도 아니다. 보이는 이름이 저장된 이름이 아니어서 미리보기가 사실과 다르기 때문이다. 앱은 항목을 나열하고 VolumeFATUnsupported로 이유를 알리며 계획하지 않는다(VolumeMatrixTests의 testFATVolumeIsListedAndLeftAlone이 이 사실이 바뀌면 실패한다).

Mac ↔ Windows 교환에 주는 뜻: Mac에서 exFAT·FAT USB로 복사한 파일은 합침형으로 저장되므로 Windows에서 이름이 풀어져 보이지 않는다. 풀어진 이름이 그대로 넘어가는 경로는 압축 파일, 메일 첨부, cloud·메신저 전송, 네트워크 공유처럼 이름 bytes를 그대로 옮기는 경우다. 그런 파일은 Mac의 APFS 위치에서 정리한 뒤 보내면 된다.

## Windows에서 쓸 수 없는 이름

NameRules.windowsIssues가 read-only로 진단한다: 예약 문자(< > : " / \ | ? *), 제어 문자, 마침표·공백으로 끝나는 이름, 장치 이름(CON, PRN, AUX, NUL, COM1–9, LPT1–9; 대소문자·확장자 무관). 목록 필터와 ‘글자 구성 자세히 보기’에서 알려 줄 뿐 이름을 자동으로 바꾸지 않는다. 이름 길이는 진단하지 않는다(macOS의 255 byte 제한이 Windows의 255 UTF-16 단위보다 항상 좁다). 전체 경로 길이와 폴더 안의 대소문자 충돌은 대상 위치에 따라 달라 진단하지 않는다.

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

이름을 합치거나 분리할 때는 NameForm을 쓴다. 표준 NFC/NFD와 같되 CJK 호환 한자(U+F900–U+FAFF, U+2F800–U+2FA1F)는 저장된 그대로 둔다(D-031). 표준 형태는 그 글자들을 모양이 다른 통합 한자로 바꾸기 때문이다. 전각/반각, 합자, 원문자 같은 호환 변환(NFKC/NFKD)은 하지 않는다. 낱자로 입력한 한글 호환 자모(ㅎㅏㄴ), 독립형 탁점(゛), 반각 가나의 탁점은 합쳐지는 글자가 아니므로 그대로다. 충돌과 동등성 판정에는 파일시스템과 같은 표준 형태를 쓴다.

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
- 실제 외장 APFS 장치(EXTERNAL_APFS_HARDWARE_QA_PENDING), SMB/cloud 환경에서의 안내 문구
- 깨끗한 Mac에서 서명·공증 패키지

현재 대기 항목은 QA.md가 원본이다.
