#!/usr/bin/env python3
"""Sign a NEW local candidate copy. No identifier changes or public upload."""
from pathlib import Path
import argparse, subprocess
root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--identity', required=True)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args()
out = args.output.resolve()
assert out.is_relative_to(root/'artifacts/release-candidate') and not out.exists()
out.mkdir(parents=True)
app = out/'Moongchi NameFix.app'; cli = out/'namefix'
def run(*args): subprocess.run(list(map(str, args)), check=True)
run('ditto', root/'.build/xcode/Build/Products/Release/Moongchi NameFix.app', app)
run('ditto', root/'.build/out/Products/Release/namefix', cli)
for path in [cli, app]:
    run('codesign', '--force', '--sign', args.identity, '--options', 'runtime', '--timestamp', path)
    run('codesign', '--verify', '--strict', '--verbose=2', path)
    signature = subprocess.run(['codesign', '-dvv', str(path)], check=True, capture_output=True, text=True).stderr
    assert 'Authority=Developer ID Application:' in signature and 'Timestamp=' in signature and 'runtime' in signature
    (out/('app-signature.txt' if path == app else 'cli-signature.txt')).write_text(signature)
print('PASS: new candidate app and CLI signed with Developer ID + hardened runtime + secure timestamp; bundle ID unchanged; notarization not performed')
