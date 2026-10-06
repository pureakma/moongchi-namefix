#!/usr/bin/env python3
"""Sign a copy of a verified pre-sign candidate with a Developer ID, in a new directory.

The input candidate is never modified, no identifier is changed, and the product facts (version,
build, source commit) are carried over from the input manifest. The app and the CLI are signed
once here; later steps notarize these same signed binaries. --dry-run stops before signing."""
from pathlib import Path
import argparse, hashlib, json, plistlib, re, shutil, struct, subprocess, tempfile
root = Path(__file__).resolve().parent.parent
RELEASE_BUNDLE_ID = 'com.ailoworks.namefix'
PRODUCT = ['version', 'build', 'configuration', 'architecture', 'minimumOS', 'bundleID', 'developer', 'support', 'distribution', 'pricing', 'sourceCommit']
DOCUMENTS = ['README.txt', 'USER_GUIDE.md', 'ThirdPartyNotices.md']
parser = argparse.ArgumentParser()
parser.add_argument('--input', required=True, type=Path, help='A pre-sign candidate directory')
parser.add_argument('--identity', help='Developer ID Application identity, e.g. "Developer ID Application: Name (TEAMID)"')
parser.add_argument('--output', type=Path)
parser.add_argument('--dry-run', action='store_true', help='Validate the input only; sign nothing')
args = parser.parse_args()
source = args.input.resolve()
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def run(*command, timeout=300): subprocess.run(list(map(str, command)), check=True, timeout=timeout)
def text(*command): return subprocess.run(list(map(str, command)), check=True, capture_output=True, text=True)
def bundle(app): return {str(p.relative_to(app)): sha(p) for p in sorted(app.rglob('*')) if p.is_file()}
def code(binary):
    """The Mach-O with its signature removed, split into load commands and everything after them.
    Removing a signature leaves the size it had reserved in one header field (__LINKEDIT vmsize),
    so the code itself is compared from the end of the load commands on."""
    with tempfile.TemporaryDirectory(prefix='namefix-unsigned-', dir='/private/tmp') as temporary:
        copy = Path(temporary)/'binary'
        shutil.copy2(binary, copy)
        run('codesign', '--remove-signature', copy)
        data = copy.read_bytes()
    assert struct.unpack_from('<I', data, 0)[0] == 0xfeedfacf, 'Expected a thin 64-bit Mach-O'
    end = 32 + struct.unpack_from('<I', data, 20)[0]
    return data[:end], hashlib.sha256(data[end:]).hexdigest(), len(data)
def same_code(a, b):
    (head_a, body_a, size_a), (head_b, body_b, size_b) = code(a), code(b)
    return size_a == size_b and body_a == body_b and len(head_a) == len(head_b) and sum(x != y for x, y in zip(head_a, head_b)) <= 8
manifest = json.loads((source/'ARTIFACT_MANIFEST.json').read_text())
source_app, source_cli = source/'Moongchi NameFix.app', source/'namefix'
assert manifest['signing'] == 'PRE_SIGN' and manifest['bundleID'] == RELEASE_BUNDLE_ID
info = plistlib.loads((source_app/'Contents/Info.plist').read_bytes())
assert info['CFBundleIdentifier'] == RELEASE_BUNDLE_ID
assert bundle(source_app) == manifest['bundleFiles'], 'Input app differs from its manifest'
assert sha(source_cli) == manifest['cliSHA256'], 'Input CLI differs from its manifest'
if args.dry_run:
    print(f"DRY RUN: input candidate {manifest['version']} build {manifest['build']} {manifest['bundleID']} matches its manifest; nothing was signed")
    raise SystemExit(0)
assert args.identity and args.output, 'Signing needs --identity and --output'
team = re.search(r'\(([A-Z0-9]{10})\)$', args.identity)
assert args.identity.startswith('Developer ID Application: ') and team, 'Expected a Developer ID Application identity'
team = team.group(1)
out = args.output.resolve()
assert out.is_relative_to(root/'artifacts/release-candidate') and not out.exists(), 'Use a new output directory'
out.mkdir(parents=True)
app, cli = out/'Moongchi NameFix.app', out/'namefix'
run('ditto', source_app, app)
run('ditto', source_cli, cli)
for name in DOCUMENTS: shutil.copy2(source/name, out/name)
executable = app/'Contents/MacOS'/info['CFBundleExecutable']
signatures = {}
for path in [cli, app]:
    run('codesign', '--force', '--sign', args.identity, '--options', 'runtime', '--timestamp', path)
    run('codesign', '--verify', '--strict', '--verbose=2', path)
    signature = subprocess.run(['codesign', '-dvv', str(path)], check=True, capture_output=True, text=True).stderr
    assert f'Authority={args.identity}' in signature and f'TeamIdentifier={team}' in signature, 'Signed by an unexpected identity'
    assert 'Timestamp=' in signature and 'runtime' in signature, 'Secure timestamp or Hardened Runtime missing'
    entitlements = subprocess.run(['codesign', '-d', '--entitlements', '-', '--xml', str(path)], capture_output=True, text=True).stdout
    assert 'get-task-allow' not in entitlements and 'com.apple.security.app-sandbox' not in entitlements
    signatures[path.name] = signature
    (out/('app-signature.txt' if path == app else 'cli-signature.txt')).write_text(signature)
run('codesign', '--verify', '--deep', '--strict', app)
assert f'Identifier={RELEASE_BUNDLE_ID}' in signatures[app.name]
for binary in [executable, cli]: assert text('lipo', '-archs', binary).stdout.strip() == 'arm64'
# Only the signature may differ from the candidate: same code, same resources.
signed_files = bundle(app)
changed = {name for name in signed_files if signed_files[name] != manifest['bundleFiles'].get(name)} | (set(manifest['bundleFiles']) - set(signed_files))
allowed = {'_CodeSignature/CodeResources', 'Contents/_CodeSignature/CodeResources', f"Contents/MacOS/{info['CFBundleExecutable']}"}
assert changed <= allowed, f'Signing changed more than the signature: {sorted(changed - allowed)}'
assert same_code(executable, source_app/'Contents/MacOS'/info['CFBundleExecutable']), 'App code differs from the candidate'
assert same_code(cli, source_cli), 'CLI code differs from the candidate'
state = {'signing': 'Developer ID', 'developerID': 'SIGNED', 'notarization': 'NOT_RUN', 'stapled': False, 'publicRelease': False}
product = {key: manifest[key] for key in PRODUCT}
(out/'BUILD_INFO.json').write_text(json.dumps({**product, **state}, ensure_ascii=False, indent=2)+'\n')
(out/'CANDIDATE_STATUS.txt').write_text(
    f"Moongchi NameFix {product['version']} build {product['build']} - Developer ID signed candidate\n"
    f"Product source commit: {product['sourceCommit']}\n"
    "Developer ID signing: DONE. Notarization: NOT RUN. Public release: NO.\n"
    "Do not distribute this directory. Notarize a copy in a new output directory.\n")
signed = {
    'schemaVersion': 3, **product, **state,
    'signingIdentity': args.identity, 'teamID': team,
    'provenance': {'preSignCandidate': str(source.relative_to(root)), 'preSignManifestSHA256': sha(source/'ARTIFACT_MANIFEST.json'),
                   'appCodeSHA256': code(executable)[1], 'cliCodeSHA256': code(cli)[1]},
    'releaseToolingCommit': text('git', '-C', root, 'rev-parse', 'HEAD').stdout.strip(),
    'bundleFiles': signed_files, 'cliSHA256': sha(cli),
    'documents': {name: sha(out/name) for name in [*DOCUMENTS, 'BUILD_INFO.json']},
    'packages': {},
}
(out/'ARTIFACT_MANIFEST.json').write_text(json.dumps(signed, ensure_ascii=False, indent=2)+'\n')
(out/'SHA256SUMS.txt').write_text(f"{sha(cli)}  namefix\n")
print(f"PASS: app and CLI signed once with {args.identity} (team {team}), hardened runtime, secure timestamp; only the signature differs from the pre-sign candidate; notarization not performed")
