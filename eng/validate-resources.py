from pathlib import Path
import json,re,hashlib,plistlib
root=Path(__file__).resolve().parent.parent
catalog=json.loads((root/'Resources/Localizable.xcstrings').read_text())['strings']
for key,item in catalog.items():
    values=[item['localizations'][lang]['stringUnit']['value'] for lang in ['ko','en','ja']]
    args=[set(re.findall(r'\{(\d+)\}',v)) for v in values]
    assert args[0]==args[1]==args[2],key
    assert all(not re.search(r'\{\d+:',v) for v in values),key
    assert all(not any(word in v for word in ['Windows','Ctrl+','Explorer','MAX_PATH']) for v in values),key
for source in (root/'App').glob('*.swift'):
    for key in re.findall(r'(?:\.t\(|L10n\.text\()"([A-Za-z]+)"',source.read_text()): assert key in catalog,(source,key)
for f in json.loads((root/'Moongchi_NameFix_macOS_Dev_Handoff_v1.0/HANDOFF_MANIFEST.json').read_text())['files']:
    assert hashlib.sha256((root/'Moongchi_NameFix_macOS_Dev_Handoff_v1.0'/f['path']).read_bytes()).hexdigest()==f['sha256']
for font in ['PretendardVariable','PretendardJPVariable']:
    assert (root/'Resources'/f'{font}-LICENSE.txt').exists()
    assert hashlib.sha256((root/'Resources'/f'{font}.ttf').read_bytes()).digest()==hashlib.sha256((root/'Moongchi_NameFix_macOS_Dev_Handoff_v1.0/assets/fonts'/f'{font}.ttf').read_bytes()).digest()
info=plistlib.loads((root/'App/Info.plist').read_bytes());assert info['LSArchitecturePriority']==['arm64'];assert info['NSServices']
assert '#DDD8C5' in (root/'docs/FILESYSTEM_CAPABILITIES.md').read_text() or 'DDD8C5' in (root/'App/Theme.swift').read_text()
assert not any(re.search(r'URLSession|NWConnection|NSURLConnection',p.read_text()) for folder in ['App','Application','Infrastructure'] for p in (root/folder).glob('*.swift'))
print(f'PASS: {len(catalog)} keys × 3 locales; placeholder parity; macOS overrides; 9 handoff hashes; fonts/licenses; arm64 Services plist; no networking APIs')
