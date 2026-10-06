"""Record focused development evidence without promoting previous release checks."""
from pathlib import Path
import hashlib,json,re,datetime
root=Path(__file__).resolve().parent.parent
folder=root/'artifacts/development/commercial-review'
def fingerprint(patterns):
    h=hashlib.sha256()
    for p in sorted({p for pat in patterns for p in root.glob(pat) if p.is_file()}):
        h.update(str(p.relative_to(root)).encode());h.update(b'\0');h.update(p.read_bytes())
    return h.hexdigest()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
cachepath=root/'.ai/validation-cache.json';cache=json.loads(cachepath.read_text())
for e in cache['entries']:
    if e['validationId'].startswith('COMMERCIAL-'):continue
    if e['status']=='PASS' and (fingerprint(e['scope'])!=e['sourceFingerprint'] or (e.get('evidencePath') and sha(root/e['evidencePath'])!=e.get('evidenceSHA256'))):
        e['status']='STALE';e['invalidationReason']='2026-10-04 commercial development changes; old evidence retained, not a current PASS'
core=['Packages/NameFixCore/Sources/**/*.swift'];runtime=core+['Infrastructure/**/*.swift','Application/**/*.swift'];ui=runtime+['App/**/*.swift','Resources/**/*']
specs=[
('COMMERCIAL-UI-MODEL',ui,['Tests/UIModelTests/**/*.swift'],'ui-model.txt','eng/test.sh --scope ui-model',7),
('COMMERCIAL-SAFETY',runtime,['Tests/IntegrationTests/SafetyTests.swift'],'safety.txt','eng/test.sh --scope safety',7),
('COMMERCIAL-TRANSACTION',runtime,['Tests/IntegrationTests/TransactionTests.swift'],'transaction.txt','eng/test.sh --scope transaction',11),
('COMMERCIAL-DEBUG',ui+['project.yml'],[],'debug-build.txt','eng/build.sh --configuration Debug --arch arm64',None),
('COMMERCIAL-RESOURCES',['Resources/**/*','eng/resources.py','eng/validate-resources.py'],[],'resources.txt','python3 eng/validate-resources.py',None),
('COMMERCIAL-RENDER',ui,[],'render.txt','Debug app --render-review artifacts/development/commercial-review/rendered',None)]
cache['entries']=[e for e in cache['entries'] if not e['validationId'].startswith('COMMERCIAL-')]
for key,scope,tests,filename,command,count in specs:
    path=folder/filename;log=path.read_text()
    if count is not None:
        passed=set(re.findall(r"Test Case '([^']+)' passed",log));assert len(passed)==count,(filename,len(passed));assert not re.search(r"Test Case '[^']+' failed",log)
    if key.endswith('DEBUG'):assert '** BUILD SUCCEEDED **' in log
    if key.endswith('RESOURCES'):assert 'PASS: 215 keys' in log
    if key.endswith('RENDER'):assert 'Rendered 20 product-review layouts' in log
    cache['entries'].append({'validationId':key,'scope':scope,'status':'PASS','architecture':'arm64','configuration':'Debug','command':command,'sourceFingerprint':fingerprint(scope),'testFingerprint':fingerprint(tests),'dependencyFingerprint':fingerprint(['Package.swift','Packages/NameFixCore/Package.swift','project.yml']),'toolchainFingerprint':fingerprint(['artifacts/evidence/environment-current.txt']),'environment':{'os':'macOS 27.0.1','sdk':'27.0','filesystem':'APFS'},'timestamp':datetime.datetime.fromtimestamp(path.stat().st_mtime,datetime.timezone.utc).isoformat(),'evidencePath':str(path.relative_to(root)),'evidenceSHA256':sha(path)})
cachepath.write_text(json.dumps(cache,ensure_ascii=False,indent=2))
source=root/'.build/xcode/Build/Products/Debug/Moongchi NameFix.app';app=root/'artifacts/development/Moongchi NameFix Dev.app'
files={str(p.relative_to(source)):sha(p) for p in source.rglob('*') if p.is_file()}
assert all(sha(app/name)==digest for name,digest in files.items())
(folder/'development-build.json').write_text(json.dumps({'configuration':'Debug','architecture':'arm64','application':str(app.relative_to(root)),'bundleFiles':files,'productVerdict':'INCOMPLETE_SOURCE_RACE','releasePerformed':False},ensure_ascii=False,indent=2))
print('PASS: 25 focused tests; Debug copy matches; previous affected PASS invalidated; six focused scopes recorded')
