#!/bin/bash
set -euo pipefail
app="${1:?Usage: verify-release.sh /absolute/App.app [--release]}"
[[ "$(lipo -archs "$app/Contents/MacOS/Moongchi NameFix")" == arm64 ]]
codesign --verify --deep --strict --verbose=2 "$app"
"$app/Contents/MacOS/Moongchi NameFix" --self-test
if [[ "${2:-}" == --release ]]; then
 spctl --assess --type execute --verbose=2 "$app"
 xcrun stapler validate "$app"
fi
