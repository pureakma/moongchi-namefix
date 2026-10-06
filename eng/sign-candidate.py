#!/usr/bin/env python3
"""Sign a copy of a verified pre-sign candidate with a Developer ID, in a new directory.
The input candidate is never modified and no identifier is changed. --dry-run stops before signing."""
from pathlib import Path
import argparse, hashlib, json, plistlib, subprocess
root = Path(__file__).resolve().parent.parent
RELEASE_BUNDLE_ID = 'com.ailoworks.namefix'
parser = argparse.ArgumentParser()
parser.add_argument('--input', required=True, type=Path, help='A pre-sign candidate directory')
parser.add_argument('--identity', help='Developer ID Application identity')
parser.add_argument('--output', type=Path)
parser.add_argument('--dry-run', action='store_true', help='Validate the input only; sign nothing')
args = parser.parse_args()
source = args.input.resolve()
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def run(*command): subprocess.run(list(map(str, command)), check=True)
manifest = json.loads((source/'ARTIFACT_MANIFEST.json').read_text())
source_app, source_cli = source/'Moongchi NameFix.app', source/'namefix'
assert manifest['signing'] == 'PRE_SIGN' and manifest['bundleID'] == RELEASE_BUNDLE_ID
assert plistlib.loads((source_app/'Contents/Info.plist').read_bytes())['CFBundleIdentifier'] == RELEASE_BUNDLE_ID
assert {str(p.relative_to(source_app)): sha(p) for p in source_app.rglob('*') if p.is_file()} == manifest['bundleFiles'], 'Input app differs from its manifest'
assert sha(source_cli) == manifest['cliSHA256'], 'Input CLI differs from its manifest'
if args.dry_run:
    print(f"DRY RUN: input candidate {manifest['version']} build {manifest['build']} {manifest['bundleID']} matches its manifest; nothing was signed")
    raise SystemExit(0)
assert args.identity and args.output, 'Signing needs --identity and --output'
out = args.output.resolve()
assert out.is_relative_to(root/'artifacts/release-candidate') and not out.exists()
out.mkdir(parents=True)
app, cli = out/'Moongchi NameFix.app', out/'namefix'
run('ditto', source_app, app)
run('ditto', source_cli, cli)
for path in [cli, app]:
    run('codesign', '--force', '--sign', args.identity, '--options', 'runtime', '--timestamp', path)
    run('codesign', '--verify', '--strict', '--verbose=2', path)
    signature = subprocess.run(['codesign', '-dvv', str(path)], check=True, capture_output=True, text=True).stderr
    assert 'Authority=Developer ID Application:' in signature and 'Timestamp=' in signature and 'runtime' in signature
    (out/('app-signature.txt' if path == app else 'cli-signature.txt')).write_text(signature)
print('PASS: copy of the candidate signed with Developer ID + hardened runtime + secure timestamp; bundle ID unchanged; notarization not performed')
