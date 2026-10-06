#!/usr/bin/env python3
"""Read-only check of a candidate directory against its manifest and the release policy.

Understands the three stages: a pre-sign candidate, a Developer ID signed candidate, and the
notarized release artifact with its packages. Mounts only the candidate's own disk image."""
from pathlib import Path
import hashlib, json, plistlib, subprocess, sys, tempfile

root = Path(__file__).resolve().parent.parent
out = Path(sys.argv[1]).resolve()
manifest = json.loads((out/'ARTIFACT_MANIFEST.json').read_text())
RELEASE_BUNDLE_ID, MINIMUM_OS = 'com.ailoworks.namefix', '14.0'
def run(*args): return subprocess.run(list(map(str, args)), check=True)
def text(*args): return subprocess.run(list(map(str, args)), check=True, capture_output=True, text=True)
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
checks = []
def check(name, condition):
    assert condition, name
    checks.append(name)

# Manifest: the facts of this candidate, and nothing from the old paid model.
stage = (manifest['signing'], manifest['developerID'], manifest['notarization'])
check('manifest states', manifest['publicRelease'] is False and stage in [('PRE_SIGN', 'NOT_RUN', 'NOT_RUN'), ('Developer ID', 'SIGNED', 'NOT_RUN'), ('Developer ID', 'SIGNED', 'ACCEPTED')])
check('manifest product', manifest['bundleID'] == RELEASE_BUNDLE_ID and manifest['architecture'] == 'arm64' and manifest['configuration'] == 'Release'
      and manifest['minimumOS'] == MINIMUM_OS and manifest['pricing'] == 'free' and manifest['distribution'] == 'direct'
      and manifest['developer'] == 'AILO WORKS' and manifest['support'] == 'ailo@ailoworks.com' and len(manifest['sourceCommit']) == 40)
check('no paid-model fields', not any('paid' in key.lower() or 'provider' in key.lower() for key in manifest))
pre_sign, notarized = manifest['signing'] == 'PRE_SIGN', manifest['notarization'] == 'ACCEPTED'
check('only a notarized artifact carries distributable packages', bool(manifest['packages']) == notarized)
if not pre_sign:
    # The product is the one the pre-sign candidate was made from, whatever commit the tooling is at.
    origin = json.loads((root/manifest['provenance']['preSignCandidate']/'ARTIFACT_MANIFEST.json').read_text())
    check('source commit carried over from the pre-sign candidate', origin['sourceCommit'] == manifest['sourceCommit']
          and sha(root/manifest['provenance']['preSignCandidate']/'ARTIFACT_MANIFEST.json') == manifest['provenance']['preSignManifestSHA256']
          and all(origin[key] == manifest[key] for key in ['version', 'build', 'bundleID', 'minimumOS', 'architecture']))
if notarized:
    check('notarization recorded with accepted submissions', manifest['stapled'] is True and manifest['gatekeeper'] == 'PASS'
          and all(manifest['notarizationSubmissions'][kind]['status'] == 'Accepted' and len(manifest['notarizationSubmissions'][kind]['id']) == 36 for kind in ['app', 'dmg']))

def verify_app(base):
    app = base/'Moongchi NameFix.app'
    actual = {str(p.relative_to(app)): sha(p) for p in app.rglob('*') if p.is_file()}
    assert actual == manifest['bundleFiles'], 'App changed after the manifest was written'
    assert sha(base/'namefix') == manifest['cliSHA256']
    info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
    assert (info['CFBundleIdentifier'], info['CFBundleShortVersionString'], info['CFBundleVersion'], info['LSMinimumSystemVersion']) == (manifest['bundleID'], manifest['version'], manifest['build'], MINIMUM_OS)
    executable = app/'Contents/MacOS'/info['CFBundleExecutable']
    for binary in [executable, base/'namefix']:
        assert text('lipo', '-archs', binary).stdout.strip() == 'arm64'
    resources = app/'Contents/Resources'
    for item in ['AppIcon.icns', 'Assets.car', 'PretendardVariable.ttf', 'PretendardJPVariable.ttf', *[f'{l}.lproj/Localizable.strings' for l in ['ko', 'en', 'ja']], *[f'{l}.lproj/InfoPlist.strings' for l in ['ko', 'en', 'ja']]]:
        assert (resources/item).is_file(), item
    run('codesign', '--verify', '--deep', '--strict', app)
    run('codesign', '--verify', '--strict', base/'namefix')
    signature = text('codesign', '-dvv', app).stderr
    assert 'runtime' in signature, 'Hardened Runtime is off'
    assert ('Signature=adhoc' in signature) == pre_sign and ('Authority=Developer ID Application:' in signature) != pre_sign
    if not pre_sign:
        assert f"Authority={manifest['signingIdentity']}" in signature and f"TeamIdentifier={manifest['teamID']}" in signature and 'Timestamp=' in signature
        cli_signature = text('codesign', '-dvv', base/'namefix').stderr
        assert f"TeamIdentifier={manifest['teamID']}" in cli_signature and 'Timestamp=' in cli_signature and 'runtime' in cli_signature
    if notarized:
        # The ticket is attached and Gatekeeper accepts the app as notarized, checked here and now.
        run('xcrun', 'stapler', 'validate', app)
        assessment = subprocess.run(['spctl', '--assess', '--type', 'execute', '--verbose=2', str(app)], capture_output=True, text=True)
        assert assessment.returncode == 0 and 'Notarized Developer ID' in assessment.stderr, assessment.stderr
    entitlements = subprocess.run(['codesign', '-d', '--entitlements', '-', '--xml', str(app)], capture_output=True, text=True).stdout
    assert 'com.apple.security.app-sandbox' not in entitlements and 'get-task-allow' not in entitlements
    # Development fixtures, diagnosis flags and switches must not be in what ships.
    app_strings, cli_strings = text('strings', '-a', executable).stdout, text('strings', '-a', base/'namefix').stdout
    for word in ['--render-', '--diagnose-window', '--live-sidebar-check', '_lastDragRegionData', '--development-pro', 'NAMEFIX_TEST']:
        assert word not in app_strings, word
    for word in ['--development-pro', 'NAMEFIX_TEST']:
        assert word not in cli_strings, word
    for word in ['URLSession', 'NWConnection']:
        assert word not in app_strings and word not in cli_strings, word
    run(executable, '--self-test')
    usage = text(base/'namefix', '--help').stdout
    for option in ['--no-recurse', '--include-folders', '--include-hidden', '--prefix', '--replace', '--number', '--csv', '--recipe', '--execute', '--json', '--undo', 'Dry-run is the default']:
        assert option in usage, 'CLI help lacks ' + option
    run(sys.executable, root/'eng/test-release-cli.py', base/'namefix')

verify_app(out)
checks.append('app and CLI: manifest hashes, Info.plist, arm64, resources, signatures, Hardened Runtime, no sandbox, no development strings, self-test, CLI contract')

# Documents a user receives: current product facts, nothing from the paid model or an earlier candidate.
for name, digest in manifest['documents'].items():
    assert sha(out/name) == digest, name
readme, guide, build_info = (out/'README.txt').read_text(), (out/'USER_GUIDE.md').read_text(), json.loads((out/'BUILD_INFO.json').read_text())
check('documents name the product', all(word in readme for word in [manifest['version'], 'AILO WORKS', 'ailo@ailoworks.com', 'free']))
for word in ['Pro 조건', 'Pro 기능', 'paid provider', 'paidProvider', 'UNCONFIGURED', 'development identifier', 'Notarization is not configured', 'not an approved public distribution']:
    assert word not in readme and word not in guide and word not in json.dumps(build_info), word
check('documents carry no paid-model or earlier-candidate wording', True)
check('BUILD_INFO agrees with the manifest', all(build_info[key] == manifest[key] for key in ['version', 'build', 'bundleID', 'signing', 'notarization', 'sourceCommit']))
status = (out/'CANDIDATE_STATUS.txt').read_text()
check('candidate status note', ('Notarization: ACCEPTED' in status) == notarized and ('Developer ID signing: NOT RUN' in status) == pre_sign and 'Public release: NO' in status)

for name, expected in manifest['packages'].items():
    assert sha(out/name) == expected['sha256']
    if name.endswith('.dmg'):
        run('hdiutil', 'verify', out/name)
        run('xcrun', 'stapler', 'validate', out/name)
        assessment = subprocess.run(['spctl', '--assess', '--type', 'open', '--context', 'context:primary-signature', '--verbose=2', str(out/name)], capture_output=True, text=True)
        assert assessment.returncode == 0 and 'Notarized Developer ID' in assessment.stderr, assessment.stderr
        checks.append('disk image: integrity, staple, Gatekeeper')
    with tempfile.TemporaryDirectory(prefix='namefix-package-check-', dir='/private/tmp') as temporary:
        destination = Path(temporary)
        if name.endswith('.zip'):
            run('unzip', '-tq', out/name)
            run('ditto', '-x', '-k', out/name, destination)
            verify_app(destination)
        else:
            mount = destination/'mounted'; mount.mkdir()
            attachment = plistlib.loads(subprocess.check_output(['hdiutil', 'attach', '-readonly', '-nobrowse', '-mountpoint', str(mount), '-plist', str(out/name)]))
            devices = [e['dev-entry'] for e in attachment['system-entities'] if e.get('dev-entry', '').startswith('/dev/disk')]
            assert devices
            try:
                assert (mount/'Applications').is_symlink()
                assert (mount/'Applications').readlink() == Path('/Applications')
                assert sorted(p.name for p in mount.iterdir() if not p.name.startswith('.')) == sorted(['Applications', 'Moongchi NameFix.app', 'namefix', *manifest['documents']]), 'Unexpected content in the disk image'
                verify_app(mount)
            finally:
                run('hdiutil', 'detach', devices[0])
    checks.append('package round trip: ' + name)
print(f"PASS: {manifest['version']} build {manifest['build']} {manifest['bundleID']} signing={manifest['signing']} developerID={manifest['developerID']} notarization={manifest['notarization']} stapled={manifest.get('stapled', False)} publicRelease={manifest['publicRelease']} sourceCommit={manifest['sourceCommit'][:7]}")
for item in checks: print(' -', item)
