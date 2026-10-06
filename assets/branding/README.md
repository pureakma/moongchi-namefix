# NameFix 앱 아이콘

`NameFix-Original.png`가 현재 앱 아이콘의 유일한 원본이다.

- 크기: 1254×1254
- 현재 원본: 2026-10-04 사용자가 확정한 투명 배경 버전
- 검증 당시 SHA-256: `1aa97856609e170b2f7679d5c9206ce6c7300d503324afe4b2248a77424dd40a`
- 이전 흰 배경/중간 아이콘 사본은 현재 트리에 보관하지 않고 Git 이력에서 확인한다.

프로젝트 루트에서 AppIcon slot 재생성:

```sh
swift -module-cache-path .build/module-cache eng/icon.swift Resources/Assets.xcassets/AppIcon.appiconset
```

eng/icon.swift는 별도 경로를 명시하지 않으면 이 원본을 사용해 macOS 16~1024px AppIcon slot을 생성한다.
