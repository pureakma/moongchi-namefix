# 개발자 직접 QA 체크리스트

플랫폼: Apple Silicon 전용. 실제 Finder/창 제어는 자동으로 수행하지 않았다. off-screen 렌더는 실제 사용자 드래그·키보드·접근성 PASS가 아니다.

## 준비와 실행

1. artifacts/release-candidate/1.0.0/build3/Moongchi NameFix.app을 Finder에서 연다. ZIP은 풀어서 앱을 열고, DMG는 직접 Applications 링크로 복사할 수 있다.
2. 공개 배포용 서명/공증 전이다. Gatekeeper 설정을 끄거나 검역을 제거하지 않는다. 로컬 빌드 사용 또는 Developer ID 빌드를 준비한다.
3. Terminal에서 **프로젝트 폴더로 이동한 다음**, 실제 파일 대신 전용 fixture를 생성한다:

```sh
eng/create-fixtures.sh --root /private/tmp/namefix-manual-20261003
```

기존 경로는 덮어쓰지 않는다. fixture만 사용하는 테스트이다. 실제 업무 데이터로 시작하지 않는다. 같은 파일을 다른 앱에서 동시에 변경하지 않는다.

## 기록 형식
각 ID 결과를 PASS / FAIL / NOT_AVAILABLE 중 하나로 기록하고 OS·CPU·테마·언어·실제 절차·관찰 결과를 남긴다. FAIL은 화면 사진과 발생 시점/transaction ID를 기록한다. 공유 진단은 기본 마스킹 상태로 내보낸다. 경로와 clipboard text는 별도로 공개하지 않는다.

| ID | 기능·목적 | 환경·준비 | 절차 | 기대 결과 | 증거·로그 | 현재 결과 |
|---|---|---|---|---|---|---|
| UI01 | 실제 전체 창 드롭 | Finder + fixture 폴더 | 파일/폴더 혼합을 sidebar, 중앙, 행, 스크롤 영역에 각각 놓는다 | 같은 입력 흐름, 한 곳의 중앙 안내, 중복 엔트리 없음 | 위치별 화면/항목 수 | NOT_AVAILABLE |
| UI02 | 기본 Olive 및 4테마 | 신규 설정 또는 별도 테스트 계정 | Light OS에서 첫 실행, Dark/Light/Olive/System 변경, OS appearance 변경 후 재시작 | Olive 기본, Olive sidebar #DDD8C5, titlebar/sheet/settings 일관성 | 각 테마 화면 | NOT_AVAILABLE |
| UI03 | 즉시 설정·보존 | fixture 검사 완료 | 언어/테마/행간/열 비율을 빠르게 바꾸고 종료 후 재실행 | 마지막 설정 유지, 저장 버튼 없음, 선택/목록 유지 | 재실행 전후 설정 | NOT_AVAILABLE |
| UI04 | 선택·필터·확인 | 3개 이상 수정 후보 | 일부 선택 후 검색으로 숨김, Rename 확인 후 취소; 재확인 실행 | 숨은 선택 표시, 확인 전 파일 불변, 완료 수 일치 | fixture raw name/작업 기록 | NOT_AVAILABLE |
| UI05 | 3언어·접근성·키보드 | ko/en/ja, VoiceOver, Full Keyboard Access | 900×640와1180×780, 큰글자/고대비/투명도축소, Tab/⌘O/⇧⌘O/⌘F/⌘A/⌘Z/Esc | 잘림/초점 유실 없음, 텍스트 편집 단축키 정상 | 접근성 관찰 기록 | NOT_AVAILABLE |
| UI06 | Inspector·clipboard | 결합문자/emoji4096 초과 text | 명시적 clipboard 분석, raw scalar/UTF16/4 forms 보기 | 파일 입력/변경 없음, 잘림 표시, 자동 clipboard 감시 없음 | 문자열 비공개, 길이만 기록 | NOT_AVAILABLE |
| F01 | Rename/Undo 실사용 흐름 | 전용 fixture | 변경 Preview→취소→다시 실행→기록 Undo→확인 | NFC raw 이름 후 원래 raw 이름 복원, 내용 그대로 | fixture manifest/작업 기록 | NOT_AVAILABLE |
| F02 | TCC/읽기전용 | 별도 테스트 계정/보호 폴더 복사본 | 권한 거부/재허용, 읽기전용 볼륨 선택 | 접근 오류 격리, 무단 권한 요청/우회 없음 | 오류 코드/진단 export | NOT_AVAILABLE |
| F03 | 외장·SMB·FileProvider | 해당 실제 기기/계정 | 분석 입력, 연결 제거, 미지원 위치 변경 시도 | 확인되지 않은 볼륨/클라우드 변경 차단, UI 응답 | 장치 종류/오류 코드 | NOT_AVAILABLE |
| J01 | 실제 프로세스 강제 종료 | 전용 fixture/별도 계정 | transaction 중 프로세스를 종료하고 재실행, recovery 상태 읽기 | 자동 광범위 변경 없음, 모호한 경우 보존, 명시 preview로만 복구 | 원본 journal 보존 | NOT_AVAILABLE |
| J02 | 종료·sleep·다중 실행 | 전용 fixture | 실행 중 ⌘Q, 창 닫기, sleep/resume, 앱 두 인스턴스 | 안전 checkpoint 종료, stale Plan 재확인, 중복 mutation 차단 | transaction ID/결과 | NOT_AVAILABLE |
| OS01 | Finder Services/Dock/Open With | 앱 직접 설치 후 Finder | Services에서 NameFix 선택, Dock·Open With로 혼합 전달 | 같은 검사 입력; busy OS 전달은 제한 큐, 자동 Rename 없음 | Services 화면/항목 수 | NOT_AVAILABLE |
| P01 | 실제100k UI 반응 | 충분한 로컬 fixture | 스크롤/검색/필터/취소/선택, Instruments 관찰 | 가상화, 시작500ms/상호작용100ms/취소피드백200ms 목표 평가 | 시간·CPU·메모리 peak | NOT_AVAILABLE |
| PK01 | 최소 지원 OS | 실제 macOS14 Apple Silicon | 앱 실행, picker→rename→undo | 컴파일 target만 아닌 실제 하한 OS 정상 실행 | OS 버전/결과 | NOT_AVAILABLE |
| PK02 | 깨끗한 Mac 배포 | Developer ID 서명/공증 package | 다운로드→DMG 설치→앱 실행→제거 | Gatekeeper 정상, 사용자 파일/기록 자동 삭제 없음 | codesign/spctl/stapler/실행 | NOT_AVAILABLE |

현재 자동화 근거는 AUTOMATED_QA_REPORT.md를 참조한다. 외부 프로세스의 source leaf 교체 race는 별도 알려진 출시 blocker이며 자동 fixture로 완전 방지되었다고 표시하지 않는다.


## 무료·Pro 확장 직접 확인 (구현 결함과 미확인을 구분)

최신 앱/안전한 테스트 폴더/절차는 EXPANSION_USER_GUIDE.md 및 artifacts/development/expansion/직접확인용_테스트파일/사용법.txt를 따른다. 실제 OS 제스처·권한·보조기술 아래 항목은 NOT_AVAILABLE/미확인 상태이며 미완성 결함으로 합산하지 않는다.

| ID | 목적과 절차 | 기대 | 상태 |
|---|---|---|---|
| EX-M01 | Finder Services와 메뉴바 drop/최근/상태 | 같은 입력과 명시 확인, 중복 창 없음 | 미확인 |
| EX-M02 | Mac 로그인 시 실행 등록/거부/해제, 알림 승인/거부 | 실제 OS 상태 반영, 원치 않는 계정 로그인 없음 | 미확인 |
| EX-M03 | 규칙/CSV/감시 sheet 키보드·VoiceOver | 명확한 label, 순서/실행/취소 접근 | 미확인 |
| EX-M04 | 320pt부터 큰 창까지 규칙·정보·카드·설정 | 정보 접근, 스크롤, 저장한 창 복원 | offscreen 33 렌더 확인, 실사용 별도 |
| EX-M05 | 사용자 실제 사진/미디어의 필드·timezone | 지원 필드 제안, 부재/예산 안내, 내용 불변 | 생성 fixture PASS, 실제 자료 별도 |
| EX-M06 | 잠자기/재시작/권한 철회/감시 위치 변경 | baseline 복원, 재검토/재승인, 무확인 mutation 없음 | 모델/fixture PASS, 실기 별도 |

개발자가 직접 확인할 때 파일 mutation은 제공된 폐기 가능한 fixture에서 먼저 수행한다. 실제 사용자 원본을 자동 테스트에 사용하지 않았다.

## v1.0 후보 후속 확인

최신 자동 근거는 V1_RELEASE_STATUS.md, 실제 후보는 build3이다. Free 사용 흐름은 이 Release 앱으로, 아직 연결되지 않은 실제 Pro 구매 흐름은 공급자 연결 후 확인한다. 구 Debug 앱의 Pro 스위치로 구매 성공을 대체하지 않는다.

| ID | 목적·준비 | 절차 | 기대 결과 | 현재 상태 |
|---|---|---|---|---|
| V1-01 | 전용 복사본에서 외부 저장 안내 | Preview 후 다른 앱에서 파일 저장, 실행 | 다시 검사/중단 안내, 잘못된 성공 없음 | NOT_AVAILABLE |
| V1-02 | 복구 위치 UI: 경합 fixture 기록, 세 언어·좁은 창 | 경로 복사/Finder에서 보기, Undo/Recovery 확인 | 긴 버튼 문구 접근 가능, 정체 불명 자동 복원 없음 | NOT_AVAILABLE |
| V1-03 | 후보 등급 안내: Release 설정 열기 | 사용 중인 버전 확인 | 무료/Pro 미제공 상태가 실제와 일치 | NOT_AVAILABLE |

화면을 직접 확인하지 못한 항목은 실패나 결함으로 바꾸지 않는다. 자동 경합 fixture PASS는 실제 UI 조작 PASS가 아니다.
