#!/bin/bash
# Archives the AppStore configuration.
#   eng/archive-store.sh --preflight <new folder>   local signature only: checks that the archive can be made and what is in it
#   eng/archive-store.sh --signed <new folder>      Xcode automatic signing for the team (D-039), then exports the signed package
# --signed changes the Apple Developer account the first time: Xcode registers the App ID and creates the
# store provisioning profile, and the cloud-managed distribution certificate if the team has none.
# It uploads nothing. Run it only when the user has asked for it.
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:?--preflight or --signed}"; out="${2:?output folder that does not exist yet}"
[[ ! -e "$out" ]] || { echo "Refusing to write into an existing folder: $out" >&2; exit 2; }
team=25373G7846
mkdir -p "$out"; out="$(cd "$out" && pwd)"
xcodegen generate >/dev/null
common=(-project MoongchiNameFix.xcodeproj -scheme MoongchiNameFix -configuration AppStore -destination 'generic/platform=macOS'
        -archivePath "$out/MoongchiNameFix.xcarchive" -derivedDataPath "$PWD/.build/xcode-archive" -clonedSourcePackagesDirPath "$PWD/.build/SourcePackages" ARCHS=arm64)
case "$mode" in
 --preflight) xcodebuild archive "${common[@]}" CODE_SIGN_IDENTITY=- ;;
 --signed)
  xcodebuild archive "${common[@]}" CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$team" CODE_SIGN_IDENTITY="Apple Development" -allowProvisioningUpdates
  xcodebuild -exportArchive -archivePath "$out/MoongchiNameFix.xcarchive" -exportPath "$out/export" -exportOptionsPlist eng/StoreExportOptions.plist -allowProvisioningUpdates ;;
 *) echo "--preflight or --signed" >&2; exit 2;;
esac
app="$out/MoongchiNameFix.xcarchive/Products/Applications/Moongchi NameFix.app"
[[ "$(lipo -archs "$app/Contents/MacOS/Moongchi NameFix")" == arm64 ]] || { echo "Not arm64 only" >&2; exit 1; }
codesign --verify --deep --strict "$app"
echo "Archive: $out/MoongchiNameFix.xcarchive"
