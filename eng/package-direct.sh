#!/bin/zsh
# The direct-download edition (D-042): the same AppStore-configuration build as the Mac App Store
# edition, with the same sandbox and entitlements, signed with Developer ID, notarized and stapled,
# as a DMG and a ZIP. Nothing differs inside the app; only the signature and the channel do.
#
#   eng/package-direct.sh <new output folder> [--notary-profile NAME]
#
# The notary profile is a notarytool Keychain profile the developer saved once
# (xcrun notarytool store-credentials). No password is passed here or written anywhere.
# Without a profile the run stops after signing, and the result is marked not for download.
set -euo pipefail
cd "$(dirname "$0")/.."

out="${1:?output folder that does not exist yet}"; shift
profile=""
while (( $# )); do
  case "$1" in
    --notary-profile) profile="${2:?profile name}"; shift 2;;
    *) echo "unknown option: $1" >&2; exit 2;;
  esac
done
[[ -e "$out" ]] && { echo "$out exists already; give a new folder" >&2; exit 2; }

# The build is made from committed product source only.
dirty=$(git status --porcelain -- App Infrastructure Application Packages Resources project.yml Package.swift)
[[ -n "$dirty" ]] && { echo "product source has uncommitted changes:" >&2; echo "$dirty" >&2; exit 2; }
commit=$(git rev-parse HEAD)

identity=$(security find-identity -v -p codesigning | sed -nE 's/.*"(Developer ID Application: .*\(25373G7846\))".*/\1/p' | head -1)
[[ -n "$identity" ]] || { echo "no Developer ID Application identity for team 25373G7846 in the keychain" >&2; exit 1; }

mkdir -p "$out/evidence"
evidence="$out/evidence"
step() { print -- "== $*" | tee -a "$evidence/steps.txt"; }

step "archive (AppStore configuration, source $commit)"
eng/archive-store.sh --preflight "$out/archive" > "$evidence/archive.txt" 2>&1
app="$out/Moongchi NameFix.app"
ditto "$out/archive/MoongchiNameFix.xcarchive/Products/Applications/Moongchi NameFix.app" "$app"
info="$app/Contents/Info.plist"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$info")
build=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$info")
name="Moongchi_NameFix_${version}_build${build}_arm64"

step "sign with $identity"
codesign --force --options runtime --timestamp --entitlements App/NameFix-AppStore.entitlements --sign "$identity" "$app"
codesign --verify --deep --strict "$app"
binary="$app/Contents/MacOS/Moongchi NameFix"
[[ "$(lipo -archs "$binary")" == "arm64" ]] || { echo "not arm64 only" >&2; exit 1; }
entitlements=$(codesign -d --entitlements - --xml "$app" 2>/dev/null | plutil -p - | grep -c "=> true")
[[ "$entitlements" == 3 ]] || { echo "expected the three store entitlements, found $entitlements" >&2; exit 1; }
probes=$(strings -a "$binary" | grep -c -e "sandbox-probe" -e "probe-support" -e "render-ux" || true)
[[ "$probes" == 0 ]] || { echo "debug probe code found in the binary" >&2; exit 1; }
codesign -dvv "$app" > "$evidence/app-signature.txt" 2>&1

notarize() {  # $1 file to submit, $2 label
  xcrun notarytool submit "$1" --keychain-profile "$profile" --wait --output-format json > "$evidence/notary-$2-submit.json"
  local id status
  id=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("id",""))' "$evidence/notary-$2-submit.json")
  status=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status",""))' "$evidence/notary-$2-submit.json")
  [[ -n "$id" ]] && xcrun notarytool log "$id" --keychain-profile "$profile" "$evidence/notary-$2-log.json" > /dev/null 2>&1 || true
  [[ "$status" == "Accepted" ]] || { echo "notarization of $2: ${status:-no answer}" >&2; return 1; }
}

notarized=false
if [[ -n "$profile" ]]; then
  step "notarize and staple the app"
  ditto -c -k --keepParent "$app" "$out/app-for-notary.zip"
  notarize "$out/app-for-notary.zip" app
  rm "$out/app-for-notary.zip"
  xcrun stapler staple "$app" > "$evidence/app-staple.txt" 2>&1
  xcrun stapler validate "$app" >> "$evidence/app-staple.txt" 2>&1
  notarized=true
fi

step "disk image"
stage="$out/dmg-stage"; mkdir -p "$stage"
ditto "$app" "$stage/Moongchi NameFix.app"; ln -s /Applications "$stage/Applications"
hdiutil create -volname "Moongchi NameFix" -srcfolder "$stage" -fs HFS+ -format UDZO -ov "$out/$name.dmg" > "$evidence/dmg.txt" 2>&1
rm -rf "$stage"
codesign --force --timestamp --sign "$identity" "$out/$name.dmg"
if $notarized; then
  step "notarize and staple the disk image"
  notarize "$out/$name.dmg" dmg
  xcrun stapler staple "$out/$name.dmg" > "$evidence/dmg-staple.txt" 2>&1
  xcrun stapler validate "$out/$name.dmg" >> "$evidence/dmg-staple.txt" 2>&1
fi
ditto -c -k --keepParent "$app" "$out/$name.zip"

step "what macOS says about the download"
spctl -a -vv -t exec "$app" > "$evidence/app-gatekeeper.txt" 2>&1 && app_gate=PASS || app_gate=REJECTED
spctl -a -vv -t open --context context:primary-signature "$out/$name.dmg" > "$evidence/dmg-gatekeeper.txt" 2>&1 && dmg_gate=PASS || dmg_gate=REJECTED

(cd "$out" && shasum -a 256 "$name.dmg" "$name.zip" > SHA256SUMS.txt)
python3 - "$out/BUILD_INFO.json" <<EOF
import json, sys
json.dump({
  "edition": "direct", "pricing": "free", "version": "$version", "build": "$build", "architecture": "arm64",
  "minimumOS": "14.0", "bundleID": "com.ailoworks.namefix", "configuration": "AppStore",
  "sameBuildAsAppStore": True, "sandbox": True, "sourceCommit": "$commit",
  "signing": "Developer ID", "signingIdentity": "$identity",
  "notarization": "ACCEPTED" if "$notarized" == "true" else "NOT_SUBMITTED",
  "gatekeeper": {"app": "$app_gate", "dmg": "$dmg_gate"},
  "forDownload": "$notarized" == "true" and "$app_gate" == "PASS" and "$dmg_gate" == "PASS",
  "packages": ["$name.dmg", "$name.zip"]
}, open(sys.argv[1], "w"), indent=1)
EOF
step "done: $out (app $app_gate, dmg $dmg_gate, notarized $notarized)"
