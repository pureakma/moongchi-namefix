#!/usr/bin/env python3
"""Record actual v1 candidate evidence. Missing/failed gates stop the receipt."""
from pathlib import Path
import ast, datetime, hashlib, json, plistlib, re

root = Path(__file__).resolve().parent.parent
candidate = root/'artifacts/release-candidate/1.0.0'
evidence = candidate/'evidence'
package = candidate/'build3'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def fingerprint(patterns):
    digest = hashlib.sha256()
    for p in sorted({p for pattern in patterns for p in root.glob(pattern) if p.is_file()}):
        digest.update(str(p.relative_to(root)).encode()); digest.update(b'\0'); digest.update(p.read_bytes())
    return digest.hexdigest()
def write(path, value): path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n')

test_logs = ['full-core.txt','full-runtime.txt','performance-and-races.txt','case-sensitive-final.txt','release-transaction-tests.txt','ui-recovery-final.txt']
passed, details = set(), {}
for name in test_logs:
    text = (evidence/name).read_text()
    assert not re.search(r"Test Case '[^']+' failed|error:.*XCTAssert", text), name
    cases = sorted(set(re.findall(r"Test Case '([^']+)' passed", text)))
    assert cases, name
    passed.update(cases); details[name] = cases
assert len(passed) == 91, len(passed)
write(evidence/'test-index.json', {'uniquePassed': len(passed), 'counting': 'union across complete baseline and affected final regressions; no duplicate architecture/configuration counts', 'logs': details})
markers = {
    'release-build3.txt': '** BUILD SUCCEEDED **', 'release-cli-final.txt': 'Build complete!',
    'cli-debug.txt': 'PASS:', 'cli-release-final.txt': 'PASS:', 'resources.txt': '393 keys',
    'render-final.txt': 'Rendered 75', 'render-history-build3.txt': 'Rendered 6',
    'signing-build3.txt': 'PASS:', 'package-build3-verification.txt': 'PASS:',
}
for name, marker in markers.items(): assert marker in (evidence/name).read_text(), name
info = plistlib.loads((package/'Moongchi NameFix.app/Contents/Info.plist').read_bytes())
assert info['CFBundleShortVersionString'] == '1.0.0' and info['CFBundleVersion'] == '3'
manifest = json.loads((package/'ARTIFACT_MANIFEST.json').read_text())
assert manifest['signing'] == 'Developer ID' and manifest['publicRelease'] is False
for name, expected in manifest['bundleFiles'].items(): assert sha(package/'Moongchi NameFix.app'/name) == expected, name
for name, expected in manifest['packages'].items(): assert sha(package/name) == expected['sha256'], name
assert sha(package/'namefix') == manifest['cliSHA256']

core = ['Packages/NameFixCore/Sources/**/*.swift']
runtime = core + ['Infrastructure/**/*.swift','Application/**/*.swift']
ui = runtime + ['App/**/*.swift','Resources/**/*']
cli = runtime + ['CLI/**/*.swift']
dependencies = ['Package.swift','Packages/NameFixCore/Package.swift','project.yml']
source = ui + cli + dependencies + ['eng/*.sh','eng/*.py']
files = sorted({p for pattern in source for p in root.glob(pattern) if p.is_file()})
write(evidence/'source-snapshot.json', {'fingerprint': fingerprint(source), 'files': {str(p.relative_to(root)): sha(p) for p in files}})
manifest['sourceFingerprint'] = fingerprint(source)
manifest['sourceSnapshot'] = 'artifacts/release-candidate/1.0.0/evidence/source-snapshot.json'
manifest['testIndexSHA256'] = sha(evidence/'test-index.json')
write(package/'ARTIFACT_MANIFEST.json', manifest)

path = root/'.ai/validation-cache.json'; cache = json.loads(path.read_text())
for old in cache['entries']:
    if old['validationId'].startswith('MAC-V1-'): continue
    if old.get('status') == 'PASS' and old.get('sourceFingerprint') != fingerprint(old.get('scope', [])):
        old['previousStatus'] = 'PASS'; old['status'] = 'STALE'
        old['invalidationReason'] = 'v1 coordination/freshness/UI/CLI changes; old evidence preserved; see MAC-V1 entries'
    if 'SOURCE-RACE' in old['validationId'] or 'SOURCE_RACE' in old['validationId']:
        if old['status'] != 'SUPERSEDED': old['previousStatus'] = old['status']
        old['status'] = 'SUPERSEDED'
        old['supersededBy'] = 'MAC-V1-SOURCE-RACE-LIMITATION'
    if old['validationId'] == 'MAC-RELEASE-SIGNING':
        if old['status'] != 'SUPERSEDED': old['previousStatus'] = old['status']
        old['status'] = 'SUPERSEDED'; old['supersededBy'] = 'MAC-V1-DEVELOPER-ID'

entries = []
def entry(key, scope, tests, filename, command, status='PASS', configuration='Debug', case=False):
    file = evidence/filename
    assert file.exists()
    entries.append({'validationId': 'MAC-V1-'+key, 'scope': scope, 'status': status,
        'architecture': 'arm64', 'configuration': configuration, 'command': command,
        'sourceFingerprint': fingerprint(scope), 'testFingerprint': fingerprint(tests),
        'dependencyFingerprint': fingerprint(dependencies), 'toolchainFingerprint': sha(evidence/'environment.txt'),
        'environment': {'os':'macOS 27.0.1 (26A434)', 'sdk':'27.0', 'filesystem':'APFS', 'caseSensitive':case},
        'timestamp':datetime.datetime.fromtimestamp(file.stat().st_mtime,datetime.timezone.utc).isoformat(),
        'evidencePath':str(file.relative_to(root)), 'evidenceSHA256':sha(file)})
entry('CORE',core,['Packages/NameFixCore/Tests/**/*.swift'],'full-core.txt','eng/test.sh --core')
entry('RUNTIME',runtime,['Tests/IntegrationTests/**/*.swift'],'test-index.json','eng/test.sh --scope all; affected coordination/performance/recovery regressions')
entry('MODEL',ui,['Tests/UIModelTests/**/*.swift'],'ui-recovery-final.txt','eng/test.sh --filter AppModelTests (with related recovery regressions)')
entry('APFS-CASE-SENSITIVE',runtime,['Tests/IntegrationTests/**/*.swift'],'case-sensitive-final.txt','python3 eng/test-case-sensitive.py',case=True)
entry('RELEASE-TRANSACTIONS',runtime,['Tests/IntegrationTests/**/*.swift'],'release-transaction-tests.txt','NAMEFIX_MUTATION_PERF=1 eng/test.sh -c release --filter TransactionTests|CoordinatedTransactionTests',configuration='Release')
entry('PERFORMANCE',runtime,['Tests/IntegrationTests/**/*.swift'],'performance-and-races.txt','NAMEFIX_MUTATION_PERF=1 NAMEFIX_EXPANSION_PERF=1 NAMEFIX_PERFORMANCE=1 eng/test.sh --filter CoordinatedTransactionTests|ExpansionPerformanceTests|SafetyTests.testScanPerformanceProfile')
entry('CLI',cli,['eng/test-release-cli.py'],'cli-release-final.txt','python3 eng/test-release-cli.py .build/out/Products/Release/namefix',configuration='Release')
entry('RESOURCES',['Resources/**/*','eng/resources.py','eng/validate-resources.py'],['eng/validate-resources.py'],'resources.txt','python3 eng/validate-resources.py')
entry('RENDER',ui,['App/ResponsiveFixtures.swift'],'render-history-build3.txt','Release --render-responsive; final affected --history-only (6 renders after 75 baseline)',configuration='Release')
entry('BUILD',ui+dependencies,[],'release-build3.txt','eng/build.sh --configuration Release --arch arm64',configuration='Release')
entry('DEVELOPER-ID',ui+cli,[],'signing-build3.txt','python3 eng/sign-candidate.py (existing Developer ID, new copy only)',configuration='Release')
entry('PACKAGES',ui+cli+['eng/package-candidate.py','eng/verify-candidate.py'],[],'package-build3-verification.txt','python3 eng/verify-candidate.py artifacts/release-candidate/1.0.0/build3',configuration='Release')
entry('SOURCE-RACE-LIMITATION',runtime,['Tests/IntegrationTests/CoordinatedTransactionTests.swift'],'performance-and-races.txt','Real executor adversarial interleaving; detection/stop PASS, atomic prevention NOT claimed',status='KNOWN_LIMITATION')
entry('NOTARIZATION',ui,[],'gatekeeper-build3.txt','spctl --assess (unnotarized Developer ID); missing notary profile',status='BLOCKED_EXTERNAL',configuration='Release')
entry('PAID-PROVIDER',core+['App/AppModel.swift','CLI/main.swift'],[],'cli-release-final.txt','Verified fail-closed Free behavior; actual purchase provider unconfigured',status='BLOCKED_EXTERNAL',configuration='Release')
cache['entries'] = [e for e in cache['entries'] if not e['validationId'].startswith('MAC-V1-')] + entries
write(path, cache)
write(evidence/'sha256.json', {str(p.relative_to(candidate)):sha(p) for p in sorted(evidence.iterdir()) if p.is_file() and p.name != 'sha256.json'})
for p in (root/'eng').glob('*.py'): ast.parse(p.read_text(), filename=str(p))
print('PASS: 91 unique XCTest cases; required final gates; Developer ID app/CLI/package hashes; source receipt; validation cache; script syntax')
