#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
configuration=Debug
build_action=(build)
build_settings=(ARCHS=arm64 CODE_SIGN_IDENTITY=-)
derived="$PWD/.build/xcode"
while [[ $# -gt 0 ]]; do
 case "$1" in
 --clean) build_action=(clean build); shift;;
 # A Debug app inside the App Sandbox with the store entitlements, for eng/test-sandbox.py.
 # It has its own identifier and build folder, so the normal Debug app is not replaced.
 --sandbox-debug) build_settings+=(ENABLE_APP_SANDBOX=YES CODE_SIGN_ENTITLEMENTS=App/NameFix-AppStore.entitlements NAMEFIX_DISTRIBUTION=appstore PRODUCT_BUNDLE_IDENTIFIER=com.moongchi.namefix.sandboxqa); derived="$PWD/.build/xcode-sandbox"; shift;;
 --configuration) configuration="$2"; shift 2;;
 --arch) [[ "$2" == arm64 ]] || { echo 'Apple Silicon arm64 only' >&2; exit 2; }; shift 2;;
 *) echo "Unknown argument: $1" >&2; exit 2;;
 esac
done
[[ "$configuration" == Debug || "$configuration" == Release || "$configuration" == AppStore ]] || exit 2
xcodegen generate
xcodebuild -project MoongchiNameFix.xcodeproj -scheme MoongchiNameFix -configuration "$configuration" -destination 'generic/platform=macOS' -derivedDataPath "$derived" -clonedSourcePackagesDirPath "$PWD/.build/SourcePackages" "${build_settings[@]}" "${build_action[@]}"
