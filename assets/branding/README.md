# NameFix 앱 아이콘

## 사용 조건

Moongchi NameFix·뭉치네임픽스·AILO WORKS의 이름과 로고, 이 폴더의 아이콘 이미지 및 Resources/AppIcon.icon의 아이콘 이미지는 코드에 적용되는 MIT 라이선스에서 제외한다. 해당 브랜딩 자산의 권리는 권리자에게 남는다. 공식 배포 앱을 수정 없이 재배포할 때 포함된 이름·아이콘은 유지할 수 있다. 별도 로고 사용이나 수정한 제품의 브랜딩에는 권리자의 허락이 필요하다. 문의: ailo@ailoworks.com.

## 원본과 생성

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

비트맵 slot만 있는 아이콘(이전 AppIcon.appiconset)은 macOS 26 이상에서 회색 판 안에 축소되어 표시되어 2026-10-06에 이 형식으로 바꿨다. 그림 자체는 바꾸지 않았다. 다만 원본의 남색 여백이 넓어 Dock에서 작아 보여, 생성할 때 1.12배로 키워 여백을 잘라 낸다(eng/icon.swift의 enlargement).
