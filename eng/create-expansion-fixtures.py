#!/usr/bin/env python3
"""Create a NEW dedicated user-review fixture directory; never replace anything."""
import csv, hashlib, json, os, pathlib, sys, unicodedata, uuid
root=pathlib.Path(sys.argv[1]).absolute()
root.mkdir(parents=False, exist_ok=False)
manifest=[]
def put(relative, content=b'NameFix disposable test data. File contents must remain unchanged.\n'):
    path=os.fsencode(root)+b'/'+relative.encode('utf-8')
    os.makedirs(os.path.dirname(path),exist_ok=True)
    with open(path,'xb') as f:f.write(content)
    manifest.append({'relativeRawBase64':__import__('base64').b64encode(relative.encode()).decode(),'sha256':hashlib.sha256(content).hexdigest()})
put('01_Unicode/NFC_'+unicodedata.normalize('NFC','한글éが')+'.txt')
put('01_Unicode/NFD_'+unicodedata.normalize('NFD','한글éが')+'.txt')
put('01_Unicode/normal.txt')
for name in ['  report  one.txt','photo 002.txt','👨‍👩‍👧‍👦 가족.txt','.hidden.txt','archive.tar.txt']:put('02_무료규칙/'+name)
for name in ['a.txt','b.txt','c.txt']:put('03_CSV교환/'+name,name.encode())
for name in ['photo.jpg','photo.raw','photo.xmp']:put('04_이름쌍/'+name,b'Filename-pair fixture only, not encoded media.\n')
put('05_감시대기/first.txt')
with (root/'swap.csv').open('x',newline='',encoding='utf-8-sig') as f:
    writer=csv.writer(f);writer.writerows([['source','destination'],['a.txt','b.txt'],['b.txt','c.txt'],['c.txt','a.txt']])
(root/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(root/'사용법.txt').write_text('''이 폴더는 새로 만든 폐기 가능한 테스트 자료입니다. 실제 원본 자료를 넣지 마세요.
01: NFC/NFD를 번갈아 선택해 문자 칸과 실제 이름이 바뀌는지 확인하고 작업 기록에서 되돌리세요.
02: 이름 변경 규칙 예제를 적용하고 미리보기 후 실행하세요.
03: 이 하위 폴더만 앱에 넣고 ‘+ 규칙 추가 → 고급 → CSV 목록’에서 상위 swap.csv를 불러오세요. 이름 교환 후 내용 a/b/c가 보존되어야 합니다.
04: 내용은 실제 사진/RAW가 아니라 테스트 텍스트입니다. jpg,raw,xmp 파일 쌍 이름 변경만 확인하세요. 실제 미디어 메타데이터 테스트에 쓰지 마세요.
05: 이 폴더를 ‘폴더 감시’에 등록한 뒤 Finder에서 파일을 추가하세요. 검토 대기만 생기고 자동 변경하지 않아야 합니다.
모든 기능은 무료이며 별도 설정 없이 쓸 수 있습니다.
각 실행은 미리보기와 확인을 거칩니다. manifest.json에 최초 파일 bytes 이름과 내용 hash를 남겼습니다.
''',encoding='utf-8')
print(root)
