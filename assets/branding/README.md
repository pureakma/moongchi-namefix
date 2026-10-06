# NameFix 앱 아이콘

`NameFix-Original.png`가 현재 앱 아이콘의 유일한 원본이다.

- 크기: 1254×1254
- 현재 원본: 2026-10-04 사용자가 확정한 투명 배경 버전
- 검증 당시 SHA-256: `1aa97856609e170b2f7679d5c9206ce6c7300d503324afe4b2248a77424dd40a`
- 이전 흰 배경/중간 아이콘 사본은 현재 트리에 보관하지 않고 Git 이력에서 확인한다.

프로젝트 루트에서 앱 아이콘 문서 재생성:

```sh
swift -module-cache-path .build/module-cache eng/icon.swift Resources/AppIcon.icon
```

eng/icon.swift는 별도 경로를 명시하지 않으면 이 원본을 1024px layer 한 장으로 넣은 Icon Composer 문서(Resources/AppIcon.icon)를 만든다. Xcode가 이 문서에서 macOS 26 이상의 아이콘과 macOS 14·15용 비트맵 아이콘을 함께 만든다.

비트맵 slot만 있는 아이콘(이전 AppIcon.appiconset)은 macOS 26 이상에서 회색 판 안에 축소되어 표시되어 2026-10-06에 이 형식으로 바꿨다. 그림 자체는 바꾸지 않았다.
