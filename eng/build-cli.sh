#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
configuration="${1:-debug}"
[[ "$configuration" == debug || "$configuration" == release ]] || exit 2
swift build --disable-sandbox --scratch-path "$PWD/.build" --configuration "$configuration" --product namefix
