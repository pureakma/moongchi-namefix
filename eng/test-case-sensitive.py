#!/usr/bin/env python3
"""Create an isolated APFSX volume, run filesystem regressions, detach our disk."""
from pathlib import Path
import os, plistlib, subprocess, tempfile
root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='namefix-apfsx-', dir='/private/tmp') as temporary:
    work = Path(temporary); image = work/'fixture.sparseimage'; mount = work/'volume'; mount.mkdir()
    subprocess.run(['hdiutil', 'create', '-size', '512m', '-fs', 'Case-sensitive APFS', '-volname', 'NameFixFixture', '-type', 'SPARSE', str(image)], check=True)
    info = plistlib.loads(subprocess.check_output(['hdiutil', 'attach', '-nobrowse', '-mountpoint', str(mount), '-plist', str(image)]))
    devices = [x['dev-entry'] for x in info['system-entities'] if x.get('dev-entry', '').startswith('/dev/disk')]
    assert devices
    try:
        # Prove this is case-sensitive before trusting the environment label.
        (mount/'CaseProbe').write_text('upper'); (mount/'caseprobe').write_text('lower')
        assert (mount/'CaseProbe').read_text() == 'upper'
        assert (mount/'caseprobe').read_text() == 'lower'
        env = dict(os.environ, NAMEFIX_FIXTURE_ROOT=str(mount))
        subprocess.run([str(root/'eng/test.sh'), '--filter', 'CoordinatedTransactionTests|TransactionTests|FilesystemTests|ExpansionTests'], cwd=root, env=env, check=True)
    finally:
        subprocess.run(['hdiutil', 'detach', devices[0]], check=True)
print('PASS: isolated case-sensitive APFS, coordination/rename/undo/recovery/metadata/watch regressions, own volume detached')
