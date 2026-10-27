"""Download source playlists into the PersonaR source tree.

One command pulls every playlist listed in PLAYLISTS below into
``<MUSIC_ROOT>/<folder>/`` using the same on-disk shape as the existing rips
(H.264 video + AAC audio + an attached picture), so the library pipeline
(``build_library.py`` -> ``execute_library.py``) picks them up with no special
cases.

Adding a playlist later is a SINGLE line in PLAYLISTS -- that is the whole
extension point. Nothing else in this file needs editing.

Usage
-----
    python3 tools/download_library_playlists.py --list      # probe only, no download
    python3 tools/download_library_playlists.py             # download all
    python3 tools/download_library_playlists.py --verify    # check folders vs playlists
    python3 tools/download_library_playlists.py --only "US UK"
    python3 tools/download_library_playlists.py --only PLbQgdqIOqKyU

After a pull, run the library chain (see the personar-music-library skill):
    build_library.py  ->  review  ->  execute_library.py  ->  desktop mirror
    ->  refresh bundled manifest  ->  build_playlists.py  ->  sync to phone

Why the verify + repair pass
----------------------------
yt-dlp's ``--download-archive`` records that a track was HANDLED, not that it was
WRITTEN. Two playlist entries whose titles differ only by CASE (e.g. "Without
You" by DEAMN and "WITHOUT YOU" by The Kid LAROI) resolve to the SAME filename on
Windows' case-insensitive filesystem, so the second is skipped by
``--no-overwrites`` -- and it still lands in the archive. The archive then claims
the folder is complete while a track is silently gone.

So after every pull this script DOES NOT trust the archive: it reads each file's
own ``comment`` tag (the YouTube URL, carrying the video id) and compares the set
of ids on disk against the playlist's ids. Any id the archive claims but disk
lacks is re-fetched individually under a unique ``<title> [<id>]`` name.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import library_paths  # noqa: E402

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

MUSIC_ROOT = library_paths.source_dir()

_FFMPEG = shutil.which("ffmpeg")
FFMPEG_DIR = Path(_FFMPEG).parent if _FFMPEG else None
FFPROBE = shutil.which("ffprobe")

def _ytdlp_command() -> list[str]:
    """yt-dlp as an argv prefix: the executable on PATH, else the Python module."""
    which = shutil.which("yt-dlp")
    return [which] if which else [sys.executable, "-m", "yt_dlp"]

def _ytdlp_available() -> bool:
    if shutil.which("yt-dlp"):
        return True
    try:
        import yt_dlp  # noqa: F401  (imported only to check presence)
        return True
    except ImportError:
        return False

YTDLP = _ytdlp_command()

PLAYLISTS = [
    {"folder": "US UK", "id": "PLfLwGYP80swY", "label": "US UK"},
    {"folder": "VPOP",  "id": "PLFRrFMxhkEIg", "label": "VPOP"},
    {"folder": "KPOP",  "id": "PLbQgdqIOqKyU", "label": "KPOP"},
    {"folder": "JPOP",  "id": "PLD-OCcgcqIwo", "label": "JPOP"},
]

PLAYLISTS_FILE = Path(__file__).resolve().parent / "playlists.json"

def _playlist_id(url: str) -> str:
    """The list id inside a playlist URL, or ''."""
    m = re.search(r"[?&]list=([A-Za-z0-9_-]+)", url or "")
    return m.group(1) if m else ""

def _entry_url(entry: dict) -> str:
    """A playlist URL: the entry's own url when it has one, else built from its id."""
    url = (entry.get("url") or "").strip()
    return url or f"https://youtube.com/playlist?list={entry['id']}"

def load_playlists() -> list[dict]:
    """The editable list, falling back to the built-in table.

    An entry needs a folder and either an id or a url; the id is derived from the
    url when only a link is given, so everything downstream can keep working off
    the id alone.
    """
    if not PLAYLISTS_FILE.is_file():
        return [dict(e) for e in PLAYLISTS]
    try:
        data = json.loads(PLAYLISTS_FILE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"playlists.json unreadable ({exc}) -- using the built-in list",
              file=sys.stderr)
        return [dict(e) for e in PLAYLISTS]

    raw = data.get("playlists", data) if isinstance(data, dict) else data
    out: list[dict] = []
    for e in raw or []:
        if not isinstance(e, dict):
            continue
        folder = (e.get("folder") or "").strip()
        pid = (e.get("id") or _playlist_id(e.get("url") or "")).strip()
        if not folder or not pid:
            print(f"  skipping an incomplete playlist entry: {e}", file=sys.stderr)
            continue
        out.append({"folder": folder, "id": pid,
                    "label": (e.get("label") or folder).strip(),
                    "url": (e.get("url") or "").strip()})
    if not out:
        print("playlists.json held no usable entries -- using the built-in list",
              file=sys.stderr)
        return [dict(e) for e in PLAYLISTS]
    return out

FORMAT = "bv*[vcodec^=avc1]+ba[acodec^=mp4a]/bv*+ba/b"
ARCHIVE = ".ytdlp-archive.txt"
MEDIA_EXT = {".mp4", ".mkv", ".webm", ".mp3", ".m4a"}
_VIDEO_ID_RE = re.compile(r"[?&]v=([A-Za-z0-9_-]{11})|youtu\.be/([A-Za-z0-9_-]{11})")

def playlist_url(entry) -> str:
    """The URL to pull. Accepts an entry dict (which may carry its own url) or a
    bare playlist id."""
    if isinstance(entry, dict):
        return _entry_url(entry)
    return f"https://youtube.com/playlist?list={entry}"

def probe(pid: str) -> tuple[int | None, str]:
    """Return (playlist_count, playlist_title) without downloading anything."""
    out = subprocess.run(
        [*YTDLP, "--flat-playlist", "--playlist-items", "1",
         "--print", "%(playlist_count)s|%(playlist_title)s", playlist_url(pid)],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    lines = (out.stdout or out.stderr).strip().splitlines()
    if not lines:
        return None, "?"
    parts = lines[-1].split("|")
    try:
        return int(parts[0]), parts[1]
    except (ValueError, IndexError):
        return None, lines[-1]

def playlist_ids(pid: str) -> dict[str, str]:
    """{video_id: title} for every entry in the playlist, in playlist order."""
    out = subprocess.run(
        [*YTDLP, "--flat-playlist", "--no-warnings",
         "--print", "%(id)s|%(title)s", playlist_url(pid)],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    entries: dict[str, str] = {}
    for line in (out.stdout or "").splitlines():
        if "|" in line:
            vid, title = line.rstrip("\n").split("|", 1)
            entries[vid] = title
    return entries

def file_video_id(path: Path) -> str | None:
    """The video id from a file's ``comment`` tag (the YouTube URL), or None."""
    if not FFPROBE:
        return None
    out = subprocess.run(
        [FFPROBE, "-v", "error",
         "-show_entries", "format_tags=comment", "-of", "default=nw=1:nk=1", str(path)],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    m = _VIDEO_ID_RE.search(out.stdout or "")
    if m:
        return m.group(1) or m.group(2)
    return None

def ids_on_disk(folder: Path) -> set[str]:
    found: set[str] = set()
    if not folder.exists():
        return found
    for p in folder.iterdir():
        if p.is_file() and p.suffix.lower() in MEDIA_EXT:
            vid = file_video_id(p)
            if vid:
                found.add(vid)
    return found

def _base_cmd(archive: Path | None, outtmpl: str) -> list[str]:
    cmd = [
        *YTDLP,
        "-f", FORMAT,
        "--merge-output-format", "mp4",
        "--no-overwrites", "--ignore-errors", "--no-warnings",
        "--retries", "5", "--fragment-retries", "5", "--concurrent-fragments", "3",
        "--embed-metadata", "--embed-thumbnail",
        "-o", outtmpl,
    ]
    if FFMPEG_DIR is not None:
        cmd += ["--ffmpeg-location", str(FFMPEG_DIR)]
    if archive is not None:
        cmd += ["--download-archive", str(archive)]
    return cmd

def download(entry: dict) -> int:
    folder = MUSIC_ROOT / entry["folder"]
    folder.mkdir(parents=True, exist_ok=True)
    archive = folder / ARCHIVE

    print(f"\n=== {entry['label']} ({entry['id']}) -> {folder} ===", flush=True)
    subprocess.call(
        _base_cmd(archive, "%(title)s.%(ext)s") + [playlist_url(entry)],
        cwd=str(folder),
    )

    entries = playlist_ids(entry["id"])
    on_disk = ids_on_disk(folder)
    missing = [vid for vid in entries if vid not in on_disk]

    for vid in missing:
        print(f"  repairing missing id {vid} ({entries[vid]!r}) under a unique name",
              flush=True)
        subprocess.call(
            _base_cmd(None, "%(title)s [%(id)s].%(ext)s")
            + [f"https://youtube.com/watch?v={vid}"],
            cwd=str(folder),
        )

    on_disk = ids_on_disk(folder)
    still = [vid for vid in entries if vid not in on_disk]
    mark = "OK" if not still else "SHORT"
    print(f"  [{mark}] {entry['label']}: playlist={len(entries)} "
          f"on-disk={len(entries) - len(still)} missing={len(still)}", flush=True)
    for vid in still:
        print(f"      MISSING {vid} | {entries[vid]}", file=sys.stderr)

    return 0 if not still else 1

def _write_playlists(entries: list[dict]) -> int:
    """Persist the editable list. This is the ONLY writer of playlists.json."""
    PLAYLISTS_FILE.write_text(
        json.dumps({"playlists": entries}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8")
    print(f"{len(entries)} playlist(s) -> {PLAYLISTS_FILE.name}")
    for e in entries:
        print(f"  {e['folder']:<12} {e['id']}")
    return 0

def cmd_add(folder: str, url: str, label: str) -> int:
    """Add a playlist, or change the link of one whose folder already exists."""
    pid = _playlist_id(url)
    if not pid:
        print(f"no playlist id found in {url!r}. Paste a link containing 'list=...'",
              file=sys.stderr)
        return 2
    entries = load_playlists()
    for e in entries:
        if e["folder"].lower() == folder.lower():
            e["id"] = pid
            e["url"] = url.strip()
            if label:
                e["label"] = label
            print(f"updated {folder}: {pid}")
            return _write_playlists(entries)
    entries.append({"folder": folder, "id": pid, "label": label or folder,
                    "url": url.strip()})
    print(f"added {folder}: {pid}")
    return _write_playlists(entries)

def cmd_remove(folder: str) -> int:
    entries = load_playlists()
    keep = [e for e in entries if e["folder"].lower() != folder.lower()]
    if len(keep) == len(entries):
        print(f"no playlist named {folder!r}", file=sys.stderr)
        return 2
    print(f"removed {folder}")
    return _write_playlists(keep)

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--list", action="store_true", help="probe playlists, download nothing")
    ap.add_argument("--verify", action="store_true",
                    help="check folders against playlists by video id, download nothing")
    ap.add_argument("--only", help="only this folder name or playlist id")
    ap.add_argument("--add", metavar="FOLDER", help="add a playlist to playlists.json")
    ap.add_argument("--url", metavar="URL", help="the playlist link for --add")
    ap.add_argument("--label", metavar="LABEL", help="display label for --add")
    ap.add_argument("--remove", metavar="FOLDER", help="remove a playlist from playlists.json")
    ap.add_argument("--list-playlists", action="store_true",
                    help="print the editable list as JSON and exit")
    ap.add_argument("--probe", action="store_true",
                    help="with --only: print that one playlist's track count, no download")
    args = ap.parse_args()

    if args.list_playlists:
        print(json.dumps({"playlists": load_playlists()}, ensure_ascii=False, indent=2))
        return 0
    if args.add:
        return cmd_add(args.add, args.url or "", args.label or args.add)
    if args.remove:
        return cmd_remove(args.remove)
    if args.probe:
        want = (args.only or "").lower()
        for e in load_playlists():
            if want in (e["folder"].lower(), e["id"], e["label"].lower()):
                n, title = probe(e["id"])
                print(f"{e['folder']:<12} {e['id']:<16} {str(n):>5} tracks  {title}")
                return 0
        print(f"no playlist matches {args.only!r}", file=sys.stderr)
        return 2

    entries = load_playlists()

    if args.only:
        wanted = [e for e in entries
                  if args.only in (e["folder"], e["id"], e["label"])]
        if not wanted:
            print(f"no playlist matches {args.only!r}; known: "
                  + ", ".join(e["folder"] for e in entries), file=sys.stderr)
            return 2
    else:
        wanted = entries

    if not _ytdlp_available():
        print("yt-dlp not found — install it (setup.ps1 or "
              "'python -m pip install yt-dlp')", file=sys.stderr)
        return 2
    if FFPROBE is None:
        print("ffprobe not found on PATH — install ffmpeg first (setup.ps1)",
              file=sys.stderr)
        return 2

    if args.list:
        for e in entries:
            n, title = probe(e["id"])
            print(f"{e['folder']:<10} {e['id']:<16} {str(n):>5} tracks  {title}")
        return 0

    if args.verify:
        rc = 0
        for e in entries:
            entries = playlist_ids(e["id"])
            on_disk = ids_on_disk(MUSIC_ROOT / e["folder"])
            missing = [vid for vid in entries if vid not in on_disk]
            print(f"{e['label']:<10} playlist={len(entries):>4} "
                  f"on-disk={len(entries) - len(missing):>4} missing={len(missing)}")
            for vid in missing:
                print(f"   MISSING {vid} | {entries[vid]}")
            rc |= 1 if missing else 0
        return rc

    rc = 0
    for e in wanted:
        rc |= download(e)
    return rc

if __name__ == "__main__":
    raise SystemExit(main())
