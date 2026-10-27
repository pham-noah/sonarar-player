"""Title / artist / album cleaning rules for the PersonaR library builder.

Pure functions only: nothing here touches the filesystem or the network.
Every rule is data-driven so the vocabulary can be extended without editing logic.

Design note: every proposal carries a confidence level.
  "high"   -> a rule matched something we can prove is noise (e.g. "(Lyrics)")
  "review" -> a heuristic guess (title casing, artist splitting); Noah decides.

Nothing is ever auto-applied from a "review" proposal.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

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

NOISE_BRACKETS = {
    "no copyright music", "copyright free", "royalty free", "non copyrighted",
    "official video", "official music video", "official audio", "official mv",
    "music video", "lyrics", "lyric video", "lyrics video", "with lyrics",
    "hd", "hq", "4k", "8k", "1080p", "mv", "m/v", "audio", "full",
    "eng sub", "english sub", "engsub", "animated", "animation", "visualizer",
    "remaster", "remastered", "explicit", "color coded", "colour coded",
}

NOISE_PARENS = {
    "p3r ver.", "p3r ver", "p3r", "lyrics", "official video",
    "official music video", "official audio", "hd", "4k", "audio",
    "mv", "m/v", "lyrics video", "remaster", "remastered", "color coded",
}

KEEP_PARENS = {
    "slowed", "sped up", "slowed & reverb", "slowed and reverb", "reverb",
    "instrumental", "acoustic", "live", "remix", "opening movie version",
    "short version", "extended", "nightcore", "cover",
}

DROP_WORDS_IN_DASH_GROUP = {"reload", "p3r", "p3r ver.", "p3r ver"}

SMALL_WORDS = {
    "a", "an", "the", "and", "or", "but", "nor", "of", "in", "on", "at", "to",
    "for", "with", "by", "from", "as", "is", "it", "its", "my", "your", "no",
    "into", "over", "under", "up", "down", "out", "off",
}

_BRACKET_RE = re.compile(r"[\[\【]([^\]\】]*)[\]\】]")
_PAREN_RE = re.compile(r"[\(\（]([^\)\）]*)[\)\）]")

_DASH_GROUP_RE = re.compile(r"\s*-([^-]{1,80}?)-\s*$")
_ARTIST_SPLIT_RE = re.compile(r"\s+[-–—]\s+")
_CHANNEL_SUFFIX_RE = re.compile(r"\s+_\s+\S.*$")
_BY_ARTIST_RE = re.compile(r"^(?P<title>.+?)\s+by\s+(?P<artist>.+)$", re.IGNORECASE)
_WS_RE = re.compile(r"\s{2,}")
_DANGLING_SEP_RE = re.compile(r"^[\s\-–—_]+|[\s\-–—_]+$")

@dataclass
class CleanResult:
    """What the cleaner thinks a file is."""

    title: str
    artist: str = ""
    album: str = ""
    track_no: int | None = None

    notes: list[str] = field(default_factory=list)

    def add_note(self, note: str, downgrade: bool = False) -> None:
        self.notes.append(note)
        if downgrade:
            self.confidence = "review"

def strip_noise_brackets(text: str, result: CleanResult) -> str:
    def repl(m: re.Match) -> str:
        inner = m.group(1).strip().lower()
        if inner in NOISE_BRACKETS:
            result.add_note(f"stripped bracket [{m.group(1).strip()}]")
            return " "
        return m.group(0)

    return _BRACKET_RE.sub(repl, text)

def strip_noise_parens(text: str, result: CleanResult) -> str:
    def repl(m: re.Match) -> str:
        inner_raw = m.group(1).strip()
        inner = inner_raw.lower()
        if inner in KEEP_PARENS:
            return m.group(0)
        if inner in NOISE_PARENS:
            result.add_note(f"stripped paren ({inner_raw})")
            return " "
        return m.group(0)

    return _PAREN_RE.sub(repl, text)

def clean_trailing_dash_group(text: str, result: CleanResult) -> str:
    """Collapse '-Reload-' style version suffixes, looping until stable."""

    while True:
        m = _DASH_GROUP_RE.search(text)
        if not m:
            return text

        inner = m.group(1).strip()
        kept = inner
        removed = []
        for word in DROP_WORDS_IN_DASH_GROUP:
            pattern = re.compile(rf"(?<![A-Za-z0-9]){re.escape(word)}(?![A-Za-z0-9])", re.I)
            if pattern.search(kept):
                kept = pattern.sub("", kept)
                removed.append(word)

        kept = _WS_RE.sub(" ", kept).strip().strip("-").strip()

        if removed:
            result.add_note(f"dash group '-{inner}-' -> " + (f"'-{kept}-'" if kept else "removed"))

        if kept:
            text = text[: m.start()] + f" -{kept}- " + text[m.end() :]
        else:
            text = text[: m.start()] + " " + text[m.end() :]

        new_m = _DASH_GROUP_RE.search(text)
        if new_m and new_m.group(1).strip() == kept and removed == []:
            return text
        if not removed:
            return text

def split_artist(text: str, result: CleanResult) -> tuple[str, str]:
    """Return (artist, title). Only splits on an unambiguous single separator."""
    parts = _ARTIST_SPLIT_RE.split(text)
    if len(parts) == 2 and 0 < len(parts[0].strip()) <= 40 and len(parts[1].strip()) > 1:
        result.add_note(f"split artist from filename: '{parts[0].strip()}'", downgrade=True)
        return parts[0].strip(), parts[1].strip()
    return "", text

def apply_by_artist(title: str, result: CleanResult) -> tuple[str, str]:
    m = _BY_ARTIST_RE.match(title)
    if m:
        result.add_note(f"parsed 'by <artist>' from title: '{m.group('artist').strip()}'", downgrade=True)
        return m.group("artist").strip(), m.group("title").strip()
    return "", title

def title_case(text: str, result: CleanResult) -> str:
    """Only touches uniformly cased text. Mixed case is treated as already styled."""
    if not text:
        return text

    letters = [c for c in text if c.isalpha()]
    if not letters:
        return text
    if not (text.isupper() or text.islower()):

    was_upper = text.isupper()

    def cap_segment(seg: str) -> str:
        words = seg.split(" ")
        out = []
        for i, w in enumerate(words):
            if not w:
                out.append(w)
                continue
            last = i == len(words) - 1
            low = w.lower()
            if low in SMALL_WORDS and i != 0 and not last:
                out.append(low)
            elif low == "i":
                out.append("I")
            else:
                out.append(w[0].upper() + w[1:].lower() if w.isupper() or w.islower() else w)
        return " ".join(out)

    pieces = re.split(r"([\(\（][^\)\）]*[\)\）])", text)
    rebuilt = []
    for piece in pieces:
        if piece.startswith("(") or piece.startswith("（"):
            inner = piece[1:-1]
            if inner.strip().lower() in KEEP_PARENS:
                rebuilt.append(f"({cap_segment(inner)})")
            else:
                rebuilt.append(piece)
        else:
            rebuilt.append(cap_segment(piece))
    text = "".join(rebuilt)

    if was_upper:
        result.add_note("was ALL CAPS -> title-cased (verify styling is wanted)", downgrade=True)
    else:
        result.add_note("was all lowercase -> title-cased", downgrade=True)

    return text

def collapse_whitespace(text: str) -> str:
    text = _WS_RE.sub(" ", text)
    text = _DANGLING_SEP_RE.sub("", text)
    return text.strip()

def clean(
    filename_stem: str,
    *,
    folder: str = "",
    folder_album: str = "",
    folder_artist: str = "",
) -> CleanResult:
    """Turn a raw filename stem into a proposal.

    filename_stem: filename without extension, e.g. "Brand New Days -Reload-"
    folder:        relative folder of the source file, e.g. "P3R"
    folder_album:  album name proposed for that folder
    folder_artist: artist name proposed for that folder
    """
    result = CleanResult(title="", album=folder_album, artist=folder_artist)
    text = filename_stem

    text = strip_noise_brackets(text, result)
    text = _CHANNEL_SUFFIX_RE.sub(" ", text)
    text = strip_noise_parens(text, result)
    text = clean_trailing_dash_group(text, result)
    text = collapse_whitespace(text)

    artist, title = split_artist(text, result)
    if not artist:
        artist, title = apply_by_artist(title, result)

    if not title.strip():
        title = collapse_whitespace(filename_stem)
        result.add_note("cleaner emptied the title; fell back to raw filename", downgrade=True)

    title = title_case(title, result)
    title = collapse_whitespace(title)

    if " " not in title and title.islower() and len(title) > 6:
        result.add_note("run-together lowercase; needs a human title", downgrade=True)

    if folder and not folder_album:
        result.album = folder

    result.title = title
    if artist:
        result.artist = artist

    return result
