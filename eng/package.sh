#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "${1:-}" == --unsigned ]] || { echo 'Use --unsigned for local QA; external signing is a separate explicit workflow.' >&2; exit 2; }
app="$PWD/.build/xcode/Build/Products/Release/Moongchi NameFix.app"
[[ -d "$app" ]] || { echo 'Run eng/build.sh --configuration Release --arch arm64 first' >&2; exit 1; }
[[ "$(lipo -archs "$app/Contents/MacOS/Moongchi NameFix")" == arm64 ]] || exit 1
stage="$(mktemp -d /private/tmp/namefix-package.XXXXXX)"
ditto "$app" "$stage/Moongchi NameFix.app"
cp ThirdPartyNotices.md "$stage/ThirdPartyNotices.md"
cp docs/QA_README.txt "$stage/README.txt"
# QA app uses an ad-hoc identity to run on arm64, with no Developer ID/notarization claim.
codesign --verify --deep --strict "$stage/Moongchi NameFix.app"
zip="$PWD/artifacts/qa/Moongchi_NameFix_1.0.0_macOS_arm64.zip"
dmg="$PWD/artifacts/qa/Moongchi_NameFix_1.0.0_macOS_arm64.dmg"
[[ ! -e "$zip" && ! -e "$dmg" ]] || { echo 'Existing packages preserved; move them to an archive before repackaging.' >&2; exit 1; }
ditto -c -k --sequesterRsrc "$stage" "$zip"
ln -s /Applications "$stage/Applications"
hdiutil create -volname 'Moongchi NameFix' -srcfolder "$stage" -fs APFS -format UDZO "$dmg"
# Detach only an attachment freshly identified by this exact generated image path.
python3 eng/detach-created-image.py "$dmg"
hdiutil verify "$dmg"
ditto "$stage/Moongchi NameFix.app" "$PWD/artifacts/qa/Moongchi NameFix.app"
shasum -a 256 "$zip" "$dmg" > artifacts/qa/SHA256SUMS.txt
printf '%s\n' "$stage" > artifacts/qa/package-stage-path.txt
