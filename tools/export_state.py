"""Export every piece of PersonaR state into one file, and import it back.

WHY THIS EXISTS
    Everything this app learns lives on one device and nowhere else: the resume
    point, what it learned from skips, the exclusions, the bookmarks, the loop
    markings. A wiped phone or a reinstall takes all of it, and none of it is
    recoverable from the music, because none of it is in the music. The plan
    calls this the mitigation, and it costs almost nothing: these are five small
    JSON files.

WHAT IS IN THE ARCHIVE
    Only the state files, plus a manifest of what was taken and when. The MUSIC
    IS NOT INCLUDED — it is hundreds of megabytes and it is already reproducible
    from the PC library. An archive that quietly bundled the audio would be
    enormous and would make "back up my settings" feel like "copy my library".

    Each state file (see `<music root>/.state` on the device, or the same folder
    under the desktop music root):
      playback_state.json   where playback was  <-- SnapshotStore writes this name
      loop_points.json      loop markings
      excluded.json         the never-in-shuffle list
      bookmarks.json        per-track positions

    The resume file is called `playback_state.json`, which is easy to get wrong:
    a first pass at this script used `resume.json` and silently backed up
    everything EXCEPT the resume point. The names here are the ones the app
    writes — `SnapshotStore._file`, and the three stores in main().

    tag_overrides.json is listed as EXPECTED BUT ABSENT by default: the plan's
    in-player tag fixing is not built, so nothing writes it. It is named here so
    the gap is visible rather than looking like a lost file.

USAGE
    python3 tools/export_state.py export --out personar-backup.json
    python3 tools/export_state.py import --in personar-backup.json
    python3 tools/export_state.py --list
"""

import argparse
import datetime as dt
import json
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import library_paths  # noqa: E402
    PC_MUSIC = os.path.join(os.fspath(library_paths.source_dir()), "Sonarar")
except Exception:  # noqa: BLE001 -- never stop the window over a path helper
    PC_MUSIC = os.path.expanduser(os.path.join("~", "Music", "Sonarar"))

STATE_DIR = os.environ.get("PERSONAR_STATE_DIR") or os.path.join(PC_MUSIC, ".state")

STATE_FILES = [
    "playback_state.json",
    "loop_points.json",
    "excluded.json",
    "bookmarks.json",
    "tag_overrides.json",
]

ARCHIVE_VERSION = 1

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
def fail(msg):
    print(f"STOPPED: {msg}", file=sys.stderr)
    sys.exit(1)

def read_state(state_dir):
    """Everything present, as parsed JSON. Absent files are simply not included.

    A file that exists but does not parse is REPORTED, not skipped: silently
    dropping it would make the backup look complete while missing exactly the
    file that was damaged.
    """
    found = {}
    broken = []
    for name in STATE_FILES:
        path = os.path.join(state_dir, name)
        if not os.path.isfile(path):
            continue
        try:
            with open(path, encoding="utf-8") as fh:
                found[name] = json.load(fh)
        except json.JSONDecodeError as exc:
            broken.append(f"{name}: {exc}")
    return found, broken

def cmd_export(args):
    if not os.path.isdir(STATE_DIR):
        fail(f"no state folder at {STATE_DIR} — has the app run on this machine?")

    found, broken = read_state(STATE_DIR)
    if broken:
        print("Refusing to export: these state files are unreadable, and a "
              "backup that quietly omits them is worse than none.")
        for b in broken:
            print(f"  {b}")
        sys.exit(2)

    absent = [n for n in STATE_FILES if n not in found]
    archive = {
        "archive_version": ARCHIVE_VERSION,
        "exported_at": dt.datetime.now().isoformat(timespec="seconds"),
        "source": STATE_DIR,

        "note": "PersonaR state only. Contains no audio.",
        "contains": sorted(found.keys()),
        "absent": absent,
        "state": found,
    }

    out = args.out
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(archive, fh, ensure_ascii=False, indent=1)

    size = os.path.getsize(out)
    print(f"exported {len(found)} state file(s) to {out} ({size} bytes)")
    for name in sorted(found):
        print(f"  {name}")
    if absent:
        print(f"absent (never written yet): {', '.join(absent)}")

def cmd_import(args):
    if not os.path.isfile(args.in_):
        fail(f"no archive at {args.in_}")
    with open(args.in_, encoding="utf-8") as fh:
        archive = json.load(fh)

    if archive.get("archive_version") != ARCHIVE_VERSION:

        fail(f"archive version {archive.get('archive_version')!r} is not "
             f"{ARCHIVE_VERSION} — this script will not guess at the shape.")

    state = archive.get("state")
    if not isinstance(state, dict):
        fail("archive has no 'state' object")

    os.makedirs(STATE_DIR, exist_ok=True)

    replaced = 0
    if args.keep_backup:
        for name in state:
            live = os.path.join(STATE_DIR, name)
            if os.path.isfile(live):
                shutil.copy2(live, live + ".pre-import")
                replaced += 1

    written = 0
    for name, payload in state.items():
        if name not in STATE_FILES:

            print(f"  skipping unknown state file: {name}")
            continue
        with open(os.path.join(STATE_DIR, name), "w", encoding="utf-8") as fh:
            json.dump(payload, fh, ensure_ascii=False, indent=1)
        written += 1

    print(f"imported {written} state file(s) into {STATE_DIR}")
    if replaced:
        print(f"  {replaced} existing file(s) kept as *.pre-import")

def cmd_list(_args):
    if not os.path.isdir(STATE_DIR):
        print(f"no state folder at {STATE_DIR}")
        return
    print(f"{STATE_DIR}\n")
    for name in STATE_FILES:
        path = os.path.join(STATE_DIR, name)
        if os.path.isfile(path):
            print(f"  {os.path.getsize(path):>8}  {name}")
        else:
            print(f"  {'-':>8}  {name}  (absent)")
    found, broken = read_state(STATE_DIR)
    if broken:
        print("\n  UNREADABLE:")
        for b in broken:
            print(f"    {b}")

def main():
    ap = argparse.ArgumentParser(description="Back up or restore PersonaR state.")
    ap.add_argument("--list", action="store_true", help="show what state exists here")
    sub = ap.add_subparsers(dest="cmd")

    e = sub.add_parser("export", help="write everything into one archive")
    e.add_argument("--out", default="personar-backup.json")

    i = sub.add_parser("import", help="restore from an archive")
    i.add_argument("--in", dest="in_", required=True)
    i.add_argument("--no-keep-backup", dest="keep_backup", action="store_false",
                   help="do not copy existing files aside first")

    args = ap.parse_args()
    if args.list:
        return cmd_list(args)
    if args.cmd == "export":
        return cmd_export(args)
    if args.cmd == "import":
        return cmd_import(args)
    ap.print_help()

if __name__ == "__main__":
    main()
