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
  eng/test-sandbox.py --direct     the same steps with the Debug app outside the sandbox (the unrestricted rule the tests and fixtures run under);
                                   its records go to a folder this script makes, never to the user's
  eng/test-sandbox.py --scroll     scroll a 1,200-row list in the Debug app and print the time per step
  eng/test-sandbox.py --large      100,000 names: search, filter, reload and scroll times of the list
  eng/test-sandbox.py --speed      time 1,000 renames and their undo with the safe and the faster record
  eng/test-sandbox.py --compare    time the same work inside and outside the sandbox (both Debug apps must be built)
"""
from pathlib import Path
import argparse, json, os, plistlib, subprocess, sys, tempfile, time, unicodedata

root = Path(__file__).resolve().parent.parent
app = root / ".build/xcode-sandbox/Build/Products/Debug/Moongchi NameFix.app"
parser = argparse.ArgumentParser(); parser.add_argument("--no-build", action="store_true"); parser.add_argument("--compare", action="store_true"); parser.add_argument("--direct", action="store_true"); parser.add_argument("--scroll", action="store_true"); parser.add_argument("--speed", action="store_true"); parser.add_argument("--large", action="store_true"); options = parser.parse_args()
plain = root / ".build/xcode/Build/Products/Debug/Moongchi NameFix.app"
sandboxed = not options.direct
if options.scroll or options.speed or options.large: options.direct = True; sandboxed = False
if not options.no_build and not options.compare:
    subprocess.run([str(root / "eng/build.sh"), "--configuration", "Debug", "--arch", "arm64"] + (["--sandbox-debug"] if sandboxed else []), cwd=root, check=True, stdout=subprocess.DEVNULL)
def granted(application):
    raw = subprocess.run(["codesign", "-d", "--entitlements", ":-", str(application)], capture_output=True).stdout
    return plistlib.loads(raw) if raw.strip() else {}
if sandboxed or options.compare:
    entitlements = granted(app)
    assert entitlements.get("com.apple.security.app-sandbox") is True, "The probe app is not sandboxed"
    assert set(entitlements) <= {"com.apple.security.app-sandbox", "com.apple.security.files.user-selected.read-write", "com.apple.security.files.bookmarks.app-scope", "com.apple.security.get-task-allow"}, entitlements
if not sandboxed: assert not granted(plain).get("com.apple.security.app-sandbox"), "The direct probe app is sandboxed"

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
def step(work, phase, target=None, ready=None, application=None, shown=False, more=()):
    """Launches the app once and returns the facts it reported."""
    application = application or (app if sandboxed else plain)
    out = work / f"report-{len(log):02d}-{phase}.txt"
    targets = [str(t) for t in (target if isinstance(target, (list, tuple)) else [target] if target else [])]
    # Outside the sandbox the app would use the user's own records: it is always given a folder of this run instead.
    extra = [] if application == app else ["--probe-support", str(work / "support")]
    # `shown` leaves the window on screen, behind the other apps, so its sheets really open.
    command = ["open", "-g", "-W", "-n"] + ([] if shown else ["-j"]) + ["-a", str(application)] + targets + ["--stdout", str(out), "--stderr", str(work / "stderr.txt"), "--args", "--skip-onboarding", "--sandbox-probe", phase, *extra, *more]
    process = subprocess.Popen(command)
    try:
        if ready:
            deadline = time.time() + 60
            while time.time() < deadline and not (out.exists() and "READY" in out.read_text()): time.sleep(0.2)
            ready()
        process.wait(timeout=600)
    except subprocess.TimeoutExpired:
        subprocess.run(["pkill", "-f", str(application.relative_to(root))]); raise SystemExit(f"{phase}: the app did not finish")
    lines = [l for l in out.read_text().splitlines() if l.startswith("REPORT ")] if out.exists() else []
    assert lines, f"{phase}: no report"
    facts = json.loads(lines[-1][7:]); log.append((phase, facts))
    if application == app: assert facts["sandboxed"] and facts["restricted"], (phase, facts)
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

if options.scroll:
    # 1,200 rows, most of them with names to fix, scrolled by the app itself; milliseconds per step.
    with tempfile.TemporaryDirectory(prefix="namefix-sandbox-", dir="/private/tmp") as temporary:
        work = Path(temporary); many = work / "many"; many.mkdir()
        samples = ["보고서 최종본", "여행 사진 모음", "café menu", "ガイドブック", "회의록 정리", "Việt Nam trip"]
        for i in range(1200):
            name = f"{samples[i % len(samples)]} {i:04d}.txt"
            touch(many, name.encode() if i % 4 == 3 else nfd(name))
        sandboxed = False
        f = step(work, "scroll", many, application=plain, shown=True)
        for key in ("draw", "between", "both"): print(key.ljust(8), json.dumps(f.get(key)))
        print("rows", f.get("rows"), "height", f.get("height"))
    sys.exit(0)
if options.large:
    # 100,000 names in one folder: how long the list takes to appear, search, filter and scroll.
    with tempfile.TemporaryDirectory(prefix="namefix-sandbox-", dir="/private/tmp") as temporary:
        work = Path(temporary); many = work / "many"; many.mkdir()
        for i in range(100_000): touch(many, (f"보고서 사진 {i:06d}.txt").encode() if i % 4 == 3 else nfd(f"보고서 사진 {i:06d}.txt"))
        f = step(work, "scroll", many, application=plain, shown=True, more=["--probe-large"])
        print("rows", f.get("rows"), "| start to ready", f.get("startup"), "s | search", f.get("search"), "s ->", f.get("searchRows"), "rows | clear", f.get("clear"), "s | filter", f.get("filter"), "s ->", f.get("filterRows"), "rows | back", f.get("unfilter"), "s | full reload of the table", f.get("reload"), "s")
        for key in ("draw", "both"): print(key.ljust(6), json.dumps(f.get(key)))
    sys.exit(0)
if options.speed:
    # 1,000 renames and their undo with the safest record and with the faster one (Settings, D-036).
    for label, more in [("safe", []), ("fast", ["--probe-fast"])]:
        with tempfile.TemporaryDirectory(prefix="namefix-sandbox-", dir="/private/tmp") as temporary:
            work = Path(temporary); big = work / "big"; small = work / "small"; big.mkdir(); small.mkdir()
            for i in range(10_000): touch(big, nfd(f"보고서 é {i:05d}.txt"))
            for i in range(1_000): touch(small, nfd(f"사진 é {i:04d}.jpg"))
            before = listing(small)
            f = step(work, "profile", [big, small], application=plain, more=more)
            assert f.get("renamed") == 1000 and f.get("undone") == 1000 and f["fastSetting"] == (label == "fast") and listing(small) == before, f
            print(label.ljust(6), "rename 1,000:", f["rename"], "s   undo 1,000:", f["undo"], "s")
    sys.exit(0)
if options.compare:
    # The same folders, the same steps, once inside the sandbox and once outside it.
    rows = {}
    for label, application in [("sandbox", app), ("direct", plain)]:
        with tempfile.TemporaryDirectory(prefix="namefix-sandbox-", dir="/private/tmp") as temporary:
            work = Path(temporary); big = work / "big"; small = work / "small"; big.mkdir(); small.mkdir()
            for i in range(10_000): touch(big, nfd(f"보고서 é {i:05d}.txt"))
            for i in range(1_000): touch(small, nfd(f"사진 é {i:04d}.jpg"))
            if application == app: step(work, "reset", application=application)
            f = step(work, "profile", [big, small], application=application)
            assert f.get("renamed") == 1000 and f.get("undone") == 1000, f
            rows[label] = f
            if application == app: step(work, "reset", application=application)
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
    if sandboxed:
        expect(f["homeIsContainer"] and f["systemRefusesNeighbour"] and f["outsideRefused"], "the sandbox keeps the app inside what it was given", f)
        expect(f["rootIsAllowed"] and f["rootRow"] == "NormalHelp", "the handed-over folder is the allowed folder and an ordinary row", f)
        expect(f["systemRefusesRootRename"], "the system itself refuses to rename the handed-over folder", f)
    else:
        expect(not f["homeIsContainer"] and not f["outsideRefused"] and f["rootRow"] == "NormalHelp", "outside the sandbox nothing is restricted", f)
    expect(f["fixable"] == 4 and f["linkRows"] == 1 and f["planned"] == 4 and f["renamed"] == 4 and f["status"] == "Completed", "scan, plan and rename inside the allowed folder", f)
    expect(nfc(names[0]).hex() in listing(photos) and nfd(names[0]).hex() not in listing(photos), "names were composed on disk", f)
    expect((work / "outside" / "not-yours.txt").read_text() == "outside the allowed folder" and listing(work / "outside") == [b"not-yours.txt".hex()], "nothing outside was touched", f)
    results.append("folder handed over: scan, rename, link not followed" + (", neighbour and the folder's own name refused by the system" if sandboxed else ""))

    # 2. A new launch with nothing handed over: the kept bookmark leads back and the undo is exact.
    f = step(work, "undo")
    expect(not f["askedForFolder"] and f["planned"] == 4 and f["undone"] == 4, "undo after reopening the app", f)
    expect(listing(photos) == before, "undo restored every name byte for byte", f)
    results.append("undo after reopening the app" + (", from the kept bookmark" if sandboxed else ""))

    # 3. The kept access is gone: the app asks for the folder and changes nothing.
    f = step(work, "rename", photos); expect(f["renamed"] == 4, "second rename", f)
    renamed = listing(photos)
    step(work, "forget")
    f = step(work, "undo")
    if sandboxed:
        expect(f["askedForFolder"] and f["message"] == "UndoNeedsFolder" and f["undone"] == 0, "without access the app asks for the folder", f)
        expect(listing(photos) == renamed, "nothing changed while access was missing", f)
        results.append("undo without kept access: asks for the folder, changes nothing")
    else:
        expect(not f["askedForFolder"] and f["undone"] == 4 and listing(photos) == before, "outside the sandbox undo needs no kept access", f)
        results.append("undo needs no kept access outside the sandbox")

    # 4. Favourite and recent folder, reopened in a new launch.
    step(work, "reset")
    f = step(work, "favorite", photos)
    expect(f["favorites"] == 1 and f["recents"] == 1 and (not sandboxed or (f["hasBookmark"] and f["recentBookmarks"] == 1)), "favourite and recent are kept", f)
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
    if sandboxed:
        expect(f["askedForFolder"] and f["askedFolder"] == "loose" and "FolderAccessNeeded" in f["reasons"], "a single file asks for its folder", f)
        expect(f["systemRefusesFileRename"], "the system itself refuses to rename a file handed over without its folder", f)
        expect(f["declinedKeepsNotice"] and f["offeredAgain"], "declining changes nothing and the folder can be chosen later", f)
        expect(listing(loose) == [nfd("혼자.txt").hex()], "the file was not touched", f)
        results.append("single file: asks for its folder instead of failing; declining changes nothing; the system refuses the rename without the folder")
    else:
        expect(not f["askedForFolder"] and f["fixable"] == 1 and "FolderAccessNeeded" not in f["reasons"], "outside the sandbox a single file is ready at once", f)
        results.append("single file: ready at once, no folder asked")

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

    # 7b. An exFAT drive: listed and explained, nothing offered, nothing changed.
    step(work, "reset")
    stick = work / "stick"; stick.mkdir(); fat = work / "fat.sparseimage"
    subprocess.run(["hdiutil", "create", "-size", "64m", "-fs", "ExFAT", "-volname", "NFEXFAT", "-type", "SPARSE", str(fat)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    device = attach(fat, stick)
    try:
        (stick / "photos").mkdir()
        for name in names: touch(stick / "photos", nfd(name))
        seen = listing(stick / "photos")
        f = step(work, "look", stick / "photos")
        expect(f["entries"] >= 3 and f["fixable"] == 0 and f["planned"] == 0 and "VolumeFATUnsupported" in f["reasons"] and f["message"] == "VolumeFATUnsupported", "an exFAT drive is explained and nothing is offered", f)
        expect(f["labels"] == ["StatusDriveExcluded"] and listing(stick / "photos") == seen, "its rows say the drive is not supported and nothing changed", f)
        results.append("exFAT drive: listed, explained as not supported, nothing offered or changed")
    finally: detach(device)

    # 8. A handed-over folder whose own name is decomposed. In the sandbox the name stays (its parent was
    #    not allowed) and everything inside is fixed; outside it the folder is fixed too and comes back on undo.
    step(work, "reset")
    album = work / unicodedata.normalize("NFD", "사진 모음"); fixture(album)
    inside = listing(album)
    f = step(work, "rename", album)
    kept = nfd("사진 모음").hex() in listing(work)
    if sandboxed:
        expect(f["rootRow"] == "ParentFolderNeeded" and f["renamed"] == 4 and kept, "without the folder above, the folder's own name stays and its contents are fixed", f)
    else:
        expect(f["renamed"] == 5 and not kept and nfc("사진 모음").hex() in listing(work), "the folder's own name is fixed too", f)
    f = step(work, "undo")
    expect(f["undone"] == (4 if sandboxed else 5) and nfd("사진 모음").hex() in listing(work) and listing(album) == inside, "undo restores the folder and its contents", f)
    results.append("folder with a decomposed name of its own: " + ("name kept, contents fixed, undo exact" if sandboxed else "name and contents fixed, undo exact"))

    # 9. The real window: its sheets open, the Windows-name filter, rename, history, undo, and what the menus offer.
    step(work, "reset")
    desk = work / "desk"; fixture(desk)
    for raw in [b"report: final.txt", b"CON.txt", b"notes."]: touch(desk, raw)
    original = listing(desk)
    f = step(work, "gui", desk, shown=True)
    expect(f["hasWindow"] and f["toolbarItems"] > 0, "the main window is there", f)
    expect(sorted(f["windowsFilter"]) == sorted(["report: final.txt", "CON.txt", "notes."]), "the Windows-name filter lists exactly the three names", f)
    expect(f["confirmationSheet"] and f["planned"] == 4 and f["resultSheet"] and f["renamed"] == 4 and f["historySheet"] and f["history"] == 1, "confirmation, result and history sheets open on the window", f)
    expect(f["undone"] == 4 and listing(desk) == original, "undo from the record restores every name", f)
    expect(f["selected"] == 4 and f["ticked"] == 4 and f["selectedAfterRename"] == 0, "names to fix start selected and ticked; the selection is cleared after the rename", f)
    expect(f["fixableAfterUndo"] == 4 and f["selectedAfterUndo"] == 4 and f["tickedAfterUndo"] == 4, "after an undo the names are selected again", f)
    expect(f["otherSheets"] == ["settings", "help", "onboarding"], "settings, help and the introduction open on the window", f)
    expect(not any("pdate" in title or "업데이트" in title or "アップデート" in title for title in f["appMenu"]), "the app has no update command of its own: the App Store updates it", f)
    expect(f["supportAddress"].startswith("mailto:"), "contact address", f)
    results.append("real window: confirmation, result, history, settings, help and introduction sheets, Windows-name filter, rename and undo; no update command in the app menu")

    # 10. Names from many scripts, byte for byte: what is fixed, what is left, and the exact way back.
    step(work, "reset")
    world = work / "world"; world.mkdir()
    def keep(text):
        """Composed form that leaves CJK compatibility ideographs as they are (the app's rule)."""
        out, run = "", ""
        for ch in text:
            if 0xF900 <= ord(ch) <= 0xFAFF or 0x2F800 <= ord(ch) <= 0x2FA1F: out += unicodedata.normalize("NFC", run) + ch; run = ""
            else: run += ch
        return out + unicodedata.normalize("NFC", run)
    d = lambda t: unicodedata.normalize("NFD", t)
    stored = [
        d("보고서 최종.txt"), "한" + d("글") + " 혼합.txt", d("café menu.pdf"), d("Ångström.txt"), d("Việt Nam.txt"), d("señor über.txt"),
        d("ガイド.txt"), d("パスポート.pdf"), d("がぎぐ.txt"), d("άλφα.txt"), d("йод.txt"),
        chr(0xFA19) + chr(0xFA4C) + " 案内.txt", chr(0xF9DC) + " " + d("ガイド") + ".txt", chr(0x2F800) + " old.txt", chr(0xF914) + chr(0xF9DC) + ".txt",
        "👨‍👩‍👧‍👦 family.jpg", "✈️ " + d("café") + " trip.txt", "🇰🇷 👍🏽.png", "Ａ１ｂ 全角.txt", "ｶﾞｲﾄﾞ.txt", "العربية.txt", "ไทย.txt", "हिन्दी.txt", "中文 日本語.txt", "plain ascii.txt",
        d("가나다라마바사아자차카타파하 긴 이름 가나다라마바사.txt")]
    for name in stored: touch(world, name.encode())
    original = listing(world)
    wanted = sorted(keep(name).encode().hex() for name in stored)
    changing = sum(1 for name in stored if keep(name) != name)
    f = step(work, "unicode", world)
    expect(f["fixable"] == changing and f["planned"] == changing and f["renamed"] == changing and f["conflicts"] == 0, "exactly the decomposed names are offered", f)
    expect(sorted(f["after"]) == wanted, "every name is the expected form, byte for byte", f)
    expect(all(name.encode().hex() in f["after"] for name in stored if keep(name) == name), "names with nothing to fix kept their bytes", f)
    # The standard composed form would have replaced these characters with look-alikes; they are still there.
    expect(all(unicodedata.normalize("NFC", chr(c)) != chr(c) and any(chr(c).encode().hex() in n for n in f["after"]) for c in (0xFA19, 0xFA4C, 0xF9DC, 0xF914, 0x2F800)), "compatibility ideographs kept their own code points", f)
    expect(f["undone"] == changing and sorted(f["restored"]) == original, "undo restores every name byte for byte", f)
    expect(listing(world) == original, "the folder is as it was", f)
    results.append(f"global names: {changing} of {len(stored)} fixed (Hangul, Latin, Vietnamese, kana, Greek, Cyrillic), compatibility ideographs (U+FA19 U+FA4C U+F9DC U+F914 U+2F800), emoji, full/half width, Arabic, Thai, Devanagari kept; undo exact")
    # 11. The same folder, and this time its own name is wanted. In the sandbox the folder above is asked for
    #     only then; cancelling changes nothing; choosing it makes the folder a row like any other.
    #     The folder above is handed to the app but kept back by the probe, which "chooses" it when asked.
    step(work, "reset")
    above = work / "above"; shelf = above / unicodedata.normalize("NFD", "여행 사진"); fixture(shelf)
    top, inside = listing(above), listing(shelf)
    f = step(work, "parent", [shelf, above], more=["--probe-hold", str(above)])
    if sandboxed:
        expect(not f["askedAtOnce"] and f["rowReason"] == "ParentFolderNeeded" and f["rowLabel"] == "StatusParentNeeded" and f["message"] == "ParentFolderNeeded" and f["fixableBefore"] == 4, "nothing is asked until the folder's own name is wanted", f)
        expect(f["askedPurposeParent"] and f["askedFor"] == "above", "exactly the folder above is asked for", f)
        expect(f["afterCancel"] == top and f["messageAfterCancel"] == "ParentFolderNeeded" and f["entriesAfterCancel"] > 4 and f["askedAgain"], "cancelling changes nothing, keeps what was added and can be retried", f)
    else:
        expect(not f["askedAtOnce"] and f["askedFor"] == "" and f["rowReason"] != "ParentFolderNeeded" and f["fixableBefore"] == 5, "outside the sandbox the folder is ready at once and nothing is asked", f)
    expect(f["rowFixable"] and f["fixableAfter"] == 5 and f["planned"] == 5 and f["renamed"] == 5 and f["status"] == "Completed", "the folder and its contents are renamed", f)
    expect(nfc("여행 사진").hex() in listing(above) and nfd("여행 사진").hex() not in listing(above), "the folder's own name was composed on disk", f)
    f = step(work, "undo")
    expect(not f["askedForFolder"] and f["undone"] == 5 and listing(above) == top and listing(shelf) == inside, "undo after a new launch restores the folder and its contents", f)
    results.append("added folder's own name: " + ("asked for the folder above only when wanted, cancel safe, then renamed; undo after a new launch exact" if sandboxed else "renamed at once, nothing asked; undo after a new launch exact"))

    # 12. One file handed over: its folder is asked for, cancelling changes nothing, choosing it goes on at once.
    step(work, "reset")
    desk1 = work / "one"; desk1.mkdir(); touch(desk1, nfd("메모.txt")); one = listing(desk1)
    f = step(work, "files", [desk1 / unicodedata.normalize("NFD", "메모.txt"), desk1], more=["--probe-hold", str(desk1), "--probe-decline-first"])
    if sandboxed:
        expect(f["messageAfterCancel"] == "FolderAccessNeeded" and f["fixableAfterCancel"] == 0 and f["entriesAfterCancel"] == 1 and f["askedAgain"], "cancel: the file stays listed, nothing changes, it can be retried", f)
        expect(f["asked"] == [{"folder": "one", "remaining": 0}], "one file, one folder asked for", f)
    else: expect(f["asked"] == [] and "askedAgain" not in f, "outside the sandbox nothing is asked", f)
    expect(f["fixable"] == 1 and f["renamed"] == 1 and listing(desk1) == [nfc("메모.txt").hex()], "the file is renamed without adding it again", f)
    f = step(work, "undo"); expect(f["undone"] == 1 and listing(desk1) == one, "undo after a new launch", f)
    results.append("single file: " + ("folder asked once, cancel safe and retried, renamed without adding it again; undo exact" if sandboxed else "renamed at once; undo exact"))

    # 13. Three files of one folder: asked once. Files of two folders: each folder in turn, the first request says one more follows.
    step(work, "reset")
    a = work / "A"; b = work / "B"; a.mkdir(); b.mkdir()
    for x in ["가.txt", "나.txt", "다.txt"]: touch(a, nfd(x))
    touch(b, nfd("라.txt"))
    files = [a / unicodedata.normalize("NFD", x) for x in ["가.txt", "나.txt", "다.txt"]]
    f = step(work, "files", files + [a], more=["--probe-hold", str(a)])
    expect(f["asked"] == ([{"folder": "A", "remaining": 0}] if sandboxed else []) and f["renamed"] == 3, "three files of one folder: one request", f)
    f = step(work, "undo"); expect(f["undone"] == 3, "undo", f)
    step(work, "reset")
    f = step(work, "files", [files[0], b / unicodedata.normalize("NFD", "라.txt"), a, b], more=["--probe-hold", str(a), "--probe-hold", str(b)])
    expect(sorted(x["folder"] for x in f["asked"]) == (["A", "B"] if sandboxed else []) and [x["remaining"] for x in f["asked"]] == ([1, 0] if sandboxed else []) and f["renamed"] == 2 and f["waiting"] == 0, "files of two folders: each folder asked for in turn", f)
    results.append("several files: " + ("one request for one folder, one per folder for two" if sandboxed else "nothing asked"))

    # 14. A folder the app can already reach again (a favourite) is not asked for.
    step(work, "reset")
    fav = work / "fav"; fixture(fav)
    f = step(work, "favorite", fav); expect(f["favorites"] == 1, "favourite added", f)
    f = step(work, "files", [fav / unicodedata.normalize("NFD", names[0])])
    expect(f["asked"] == [] and f["fixable"] == 1 and f["renamed"] == 1, "a file in a favourite folder needs no request", f)
    results.append("file in a favourite folder: " + ("kept access reused, nothing asked" if sandboxed else "nothing asked"))
    step(work, "reset")
print("\n".join("PASS " + line for line in results))
print("PASS: real App Sandbox, store entitlements, access granted by macOS through Open With; no clicks, no user folders" if sandboxed
      else "PASS: Debug app outside the sandbox, records in a folder of this run; no clicks, no user folders")
