#!/usr/bin/env python3
"""Runs NameFix inside the real App Sandbox and checks what it can and cannot do there.

A Debug app is built with the store entitlements (eng/build.sh --sandbox-debug). Folders and
files are handed to it with `open -a`, the way Finder's Open With does, so macOS itself grants
the access; nothing is clicked. Each step is a separate launch, so "after reopening the app"
is real. The app reports facts on stdout, which `open --stdout` connects to a file.

Only folders this script creates under a new temporary folder are used, and only disk images
it creates are attached or detached.

  eng/test-sandbox.py              build, then run every step
  eng/test-sandbox.py --no-build   reuse the sandboxed Debug app
  eng/test-sandbox.py --compare    time the same work inside and outside the sandbox (both Debug apps must be built)
"""
from pathlib import Path
import argparse, json, os, plistlib, subprocess, sys, tempfile, time, unicodedata

root = Path(__file__).resolve().parent.parent
app = root / ".build/xcode-sandbox/Build/Products/Debug/Moongchi NameFix.app"
parser = argparse.ArgumentParser(); parser.add_argument("--no-build", action="store_true"); parser.add_argument("--compare", action="store_true"); options = parser.parse_args()
plain = root / ".build/xcode/Build/Products/Debug/Moongchi NameFix.app"
if not options.no_build and not options.compare:
    subprocess.run([str(root / "eng/build.sh"), "--configuration", "Debug", "--arch", "arm64", "--sandbox-debug"], cwd=root, check=True, stdout=subprocess.DEVNULL)
entitlements = plistlib.loads(subprocess.check_output(["codesign", "-d", "--entitlements", ":-", str(app)], stderr=subprocess.DEVNULL))
assert entitlements.get("com.apple.security.app-sandbox") is True, "The probe app is not sandboxed"
assert set(entitlements) <= {"com.apple.security.app-sandbox", "com.apple.security.files.user-selected.read-write", "com.apple.security.files.bookmarks.app-scope", "com.apple.security.get-task-allow"}, entitlements

def nfd(text): return unicodedata.normalize("NFD", text).encode()
def nfc(text): return unicodedata.normalize("NFC", text).encode()
def listing(folder): return sorted(n.hex() for n in os.listdir(os.fsencode(str(folder))))
def touch(folder, raw): os.close(os.open(os.path.join(os.fsencode(str(folder)), raw), os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600))
names = ["보고서.txt", "café.pdf", "ガイド.txt"]

def fixture(folder):
    """A folder with decomposed names, a subfolder, a plain name and a link that points outside."""
    folder.mkdir(parents=True)
    for name in names: touch(folder, nfd(name))
    touch(folder, b"plain.txt")
    (folder / "day 1").mkdir(); touch(folder / "day 1", nfd("저녁 식사.jpg"))
    outside = folder.parent / "outside"
    if not outside.exists(): outside.mkdir(); (outside / "not-yours.txt").write_text("outside the allowed folder")
    os.symlink("../outside", folder / "escape")

log = []
def step(work, phase, target=None, ready=None, application=app, extra=()):
    """Launches the app once and returns the facts it reported."""
    out = work / f"report-{len(log):02d}-{phase}.txt"
    targets = [str(t) for t in (target if isinstance(target, (list, tuple)) else [target] if target else [])]
    command = ["open", "-g", "-j", "-W", "-n", "-a", str(application)] + targets + ["--stdout", str(out), "--stderr", str(work / "stderr.txt"), "--args", "--skip-onboarding", "--sandbox-probe", phase, *extra]
    process = subprocess.Popen(command)
    try:
        if ready:
            deadline = time.time() + 60
            while time.time() < deadline and not (out.exists() and "READY" in out.read_text()): time.sleep(0.2)
            ready()
        process.wait(timeout=600)
    except subprocess.TimeoutExpired:
        subprocess.run(["pkill", "-f", "xcode-sandbox/Build/Products/Debug/Moongchi NameFix.app"]); raise SystemExit(f"{phase}: the app did not finish")
    lines = [l for l in out.read_text().splitlines() if l.startswith("REPORT ")] if out.exists() else []
    assert lines, f"{phase}: no report"
    facts = json.loads(lines[-1][7:]); log.append((phase, facts))
    if application == app: assert facts["sandboxed"] and facts["restricted"] and facts["edition"] == "appstore", (phase, facts)
    else: assert not facts["sandboxed"] and not facts["restricted"], (phase, facts)
    return facts

def expect(condition, message, facts):
    if not condition: raise SystemExit(f"FAIL {message}: {json.dumps(facts, ensure_ascii=False)}")

def attach(image, mount):
    assert Path(image).parent == Path(mount).parent
    info = plistlib.loads(subprocess.check_output(["hdiutil", "attach", "-nobrowse", "-mountpoint", str(mount), "-plist", str(image)], stderr=subprocess.DEVNULL))
    return min((e["dev-entry"] for e in info["system-entities"] if e.get("dev-entry", "").startswith("/dev/disk")), key=len)
def detach(device): subprocess.run(["hdiutil", "detach", device], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
def image(path, megabytes=64):
    subprocess.run(["hdiutil", "create", "-size", f"{megabytes}m", "-fs", "APFS", "-volname", "NFSANDBOX", "-type", "SPARSE", str(path)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

if options.compare:
    # The same folders, the same steps, once inside the sandbox and once outside it.
    rows = {}
    for label, application in [("sandbox", app), ("direct", plain)]:
        with tempfile.TemporaryDirectory(prefix="namefix-sandbox-", dir="/private/tmp") as temporary:
            work = Path(temporary); big = work / "big"; small = work / "small"; big.mkdir(); small.mkdir()
            for i in range(10_000): touch(big, nfd(f"보고서 é {i:05d}.txt"))
            for i in range(1_000): touch(small, nfd(f"사진 é {i:04d}.jpg"))
            support = work / "support"
            extra = [] if application == app else ["--probe-support", str(support)]
            if application == app: step(work, "reset")
            f = step(work, "profile", [big, small], application=application, extra=extra)
            assert f.get("renamed") == 1000 and f.get("undone") == 1000, f
            rows[label] = f
            if application == app: step(work, "reset")
    keys = ["startup", "scan", "filter", "plan", "rename", "undoPlan", "undo", "favoriteReopen"]
    print("seconds      " + "".join(k.rjust(15) for k in keys))
    for label in rows: print(label.ljust(13) + "".join(str(rows[label].get(k, "-")).rjust(15) for k in keys))
    print("PASS: 10,000 names scanned and filtered, 1,000 renamed and undone, in both; Debug builds, same machine")
    sys.exit(0)

results = []
with tempfile.TemporaryDirectory(prefix="namefix-sandbox-", dir="/private/tmp") as temporary:
    work = Path(temporary); photos = work / "photos"; fixture(photos)
    before = listing(photos)
    step(work, "reset")

    # 1. A folder handed over: the system refuses its neighbour, the app scans, renames and keeps the way back.
    f = step(work, "rename", photos)
    expect(f["homeIsContainer"] and f["systemRefusesNeighbour"] and f["outsideRefused"], "the sandbox keeps the app inside what it was given", f)
    expect(f["rootIsAllowed"] and f["rootRow"] == "RootNameExcluded", "the handed-over folder is the allowed folder", f)
    expect(f["fixable"] == 4 and f["linkRows"] == 1 and f["planned"] == 4 and f["renamed"] == 4 and f["status"] == "Completed", "scan, plan and rename inside the allowed folder", f)
    expect(nfc(names[0]).hex() in listing(photos) and nfd(names[0]).hex() not in listing(photos), "names were composed on disk", f)
    expect((work / "outside" / "not-yours.txt").read_text() == "outside the allowed folder" and listing(work / "outside") == [b"not-yours.txt".hex()], "nothing outside was touched", f)
    results.append("folder handed over: scan, rename, link not followed, neighbour refused by the system")

    # 2. A new launch with nothing handed over: the kept bookmark leads back and the undo is exact.
    f = step(work, "undo")
    expect(not f["askedForFolder"] and f["planned"] == 4 and f["undone"] == 4, "undo after reopening the app", f)
    expect(listing(photos) == before, "undo restored every name byte for byte", f)
    results.append("undo after reopening the app, from the kept bookmark")

    # 3. The kept access is gone: the app asks for the folder and changes nothing.
    f = step(work, "rename", photos); expect(f["renamed"] == 4, "second rename", f)
    renamed = listing(photos)
    step(work, "forget")
    f = step(work, "undo")
    expect(f["askedForFolder"] and f["message"] == "UndoNeedsFolder" and f["undone"] == 0, "without access the app asks for the folder", f)
    expect(listing(photos) == renamed, "nothing changed while access was missing", f)
    results.append("undo without kept access: asks for the folder, changes nothing")

    # 4. Favourite and recent folder, reopened in a new launch.
    step(work, "reset")
    f = step(work, "favorite", photos)
    expect(f["favorites"] == 1 and f["hasBookmark"] and f["recents"] == 1 and f["recentBookmarks"] == 1, "favourite and recent keep a bookmark", f)
    f = step(work, "reopen")
    expect(f["favoriteEntries"] > 1 and f["favoriteProblem"] == 0 and f["recentEntries"] > 1, "favourite and recent reopen after a new launch", f)
    results.append("favourite and recent folder reopen after a new launch")

    # 5. Folder Watch: started from its bookmark in a new launch, it notices a new file.
    step(work, "reset")
    f = step(work, "watch", photos)
    expect(f["watches"] == 1 and not f["watchErrors"], "watch added", f)
    f = step(work, "watching", ready=lambda: touch(photos, nfd("새 파일.txt")))
    expect(f["watches"] == 1 and not f["watchErrors"] and f["noticed"] and f["reviewFixable"] >= 1, "watch runs from its bookmark and notices a new file", f)
    results.append("Folder Watch after a new launch: runs from its bookmark, notices a new file, review lists it")

    # 6. A file handed over on its own: the app asks for its folder.
    step(work, "reset")
    loose = work / "loose"; loose.mkdir(); touch(loose, nfd("혼자.txt"))
    f = step(work, "loose", loose / unicodedata.normalize("NFD", "혼자.txt"))
    expect(f["askedForFolder"] and f["askedFolder"] == "loose" and "FolderAccessNeeded" in f["reasons"], "a single file asks for its folder", f)
    results.append("single file: asks for its folder instead of failing")

    # 7. An external APFS volume: undo after it was detached and attached again under another
    #    device number, and refusal when a different disk is in its place.
    volume = work / "volume"; volume.mkdir(); disk = work / "disk.sparseimage"; image(disk)
    device = attach(disk, volume)
    try:
        step(work, "reset")
        fixture(volume / "photos"); original = listing(volume / "photos")
        f = step(work, "rename", volume / "photos"); expect(f["renamed"] == 4, "rename on an external volume", f)
        detach(device); device = None
        other = work / "other.sparseimage"; image(other); (work / "othermount").mkdir(); spare = attach(other, work / "othermount")
        try: device = attach(disk, volume); f = step(work, "undo")
        finally: detach(spare)
        expect(not f["askedForFolder"] and f["undone"] == 4 and listing(volume / "photos") == original, "undo on a reconnected external volume", f)
        results.append("external APFS: undo after reconnecting under another device number")
        f = step(work, "rename", volume / "photos"); expect(f["renamed"] == 4, "rename before the swap", f)
        detach(device); device = None
        twin = work / "twin.sparseimage"; image(twin); device = attach(twin, volume)
        fixture(volume / "photos")
        for name in names: os.rename(os.path.join(os.fsencode(str(volume / "photos")), nfd(name)), os.path.join(os.fsencode(str(volume / "photos")), nfc(name)))
        swapped = listing(volume / "photos")
        f = step(work, "undo")
        expect(f["undone"] == 0 and listing(volume / "photos") == swapped, "a different disk in its place is not touched", f)
        results.append("external APFS: a different disk at the same place is refused")
    finally:
        if device: detach(device)
    step(work, "reset")
print("\n".join("PASS " + line for line in results))
print("PASS: real App Sandbox, store entitlements, access granted by macOS through Open With; no clicks, no user folders")
