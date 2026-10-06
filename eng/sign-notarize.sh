#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${NAMEFIX_SIGN_IDENTITY:?Provide an explicitly approved Developer ID Application identity}"
: "${NAMEFIX_NOTARY_PROFILE:?Provide a Keychain notarytool profile}"
: "${NAMEFIX_RELEASE_BUNDLE_ID:?Provide your team-owned bundle ID}"
: "${NAMEFIX_SIGN_INPUT_APP:?Provide a separate release app copy, not the QA artifact}"
[[ -d "$NAMEFIX_SIGN_INPUT_APP" ]] || exit 1
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $NAMEFIX_RELEASE_BUNDLE_ID" "$NAMEFIX_SIGN_INPUT_APP/Contents/Info.plist"
codesign --force --sign "$NAMEFIX_SIGN_IDENTITY" --options runtime --timestamp "$NAMEFIX_SIGN_INPUT_APP"
codesign --verify --deep --strict --verbose=2 "$NAMEFIX_SIGN_INPUT_APP"
work="$(mktemp -d /private/tmp/namefix-notary.XXXXXX)"
ditto -c -k --keepParent "$NAMEFIX_SIGN_INPUT_APP" "$work/submission.zip"
xcrun notarytool submit "$work/submission.zip" --keychain-profile "$NAMEFIX_NOTARY_PROFILE" --wait
xcrun stapler staple "$NAMEFIX_SIGN_INPUT_APP"
xcrun stapler validate "$NAMEFIX_SIGN_INPUT_APP"
spctl --assess --type execute --verbose=2 "$NAMEFIX_SIGN_INPUT_APP"
printf '%s\n' 'Signed app ready. Package the stapled app; submit and staple the resulting DMG separately before release.'
