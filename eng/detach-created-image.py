from pathlib import Path
import plistlib,subprocess,sys
image=Path(sys.argv[1]).resolve()
assert image.parent.name=='qa' and image.name.startswith('Moongchi_NameFix_') and image.suffix=='.dmg'
info=plistlib.loads(subprocess.check_output(['hdiutil','info','-plist']))
for item in info.get('images',[]):
    if Path(item.get('image-path','/')).resolve()==image:
        device=next((e['dev-entry'] for e in item.get('system-entities',[]) if e.get('dev-entry','').startswith('/dev/disk')),None)
        if device:
            print('Verified newly created image:',image,'device:',device,flush=True)
            subprocess.run(['hdiutil','detach',device],check=True)
