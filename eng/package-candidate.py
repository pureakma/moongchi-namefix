#!/usr/bin/env python3
"""Assemble a Release candidate from an already built Release app and CLI.

Default: a pre-sign candidate (app, CLI, user documents, manifest). It is not signed with a
Developer ID, not notarized and not packaged for distribution.
--developer-id: package an app and CLI that are already Developer ID signed, as ZIP and DMG.
Every run writes to a new directory; an existing candidate is never overwritten.
"""
from pathlib import Path
import argparse, hashlib, json, plistlib, shutil, subprocess, tempfile

root = Path(__file__).resolve().parent.parent
RELEASE_BUNDLE_ID = 'com.ailoworks.namefix'
parser = argparse.ArgumentParser()
parser.add_argument('--output', required=True, type=Path)
parser.add_argument('--app', type=Path, default=root/'.build/xcode/Build/Products/Release/Moongchi NameFix.app')
parser.add_argument('--cli', type=Path, required=True)
parser.add_argument('--developer-id', action='store_true', help='Package an already Developer ID signed app and CLI')
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
if args.developer_id:
    assert 'Authority=Developer ID Application:' in signature and 'Timestamp=' in signature and 'runtime' in signature
else:
    assert 'Signature=adhoc' in signature, 'Use --developer-id for already signed candidates'
state = {
    'signing': 'Developer ID' if args.developer_id else 'PRE_SIGN',
    'developerID': 'SIGNED' if args.developer_id else 'NOT_RUN',
    'notarization': 'NOT_RUN',
    'publicRelease': False,
}
product = {
    'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'], 'configuration': 'Release',
    'architecture': 'arm64', 'minimumOS': info['LSMinimumSystemVersion'], 'bundleID': info['CFBundleIdentifier'],
    'developer': 'AILO WORKS', 'support': 'ailo@ailoworks.com', 'distribution': 'direct', 'pricing': 'free',
    'sourceCommit': commit,
}
out.mkdir(parents=True)
packages = []
with tempfile.TemporaryDirectory(prefix='namefix-candidate-', dir='/private/tmp') as temporary:
    stage = Path(temporary)
    run('ditto', app, stage/app.name)
    run('ditto', cli, stage/'namefix')
    if not args.developer_id: run('codesign', '--force', '--sign', '-', stage/'namefix')
    run('codesign', '--verify', '--strict', stage/'namefix')
    if args.developer_id:
        cli_signature = subprocess.run(['codesign', '-dvv', str(stage/'namefix')], capture_output=True, text=True, check=True).stderr
        team = next(line for line in signature.splitlines() if line.startswith('TeamIdentifier='))
        assert team in cli_signature and 'Authority=Developer ID Application:' in cli_signature and 'Timestamp=' in cli_signature
    shutil.copy2(root/'ThirdPartyNotices.md', stage/'ThirdPartyNotices.md')
    shutil.copy2(root/'docs/PACKAGE_README.txt', stage/'README.txt')
    shutil.copy2(root/'docs/EXPANSION_USER_GUIDE.md', stage/'USER_GUIDE.md')
    (stage/'BUILD_INFO.json').write_text(json.dumps({**product, **state}, ensure_ascii=False, indent=2)+'\n')
    if args.developer_id:
        basename = f"Moongchi_NameFix_{product['version']}_build{product['build']}_arm64"
        archive, image = out/(basename+'.zip'), out/(basename+'.dmg')
        run('ditto', '-c', '-k', '--sequesterRsrc', stage, archive)
        (stage/'Applications').symlink_to('/Applications')
        run('hdiutil', 'create', '-volname', 'Moongchi NameFix', '-srcfolder', stage, '-fs', 'APFS', '-format', 'UDZO', image)
        # Some hdiutil versions leave the newly created image attached. Touch only
        # devices reported for this exact, new image, never unrelated user disks.
        attached = plistlib.loads(subprocess.check_output(['hdiutil', 'info', '-plist']))
        for item in attached.get('images', []):
            if Path(item.get('image-path', '/')).resolve() == image:
                devices = [e['dev-entry'] for e in item.get('system-entities', []) if e.get('dev-entry', '').startswith('/dev/disk')]
                if devices: run('hdiutil', 'detach', devices[0])
        run('hdiutil', 'verify', image)
        (stage/'Applications').unlink()
        packages = [archive, image]
    for name in [app.name, 'namefix', 'README.txt', 'USER_GUIDE.md', 'ThirdPartyNotices.md', 'BUILD_INFO.json']:
        run('ditto', stage/name, out/name)
if not args.developer_id:
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
    'documents': {name: sha(out/name) for name in ['README.txt', 'USER_GUIDE.md', 'ThirdPartyNotices.md', 'BUILD_INFO.json']},
    'packages': {p.name: {'sha256': sha(p), 'bytes': p.stat().st_size} for p in packages},
}
(out/'ARTIFACT_MANIFEST.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n')
(out/'SHA256SUMS.txt').write_text(''.join(f'{sha(p)}  {p.name}\n' for p in [*packages, out/'namefix']))
print('Created', 'Developer ID package:' if args.developer_id else 'pre-sign candidate:', out)
