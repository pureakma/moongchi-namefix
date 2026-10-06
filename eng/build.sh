#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
configuration=Debug
build_action=(build)
build_settings=(ARCHS=arm64 CODE_SIGN_IDENTITY=-)
while [[ $# -gt 0 ]]; do
 case "$1" in
 --clean) build_action=(clean build); shift;;
 --configuration) configuration="$2"; shift 2;;
 --arch) [[ "$2" == arm64 ]] || { echo 'Apple Silicon arm64 only' >&2; exit 2; }; shift 2;;
 --bundle-id) [[ "$2" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]] || { echo 'Invalid bundle ID' >&2; exit 2; }; build_settings+=("PRODUCT_BUNDLE_IDENTIFIER=$2"); shift 2;;
 *) echo "Unknown argument: $1" >&2; exit 2;;
 esac
done
[[ "$configuration" == Debug || "$configuration" == Release ]] || exit 2
xcodegen generate
xcodebuild -project MoongchiNameFix.xcodeproj -scheme MoongchiNameFix -configuration "$configuration" -destination 'generic/platform=macOS' -derivedDataPath "$PWD/.build/xcode" -clonedSourcePackagesDirPath "$PWD/.build/SourcePackages" "${build_settings[@]}" "${build_action[@]}"
