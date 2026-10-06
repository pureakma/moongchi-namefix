#!/usr/bin/env python3
"""Release CLI read-only boundary test; never executes a user-file mutation."""
from pathlib import Path
import base64, hashlib, json, subprocess, sys, tempfile
binary = Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix='namefix-release-cli-', dir='/private/tmp') as temporary:
    root = Path(temporary); source = root/'a.txt'; source.write_bytes(b'unchanged fixture')
    before = hashlib.sha256(source.read_bytes()).hexdigest()
    def run(*args): return subprocess.run([str(binary), *map(str, args)], capture_output=True, text=True, timeout=15)
    result = run('--prefix', 'new_', '--json', source)
    assert result.returncode == 0, result.stderr
    plan = json.loads(result.stdout)
    assert len(plan['operations']) == 1
    assert base64.b64decode(plan['operations'][0]['destination']) == b'new_a.txt'
    assert 'contentVersion' in plan['operations'][0]
    assert run('--development-pro', '--json', source).returncode == 1
    refused = run('--prefix', 'new_', '--execute', source)
    assert refused.returncode == 1 and 'InteractiveConfirmationRequired' in refused.stderr
    csv = root/'mapping.csv'; csv.write_text('source,destination\na.txt,b.txt\n')
    pro = run('--csv', csv, '--json', source)
    assert pro.returncode == 1 and 'ProRequired' in pro.stderr
    assert hashlib.sha256(source.read_bytes()).hexdigest() == before
    assert not (root/'new_a.txt').exists()
print('PASS: Release raw JSON/dry-run/freshness, non-TTY refusal, development Pro flag excluded, unlicensed Pro denied, source hash unchanged')
