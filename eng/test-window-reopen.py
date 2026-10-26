#!/usr/bin/env python3
"""Targeted AppKit regression: close the main window, reopen using its actual menu.

Uses an already-built Debug app, isolated records and a sample file this script creates.
No renaming, input synthesis, release build, account access or user data.
"""
from pathlib import Path
import argparse
import json
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path, required=True)
options = parser.parse_args()
output = options.output.resolve()
output.mkdir(parents=True, exist_ok=True)
scratch = root / ".devtmp/scratch"
scratch.mkdir(parents=True, exist_ok=True)
app = root / ".build/xcode/Build/Products/Debug/Moongchi NameFix.app"
assert app.is_dir(), "Build Debug first: eng/build.sh --configuration Debug --arch arm64"
with tempfile.TemporaryDirectory(prefix="window-reopen-", dir=scratch) as temporary:
    work = Path(temporary)
    sample = work / "samples"
    sample.mkdir()
    (sample / "example.txt").write_text("Window-state preservation fixture.\n")
    stdout, stderr = output / "runtime.txt", output / "runtime-stderr.txt"
    subprocess.run([
        "open", "-g", "-W", "-n", "-a", str(app),
        "--stdout", str(stdout), "--stderr", str(stderr), "--args",
        "--skip-onboarding", "--sandbox-probe", "window-reopen",
        "--probe-support", str(work / "support"),
    ], check=True, timeout=120)
    reports = [json.loads(line[7:]) for line in stdout.read_text().splitlines() if line.startswith("REPORT ")]
    assert reports, f"The app did not finish its probe; inspect {stdout} and {stderr}"
    report = reports[-1]
    assert "error" not in report, report
    checks = report.get("checks", [])
    assert {c["language"] for c in checks} == {"ko-KR", "en-US", "ja-JP"}, report
    contracts = ["shortcut", "closedWindowReopensTwice", "minimizedWindowRestored", "dockReopens",
                 "sameWindow", "statePreserved", "keepsRunningAfterClose"]
    for check in checks:
        assert all(check.get(key) is True for key in contracts), check
    assert (sample / "example.txt").read_text() == "Window-state preservation fixture.\n"
    report["status"] = "PASS"
    report["sampleUnchanged"] = True
    (output / "window-reopen.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print("PASS: 3 locales, repeated close/menu reopen, minimized restore, Dock reopen, same window and input state; sample unchanged")
