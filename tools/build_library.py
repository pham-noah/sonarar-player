"""PersonaR library builder — inventory and dry-run planner.

STAGE 1 of the PersonaR plan.

Default behaviour is REPORT ONLY. This script writes nothing except its own
report files under reports/. No audio file is renamed, moved, transcoded, or
re-tagged unless --execute is passed AND --yes is given.

    python3 build_library.py                 # dry run -> reports/dry_run_report.{md,json}
    python3 build_library.py --no-loudness   # dry run, skip the slow LUFS measurement

Design notes
------------
* The source folder is read-only, always.
* One file = one proposal. Every proposal records what *would* happen.
* "confidence == review" means the cleaner guessed; Noah decides. Those are
  listed first in the report.
* Formats: .mp3 is kept as-is (transcoding it would only lose quality).
  .mp4/.m4a/.webm (AAC inside) are proposed for Opus 128k.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import clean_titles  # noqa: E402
import library_paths  # noqa: E402

SOURCE_DIR = library_paths.source_dir()
PROJECT_DIR = library_paths.project_dir()
OUT_DIR = PROJECT_DIR
REPORT_DIR = OUT_DIR / "reports"
LOUDNESS_CACHE = REPORT_DIR / "loudness_cache.json"

EXCLUDED_DIRS = {
    "standard": "chess SFX pack, not music — excluded from library, left in place, untouched",
}

FOLDER_ALBUMS: dict[str, tuple[str, str]] = {
    "P3R": ("Persona 3 Reload", "ATLUS Sound Team"),
    "P5R": ("Persona 5", "ATLUS Sound Team"),

    "Weathering With You": ("Weathering With You", "RADWIMPS"),
    "P4": ("Persona 4", "ATLUS Sound Team"),
}

FOLDER_TAG_POLICY: dict[str, dict[str, str]] = {
    "P5R": {"artist": "ATLUS Sound Team"},
    "P4": {"artist": "ATLUS Sound Team", "album": "Persona 4"},
}

JUNK_FILES = {"desktop.ini", ".ds_store", "thumbs.db", ".gitkeep",

              ".ytdlp-archive.txt"}

TITLE_OVERRIDES: dict[str, str] = {
    "ilikeyouthemost.mp3": "I Like You The Most",
    "P3R/tartarus_0d01 (P3R ver.).mp4": "Tartarus 1st Block",
    "P3R/tartarus_0d02 (P3R ver.).mp4": "Tartarus 2nd Block",
    "P3R/tartarus_0d03 (P3R ver.).mp4": "Tartarus 3rd Block",
    "P3R/tartarus_0d04 (P3R ver.).mp4": "Tartarus 4th Block",
    "P3R/tartarus_0d05 (P3R ver.).mp4": "Tartarus 5th Block",
    "P3R/tartarus_0d06 (P3R ver.).mp4": "Tartarus 6th Block",

    'Weathering With You/Theme Of ＂Weathering With You＂.mp4':
        'Theme Of "Weathering With You"',
    'Weathering With You/Hodaka Escapes ⧸ Kid\'s Plot.mp4':
        "Hodaka Escapes / Kid's Plot",
    'Weathering With You/Is There Still Anything That Love Can Do？.mp4':
        "Is There Still Anything That Love Can Do?",
    'Weathering With You/Is There Still Anything That Love Can Do？ (Movie Edit).mp4':
        "Is There Still Anything That Love Can Do? (Movie Edit)",
    'P4/How much？.mp4': "How much?",
    'P4/そこにいるのは誰？.mp4': "そこにいるのは誰?",

    'P4/ケロリンMAGIC!.mp4': "ケロリンMAGIC!",
    'P5R/Nothingness...？.mp4': "Nothingness...?",
    "P5R/What's Going On？.mp4": "What's Going On?",
    'P5R/おかえりなさいませ!ご主人様？.mp4': "おかえりなさいませ!ご主人様?",
    'P5R/告白⧸秘密.mp4': "告白/秘密",
    'P5R/告白⧸秘密 -piano version-.mp4': "告白/秘密 -piano version-",
}

KEEP_ORIGINAL_CASE: set[str] = {
    "IRIS OUT.mp3",
}

DROP_FROM_LIBRARY: dict[str, str] = {
    "P5R/A Ronin Mode Tribute to Persona 5 Beneath the Mask HQ Remastered.mp4":
        "dropped by request — third-party fan remaster, not on the official P5 OST",
    "CLOWN NO MORE [Hollow Knight Animation].mp4": "21s clip, not music",
    "BellyJay - MONTAGEM HERMOSA.mp4": "ALL CAPS styling is intentional",
    "MONTAGEM HIKARI.mp4": "ALL CAPS styling is intentional",
    "MONTAGEM KAGE.mp4": "ALL CAPS styling is intentional",
    "MONTAGEM KOE.mp4": "ALL CAPS styling is intentional",
    "KINDA HOMELESS FUNK.mp3": "ALL CAPS styling is intentional",
    "beauty and a beat at coachella.mp3": "dropped by request — cover art version is a live/coachella recording",
    "bruno mars - that's what i like (slowed & reverb).mp3": "dropped by request — slowed edit, not the original",
    "ariaofthesoul.mp4": "dropped by request — use the P3R version already in the library",
    "hurt.mp3": "dropped by request — file metadata is wrong (internally tagged 'Brazilian Phonk Sport', not 'Hurt')",
    "Persona 3 Reload - All Vocal songs (Lyrics).mp3": "dropped by request — compilation; songs will be downloaded individually later",
    "Phonk Brazilian Workout by Infraction, Emerel Gray [No Copyright Music] _ Todo Mundo.mp4": "dropped by request",
}

PREFER_EMBEDDED_TAGS = True

JUNK_ARTIST_PATTERNS = ("determination", "gemini", "unknown", "various artists")

ARTIST_ALIASES = {
    "atlus sound team": "ATLUS Sound Team",
    "lotus juice": "Lotus Juice",
}

METADATA_OVERRIDES: dict[str, dict[str, str]] = {

    "ilikeyouthemost.mp3": {"artist": "Shayne Orok & Aliorok"},
}

OUTPUT_TOP_DIR = "Sonarar"
OUTPUT_TOP_DIRS = {"Sonarar"}

AUDIO_EXT = {".mp3", ".opus", ".ogg", ".flac", ".wav", ".m4a", ".aac", ".wma"}
VIDEO_EXT = {".mp4", ".webm", ".mkv", ".mov"}

TARGET_LUFS = -16.0
MAX_TRUE_PEAK_DBFS = -1.0

OPUS_BITRATE = "128k"

NON_MUSIC_HINTS = [
    r"\banimation\b", r"\banimated\b", r"\bno copyright music\b", r"\blyrics video\b",
    r"\btrailer\b", r"\bgameplay\b", r"\bmontage\b", r"\bmusic video\b",
]

@dataclass
class Proposal:
    src_path: str
    rel_path: str
    folder: str
    ext: str
    size_bytes: int
    duration_s: float | None = None

    proposed_title: str = ""
    proposed_artist: str = ""
    proposed_album: str = ""
    proposed_track_no: int | None = None
    embedded_title: str = ""
    embedded_artist: str = ""
    embedded_album: str = ""

    confidence: str = "high"
    notes: list[str] = field(default_factory=list)
    flags: list[str] = field(default_factory=list)

    src_codec: str = ""
    src_bitrate: str = ""
    src_channels: int | None = None
    src_sample_rate: int | None = None
    has_art: bool = False

    measured_lufs: float | None = None
    measured_peak_dbfs: float | None = None
    proposed_gain_db: float | None = None

    chapter_candidates: list = field(default_factory=list)

    target_rel_path: str = ""
    planned_command: str = ""

    raw_tags: dict = field(default_factory=dict)

_FILENAME_SUBSTITUTIONS = str.maketrans({
    "？": "?", "＂": '"', "：": ":", "｜": "|", "⧸": "/", "／": "/",
    "＊": "*", "＜": "<", "＞": ">", "＼": "\\",
})
_WS_NORM_RE = re.compile(r"\s+")

def normalise_title(text: str) -> str:
    """Fold casing and YouTube's filename character substitutions, so two
    spellings of the same title compare equal."""
    return _WS_NORM_RE.sub(" ", text.translate(_FILENAME_SUBSTITUTIONS)).strip().lower()

def have(binary: str) -> bool:
    return shutil.which(binary) is not None

def _force_utf8_console() -> None:
    """Stop a Windows console from mangling or refusing non-ASCII output.

    Python on Windows encodes stdout as cp1252, so printing a Japanese title
    raises UnicodeEncodeError and kills the run mid-scan. A Windows console can
    display it once told to use UTF-8; a WSL pipe just gets the bytes.
    """
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, OSError, ValueError):
            pass

_force_utf8_console()

def run(cmd: list[str], timeout: int = 300) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout,
                          encoding="utf-8", errors="replace")

def ffprobe_json(path: Path) -> dict:
    proc = run([
        "ffprobe", "-v", "error", "-show_format", "-show_streams",
        "-show_chapters", "-print_format", "json", str(path),
    ], timeout=120)
    if proc.returncode != 0:
        return {}
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError:
        return {}

_LUFS_RE = re.compile(r"I:\s+(-?\d+(?:\.\d+)?)\s+LUFS")
_PEAK_RE = re.compile(r"Peak:\s+(-?\d+(?:\.\d+)?)\s+dBFS")

_TS_RE = re.compile(r"^\s*(\d{1,2}):(\d{2})(?::(\d{2}))?\s+(\S.*?)\s*$", re.MULTILINE)

def extract_chapter_candidates(tags: dict, min_chapters: int = 5) -> list[dict]:
    """Find a timestamped tracklist inside tag text.

    Only accepts a list that starts at 00:00 and is in strictly ascending order —
    that is what separates a real tracklist from a "chapters" link or a stray
    timestamp in a comment.
    """
    for value in tags.values():
        text = str(value)
        if text.count(":") < min_chapters:
            continue
        entries: list[tuple[int, str]] = []
        for h, m, s, title in _TS_RE.findall(text):
            secs = (int(h) * 3600 + int(m) * 60 + int(s)) if s else (int(h) * 60 + int(m))
            entries.append((secs, title.strip()))
        if len(entries) < min_chapters:
            continue
        if entries[0][0] != 0:
            continue
        if any(entries[i + 1][0] <= entries[i][0] for i in range(len(entries) - 1)):
            continue
        return [{"start_s": s, "title": t} for s, t in entries]
    return []

def load_loudness_cache() -> dict:
    if LOUDNESS_CACHE.exists():
        try:
            return json.loads(LOUDNESS_CACHE.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return {}
    return {}

def save_loudness_cache(cache: dict) -> None:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    LOUDNESS_CACHE.write_text(json.dumps(cache, indent=1), encoding="utf-8")

def measure_loudness_cached(path: Path, rel: str, cache: dict) -> tuple[float | None, float | None]:
    """Measure once, remember forever.

    Loudness of a file never changes unless the file changes, and each
    measurement decodes the whole track (~3 s each). The cache key is
    rel_path + size + mtime, so editing a file invalidates just that entry.

    A file that disappears between the scan and the measurement is not an
    error — see the guard below.
    """
    try:
        st = path.stat()
    except FileNotFoundError:

        return None, None
    key = f"{rel}|{st.st_size}|{int(st.st_mtime)}"
    hit = cache.get(key)
    if hit:
        return hit.get("lufs"), hit.get("peak")
    lufs, peak = measure_loudness(path)
    cache[key] = {"lufs": lufs, "peak": peak}
    save_loudness_cache(cache)
    return lufs, peak

def measure_loudness(path: Path) -> tuple[float | None, float | None]:
    """Return (integrated LUFS, true peak dBFS). None on failure."""
    proc = run([
        "ffmpeg", "-hide_banner", "-nostats", "-i", str(path),
        "-af", "ebur128=peak=true", "-f", "null", "-",
    ], timeout=1800)
    if proc.returncode != 0:
        return None, None

    lufs = _LUFS_RE.findall(proc.stderr)
    peaks = _PEAK_RE.findall(proc.stderr)
    if not lufs:
        return None, None
    return float(lufs[-1]), (float(peaks[-1]) if peaks else None)

def compute_gain(lufs: float | None, peak: float | None) -> float | None:
    if lufs is None:
        return None
    gain = TARGET_LUFS - lufs
    if peak is not None and peak + gain > MAX_TRUE_PEAK_DBFS:
        gain = MAX_TRUE_PEAK_DBFS - peak
    return round(gain, 2)

def first_audio_stream(probe: dict) -> dict:
    for s in probe.get("streams", []):
        if s.get("codec_type") == "audio":
            return s
    return {}

def display_width(text: str) -> int:
    """East-Asian wide characters count as 2 columns for report alignment."""
    import unicodedata
    return sum(2 if unicodedata.east_asian_width(c) in ("W", "F") else 1 for c in text)

def pad(text: str, width: int) -> str:
    return text + " " * max(0, width - display_width(text))

def scan() -> list[Proposal]:
    proposals: list[Proposal] = []

    for root, dirs, files in os.walk(SOURCE_DIR):
        dirs[:] = sorted(
            d for d in dirs
            if not d.startswith(".") and d not in OUTPUT_TOP_DIRS
        )
        root_path = Path(root)
        rel_dir = root_path.relative_to(SOURCE_DIR)
        folder = "" if str(rel_dir) == "." else str(rel_dir)

        for name in sorted(files):
            if name.lower() in JUNK_FILES:
                proposals.append(Proposal(
                    src_path=str(root_path / name),
                    rel_path=name, folder=folder, ext=Path(name).suffix.lower(),
                    size_bytes=(root_path / name).stat().st_size,
                    kind="junk",
                    proposed_title=name,
                    notes=["system/junk file — not part of the library"],
                ))
                continue

            ext = Path(name).suffix.lower()
            if ext not in AUDIO_EXT and ext not in VIDEO_EXT:
                proposals.append(Proposal(
                    src_path=str(root_path / name),
                    rel_path=os.path.join(folder, name) if folder else name,
                    folder=folder, ext=ext,
                    size_bytes=(root_path / name).stat().st_size,
                    kind="unknown",
                    proposed_title=name,
                    confidence="review",
                    notes=[f"unrecognised extension {ext} — ignored"],
                ))
                continue

            rel = os.path.join(folder, name) if folder else name
            size = (root_path / name).stat().st_size

            if folder and folder.split(os.sep)[0] in EXCLUDED_DIRS:
                proposals.append(Proposal(
                    src_path=str(root_path / name), rel_path=rel, folder=folder,
                    ext=ext, size_bytes=size, kind="sfx",
                    proposed_title=Path(name).stem,
                    notes=[f"excluded: {EXCLUDED_DIRS[folder.split(os.sep)[0]]}"],
                ))
                continue

            if rel in DROP_FROM_LIBRARY:
                proposals.append(Proposal(
                    src_path=str(root_path / name), rel_path=rel, folder=folder,
                    ext=ext, size_bytes=size, kind="dropped",
                    proposed_title=Path(name).stem,
                    notes=[f"dropped by request: {DROP_FROM_LIBRARY[rel]}",
                           "source file is NOT deleted"],
                ))
                continue

            proposals.append(Proposal(
                src_path=str(root_path / name), rel_path=rel, folder=folder,
                ext=ext, size_bytes=size, kind="music",
            ))

    return proposals

def analyse(prop: Proposal, do_loudness: bool, loud_cache: dict) -> None:
    path = Path(prop.src_path)
    if prop.kind != "music":
        return

    probe = ffprobe_json(path)
    audio = first_audio_stream(probe)
    fmt = probe.get("format", {})

    prop.src_codec = audio.get("codec_name", "")
    try:
        prop.src_bitrate = f"{int(fmt.get('bit_rate', 0)) // 1000}k"
    except (TypeError, ValueError):
        prop.src_bitrate = ""
    prop.src_channels = audio.get("channels")
    prop.src_sample_rate = int(audio["sample_rate"]) if audio.get("sample_rate") else None
    try:
        prop.duration_s = float(fmt.get("duration", 0)) or None
    except (TypeError, ValueError):
        prop.duration_s = None

    prop.has_art = any(
        s.get("codec_type") == "video" and s.get("disposition", {}).get("attached_pic")
        for s in probe.get("streams", [])
    ) or any(s.get("codec_type") == "video" for s in probe.get("streams", []))

    raw_tags = fmt.get("tags", {}) or {}

    prop.chapter_candidates = extract_chapter_candidates(raw_tags)
    prop.raw_tags = {
        k: (v if len(str(v)) < 300 else str(v)[:300] + "…")
        for k, v in raw_tags.items()
    }

    if prop.ext == ".mp3":
        prop.keep_format = True
        prop.notes.append("keep .mp3 as-is — no re-encode (source is already lossy)")
    elif prop.ext in VIDEO_EXT or prop.ext in {".m4a", ".aac"}:
        prop.keep_format = False
        prop.notes.append(f"transcode {prop.src_codec or 'aac'} -> opus {OPUS_BITRATE}")
    else:
        prop.keep_format = True
        prop.notes.append(f"keep {prop.ext} as-is")

    folder_top = prop.folder.split(os.sep)[0] if prop.folder else ""
    album, artist = FOLDER_ALBUMS.get(folder_top, ("", ""))
    cleaned = clean_titles.clean(
        Path(prop.src_path).stem,
        folder=prop.folder,
        folder_album=album,
        folder_artist=artist,
    )
    prop.proposed_title = cleaned.title
    prop.proposed_artist = cleaned.artist
    prop.proposed_album = cleaned.album
    prop.confidence = cleaned.confidence
    prop.notes.extend(cleaned.notes)

    raw_stem = Path(prop.src_path).stem
    if prop.rel_path in TITLE_OVERRIDES:
        if folder_top == "P3R":
            prop.proposed_artist = prop.proposed_artist or "ATLUS Sound Team"
            if not prop.proposed_album:
                prop.proposed_album = "Persona 3 Reload"
        override = TITLE_OVERRIDES[prop.rel_path]
        prop.notes.insert(0, f"title: '{raw_stem}' -> '{override}'  [override]")
        prop.proposed_title = override
        prop.confidence = "high"

    if prop.rel_path in KEEP_ORIGINAL_CASE:
        prop.proposed_title = raw_stem
        prop.confidence = "high"
        prop.notes.insert(0, f"title kept exactly as authored: '{raw_stem}'  [keep case]")

    if prop.proposed_title != raw_stem and not any(
        n.startswith("title:") or n.startswith("title kept") for n in prop.notes
    ):
        prop.notes.insert(0, f"title: '{raw_stem}' -> '{prop.proposed_title}'")

    low_tags = {k.lower(): v for k, v in prop.raw_tags.items()}
    prop.embedded_title = str(low_tags.get("title", "")).strip()
    prop.embedded_artist = str(low_tags.get("artist", "")).strip()
    prop.embedded_album = str(low_tags.get("album", "")).strip()

    if PREFER_EMBEDDED_TAGS:
        raw_tags_full = {k.lower(): v for k, v in prop.raw_tags.items()}

        emb_artist = prop.embedded_artist
        if emb_artist and not any(j in emb_artist.lower() for j in JUNK_ARTIST_PATTERNS):
            canonical = ARTIST_ALIASES.get(emb_artist.lower(), emb_artist)
            if canonical != prop.proposed_artist:
                prop.notes.append(
                    f"artist from embedded tag: '{canonical}'"
                    + (f" (filename said '{prop.proposed_artist}')" if prop.proposed_artist else "")
                )
            prop.proposed_artist = canonical
        elif emb_artist:
            prop.notes.append(f"ignored unusable embedded artist: '{emb_artist}'")

        if prop.embedded_album:
            prop.proposed_album = prop.embedded_album
            prop.notes.append(f"album from embedded tag: '{prop.embedded_album}'")

        if prop.embedded_title and prop.embedded_title != prop.proposed_title:
            prop.notes.append(f"embedded title: '{prop.embedded_title}'")

        if (
            prop.embedded_title
            and prop.rel_path not in TITLE_OVERRIDES
            and prop.rel_path not in KEEP_ORIGINAL_CASE
            and normalise_title(prop.embedded_title)
            == normalise_title(Path(prop.src_path).stem)
            and prop.embedded_title != prop.proposed_title
        ):
            from_tag = prop.embedded_title
            from_tag = clean_titles._DANGLING_SEP_RE.sub("", from_tag).strip()
            if from_tag and from_tag != prop.proposed_title:
                prop.notes.append(
                    f"title from embedded tag (punctuation/casing): "
                    f"'{prop.proposed_title}' -> '{from_tag}'"
                )
                prop.proposed_title = from_tag

                prop.confidence = "high"

    policy = FOLDER_TAG_POLICY.get(folder_top, {})

    forced_artist = policy.get("artist")
    if forced_artist and prop.proposed_artist != forced_artist:
        prop.notes.append(
            f"artist collapsed from credit list '{prop.proposed_artist}' -> '{forced_artist}'"
        )
        prop.proposed_artist = forced_artist

    forced_album = policy.get("album")
    if forced_album and prop.proposed_album != forced_album:
        prop.notes.append(
            f"album set by folder policy: '{prop.proposed_album}' -> '{forced_album}'"
        )
        prop.proposed_album = forced_album

    if re.search(r"\(\s*CV\s*[:：]", prop.proposed_artist):
        collapsed = prop.proposed_artist.split(",", 1)[0].strip()
        if collapsed and collapsed != prop.proposed_artist:
            prop.notes.append(
                f"artist credit list collapsed: '{prop.proposed_artist[:60]}…' "
                f"-> '{collapsed}'  (voice-cast list; long path)"
            )
            prop.proposed_artist = collapsed

    md = METADATA_OVERRIDES.get(prop.rel_path)
    if md:
        for field_name, value in md.items():
            setattr(prop, f"proposed_{field_name}", value)
            prop.notes.insert(0, f"{field_name} overridden to '{value}'  [manual]")
        prop.confidence = "high"

    lower = prop.proposed_title.lower()
    for hint in NON_MUSIC_HINTS:
        if re.search(hint, lower):
            prop.flags.append(f"may not be music (matched '{hint.strip(chr(92)+'b')}')")
            prop.confidence = "review"
            break

    if prop.ext in VIDEO_EXT and prop.duration_s and prop.duration_s < 45:
        prop.flags.append(f"very short ({prop.duration_s:.0f}s) — likely a clip, not a song")
        prop.confidence = "review"

    if prop.duration_s and prop.duration_s > 600:
        prop.flags.append(f"long file ({prop.duration_s / 60:.0f} min) — compilation? see chapter proposals")

    if do_loudness:
        lufs, peak = measure_loudness_cached(path, prop.rel_path, loud_cache)
        prop.measured_lufs = lufs
        prop.measured_peak_dbfs = peak
        prop.proposed_gain_db = compute_gain(lufs, peak)

    safe_title = re.sub(r'[<>:"/\\|?*]', "-", prop.proposed_title).strip()
    safe_artist = re.sub(r'[<>:"/\\|?*]', "-", prop.proposed_artist).strip()
    safe_album = re.sub(r'[<>:"/\\|?*]', "-", prop.proposed_album).strip()
    out_ext = ".opus" if not prop.keep_format else prop.ext

    parts = [p for p in (safe_artist or "Unknown Artist", safe_album) if p]
    prop.target_rel_path = os.path.join(*parts, f"{safe_title}{out_ext}")

    src, dst = f'"{prop.src_path}"', f'"{prop.target_rel_path}"'
    if prop.keep_format:
        prop.planned_command = f"copy  {src}  ->  {dst}"
    else:
        prop.planned_command = (
            f'ffmpeg -i {src} -vn -c:a libopus -b:a {OPUS_BITRATE} -map_metadata 0 {dst}'
        )

def chapter_proposals(proposals: list[Proposal]) -> list[dict]:
    """Compilations whose own tags carry a timestamped tracklist worth splitting."""
    out = []
    for prop in proposals:
        if prop.kind != "music" or not prop.chapter_candidates:
            continue
        if prop.duration_s and prop.duration_s < 600:
            continue
        out.append({
            "file": prop.rel_path,
            "duration_s": prop.duration_s,
            "chapter_count": len(prop.chapter_candidates),
            "chapters": prop.chapter_candidates,
        })
    return out

def write_report(proposals: list[Proposal], do_loudness: bool) -> Path:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    music = [p for p in proposals if p.kind == "music"]
    review = [p for p in music if p.confidence == "review"]
    solid = [p for p in music if p.confidence == "high"]
    sfx = [p for p in proposals if p.kind == "sfx"]
    junk = [p for p in proposals if p.kind == "junk" or p.kind == "unknown"]

    data = {
        "source_dir": str(SOURCE_DIR),
        "loudness_measured": do_loudness,
        "target_lufs": TARGET_LUFS,
        "summary": {
            "total_files": len(proposals),
            "music": len(music),
            "sfx_excluded": len(sfx),
            "junk_or_unknown": len(junk),
            "needs_review": len(review),
            "high_confidence": len(solid),
            "transcode": len([p for p in music if not p.keep_format]),
            "copy_as_is": len([p for p in music if p.keep_format]),
        },
        "proposals": [asdict(p) for p in proposals],
        "chapters": chapter_proposals(proposals),
    }

    json_path = REPORT_DIR / "dry_run_report.json"
    json_path.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")

    lines: list[str] = []
    add = lines.append

    add("# PersonaR — Stage 1 dry-run report")
    add("")
    add(f"Source: `{SOURCE_DIR}` (READ ONLY — nothing was modified)")
    add(f"Loudness measured: **{'yes' if do_loudness else 'no'}** (target {TARGET_LUFS:+.0f} LUFS)")
    add("")
    add("## Summary")
    add("")
    add(f"- Total files scanned: **{len(proposals)}**")
    add(f"- Music files: **{len(music)}**")
    add(f"- Excluded as SFX: **{len(sfx)}**")
    add(f"- Junk / unknown: **{len(junk)}**")
    add(f"- Will be transcoded to Opus: **{data['summary']['transcode']}**")
    add(f"- Kept in original format: **{data['summary']['copy_as_is']}**")
    add(f"- **Needs your decision: {len(review)}**")
    add("")

    if review:
        add(f"## Needs your decision ({len(review)})")
        add("")
        add("The cleaner could not be certain about these. Nothing is guessed silently.")
        add("")
        for p in review:
            add(f"### `{p.rel_path}`")
            add(f"- proposed title: **{p.proposed_title}**")
            add(f"- proposed artist: {p.proposed_artist or '_(none)_'}")
            add(f"- proposed album: {p.proposed_album or '_(none)_'}")
            if p.flags:
                for f in p.flags:
                    add(f"- ⚠ {f}")
            for n in p.notes:
                add(f"- {n}")
            add("")

    add(f"## Full inventory ({len(music)})")
    add("")
    add("```")
    add(f"{pad('SOURCE', 52)} {pad('PROPOSED TITLE', 46)} {'GAIN':>7}  ACTION")
    add("-" * 120)
    for p in sorted(music, key=lambda x: x.rel_path):
        gain = f"{p.proposed_gain_db:+.1f}dB" if p.proposed_gain_db is not None else "—"
        action = "copy" if p.keep_format else "->opus"
        add(f"{pad(p.rel_path, 52)} {pad(p.proposed_title, 46)} {gain:>7}  {action}")
    add("```")
    add("")

    if data["chapters"]:
        add("## Compilation files worth splitting")
        add("")
        add("These files are single long recordings whose own tags contain a timestamped")
        add("tracklist. They could be split into individual tracks instead of staying as one")
        add("long file. This is a proposal only.")
        add("")
        for c in data["chapters"]:
            add(f"### `{c['file']}` — {c['chapter_count']} chapters")
            add("")
            for ch in c["chapters"]:
                mins, secs = divmod(ch["start_s"], 60)
                add(f"- `{mins:02d}:{secs:02d}` {ch['title']}")
            add("")

    if sfx:
        add("## Excluded folders")
        add("")
        seen_folders = {}
        for p in sfx:
            seen_folders.setdefault(p.folder, p)
        for folder, p in seen_folders.items():
            count = len([x for x in sfx if x.folder == folder])
            add(f"- `{folder}` — {p.notes[0] if p.notes else ''} ({count} files)")
        add("")

    if junk:
        add("## Skipped")
        add("")
        for p in junk:
            add(f"- `{p.rel_path}` — {p.notes[0] if p.notes else p.kind}")
        add("")

    md_path = REPORT_DIR / "dry_run_report.md"
    md_path.write_text("\n".join(lines), encoding="utf-8")
    return md_path

def main() -> int:
    ap = argparse.ArgumentParser(description="PersonaR library builder (dry run)")
    ap.add_argument("--no-loudness", action="store_true",
                    help="skip LUFS measurement (much faster, less useful report)")
    ap.add_argument("--execute", action="store_true",
                    help="NOT IMPLEMENTED YET — dry run only in this stage")
    ap.add_argument("--source", metavar="DIR",
                    help="music folder to scan (default: auto-detected)")
    ap.add_argument("--project", metavar="DIR",
                    help="folder that holds reports/ (default: ~/Documents/PersonaR)")
    args = ap.parse_args()

    global SOURCE_DIR, PROJECT_DIR, OUT_DIR, REPORT_DIR, LOUDNESS_CACHE
    SOURCE_DIR = library_paths.source_dir(args.source)
    PROJECT_DIR = library_paths.project_dir(args.project)
    OUT_DIR = PROJECT_DIR
    REPORT_DIR = OUT_DIR / "reports"
    LOUDNESS_CACHE = REPORT_DIR / "loudness_cache.json"

    if args.execute:
        print("--execute is not implemented yet. This stage is dry-run only.", file=sys.stderr)
        return 2

    for binary in ("ffprobe", "ffmpeg"):
        if not have(binary):
            print(f"missing required binary: {binary}", file=sys.stderr)
            return 2

    if not SOURCE_DIR.is_dir():
        print(f"source dir not found: {SOURCE_DIR}", file=sys.stderr)
        return 2

    print(f"Scanning {SOURCE_DIR} ...")
    proposals = scan()
    music = [p for p in proposals if p.kind == "music"]
    print(f"  {len(proposals)} files, {len(music)} candidates")

    do_loudness = not args.no_loudness
    loud_cache = load_loudness_cache()
    cached_hits = 0
    for i, prop in enumerate(music, 1):
        before = len(loud_cache)
        analyse(prop, do_loudness, loud_cache)
        if do_loudness and len(loud_cache) == before:
            cached_hits += 1
        label = Path(prop.src_path).name
        print(f"  [{i}/{len(music)}] {label[:60]}", end="\r" if do_loudness else "\n")
    if do_loudness:
        print(" " * 80, end="\r")
        print(f"  loudness: {len(music) - cached_hits} measured now, {cached_hits} from cache")

    path = write_report(proposals, do_loudness)
    print(f"\nReport written: {path}")
    print(f"JSON:           {REPORT_DIR / 'dry_run_report.json'}")
    print("\nNothing was modified. Source folder is untouched.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
