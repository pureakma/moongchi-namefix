#!/bin/bash
set -euo pipefail
[[ "${1:-}" == --root && -n "${2:-}" ]] || { echo 'Usage: eng/create-fixtures.sh --root /private/tmp/namefix-manual-UNIQUE' >&2; exit 2; }
python3 - "$2" <<'PY'
import pathlib,sys,hashlib,json
root=pathlib.Path(sys.argv[1])
if not str(root).startswith('/private/tmp/namefix-') or root.exists(): raise SystemExit('Use a new /private/tmp/namefix-* directory; existing data is never replaced.')
root.mkdir()
paths=['e\u0301.txt','\u1112\u1161\u11ab\u1100\u1173\u11af.txt','\u304b\u3099.txt','normal.txt','folder-e\u0301/child-e\u0301.txt']
manifest=[]
for name in paths:
 p=root/name;p.parent.mkdir(exist_ok=True);p.write_bytes(b'NameFix dedicated manual QA content\n')
 manifest.append({'relativeRawHex':name.encode().hex(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(root/'fixture-manifest.json').write_text(json.dumps(manifest,indent=2))
print(root)
PY
