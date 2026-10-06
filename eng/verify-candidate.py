#!/usr/bin/env python3
"""Read-only check of a candidate directory against its manifest and the release policy.
Mounts only the candidate's own disk image, when it has one."""
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
check('manifest states', manifest['publicRelease'] is False and manifest['notarization'] == 'NOT_RUN'
      and (manifest['signing'], manifest['developerID']) in [('PRE_SIGN', 'NOT_RUN'), ('Developer ID', 'SIGNED')])
check('manifest product', manifest['bundleID'] == RELEASE_BUNDLE_ID and manifest['architecture'] == 'arm64' and manifest['configuration'] == 'Release'
      and manifest['minimumOS'] == MINIMUM_OS and manifest['pricing'] == 'free' and manifest['distribution'] == 'direct'
      and manifest['developer'] == 'AILO WORKS' and manifest['support'] == 'ailo@ailoworks.com' and len(manifest['sourceCommit']) == 40)
check('no paid-model fields', not any('paid' in key.lower() or 'provider' in key.lower() for key in manifest))
pre_sign = manifest['signing'] == 'PRE_SIGN'
check('pre-sign candidate carries no distributable package', bool(manifest['packages']) != pre_sign)

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
    run(base/'namefix', '--help')
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
check('BUILD_INFO agrees with the manifest', all(build_info[key] == manifest[key] for key in ['version', 'build', 'bundleID', 'signing', 'developerID', 'notarization', 'publicRelease', 'sourceCommit']))
if pre_sign: check('candidate status note', 'NOT RUN' in (out/'CANDIDATE_STATUS.txt').read_text())

for name, expected in manifest['packages'].items():
    assert sha(out/name) == expected['sha256']
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
                verify_app(mount)
            finally:
                run('hdiutil', 'detach', devices[0])
    checks.append('package round trip: ' + name)
print(f"PASS: {manifest['version']} build {manifest['build']} {manifest['bundleID']} signing={manifest['signing']} developerID={manifest['developerID']} notarization={manifest['notarization']} publicRelease={manifest['publicRelease']} commit={manifest['sourceCommit'][:7]}")
for item in checks: print(' -', item)
