# 인수인계 문서 검증

검증일: 2026-10-03. 결과: 문서 패키지 검증 PASS.

- 4개 Markdown 본문 UTF-8/대체 문자 없음/코드 fence 짝 확인.
- 로컬 문서·자산 링크 12 개 대상 존재 확인.
- Master 필수 기능 MAC-F01..MAC-F21 포함 확인.
- 다크/올리브 토큰, Mac 파일 안전 계약, 검증 정책, CPU/배포 항목 포함 확인.
- 기존 localization 157개 키와 3개 언어 키 집합 일치. 전체 원문 표 157행.
- Mac override 6개 및 추가 키 15개 제공. 최종 번역/UI 검수는 Mac QA에서 수행.
- 두 TTF와 두 OFL 라이선스 사본 SHA-256이 원본과 동일.
- HANDOFF_MANIFEST.json에 전달 파일과 근거 자료의 SHA-256 기록.

이 검증은 문서/전달 자산 완전성 검사입니다. macOS 빌드, APFS Rename/Undo, 실제 Finder 드롭, 폰트 렌더링, 서명/공증/기기 테스트는 수행하지 않았습니다. Windows 제품 소스·실행 파일·기존 QA 상태는 이 문서 작업으로 변경하지 않았습니다.