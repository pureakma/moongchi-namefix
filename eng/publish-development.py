#!/usr/bin/env python3
"""Copy already-built Debug artifacts for review. No Release/build/sign/package step."""
from pathlib import Path
import datetime, hashlib, json, plistlib, shutil, subprocess, uuid
root=Path(__file__).resolve().parent.parent
source=root/'.build/xcode/Build/Products/Debug/Moongchi NameFix.app'
cli=root/'.build/out/Products/Debug/namefix'
output=root/'artifacts/development'
app=output/'Moongchi NameFix 확장 Dev.app'
assert source.is_dir() and cli.is_file(), 'Build the Debug app and namefix product first.'
with (source/'Contents/Info.plist').open('rb') as f: info=plistlib.load(f)
executable=source/'Contents/MacOS'/info['CFBundleExecutable']
for path in [executable, cli]:
    assert subprocess.check_output(['/usr/bin/lipo','-archs',str(path)],text=True).strip()=='arm64'
stage=output/('.namefix-development-'+str(uuid.uuid4())+'.app')
subprocess.run(['/usr/bin/ditto',str(source),str(stage)],check=True)
if app.exists():
    backup=output/'expansion'/('previous-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S')+'.app')
    assert not backup.exists(); app.rename(backup)
stage.rename(app)
(output/'expansion').mkdir(exist_ok=True)
shutil.copy2(cli,output/'expansion/namefix')
receipt={'configuration':'Debug','architecture':'arm64','app':str(app.relative_to(root)),'cli':'artifacts/development/expansion/namefix','files':{}}
for path in sorted(app.rglob('*')):
    if path.is_file(): receipt['files'][str(path.relative_to(app))]=hashlib.sha256(path.read_bytes()).hexdigest()
receipt['cliSHA256']=hashlib.sha256(cli.read_bytes()).hexdigest()
(output/'expansion/artifact-receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print(app)
