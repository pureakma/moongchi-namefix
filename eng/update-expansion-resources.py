from pathlib import Path
import json
root=Path(__file__).resolve().parent.parent
values=json.loads((root/'eng/expansion-localizations.json').read_text())
p=root/'Resources/Localizable.xcstrings';catalog=json.loads(p.read_text())
for key,texts in values.items():
    assert len(texts)==3
    catalog['strings'][key]={'extractionState':'manual','localizations':{lang:{'stringUnit':{'state':'translated','value':v}} for lang,v in zip(['ko','en','ja'],texts)}}
p.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
for lang in ['ko','en','ja']:
    (root/'Resources'/f'{lang}.lproj/Localizable.strings').write_text('\n'.join(json.dumps(k)+' = '+json.dumps(v['localizations'][lang]['stringUnit']['value'],ensure_ascii=False)+';' for k,v in sorted(catalog['strings'].items()))+'\n')
