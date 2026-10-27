"""Exercise the Stage 8 scripts without a phone.

Run: python3 tools/selfcheck.py

WHY THIS EXISTS
    Stage 8's scripts all talk to a phone over adb, so the natural test is "plug
    a phone in and see" — which means the parts that could silently do the wrong
    thing (push nothing, or push the whole library every time) never get tested
    at all. This drives the pure parts directly, plus the version refusal in
    export_state.py, and reports what it checked.

    It writes nothing outside a scratch folder and needs no device.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
from types import SimpleNamespace

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import export_state as ex            # noqa: E402
import sync_library as sl            # noqa: E402

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
def check(label, ok, detail=""):
    print(f"  [{'ok' if ok else 'FAIL'}] {label}" + (f" — {detail}" if detail else ""))
    return ok

def main():
    passed = 0
    failed = 0

    def run(label, ok, detail=""):
        nonlocal passed, failed
        if check(label, ok, detail):
            passed += 1
        else:
            failed += 1

    work = tempfile.mkdtemp(prefix="personar-selfcheck-")
    try:
        print("Stage 8 self-check\n")

        print("sync_library.diff_library")
        lib = os.path.join(work, "lib")
        os.makedirs(os.path.join(lib, "covers"), exist_ok=True)
        for name in ("a.opus", "b.opus"):
            with open(os.path.join(lib, name), "wb") as fh:
                fh.write(b"x" * 100)

        tracks = [{"file": "a.opus"}, {"file": "b.opus"}, {"file": "gone.opus"}]

        push, missing, changed, ml = sl.diff_library(tracks, lib, {})
        run("everything missing is pushed", len(push) == 2 and missing == 2)
        run("a track absent locally is reported, not pushed",
            ml == ["gone.opus"] and changed == 0)

        push, missing, changed, ml = sl.diff_library(
            tracks, lib, {"a.opus": 100, "b.opus": 100})
        run("an in-sync library pushes nothing", push == [] and missing == 0)

        push, missing, changed, ml = sl.diff_library(
            tracks, lib, {"a.opus": 100, "b.opus": 99})
        run("a size difference pushes exactly that file",
            len(push) == 1 and push[0][0] == "b.opus" and changed == 1)

        push, missing, changed, ml = sl.diff_library(
            tracks, lib, {"a.opus": 100, "b.opus": 100})
        run("same size is treated as up to date (documented tradeoff)",
            push == [])

        print("\nexport_state round trip")
        state = os.path.join(work, "state")
        os.makedirs(state, exist_ok=True)
        payloads = {

            "playback_state.json": {"version": 1, "track_id": "abc", "position_ms": 1234},
            "loop_points.json": [
                {"track_id": "t1", "loop_start_ms": 1000, "loop_end_ms": 2000, "loop_count": 2}
            ],
            "excluded.json": {"t7": True},
            "bookmarks.json": {"t3": 95000},
        }
        for name, payload in payloads.items():
            with open(os.path.join(state, name), "w", encoding="utf-8") as fh:
                json.dump(payload, fh)

        real_dir = ex.STATE_DIR
        ex.STATE_DIR = state
        try:
            archive = os.path.join(work, "backup.json")

            a = SimpleNamespace(out=archive)
            ex.cmd_export(a)

            run("the resume file is captured",
                "playback_state.json" in json.load(open(archive))["state"])

            before = {n: json.load(open(os.path.join(state, n))) for n in payloads}
            for n in payloads:
                os.remove(os.path.join(state, n))

            ex.cmd_import(SimpleNamespace(in_=archive, keep_backup=True))

            after = {n: json.load(open(os.path.join(state, n))) for n in payloads}
            run("state survives export then import unchanged", before == after)

            bad = os.path.join(work, "bad.json")
            json.dump({"archive_version": 999, "state": payloads}, open(bad, "w"))
            r = subprocess.run(
                [sys.executable, os.path.join(HERE, "export_state.py"),
                 "import", "--in", bad],
                capture_output=True, text=True, encoding="utf-8", errors="replace")
            run("a future archive version is refused", r.returncode != 0)

            open(os.path.join(state, "excluded.json"), "w").write("{broken")
            r = subprocess.run(
                [sys.executable, os.path.join(HERE, "export_state.py"),
                 "export", "--out", os.path.join(work, "x.json")],
                capture_output=True, text=True, encoding="utf-8", errors="replace",
                env={**os.environ, "PERSONAR_STATE_DIR": state})
            run("an unreadable state file blocks the export",
                r.returncode != 0, "(rc=%d)" % r.returncode)
        finally:
            ex.STATE_DIR = real_dir

        print(f"\n{passed} passed, {failed} failed")
        return 1 if failed else 0
    finally:
        shutil.rmtree(work, ignore_errors=True)

if __name__ == "__main__":
    sys.exit(main())
