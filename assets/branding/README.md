# NameFix 앱 아이콘

사용자가 제공한 전용 아이콘이다. 원본: `/Users/inno/Desktop/workspace/DESKTOP/00 Moongchi Icon/뭉치네임픽스.png`.

`NameFix-Original.png`: 1254×1254, 원본 그대로 보존. 2026-10-04 사용자가 갱신한 투명 배경 원본이다. 바깥 흰 배경이 제거됐으며, 이전 원본은 archive/NameFix-WhiteBackground.png에 보존했다. 생성한 10개 슬롯 모두 네 모서리 alpha=0 검증을 통과했다. SHA-256: `1aa97856609e170b2f7679d5c9206ce6c7300d503324afe4b2248a77424dd40a`.

프로젝트 루트에서 재생성:
```sh
swift -module-cache-path .build/module-cache eng/icon.swift Resources/Assets.xcassets/AppIcon.appiconset
```

기존 임시 도형 생성기를 원본 기반 리사이즈로 변경했다. 16~1024px의 macOS 10개 슬롯을 생성하며 Release/공증은 별도다.

최신 재적용 원본: `1aa97856609e170b2f7679d5c9206ce6c7300d503324afe4b2248a77424dd40a`. 직전 원본은 archive에 해시 이름으로 보존했다.
