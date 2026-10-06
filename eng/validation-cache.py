from pathlib import Path
import hashlib,json,datetime,subprocess
root=Path(__file__).resolve().parent.parent

def fingerprint(patterns):
    files=sorted({p for pattern in patterns for p in root.glob(pattern) if p.is_file()})
    digest=hashlib.sha256()
    for f in files:
        digest.update(str(f.relative_to(root)).encode());digest.update(b'\0');digest.update(f.read_bytes())
    return digest.hexdigest()

def entry(id,scope,tests,evidence,command,status='PASS',configuration='Debug',case=False):
    path=root/evidence
    return {'validationId':id,'scope':scope,'status':status,'architecture':'arm64','configuration':configuration,'command':command,'sourceFingerprint':fingerprint(scope),'testFingerprint':fingerprint(tests),'dependencyFingerprint':fingerprint(['Package.swift','Packages/NameFixCore/Package.swift','project.yml']),'toolchainFingerprint':fingerprint(['artifacts/evidence/environment-current.txt']),'environment':{'os':'macOS 27.0.1 (26A434)','sdk':'27.0','filesystem':'APFS','caseSensitive':case,'signing':'ad-hoc / no Developer ID','fixtureVersion':2},'timestamp':datetime.datetime.fromtimestamp(path.stat().st_mtime,datetime.timezone.utc).isoformat() if path.exists() else None,'evidencePath':evidence,'evidenceSHA256':hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None}
core=['Packages/NameFixCore/Sources/**/*.swift']
fs=core+['Infrastructure/**/*.swift','Application/**/*.swift']
ui=fs+['App/**/*.swift','Resources/**/*.strings','Resources/*.xcstrings','App/Info.plist']
entries=[
entry('MAC-CORE-UNICODE',core,['Packages/NameFixCore/Tests/**/*.swift'],'artifacts/evidence/full-tests.txt','eng/test.sh --level 3'),
entry('MAC-FS-SCAN-EXECUTE-UNDO-RECOVERY',fs,['Tests/IntegrationTests/**/*.swift'],'artifacts/evidence/fs-final-regression.txt','NAMEFIX_PERFORMANCE=1 eng/test.sh --level 2 --scope all'),
entry('MAC-UI-STATE',ui,['Tests/UIModelTests/**/*.swift'],'artifacts/evidence/fs-final-regression.txt','eng/test.sh --scope ui-model'),
entry('MAC-APFS-CASE-SENSITIVE',fs,['Tests/IntegrationTests/**/*.swift'],'artifacts/evidence/case-final.txt','NAMEFIX_FIXTURE_ROOT=/private/tmp/namefix-case-qa-mount eng/test.sh --scope all',case=True),
entry('MAC-PERFORMANCE',fs,['Tests/IntegrationTests/SafetyTests.swift'],'artifacts/evidence/fs-final-regression.txt','NAMEFIX_PERFORMANCE=1 eng/test.sh --level 2 --scope all'),
entry('MAC-UI-TEST-BUILD',ui,['Tests/UITests/**/*.swift'],'artifacts/evidence/ui-tests-build.txt','xcodebuild build-for-testing'),
entry('MAC-RELEASE-SOURCE-RACE',fs,['Tests/IntegrationTests/SafetyTests.swift'],'docs/FILESYSTEM_CAPABILITIES.md',None,status='BLOCKED_RELEASE_SOURCE_RACE'),
entry('MAC-RESOURCES', ['Resources/**/*','eng/resources.py','eng/validate-resources.py'],[], 'artifacts/evidence/resources.txt','python3 eng/validate-resources.py'),
entry('MAC-RELEASE-BUILD',ui+['project.yml'],[], 'artifacts/evidence/final-release.txt','eng/build.sh --configuration Release --arch arm64',configuration='Release'),
entry('MAC-RENDER',ui,[], 'artifacts/evidence/render.txt','QA app --render-fixtures artifacts/evidence/rendered',configuration='Release'),
entry('MAC-PACKAGE',ui+['eng/package.sh','eng/detach-created-image.py'],[], 'artifacts/evidence/final-package-check.txt','eng/verify-release.sh + ZIP/DMG mount/hash verification',configuration='Release'),
entry('MAC-FINDER-REAL-GESTURE',ui,['Tests/UITests/**/*.swift'],'docs/MANUAL_QA_CHECKLIST.md',None,status='NEEDS_MANUAL_QA'),
entry('MAC-RELEASE-SIGNING',ui,[], 'docs/RELEASE.md',None,status='BLOCKED_RELEASE_SIGNING',configuration='Release')]
for e in entries:
    if e['status']=='PASS' and not (root/e['evidencePath']).exists():
        raise SystemExit('Missing verification evidence: '+e['evidencePath'])
(root/'.ai/validation-cache.json').write_text(json.dumps({'schemaVersion':1,'invalidationPolicy':'Content fingerprints, dependencies, tests, toolchain and environment. FS changes invalidate scan/execute/undo/recovery/UI orchestration; no commit-only reuse.','entries':entries},indent=2))
print('Recorded',len(entries),'validation scopes')
