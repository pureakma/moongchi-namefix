#!/usr/bin/env python3
"""Isolated Debug CLI contract check. Never uses the user's support directory."""
import base64, hashlib, json, os, pathlib, pty, select, subprocess, sys, tempfile, time
binary = pathlib.Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix='namefix-cli-', dir='/private/tmp') as temporary:
    root = pathlib.Path(temporary)
    environment = dict(os.environ, NAMEFIX_TEST_SUPPORT=str(root/'support'))
    source = root/'a.txt'; source.write_bytes(b'unchanged fixture contents')
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    def run(*args):
        return subprocess.run([str(binary), *map(str,args)], env=environment, capture_output=True, text=True, timeout=15)
    preview = run('--prefix','new_','--json',source)
    assert preview.returncode == 0, preview.stderr
    plan = json.loads(preview.stdout); assert len(plan['operations']) == 1
    assert base64.b64decode(plan['operations'][0]['destination']) == b'new_a.txt'
    assert source.exists() and not (root/'new_a.txt').exists()
    refused = run('--prefix','new_','--execute',source)
    assert refused.returncode == 1 and 'InteractiveConfirmationRequired' in refused.stderr
    assert hashlib.sha256(source.read_bytes()).hexdigest() == digest
    def confirm(*args):
        master, slave = pty.openpty()
        process = subprocess.Popen([str(binary), *map(str,args)], stdin=slave, stdout=slave, stderr=slave, env=environment)
        os.close(slave); output=b''; sent=False; deadline=time.monotonic()+15
        try:
            while time.monotonic()<deadline and process.poll() is None:
                readable,_,_=select.select([master],[],[],0.1)
                if readable:
                    try: output+=os.read(master,65536)
                    except OSError: break
                    if b'Type RENAME' in output and not sent: os.write(master,b'RENAME\n'); sent=True
            assert process.wait(timeout=5)==0, output.decode(errors='replace')
            assert sent
        finally:
            os.close(master)
            if process.poll() is None: process.kill(); process.wait()
    confirm('--prefix','new_','--execute',source)
    renamed=root/'new_a.txt'; assert renamed.exists() and not source.exists()
    assert hashlib.sha256(renamed.read_bytes()).hexdigest()==digest
    journals=list((root/'support'/'History').glob('*.jsonl')); assert len(journals)==1
    confirm('--undo',journals[0].stem,'--execute')
    assert source.exists() and not renamed.exists() and hashlib.sha256(source.read_bytes()).hexdigest()==digest
    recipe={'id':'80E55D52-8AFC-4E5B-945D-9BF2A66F52A4','name':'fixture','pipeline':{'schemaVersion':1,'target':'NFC','rules':[]}}
    path=root/'preset.json'; path.write_text(json.dumps(recipe))
    assert run('--recipe',path,'--json',source).returncode==1
    assert run('--development-pro','--recipe',path,'--json',source).returncode==0
    invalid=run('--insert','-1','x','--json',source); assert invalid.returncode==1
    print('PASS: CLI dry-run/raw JSON, non-TTY refusal, explicit TTY rename/undo, content hash, free/Pro preset boundary, invalid input; isolated temporary support')
