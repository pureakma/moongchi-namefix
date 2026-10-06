#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
level=1
scope=""
args=(--no-parallel)
while [[ $# -gt 0 ]]; do
 case "$1" in
 --level) level="$2"; shift 2;;
 --scope) scope="$2"; shift 2;;
 --core) scope=core; shift;;
 *) args+=("$1"); shift;;
 esac
done
[[ "$level" == 1 || "$level" == 2 || "$level" == 3 ]] || exit 2
if [[ "$scope" == core || "$scope" == unicode ]]; then
 swift test --disable-sandbox --package-path Packages/NameFixCore --scratch-path "$PWD/.build/core-tests" "${args[@]}"
else
 case "$scope" in
 safety) args+=(--filter SafetyTests);;
 transaction) args+=(--filter TransactionTests);;
 filesystem) args+=(--filter FilesystemTests);;
 ui-model) args+=(--filter AppModelTests);;
 ''|all) ;;
 *) echo "Unknown scope: $scope" >&2; exit 2;;
 esac
 swift test --disable-sandbox --scratch-path "$PWD/.build" "${args[@]}"
 if [[ "$level" == 3 ]]; then
  swift test --disable-sandbox --package-path Packages/NameFixCore --scratch-path "$PWD/.build/core-tests"
 fi
fi
