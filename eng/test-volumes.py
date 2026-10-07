#!/usr/bin/env python3
"""Runs the volume contracts on disposable disk images.

For each kind (apfs, apfs-case-sensitive, exfat, fat) a new sparse image is created in a new
temporary folder, mounted there without appearing in Finder, tested, detached and deleted.
Only the image this script created is ever attached or detached; no existing disk is touched.

  eng/test-volumes.py                      all kinds
  eng/test-volumes.py --kinds apfs,exfat   some kinds
  eng/test-volumes.py --performance        also time scan and rename on the APFS images
"""
from pathlib import Path
import argparse, os, plistlib, subprocess, sys, tempfile

root = Path(__file__).resolve().parent.parent
formats = {"apfs": "APFS", "apfs-case-sensitive": "Case-sensitive APFS", "exfat": "ExFAT", "fat": "MS-DOS FAT32"}
parser = argparse.ArgumentParser()
parser.add_argument("--kinds", default=",".join(formats))
parser.add_argument("--performance", action="store_true")
options = parser.parse_args()
kinds = [k for k in options.kinds.split(",") if k]
assert all(k in formats for k in kinds), f"Unknown kind; choose from {', '.join(formats)}"

def attach(image, mount, readonly=False):
    """Mounts our own image at our own folder and returns its device."""
    assert Path(image).parent == Path(mount).parent, "The image and its mount point belong to one temporary folder"
    command = ["hdiutil", "attach", "-nobrowse", "-mountpoint", str(mount), "-plist"] + (["-readonly"] if readonly else []) + [str(image)]
    info = plistlib.loads(subprocess.check_output(command, stderr=subprocess.DEVNULL))
    devices = [e["dev-entry"] for e in info["system-entities"] if e.get("dev-entry", "").startswith("/dev/disk")]
    assert devices, "The image was not attached"
    return min(devices, key=len)

def detach(device):
    subprocess.run(["hdiutil", "detach", device], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def tests(filter, environment):
    subprocess.run([str(root / "eng/test.sh"), "--filter", filter], cwd=root, env=dict(os.environ, **environment), check=True)

def create(image, kind, megabytes=512):
    subprocess.run(["hdiutil", "create", "-size", f"{megabytes}m", "-fs", formats[kind], "-volname", "NFFIXTURE", "-type", "SPARSE", str(image)],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

results = []
for kind in kinds:
    with tempfile.TemporaryDirectory(prefix="namefix-volume-", dir="/private/tmp") as temporary:
        work = Path(temporary); image = work / "fixture.sparseimage"; mount = work / "volume"; state = work / "state"
        mount.mkdir(); state.mkdir()
        create(image, kind)
        device = attach(image, mount)
        environment = {"NAMEFIX_FIXTURE_ROOT": str(mount), "NAMEFIX_VOLUME_KIND": kind, "NAMEFIX_STATE_DIR": str(state)}
        try:
            if kind.startswith("apfs"):
                # Every filesystem, transaction, recovery and coordination contract, on this volume.
                tests("VolumeMatrixTests|FilesystemTests|TransactionTests|CoordinatedTransactionTests|SafetyTests|ExpansionTests", environment)
                if options.performance:
                    tests("VolumeMatrixTests/testScanRenameAndUndoProfile|SafetyTests/testScanPerformanceProfile|CoordinatedTransactionTests/testThousandCoordinatedRenamesProfile|ExpansionPerformanceTests",
                          dict(environment, NAMEFIX_PERFORMANCE="1", NAMEFIX_MUTATION_PERF="1"))
                # Rename, lose the volume, get it back under another device number,
                # put a different disk in its place, then mount it read-only.
                tests("VolumeMatrixTests/testPhasePrepare", dict(environment, NAMEFIX_VOLUME_PHASE="prepare"))
                detach(device); device = None
                tests("VolumeMatrixTests/testPhaseDetached", dict(environment, NAMEFIX_VOLUME_PHASE="detached"))
                other_image = work / "other.sparseimage"; other_mount = work / "other"; other_mount.mkdir()
                create(other_image, "apfs", megabytes=64)
                other = attach(other_image, other_mount)
                try:
                    device = attach(image, mount)
                    tests("VolumeMatrixTests/testPhaseReattached", dict(environment, NAMEFIX_VOLUME_PHASE="reattached"))
                finally:
                    detach(other)
                detach(device); device = None
                twin_image = work / "twin.sparseimage"
                create(twin_image, kind, megabytes=64)
                device = attach(twin_image, mount)
                tests("VolumeMatrixTests/testPhaseAnotherDisk", dict(environment, NAMEFIX_VOLUME_PHASE="twin"))
                detach(device); device = attach(image, mount, readonly=True)
                tests("VolumeMatrixTests/testPhaseReadOnly", dict(environment, NAMEFIX_VOLUME_PHASE="readonly"))
            else:
                tests("VolumeMatrixTests", environment)
            results.append(f"PASS {kind}")
        finally:
            if device: detach(device)
print("\n".join(results))
print("PASS: disposable volumes only; every image this run attached was detached and deleted")
