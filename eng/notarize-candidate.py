#!/usr/bin/env python3
"""Notarize a Developer ID signed candidate, staple it, and build the distribution packages.

Works on a copy in a new directory; the signed candidate is not modified. Nothing is re-signed:
the app and the CLI that were signed once are the binaries submitted. A state is recorded only
after it is observed: ACCEPTED after Apple accepts the submission, stapled after stapler validates.
The disk image is the primary package; it is signed, notarized and stapled as well. The ZIP holds
the same contents. Nothing is uploaded anywhere except the submissions to Apple's notary service."""
from pathlib import Path
import argparse, hashlib, json, plistlib, shutil, subprocess, tempfile
root = Path(__file__).resolve().parent.parent
PRODUCT = ['version', 'build', 'configuration', 'architecture', 'minimumOS', 'bundleID', 'developer', 'support', 'distribution', 'pricing', 'sourceCommit']
DOCUMENTS = ['README.txt', 'USER_GUIDE.md', 'ThirdPartyNotices.md']
parser = argparse.ArgumentParser()
parser.add_argument('--input', required=True, type=Path, help='A Developer ID signed candidate directory')
parser.add_argument('--profile', required=True, help='notarytool Keychain profile name')
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args()
source, out = args.input.resolve(), args.output.resolve()
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def run(*command, timeout=3600): return subprocess.run(list(map(str, command)), check=True, timeout=timeout)
def text(*command, timeout=3600): return subprocess.run(list(map(str, command)), check=True, capture_output=True, text=True, timeout=timeout)
def bundle(app): return {str(p.relative_to(app)): sha(p) for p in sorted(app.rglob('*')) if p.is_file()}
signed = json.loads((source/'ARTIFACT_MANIFEST.json').read_text())
assert (signed['signing'], signed['developerID'], signed['notarization']) == ('Developer ID', 'SIGNED', 'NOT_RUN'), 'Input must be a signed, not yet notarized candidate'
assert out.is_relative_to(root/'artifacts/release-candidate') and not out.exists(), 'Use a new output directory'
assert bundle(source/'Moongchi NameFix.app') == signed['bundleFiles'] and sha(source/'namefix') == signed['cliSHA256'], 'Input differs from its manifest'
identity, team = signed['signingIdentity'], signed['teamID']
out.mkdir(parents=True)
evidence = out/'evidence'; evidence.mkdir()
app, cli = out/'Moongchi NameFix.app', out/'namefix'
run('ditto', source/'Moongchi NameFix.app', app)
run('ditto', source/'namefix', cli)
for name in DOCUMENTS: shutil.copy2(source/name, out/name)
# The binaries submitted are the ones that were signed: byte for byte.
assert bundle(app) == signed['bundleFiles'] and sha(cli) == signed['cliSHA256']

def notarize(path, label):
    """Submit and wait. Returns the submission only when Apple's answer is Accepted."""
    result = subprocess.run(['xcrun', 'notarytool', 'submit', str(path), '--keychain-profile', args.profile, '--wait', '--output-format', 'json'], capture_output=True, text=True, timeout=7200)
    (evidence/f'notary-{label}-submit.json').write_text(result.stdout or result.stderr)
    try: answer = json.loads(result.stdout)
    except ValueError: raise SystemExit(f'notarytool gave no result for the {label}: {(result.stderr or result.stdout).strip()[:400]}')
    submission, status = answer.get('id'), answer.get('status')
    if submission:
        log = subprocess.run(['xcrun', 'notarytool', 'log', submission, '--keychain-profile', args.profile], capture_output=True, text=True, timeout=600)
        (evidence/f'notary-{label}-log.json').write_text(log.stdout or log.stderr)
    if status != 'Accepted': raise SystemExit(f'Notarization of the {label} was not accepted: status={status} id={submission}. See {evidence}')
    return {'id': submission, 'status': status}

with tempfile.TemporaryDirectory(prefix='namefix-notary-', dir='/private/tmp') as temporary:
    work = Path(temporary)
    run('ditto', '-c', '-k', '--keepParent', app, work/'app.zip')
    submissions = {'app': notarize(work/'app.zip', 'app')}
    run('xcrun', 'stapler', 'staple', app)
    (evidence/'app-stapler-validate.txt').write_text(text('xcrun', 'stapler', 'validate', app).stdout)
    run('codesign', '--verify', '--deep', '--strict', app)
    assessment = subprocess.run(['spctl', '--assess', '--type', 'execute', '--verbose=2', str(app)], capture_output=True, text=True)
    (evidence/'app-gatekeeper.txt').write_text(assessment.stderr + assessment.stdout)
    assert assessment.returncode == 0 and 'Notarized Developer ID' in assessment.stderr, 'Gatekeeper did not accept the app'
    # Stapling adds the ticket and changes nothing that was signed.
    stapled = bundle(app)
    assert {name for name in stapled if stapled[name] != signed['bundleFiles'].get(name)} <= {'Contents/CodeResources'}, 'Stapling changed signed content'
    product = {key: signed[key] for key in PRODUCT}
    (out/'BUILD_INFO.json').write_text(json.dumps({**product, 'signing': 'Developer ID', 'teamID': team, 'notarization': 'ACCEPTED'}, ensure_ascii=False, indent=2)+'\n')
    stage = work/'stage'; stage.mkdir()
    run('ditto', app, stage/app.name)
    run('ditto', cli, stage/'namefix')
    for name in [*DOCUMENTS, 'BUILD_INFO.json']: shutil.copy2(out/name, stage/name)
    basename = f"Moongchi_NameFix_{product['version']}_build{product['build']}_arm64"
    archive, image = out/(basename+'.zip'), out/(basename+'.dmg')
    run('ditto', '-c', '-k', '--sequesterRsrc', stage, archive)
    (stage/'Applications').symlink_to('/Applications')
    run('hdiutil', 'create', '-volname', 'Moongchi NameFix', '-srcfolder', stage, '-fs', 'APFS', '-format', 'UDZO', image)
    # Some hdiutil versions leave the newly created image attached. Touch only
    # devices reported for this exact, new image, never unrelated user disks.
    attached = plistlib.loads(subprocess.check_output(['hdiutil', 'info', '-plist']))
    for item in attached.get('images', []):
        if Path(item.get('image-path', '/')).resolve() == image:
            devices = [e['dev-entry'] for e in item.get('system-entities', []) if e.get('dev-entry', '').startswith('/dev/disk')]
            if devices: run('hdiutil', 'detach', devices[0])
    run('hdiutil', 'verify', image)
    run('codesign', '--sign', identity, '--timestamp', image)
    submissions['dmg'] = notarize(image, 'dmg')
    run('xcrun', 'stapler', 'staple', image)
    (evidence/'dmg-stapler-validate.txt').write_text(text('xcrun', 'stapler', 'validate', image).stdout)
    run('hdiutil', 'verify', image)
    assessment = subprocess.run(['spctl', '--assess', '--type', 'open', '--context', 'context:primary-signature', '--verbose=2', str(image)], capture_output=True, text=True)
    (evidence/'dmg-gatekeeper.txt').write_text(assessment.stderr + assessment.stdout)
    assert assessment.returncode == 0 and 'Notarized Developer ID' in assessment.stderr, 'Gatekeeper did not accept the disk image'
packages = [image, archive]
final = {
    'schemaVersion': 3, **product,
    'signing': 'Developer ID', 'developerID': 'SIGNED', 'notarization': 'ACCEPTED', 'stapled': True, 'gatekeeper': 'PASS', 'publicRelease': False,
    'signingIdentity': identity, 'teamID': team, 'notarizationSubmissions': submissions,
    'provenance': {**signed['provenance'], 'signedCandidate': str(source.relative_to(root)), 'signedManifestSHA256': sha(source/'ARTIFACT_MANIFEST.json')},
    'releaseToolingCommit': text('git', '-C', root, 'rev-parse', 'HEAD').stdout.strip(),
    'primaryPackage': image.name,
    'bundleFiles': stapled, 'cliSHA256': sha(cli),
    'documents': {name: sha(out/name) for name in [*DOCUMENTS, 'BUILD_INFO.json']},
    'packages': {p.name: {'sha256': sha(p), 'bytes': p.stat().st_size} for p in packages},
}
(out/'ARTIFACT_MANIFEST.json').write_text(json.dumps(final, ensure_ascii=False, indent=2)+'\n')
(out/'SHA256SUMS.txt').write_text(''.join(f'{sha(p)}  {p.name}\n' for p in [*packages, cli]))
(out/'CANDIDATE_STATUS.txt').write_text(
    f"Moongchi NameFix {product['version']} build {product['build']} - notarized release artifact\n"
    f"Product source commit: {product['sourceCommit']}\n"
    f"Developer ID signing: DONE (team {team}). Notarization: ACCEPTED (app {submissions['app']['id']}, disk image {submissions['dmg']['id']}). Stapled: YES.\n"
    "Public release: NO. Publishing is a separate, explicit step.\n")
print(f"PASS: app notarized ({submissions['app']['id']}) and stapled; disk image signed, notarized ({submissions['dmg']['id']}) and stapled; Gatekeeper accepted both; packages: {image.name}, {archive.name}")
