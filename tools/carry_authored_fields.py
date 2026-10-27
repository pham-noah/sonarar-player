"""Carry AUTHORED manifest fields across a library rebuild.

WHY THIS EXISTS
    `execute_library.py` rebuilds the library manifest from the source files, so
    every entry it writes is derived from the audio. Some fields are NOT derived
    and cannot be: `variant_of` and `variant` are authored BY HAND (they say a
    track is an alternate cut of another), and `romaji` is a generated reading
    that is expensive to recompute and needs pykakasi. A rebuild silently drops
    all three, and the loss reaches the APK because the bundled manifest is
    refreshed from the rebuilt one.

    The symptom is specific and self-diagnosing: `library_variants_test.dart`
    fails on `no track declares variant_of, so nothing can ever be swapped` —
    the code is fine, the data is gone.

    `tools/add_romaji.py` was the only step that preserved anything, because it
    reads the existing manifest and writes it back with one field changed. This
    tool makes that a first-class, re-runnable step for every authored field.

HOW IT RUNS
    Reads the previously-good bundled manifest (at `--from`, default: the git
    HEAD copy), and for every track present in BOTH manifests by id, copies the
    authored fields onto the rebuilt manifest. Only these fields are touched —
    nothing derived is overwritten, and a track the rebuild added simply gets no
    authored fields (it has none yet).

    Writes to `--path` (default: the bundled manifest the app ships) and, with
    `--also`, to additional manifests that the app reads on device (the phone
    and desktop libraries).

USAGE
    python3 tools/carry_authored_fields.py                 # dry run
    python3 tools/carry_authored_fields.py --write         # apply
    python3 tools/carry_authored_fields.py --write \
        --also /mnt/c/Users/Noah/Music/Sonarar/library_manifest.json \
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys

AUTHORED_FIELDS = ("variant_of", "variant", "romaji")

DEFAULT_FROM = "HEAD:app_src/assets/library/library_manifest.json"
DEFAULT_PATH = "app_src/assets/library/library_manifest.json"

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
def load_previous(spec: str) -> list[dict]:
    """Read the previous manifest — from a git object (`HEAD:path`) or the disk."""
    if ":" in spec and not os.path.isfile(spec):
        out = subprocess.run(["git", "show", spec],
                             capture_output=True, text=True,
                             encoding="utf-8", errors="replace")
        if out.returncode != 0:
            print(f"cannot read git object {spec}: {out.stderr.strip()[:160]}",
                  file=sys.stderr)
            return []
        data = json.loads(out.stdout)
    else:
        with open(spec, encoding="utf-8") as fh:
            data = json.load(fh)
    return data.get("tracks", data) if isinstance(data, dict) else data

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--write", action="store_true", help="apply (default is a dry run)")
    ap.add_argument("--from", dest="src", default=DEFAULT_FROM,
                    help=f"previous manifest: a git object or a path (default {DEFAULT_FROM})")
    ap.add_argument("--path", default=DEFAULT_PATH,
                    help=f"manifest to update (default {DEFAULT_PATH})")
    ap.add_argument("--also", action="append", default=[],
                    help="additional manifest to update (repeatable)")
    args = ap.parse_args()

    prev = load_previous(args.src)
    if not prev:
        print("no previous manifest tracks — nothing to carry", file=sys.stderr)
        return 1
    by_id = {t["id"]: t for t in prev if t.get("id")}

    targets = [args.path] + args.also
    total = 0
    for path in targets:
        if not os.path.isfile(path):
            print(f"  SKIP (absent): {path}", file=sys.stderr)
            continue
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
        tracks = data.get("tracks", data) if isinstance(data, dict) else data

        carried = {}
        for t in tracks:
            old = by_id.get(t.get("id"))
            if not old:
                continue
            for field in AUTHORED_FIELDS:
                if old.get(field):
                    t[field] = old[field]
                    carried[field] = carried.get(field, 0) + 1

        print(f"{path}: " + ", ".join(f"{k}={v}" for k, v in carried.items())
              if carried else f"{path}: nothing carried")
        total += sum(carried.values())

        if args.write:
            indent = 1 if ("assets" in path) else 2
            with open(path, "w", encoding="utf-8") as fh:
                json.dump(data, fh, ensure_ascii=False, indent=indent)
                fh.write("\n")

    print(f"\nfields carried: {total}"
          + ("" if args.write else "  (dry run — re-run with --write to apply)"))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
