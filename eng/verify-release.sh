#!/bin/bash
# Checks a built app: Apple Silicon only, a valid signature, and the app's own self-test.
set -euo pipefail
app="${1:?Usage: verify-release.sh /absolute/App.app}"
[[ "$(lipo -archs "$app/Contents/MacOS/Moongchi NameFix")" == arm64 ]]
codesign --verify --deep --strict --verbose=2 "$app"
"$app/Contents/MacOS/Moongchi NameFix" --self-test
