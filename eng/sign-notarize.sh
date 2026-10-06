#!/bin/bash
# Signs and notarizes a copy of an already built Release app. It never edits the app: the bundle
# identifier comes from the Release build itself, and a different one stops the run.
set -euo pipefail
cd "$(dirname "$0")/.."
expected_bundle_id="com.ailoworks.namefix"
: "${NAMEFIX_SIGN_IDENTITY:?Provide an explicitly approved Developer ID Application identity}"
: "${NAMEFIX_NOTARY_PROFILE:?Provide a Keychain notarytool profile}"
: "${NAMEFIX_SIGN_INPUT_APP:?Provide a separate release app copy, not the pre-sign candidate itself}"
[[ -d "$NAMEFIX_SIGN_INPUT_APP" ]] || exit 1
actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$NAMEFIX_SIGN_INPUT_APP/Contents/Info.plist")"
[[ "$actual_bundle_id" == "$expected_bundle_id" ]] || { echo "Bundle ID is $actual_bundle_id, expected $expected_bundle_id. Build the Release configuration; do not edit the app." >&2; exit 1; }
[[ "$(lipo -archs "$NAMEFIX_SIGN_INPUT_APP/Contents/MacOS/Moongchi NameFix")" == arm64 ]] || { echo 'Expected an arm64-only app' >&2; exit 1; }
codesign --force --sign "$NAMEFIX_SIGN_IDENTITY" --options runtime --timestamp "$NAMEFIX_SIGN_INPUT_APP"
codesign --verify --deep --strict --verbose=2 "$NAMEFIX_SIGN_INPUT_APP"
work="$(mktemp -d /private/tmp/namefix-notary.XXXXXX)"
ditto -c -k --keepParent "$NAMEFIX_SIGN_INPUT_APP" "$work/submission.zip"
xcrun notarytool submit "$work/submission.zip" --keychain-profile "$NAMEFIX_NOTARY_PROFILE" --wait
xcrun stapler staple "$NAMEFIX_SIGN_INPUT_APP"
xcrun stapler validate "$NAMEFIX_SIGN_INPUT_APP"
spctl --assess --type execute --verbose=2 "$NAMEFIX_SIGN_INPUT_APP"
printf '%s\n' 'Signed app ready. Package the stapled app; submit and staple the resulting DMG separately before release.'
