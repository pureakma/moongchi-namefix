#!/usr/bin/env python3
"""Read-only package round trip; mounts only the explicitly supplied candidate."""
from pathlib import Path
import hashlib, json, plistlib, subprocess, sys, tempfile

out = Path(sys.argv[1]).resolve()
manifest = json.loads((out/'ARTIFACT_MANIFEST.json').read_text())
def run(*args): return subprocess.run(list(map(str, args)), check=True)
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def verify_app(base):
    app = base/'Moongchi NameFix.app'
    actual = {str(p.relative_to(app)): sha(p) for p in app.rglob('*') if p.is_file()}
    assert actual == manifest['bundleFiles'], 'App changed during packaging'
    assert sha(base/'namefix') == manifest['cliSHA256']
    run('codesign', '--verify', '--deep', '--strict', app)
    run('codesign', '--verify', '--strict', base/'namefix')
    run(app/'Contents/MacOS/Moongchi NameFix', '--self-test')
    run(base/'namefix', '--help')
verify_app(out)
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
print('PASS: app/CLI hashes and signatures; ZIP integrity/extraction; read-only DMG mount; resources startup; CLI help; signing='+manifest['signing'])
