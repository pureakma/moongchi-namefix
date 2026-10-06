# Moongchi NameFix macOS 개발 인수인계

작성일: 2026-10-03. **문서/자산 패키지이며, macOS 앱 빌드 결과물이 아닙니다.**

## 바로 시작하는 방법

1. 이 폴더 전체 또는 `Moongchi_NameFix_macOS_Dev_Handoff_v1.0.zip`을 Mac으로 전달합니다.
2. 별도 프로젝트 `Moongchi_NameFix_macOS`를 만들고 이 폴더를 `docs/macos/`에 놓습니다. 기존 Mac 프로젝트가 있으면 그 프로젝트에서 진행합니다.
3. 개발 AI에게 아래 지시를 전달하거나 [실행 프롬프트](Moongchi_NameFix_macOS_DevAI_StartPrompt_v1.0.md) 전체를 붙여 넣습니다.

```text
docs/macos/Moongchi_NameFix_macOS_Project_Master_v1.0.md와
docs/macos/Moongchi_NameFix_macOS_DevAI_StartPrompt_v1.0.md를 처음부터 끝까지 읽어라.
macOS Master를 제품 SSOT로 삼고 StartPrompt의 실행 정책에 따라 개발하라.
LOCALIZATION_CATALOG.md와 assets/fonts 및 라이선스를 함께 사용하라.
현재 프로젝트를 점검하고 가장 첫 미완료 항목부터 실제 개발을 시작하라.
Phase마다 승인을 묻지 말고 Feature Complete → Full Automated QA → 수정/회귀검증
→ AUTO-QA PASS → 자동 QA 보고서/수동 QA 체크리스트 → 실행 가능한 QA 앱·ZIP·DMG까지 진행하라.
실제 검증하지 않은 macOS 동작이나 출시 상태를 PASS로 보고하지 마라.
```

## 포함 내용

| 파일 | 역할 |
|---|---|
| [macOS Project Master](Moongchi_NameFix_macOS_Project_Master_v1.0.md) | 기능 21개 계약, 화면/동작, exact theme, 안전성, 구조, 성능, QA, 배포 |
| [DevAI Start Prompt](Moongchi_NameFix_macOS_DevAI_StartPrompt_v1.0.md) | 개발 시작 순서, 무승인 Phase 진행, Level 1/2/3, Validation Cache, 완료 기준 |
| [Localization Catalog](LOCALIZATION_CATALOG.md) | 현재 157개 키 × ko/en/ja, Mac 문구 수정과 신규 오류 문구 |
| [폰트](assets/fonts) | Pretendard/Pretendard JP Variable TTF + 각 OFL 라이선스 |
| [HANDOFF_MANIFEST.json](HANDOFF_MANIFEST.json) | 인수인계 파일 크기/SHA-256 및 Windows 기준 자료 fingerprint |

Windows 소스가 없어도 구현할 수 있게 구성했습니다. Windows v2.0 FINAL과 최신 사용자 요청/현재 구현을 바탕으로 macOS 요구사항을 별도 정리했습니다. Windows 문서의 플랫폼 전용 부분을 Mac 프로젝트에서 재사용하지 마세요.

## 우선 주의할 차이

- Swift String의 canonical equality로 NFC 수정 필요 여부를 판정하면 놓치는 항목이 생깁니다. raw bytes 비교가 필요합니다.
- APFS는 저장된 이름 형식과 lookup의 동등성 규칙이 다릅니다. 실제 디렉터리 엔트리와 identity로 결과를 검증해야 합니다.
- 기본 POSIX rename은 대상 교체가 가능하므로 no-replace 어댑터와 경합 검증이 필요합니다.
- 기본 Dark, 정확한 Olive palette 및 진한 sidebar, 단일 드롭 안내/창 전체 수신, 즉시 설정을 유지해야 합니다.
- Windows의 자동 QA 결과는 Mac 결과가 아닙니다. 실제 Finder 드롭/APFS/서명/실기 검증이 따로 필요합니다.

기술 근거와 Apple/Swift 공식 링크는 Master 해당 절에 있습니다. Mac 실행 환경과 배포 인증서는 이 문서 패키지에 포함되지 않습니다.
