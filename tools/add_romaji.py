"""Add a romaji reading to every manifest entry that needs one.

WHY THIS EXISTS SEPARATELY. The library builder (`tools/build_library.py`) is not
in this repository — the README says so plainly — so the reading cannot be added
where the manifest is written. It is added here, to the manifest that exists,
because a missing builder must not mean the feature cannot be built.

WHAT IT DOES. The app's search is a plain substring test against
`title + artist + album + file`. 106 of the 279 tracks carry Japanese script in
the title, and the manifest holds NO reading for any of them — so searching
"kioku" or "tenshi" could never match, because there was nothing to match
against. This writes a `romaji` field holding the hepburn reading of the title,
artist and album, and the app folds it into the search blob.

KANJI IS THE WHOLE POINT. Kana is a table lookup; kanji needs a READING, and no
table gives you 記憶 -> kioku. pykakasi supplies it, which is why it is a
dependency rather than a hand-written mapping.

IT IS DELIBERATELY SEPARATE FROM THE FILE PATH. `file` is not transliterated: the
path is what is on disk and is not searched as text in practice, and rewriting it
would produce a reading that matches nothing the app opens.

IDEMPOTENT AND SAFE. Running it twice changes nothing the second time; a track
that already has a `romaji` is left alone unless --force. It writes through a
temporary file and renames, so an interrupted run cannot leave a half-written
manifest that the app would fail to parse.

Usage:
    python3 tools/add_romaji.py            # dry run, reports what it would do
    python3 tools/add_romaji.py --write    # actually write the manifest
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile

MANIFEST = os.path.join("app_src", "assets", "library", "library_manifest.json")

NON_LATIN = re.compile(r"[^\x00-\x7F\u00C0-\u024F]")

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
def needs_romaji(*fields: str) -> bool:
    """True when any field carries something a latin search box cannot type."""
    return any(f and NON_LATIN.search(f) for f in fields)

def make_converter():
    """The kakasi converter, or a clear failure.

    A missing dependency is reported as itself. The alternative — silently
    writing empty readings — would produce a manifest that looks processed and
    searches no better than before, which is the worst possible outcome for a
    fix whose entire purpose is searchability.
    """
    try:
        import pykakasi
    except ImportError:
        sys.exit(
            "pykakasi is not installed, and it is what supplies the kanji "
            "readings this needs.\n  python3 -m pip install pykakasi"
        )
    return pykakasi.kakasi()

def reading(kakasi, text: str) -> str:
    """The hepburn reading, lowercased, in a form a search box can match.

    The separators are stripped because they are not what anyone types: a
    reading of "sorezore no kako" would fail a search for "sorezorenokako" if the
    spaces were kept, and the app's search is a plain substring test — it has no
    notion of word boundaries to fall back on.
    """
    if not text:
        return ""
    converted = "".join(item["hepburn"] for item in kakasi.convert(text))

    cleaned = re.sub(r"[\s\u3000・\-–—]+", "", converted.lower())
    return cleaned

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true",
                        help="write the manifest (default is a dry run)")
    parser.add_argument("--force", action="store_true",
                        help="recompute romaji even where one is already present")
    parser.add_argument("--path", default=MANIFEST,
                        help=f"manifest to read (default {MANIFEST})")
    args = parser.parse_args()

    if not os.path.exists(args.path):
        sys.exit(f"no manifest at {args.path}")

    with open(args.path, encoding="utf-8") as fh:
        doc = json.load(fh)

    tracks = doc.get("tracks") if isinstance(doc, dict) else None
    if not tracks:
        sys.exit(f"manifest at {args.path} carries no tracks")

    kakasi = make_converter()

    added = 0
    kept = 0
    skipped = 0
    samples: list[tuple[str, str]] = []

    for track in tracks:
        title = track.get("title") or ""
        artist = track.get("artist") or ""
        album = track.get("album") or ""

        if not needs_romaji(title, artist, album):

            skipped += 1
            continue

        if track.get("romaji") and not args.force:
            kept += 1
            continue

        parts = [reading(kakasi, title), reading(kakasi, artist), reading(kakasi, album)]
        value = " ".join(p for p in parts if p)
        track["romaji"] = value
        added += 1
        if len(samples) < 8:
            samples.append((title, value))

    if isinstance(doc, dict):
        doc["track_count"] = len(tracks)

    for title, value in samples:
        print(f"  {title}\n    -> {value}")

    print(
        f"\n{len(tracks)} tracks: {added} given a reading, {kept} already had one, "
        f"{skipped} needed none"
    )

    if not args.write:
        print("\ndry run — nothing written. Re-run with --write to apply.")
        return 0

    directory = os.path.dirname(os.path.abspath(args.path))
    fd, tmp = tempfile.mkstemp(dir=directory, suffix=".json.tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(doc, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
        os.replace(tmp, args.path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise

    print(f"wrote {args.path}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
