#!/bin/bash
set -euo pipefail
sw_vers
uname -m
xcode-select -p
xcodebuild -version
swift --version
xcrun --show-sdk-version
xcrun --show-sdk-path
