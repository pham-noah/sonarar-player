"""PersonaR library builder — EXECUTE stage.

Reads reports/dry_run_report.json (the plan Noah reviewed) and materialises the
library. It acts ONLY on what the report says; it never re-decides anything.

    python3 execute_library.py --limit 2      # proof run: first 2 tracks
    python3 execute_library.py                # full run
    python3 execute_library.py --resume       # skip tracks already built

HARD GUARANTEES
---------------
* SOURCE_DIR is opened read-only. Nothing in it is renamed, moved, deleted, or
  even written to. The only exception is the OUTPUT_DIR, which lives inside it
  as a new subfolder and is added to the builder's own ignore list.
* Every destination path is checked to be inside OUTPUT_DIR before any write.
* Re-running is safe: finished tracks are skipped when --resume is used.

Output layout
-------------
    Music/Sonarar/
        library_manifest.json
        covers/<md5>.jpg          one file per unique cover
        <Artist>/<Album>/<Title>.opus

Loudness is NOT baked into the audio. The measured gain is written to the
manifest (and to the R128_TRACK_GAIN tag on Opus) so the player applies it at
playback and the change stays reversible.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import library_paths  # noqa: E402

HERE = Path(__file__).resolve().parent
SOURCE_DIR = library_paths.source_dir()
PROJECT = library_paths.project_dir()
OUTPUT_DIR = SOURCE_DIR / "Sonarar"
COVER_DIR = OUTPUT_DIR / "covers"
REPORT_JSON = PROJECT / "reports" / "dry_run_report.json"
LOG_PATH = PROJECT / "reports" / "execute_log.txt"

OPUS_BITRATE = "128k"

_ILLEGAL = re.compile(r'[<>:"/\\|?*\x00-\x1f]')

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

_log_lines: list[str] = []

def log(msg: str, echo: bool = True) -> None:
    stamp = time.strftime("%H:%M:%S")
    line = f"[{stamp}] {msg}"
    _log_lines.append(line)
    if echo:
        print(line, flush=True)

def flush_log() -> None:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    LOG_PATH.write_text("\n".join(_log_lines), encoding="utf-8")

def safe_component(name: str, fallback: str = "Unknown") -> str:
    """Make a string safe as a single Windows path component."""
    name = _ILLEGAL.sub("-", name)
    name = name.strip().rstrip(".")
    name = re.sub(r"\s{2,}", " ", name)
    return name or fallback

def assert_inside_output(path: Path) -> None:
    p = path.resolve()
    out = OUTPUT_DIR.resolve()
    if out != p and out not in p.parents:
        raise RuntimeError(f"refusing to write outside OUTPUT_DIR: {p}")

def md5_of(path: Path) -> str:
    h = hashlib.md5()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def run(cmd: list[str], timeout: int = 900) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout,
                          encoding="utf-8", errors="replace")

def src_for(rel: str) -> Path:
    return SOURCE_DIR / rel

def has_attached_pic(path: Path) -> bool:
    proc = run(["ffprobe", "-v", "error", "-select_streams", "v",
                "-show_entries", "stream_disposition=attached_pic",
                "-print_format", "json", str(path)], timeout=60)
    try:
        return any(
            s.get("disposition", {}).get("attached_pic")
            for s in json.loads(proc.stdout).get("streams", [])
        )
    except json.JSONDecodeError:
        return False

def extract_cover(prop: dict) -> tuple[Path | None, bool]:
    """Return (temp cover path or None, is_real_embedded_art).

    Two different worlds live in this library:
      * .mp3 rips carry a real, tagged cover picture -> use it verbatim.
      * .mp4 rips are album-art videos (a still picture held for the whole
        song) -> pull one frame. Seeking is applied AFTER -i so it can never
        land on a title card, which is what happens with -ss before -i when
        the container is a still image.
    """
    src = src_for(prop["rel_path"])

    tmp = Path(tempfile.gettempdir()) / "personar_cover.jpg"
    if tmp.exists():
        tmp.unlink()

    real_art = has_attached_pic(src)

    vf = (f"scale={COVER_SIZE}:{COVER_SIZE}:force_original_aspect_ratio=decrease,"
          f"pad={COVER_SIZE}:{COVER_SIZE}:(ow-iw)/2:(oh-ih)/2:color=black")

    if real_art:
        cmd = ["ffmpeg", "-hide_banner", "-v", "error", "-y",
               "-i", str(src), "-map", "0:v:0", "-frames:v", "1",
               "-vf", vf, "-q:v", str(COVER_QUALITY), str(tmp)]
    else:
        dur = prop.get("duration_s") or 0
        seek = max(3.0, dur * 0.35)
        cmd = ["ffmpeg", "-hide_banner", "-v", "error", "-y",
               "-i", str(src), "-frames:v", "1", "-ss", f"{seek:.1f}",
               "-vf", vf, "-q:v", str(COVER_QUALITY), str(tmp)]

    proc = run(cmd, timeout=300)
    if proc.returncode != 0 or not tmp.exists():
        return None, real_art
    return tmp, real_art

def build_track(prop: dict, cover_hashes: dict, dry: bool) -> dict | None:
    rel = prop["rel_path"]
    src = src_for(rel)
    if not src.exists():
        log(f"  SKIP (source missing): {rel}")
        return None

    title = prop["proposed_title"].strip() or src.stem
    artist = prop["proposed_artist"].strip() or "Unknown Artist"
    album = prop["proposed_album"].strip() or ""

    ext = ".opus" if not prop["keep_format"] else Path(rel).suffix.lower()
    parts = [safe_component(artist, "Unknown Artist")]
    if album:
        parts.append(safe_component(album, "Unknown Album"))
    parts.append(safe_component(title, "Untitled") + ext)
    dest = OUTPUT_DIR.joinpath(*parts)
    assert_inside_output(dest)

    if dest.exists() and dest.stat().st_size > 0:
        log(f"  EXISTS  {dest.relative_to(OUTPUT_DIR)}")
        return None

    if dry:
        log(f"  would build -> {dest.relative_to(OUTPUT_DIR)}")
        return None

    dest.parent.mkdir(parents=True, exist_ok=True)

    gain = prop.get("proposed_gain_db")

    if prop["keep_format"]:

        tmp_out = dest.with_name(dest.stem + ".tmping" + dest.suffix)
        cmd = [
            "ffmpeg", "-hide_banner", "-v", "error", "-y",
            "-i", str(src), "-map", "0", "-c", "copy",
            "-map_metadata", "-1",
            "-metadata", f"title={title}",
            "-metadata", f"artist={artist}",
        ]
        if album:
            cmd += ["-metadata", f"album={album}"]
        cmd.append(str(tmp_out))
        proc = run(cmd, timeout=600)
        if proc.returncode == 0 and tmp_out.exists():
            tmp_out.replace(dest)
        else:
            log(f"  FAIL tag-copy {rel}: {proc.stderr.strip()[:200]}")
            if tmp_out.exists():
                tmp_out.unlink()
            return None
    else:
        cmd = [
            "ffmpeg", "-hide_banner", "-v", "error", "-y",
            "-i", str(src),
            "-vn",
            "-c:a", "libopus", "-b:a", OPUS_BITRATE,
            "-map_metadata", "-1",
            "-metadata", f"title={title}",
            "-metadata", f"artist={artist}",
        ]
        if album:
            cmd += ["-metadata", f"album={album}"]
        if prop.get("embedded_title") and prop["embedded_title"] != title:
            cmd += ["-metadata", f"ORIGINAL_TITLE={prop['embedded_title']}"]

        if gain is not None:
            cmd += ["-metadata", f"R128_TRACK_GAIN={int(round(gain * 256))}"]
        cmd.append(str(dest))
        proc = run(cmd, timeout=1800)
        if proc.returncode != 0 or not dest.exists():
            log(f"  FAIL transcode {rel}: {proc.stderr.strip()[:200]}")
            return None

    cover_rel = ""
    source_of_cover = ""
    tmp_cover, real_art = extract_cover(prop)
    if tmp_cover and tmp_cover.exists():
        h = md5_of(tmp_cover)
        cover_name = f"{h}.jpg"
        cover_path = COVER_DIR / cover_name
        assert_inside_output(cover_path)
        if not cover_path.exists():
            COVER_DIR.mkdir(parents=True, exist_ok=True)
            shutil.move(str(tmp_cover), cover_path)
            cover_hashes[h] = cover_name
        else:
            tmp_cover.unlink()
        cover_rel = f"covers/{cover_name}"
        source_of_cover = "embedded-tag" if real_art else "video-frame"

    entry = {
        "id": hashlib.sha1(rel.encode()).hexdigest()[:16],
        "title": title,
        "artist": artist,
        "album": album,
        "duration_s": round(prop.get("duration_s") or 0, 3),
        "file": dest.relative_to(OUTPUT_DIR).as_posix(),
        "cover": cover_rel,
        "cover_source": source_of_cover,
        "gain_db": gain,
        "peak_dbfs": prop.get("measured_peak_dbfs"),
        "lufs": prop.get("measured_lufs"),
        "source": rel,
    }
    log(f"  OK      {dest.relative_to(OUTPUT_DIR)}")
    return entry

def main() -> int:
    ap = argparse.ArgumentParser(description="PersonaR library builder — execute")
    ap.add_argument("--limit", type=int, default=0, help="build only the first N (proof run)")
    ap.add_argument("--dry", action="store_true", help="show destinations, write nothing")
    ap.add_argument("--resume", action="store_true", help="keep existing manifest entries")
    ap.add_argument("--source", metavar="DIR",
                    help="music folder to build from (default: auto-detected)")
    ap.add_argument("--project", metavar="DIR",
                    help="folder that holds reports/ (default: ~/Documents/PersonaR)")
    args = ap.parse_args()

    global SOURCE_DIR, PROJECT, OUTPUT_DIR, COVER_DIR, REPORT_JSON, LOG_PATH
    SOURCE_DIR = library_paths.source_dir(args.source)
    PROJECT = library_paths.project_dir(args.project)
    OUTPUT_DIR = SOURCE_DIR / "Sonarar"
    COVER_DIR = OUTPUT_DIR / "covers"
    REPORT_JSON = PROJECT / "reports" / "dry_run_report.json"
    LOG_PATH = PROJECT / "reports" / "execute_log.txt"

    if not REPORT_JSON.exists():
        print(f"missing {REPORT_JSON} — run build_library.py first", file=sys.stderr)
        return 2
    for binary in ("ffmpeg", "ffprobe"):
        if not shutil.which(binary):
            print(f"missing {binary}", file=sys.stderr)
            return 2

    data = json.loads(REPORT_JSON.read_text(encoding="utf-8"))
    music = [p for p in data["proposals"] if p["kind"] == "music"]
    if args.limit:
        music = music[: args.limit]

    log(f"PersonaR execute — {len(music)} tracks")
    log(f"source : {SOURCE_DIR}  (read-only)")
    log(f"output : {OUTPUT_DIR}")
    if args.dry:
        log("DRY RUN — nothing will be written")

    if not args.dry:
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        COVER_DIR.mkdir(parents=True, exist_ok=True)

    manifest_entries: list[dict] = []
    if args.resume:
        mf = OUTPUT_DIR / "library_manifest.json"
        if mf.exists():
            prev = json.loads(mf.read_text(encoding="utf-8"))
            carried = prev.get("tracks", [])

            manifest_entries = [
                e for e in carried
                if (SOURCE_DIR / (e.get("source") or "")).exists()
            ]
            dropped = len(carried) - len(manifest_entries)
            log(f"resume: {len(manifest_entries)} existing entries"
                + (f", dropped {dropped} ghost(s) whose source is gone" if dropped else ""))

    cover_hashes: dict[str, str] = {}
    built = 0
    failed = 0

    for i, prop in enumerate(music, 1):
        log(f"[{i}/{len(music)}] {prop['rel_path']}")
        try:
            entry = build_track(prop, cover_hashes, args.dry)
        except Exception as exc:                      # noqa: BLE001
            log(f"  ERROR {prop['rel_path']}: {exc}")
            failed += 1
            flush_log()
            continue
        if entry:
            manifest_entries = [e for e in manifest_entries if e["source"] != prop["rel_path"]]
            manifest_entries.append(entry)
            built += 1
        if i % 5 == 0:
            flush_log()

    if args.dry:
        log("dry run complete — nothing written")
        return 0

    manifest_entries.sort(key=lambda e: (e["artist"].lower(), e["album"].lower(), e["title"].lower()))
    manifest = {
        "version": 1,
        "generated": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "track_count": len(manifest_entries),
        "cover_dir": "covers",
        "normalisation": {"target_lufs": -16.0, "applied_at": "playback"},
        "tracks": manifest_entries,
    }
    mf_path = OUTPUT_DIR / "library_manifest.json"
    assert_inside_output(mf_path)
    mf_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")

    total_bytes = sum(
        (OUTPUT_DIR / e["file"]).stat().st_size
        for e in manifest_entries
        if (OUTPUT_DIR / e["file"]).exists()
    )
    log("")
    log(f"built          : {built}")
    log(f"failed         : {failed}")
    log(f"manifest tracks: {len(manifest_entries)}")
    log(f"covers         : {len(list(COVER_DIR.glob('*.jpg')))}")
    log(f"library size   : {total_bytes / 1e6:.1f} MB")
    log(f"manifest       : {mf_path}")
    log(f"log            : {LOG_PATH}")
    flush_log()
    return 0 if failed == 0 else 1

if __name__ == "__main__":
    raise SystemExit(main())
