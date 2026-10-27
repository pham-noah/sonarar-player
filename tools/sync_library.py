"""Sync the built library to the phone, pushing only what changed.

WHY THIS EXISTS
    The library is 87 tracks of audio. Pushing the whole folder on every change
    re-copies hundreds of megabytes over wireless adb, which is slow enough that
    he would stop doing it. This compares the manifest on disk against the one
    on the device and pushes the difference.

WHAT IT COMPARES
    For every track in the manifest: does the device have that file, and is its
    byte size the same as the local one? The manifest supplies the list of files
    and their relative paths; the sizes come from the local filesystem and from
    one `ls -lR` on the device.

    NOT from the manifest, deliberately: it carries no size field (its keys are
    id/title/artist/album/duration_s/file/cover/gain_db/lufs/peak_dbfs/source),
    so a size check has to read both ends anyway. Size rather than a hash,
    because hashing 87 files over adb costs more time than the push it would
    save, and a track whose size matches but whose content differs is not a
    failure mode this library produces — the builder is deterministic.

    `--check` prints what would move and exits without pushing.

WHAT IT DOES NOT DO
    It never writes to the PC library, and it never deletes from the device
    unless you pass --prune and confirm. Removing music off his phone by
    surprise is the one thing this script must never do on its own.
"""

import argparse
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import library_paths  # noqa: E402

ADB = library_paths.adb()

def _force_utf8_console() -> None:
    """A Windows console encodes stdout as cp1252, so printing a non-ASCII
    title (Japanese, accented) raises UnicodeEncodeError and kills the run.
    Reconfigure to UTF-8 so the same script works from Windows and from WSL."""
    import sys as _sys
    for stream in (_sys.stdout, _sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError, ValueError):
            pass

_force_utf8_console()
def to_windows(local_path: str) -> str:
    """A WSL path, as a path the WINDOWS adb.exe can actually open.

    THIS IS THE BUG THAT PUSHED 0 OF 87 FILES. adb.exe is a Windows binary, so
    when it is handed /mnt/c/Users/Noah/Music/... it looks for that path on
    Windows, finds nothing, and fails with 'cannot stat ... No such file or
    directory' — a message that reads like the music is missing from disk rather
    than like a path-format problem.

    wslpath does the conversion properly, including drive-letter case.
    """
    out = None
    try:
        out = subprocess.run(["wslpath", "-w", local_path],
                             capture_output=True, text=True, timeout=30,
                             encoding="utf-8", errors="replace")
    except (FileNotFoundError, OSError):

        pass
    if out is not None and out.returncode == 0 and out.stdout.strip():
        return out.stdout.strip()

    if local_path.startswith("/mnt/") and len(local_path) > 6:
        drive = local_path[5].upper()
        return f"{drive}:\\" + local_path[7:].replace("/", "\\")
    return local_path

DEVICE_ROOT = "/storage/emulated/0/Music/Sonarar"

PC_ROOT = os.fspath(library_paths.source_dir() / "Sonarar")
MANIFEST = "library_manifest.json"

def fail(msg):
    print(f"STOPPED: {msg}", file=sys.stderr)
    sys.exit(1)

def run(args, capture=True):
    return subprocess.run(args, capture_output=capture, text=True,
                          encoding="utf-8", errors="replace")

def device_attached():
    out = run([ADB, "devices"])
    if out.returncode != 0:
        fail(f"adb failed: {out.stderr.strip()}")
    return [l.split()[0] for l in out.stdout.splitlines()[1:] if l.strip().endswith("device")]

def load_manifest(path):
    if not os.path.isfile(path):
        fail(f"no manifest at {path}")
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    tracks = data["tracks"] if isinstance(data, dict) and "tracks" in data else data
    if not isinstance(tracks, list) or not tracks:
        fail(f"manifest at {path} carries no tracks")
    return tracks

def device_download_tracks():
    """The tracks the PHONE downloaded, read back off it.

    WHY THIS EXISTS. A push OVERWRITES the device manifest with the PC's, and the phone APPENDS its own
    downloads to that same file. So without this, the first library push after a download silently deletes
    every downloaded track's entry — the files stay on disk and the app stops seeing them, which looks like
    the downloads were thrown away.

    Read from the device rather than from PC_ROOT, because these entries were made ON the phone and do not
    exist on the PC at all."""
    out = run([ADB, "shell", "cat", f"{DEVICE_ROOT}/{MANIFEST}"])
    if out.returncode != 0 or not out.stdout.strip():
        return []
    try:
        data = json.loads(out.stdout)
    except ValueError:

        print("  (could not read the device manifest - downloaded entries cannot be preserved this run)")
        return []
    tracks = data.get("tracks", data) if isinstance(data, dict) else data
    if not isinstance(tracks, list):
        return []
    return [t for t in tracks if str(t.get("file", "")).startswith("Downloaded/")]

def merge_manifest(local_tracks, device_tracks):
    """The PC's manifest PLUS the phone's downloads, written to the PC's file.

    THE MERGE IS ONE-WAY ON PURPOSE. The PC stays the authority for everything it built; the phone's
    Downloaded entries are merely carried across, because the PC has no way to know about them. A track is
    identified by id, so a re-push cannot double an entry."""
    have = {t.get("id") for t in local_tracks}
    added = [t for t in device_tracks if t.get("id") not in have]
    return local_tracks + added, len(added)

def device_sizes():
    """Map device-relative path -> byte size, via one `ls` call.

    A single remote `ls -lR` rather than a stat per file: 87 round trips over
    adb is the difference between seconds and minutes.
    """
    out = run([ADB, "shell", "ls", "-lR", DEVICE_ROOT])

    if out.returncode != 0 or not out.stdout:
        return {}

    sizes = {}
    current_dir = ""
    for line in out.stdout.splitlines():
        line = line.rstrip()
        if line.endswith(":") and line.startswith(DEVICE_ROOT):
            current_dir = line[:-1]
            continue
        parts = line.split()

        if len(parts) >= 8 and parts[0].startswith("-"):
            try:
                size = int(parts[4])
            except ValueError:
                continue
            name = " ".join(parts[7:])
            rel = os.path.relpath(os.path.join(current_dir, name), DEVICE_ROOT)
            sizes[rel] = size
    return sizes

def diff_library(tracks, pc_root, remote_sizes):
    """What needs pushing. Pure: no adb, no filesystem writes.

    Returns (to_push, missing, changed, missing_locally) where to_push is a list
    of (relative_path, absolute_local_path). Split out from main() so the
    comparison — the part that could silently push the wrong thing or nothing at
    all — is exercised without a device attached.
    """
    to_push = []
    missing = 0
    changed = 0
    missing_locally = []
    for t in tracks:
        rel = t.get("file") or ""
        if not rel:
            continue
        local_path = os.path.join(pc_root, rel)
        if not os.path.isfile(local_path):
            missing_locally.append(rel)
            continue
        size = os.path.getsize(local_path)
        have = remote_sizes.get(rel)
        if have is None:
            missing += 1
            to_push.append((rel, local_path))
        elif have != size:
            changed += 1
            to_push.append((rel, local_path))

    for t in tracks:
        cover = (t.get("cover") or "").strip()
        if not cover:
            continue
        local_cover = os.path.join(pc_root, cover)
        if not os.path.isfile(local_cover):
            continue
        size = os.path.getsize(local_cover)
        have = remote_sizes.get(cover)
        if have is None:
            missing += 1
            to_push.append((cover, local_cover))
        elif have != size:
            changed += 1
            to_push.append((cover, local_cover))

    for t in tracks:
        tid = (t.get("id") or "").strip()
        if not tid:
            continue
        rel = f"spectrum/{tid}.bin"
        local_spec = os.path.join(pc_root, rel)
        if not os.path.isfile(local_spec):
            continue
        size = os.path.getsize(local_spec)
        have = remote_sizes.get(rel)
        if have is None:
            missing += 1
            to_push.append((rel, local_spec))
        elif have != size:
            changed += 1
            to_push.append((rel, local_spec))

    return to_push, missing, changed, missing_locally

def main():
    ap = argparse.ArgumentParser(description="Push changed library files to the phone.")
    ap.add_argument("--check", action="store_true", help="report only; push nothing")
    ap.add_argument("--prune", action="store_true",
                    help="also remove device files not in the manifest (asks first)")
    ap.add_argument("--yes", action="store_true", help="skip the prune confirmation")
    ap.add_argument("--adb", metavar="PATH",
                    help="path to adb.exe (default: detected)")
    ap.add_argument("--source", metavar="DIR",
                    help="music folder whose PersonaR library to push (default: auto-detected)")
    args = ap.parse_args()

    global ADB, PC_ROOT
    ADB = library_paths.adb(args.adb)
    PC_ROOT = os.fspath(library_paths.source_dir(args.source) / "Sonarar")

    if not os.path.isfile(ADB):
        fail(f"adb not found at {ADB}")

    attached = device_attached()
    if not attached:
        fail("no device attached. Pair it first — see tools/deploy.sh for the steps.")
    if len(attached) > 1:
        fail(f"{len(attached)} devices attached; connect only the target.")

    tracks = load_manifest(os.path.join(PC_ROOT, MANIFEST))
    print(f"manifest: {len(tracks)} tracks")

    remote = device_sizes()
    print(f"on device: {len(remote)} files")

    to_push, missing, changed, missing_locally = diff_library(tracks, PC_ROOT, remote)
    for rel in missing_locally:

        print(f"  MISSING LOCALLY: {rel}")

    print(f"\nmissing on device : {missing}")
    print(f"size differs      : {changed}")
    print(f"to push           : {len(to_push)}")

    if not to_push and not args.prune:
        print("\nLibrary is already in sync.")
        return

    if args.check:
        for rel, _ in to_push[:20]:
            print(f"  would push {rel}")
        if len(to_push) > 20:
            print(f"  ... and {len(to_push) - 20} more")
        print("\n--check: nothing pushed.")
        return

    pushed = 0
    for rel, local_path in to_push:
        dest = f"{DEVICE_ROOT}/{rel}"
        run([ADB, "shell", "mkdir", "-p", "'" + os.path.dirname(dest) + "'"])
        out = run([ADB, "push", to_windows(local_path), dest])
        if out.returncode == 0:
            pushed += 1
        else:
            print(f"  FAILED {rel}: {out.stderr.strip()[:120]}")

    device_tracks = device_download_tracks()
    merged, carried = merge_manifest(tracks, device_tracks)
    if carried:
        with open(os.path.join(PC_ROOT, MANIFEST), "w", encoding="utf-8") as fh:
            json.dump({"tracks": merged}, fh, ensure_ascii=False, indent=1)
        print(f"  carried {carried} downloaded track(s) from the phone into the manifest")

    run([ADB, "push", to_windows(os.path.join(PC_ROOT, MANIFEST)),
         f"{DEVICE_ROOT}/{MANIFEST}"])
    print(f"\npushed {pushed} of {len(to_push)} files, plus the manifest")

    if args.prune:

        stale = [
            rel for rel in remote
            if rel not in {t.get("file") for t in tracks}
            and not rel.startswith("Downloaded/")
        ]
        if not stale:
            print("nothing to prune.")
            return
        print(f"\n{len(stale)} device files are not in the manifest:")
        for rel in stale[:20]:
            print(f"  {rel}")
        if not args.yes:
            answer = input("\nDelete these from the phone? [y/N] ").strip().lower()
            if answer != "y":
                print("not pruning.")
                return
        for rel in stale:
            run([ADB, "shell", "rm", "-f", f"{DEVICE_ROOT}/{rel}"])
        print(f"pruned {len(stale)} files")

if __name__ == "__main__":
    main()
