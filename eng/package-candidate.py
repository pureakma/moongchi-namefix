#!/usr/bin/env python3
"""Assemble a pre-sign candidate from an already built Release app and CLI.

The result holds the app, the CLI, the user documents and a manifest that records the source
commit. It is not signed with a Developer ID, not notarized and not packaged for distribution;
sign-candidate.py and notarize-candidate.py take it from here, each in a new directory.
An existing candidate is never overwritten."""
from pathlib import Path
import argparse, hashlib, json, plistlib, shutil, subprocess, tempfile

root = Path(__file__).resolve().parent.parent
RELEASE_BUNDLE_ID = 'com.ailoworks.namefix'
DOCUMENTS = {'README.txt': 'docs/PACKAGE_README.txt', 'USER_GUIDE.md': 'docs/EXPANSION_USER_GUIDE.md', 'ThirdPartyNotices.md': 'ThirdPartyNotices.md'}
parser = argparse.ArgumentParser()
parser.add_argument('--output', required=True, type=Path)
parser.add_argument('--app', type=Path, default=root/'.build/xcode/Build/Products/Release/Moongchi NameFix.app')
parser.add_argument('--cli', type=Path, required=True)
args = parser.parse_args()
out, app, cli = args.output.resolve(), args.app.resolve(), args.cli.resolve()
assert out.is_relative_to(root/'artifacts/release-candidate'), 'Use a new candidate output directory'
assert not out.exists(), 'Existing output preserved; choose a new output directory'
info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
def run(*command):
    return subprocess.run(list(map(str, command)), check=True)
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def git(*command):
    return subprocess.check_output(['git', '-C', str(root), *command], text=True).strip()
# The identifier comes from the Release build. A candidate is never made from any other.
assert info['CFBundleIdentifier'] == RELEASE_BUNDLE_ID, f"Bundle ID is {info['CFBundleIdentifier']}; build the Release configuration"
commit, dirty = git('rev-parse', 'HEAD'), bool(git('status', '--porcelain'))
assert not dirty, 'Commit the source first: a candidate must correspond to one commit'
for binary in [app/'Contents/MacOS'/info['CFBundleExecutable'], cli]:
    assert subprocess.check_output(['lipo', '-archs', str(binary)], text=True).strip() == 'arm64'
run('codesign', '--verify', '--deep', '--strict', app)
signature = subprocess.run(['codesign', '-dvv', str(app)], capture_output=True, text=True, check=True).stderr
assert 'Signature=adhoc' in signature, 'A pre-sign candidate starts from the ad-hoc signed Release build'
state = {'signing': 'PRE_SIGN', 'developerID': 'NOT_RUN', 'notarization': 'NOT_RUN', 'publicRelease': False}
product = {
    'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'], 'configuration': 'Release',
    'architecture': 'arm64', 'minimumOS': info['LSMinimumSystemVersion'], 'bundleID': info['CFBundleIdentifier'],
    'developer': 'AILO WORKS', 'support': 'ailo@ailoworks.com', 'distribution': 'direct', 'pricing': 'free',
    'sourceCommit': commit,
}
out.mkdir(parents=True)
with tempfile.TemporaryDirectory(prefix='namefix-candidate-', dir='/private/tmp') as temporary:
    stage = Path(temporary)
    run('ditto', app, stage/app.name)
    run('ditto', cli, stage/'namefix')
    run('codesign', '--force', '--sign', '-', stage/'namefix')
    run('codesign', '--verify', '--strict', stage/'namefix')
    for name, origin in DOCUMENTS.items(): shutil.copy2(root/origin, stage/name)
    (stage/'BUILD_INFO.json').write_text(json.dumps({**product, **state}, ensure_ascii=False, indent=2)+'\n')
    for name in [app.name, 'namefix', *DOCUMENTS, 'BUILD_INFO.json']:
        run('ditto', stage/name, out/name)
# The state of this directory, kept apart from the documents a user will receive.
(out/'CANDIDATE_STATUS.txt').write_text(
    f"Moongchi NameFix {product['version']} build {product['build']} - pre-sign candidate\n"
    f"Source commit: {commit}\n"
    "Developer ID signing: NOT RUN. Notarization: NOT RUN. Public release: NO.\n"
    "Do not distribute this directory. Sign and notarize a copy in a new output directory.\n")
files = {str(p.relative_to(out/app.name)): sha(p) for p in sorted((out/app.name).rglob('*')) if p.is_file()}
manifest = {
    'schemaVersion': 2, **product, **state,
    'bundleFiles': files, 'cliSHA256': sha(out/'namefix'),
    'documents': {name: sha(out/name) for name in [*DOCUMENTS, 'BUILD_INFO.json']},
    'packages': {},
}
(out/'ARTIFACT_MANIFEST.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n')
(out/'SHA256SUMS.txt').write_text(f"{sha(out/'namefix')}  namefix\n")
print('Created pre-sign candidate:', out)
