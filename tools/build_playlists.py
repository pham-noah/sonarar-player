"""Generate the seed playlists the app ships with.

WHY A GENERATOR AND NOT A HAND-WRITTEN FILE
    A playlist is a list of track ids. Those ids are hashes, so a file typed by
    hand would be unreadable and would silently rot the moment the library is
    rebuilt. Generating it from the manifest means the seed is always correct for
    the library it ships with, and the RULE that picked the tracks is written down
    rather than implied by a wall of hex.

WHAT IT MAKES
    assets/config/playlists.json — the seed. The app copies it out to its writable
    state folder on first run and reads that copy from then on, so shipping a new
    seed never clobbers playlists the user has edited.

THE RULES, STATED PLAINLY
    A playlist is selected by the track's ALBUM, or — for library folders that
    are a curated mix rather than one album — by the track's SOURCE FOLDER.

        P3R                  album names Persona 3, P3D, or is a P3 track listed
                             by hand below (one exception, see P3_BY_TITLE)
        P4R                  album names Persona 4
        P5R                  album names Persona 5
        Weathering With You  album names Weathering With You (a film score —
                             the one playlist here that is not a game)
        US UK / VPOP / KPOP  source folder is that folder. These are download
                             folders: each holds many real albums from many
                             artists, so album markers cannot select them — the
                             folder is the only thing that ties the tracks
                             together. Add one row to PLAYLISTS per folder.

    Album is preferred over artist for the game OSTs because the same artists
    (ATLUS Sound Team, RADWIMPS) appear across several of them and the album is
    what says which game a track is from.

    ONE DELIBERATE EXCEPTION, listed by hand below rather than papered over with a
    looser rule: "Living With Determination -巌戸台分寮アレンジ" is filed under an
    album called "Gemini", which is not a Persona album at all — but 巌戸台分寮 is
    Iwatodai Dorm and the track is Persona 3. Loosening the rule to catch it would
    also drag in the genuinely non-Persona tracks, so it is named explicitly.

    ORDER: the manifest's own order, which is artist/album/path — stable, and the
    same every run, so re-generating does not churn the file.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "app_src", "assets", "library", "library_manifest.json")
OUT = os.path.join(ROOT, "app_src", "assets", "config", "playlists.json")

P3_BY_TITLE = {
    "Living With Determination -巌戸台分寮アレンジ",
}

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
PLAYLISTS = [
    ("p3r", "P3R", ("persona 3", "persona3", "p3d"), P3_BY_TITLE, ()),
    ("p4r", "P4R", ("persona 4", "persona4", "p4d"), set(), ()),
    ("p5r", "P5R", ("persona 5", "persona5"), set(), ()),
    ("weathering", "Weathering With You", ("weathering with you",), set(), ()),
    ("us_uk", "US UK", (), set(), ("US UK",)),
    ("vpop", "VPOP", (), set(), ("VPOP",)),
    ("kpop", "KPOP", (), set(), ("KPOP",)),
    ("jpop", "JPOP", (), set(), ("JPOP",)),
]

def source_folder(track) -> str:
    """Top folder of the track's original rip, e.g. 'US UK' from
    'US UK/Payphone.mp4'. Empty when the manifest has no source path."""
    src = (track.get("source") or "").replace("\\", "/")
    return src.split("/", 1)[0].strip() if src else ""

def matches(track, markers, by_title, folders) -> bool:
    title = (track.get("title") or "").strip()
    if title in by_title:
        return True
    if folders and source_folder(track) in folders:
        return True
    album = (track.get("album") or "").lower()
    return any(m in album for m in markers)

def main() -> int:
    if not os.path.isfile(MANIFEST):
        print(f"no manifest at {MANIFEST}", file=sys.stderr)
        return 1

    with open(MANIFEST, encoding="utf-8") as fh:
        data = json.load(fh)
    tracks = data if isinstance(data, list) else data.get("tracks", data)
    if not tracks:
        print("manifest has no tracks", file=sys.stderr)
        return 1

    out = []
    matched_ids = set()
    for pid, name, markers, by_title, folders in PLAYLISTS:
        hits = [t for t in tracks if matches(t, markers, by_title, folders)]
        if not hits:

            print(
                f"{name}: the rule matched nothing — refusing to write it",
                file=sys.stderr,
            )
            return 1
        for t in hits:
            matched_ids.add(t["id"])
        out.append({"id": pid, "name": name, "track_ids": [t["id"] for t in hits]})

    generated_ids = {pl["id"] for pl in out}
    preserved = []
    if os.path.isfile(OUT):
        try:
            with open(OUT, encoding="utf-8") as fh:
                prev = json.load(fh).get("playlists", [])
            for pl in prev:
                if pl.get("id") not in generated_ids:
                    preserved.append(pl)
        except (json.JSONDecodeError, OSError):
            print("existing seed unreadable — writing game/source lists only",
                  file=sys.stderr)
    out.extend(preserved)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump({"playlists": out}, fh, ensure_ascii=False, indent=2)
        fh.write("\n")

    print(f"{len(tracks)} tracks in the manifest -> {os.path.relpath(OUT, ROOT)}")
    for pl in out:
        print(f"  {pl['name']}: {len(pl['track_ids'])} tracks")
    if preserved:
        print(f"preserved (not generated here): "
              + ", ".join(pl["name"] for pl in preserved))

    skipped = [t for t in tracks if t["id"] not in matched_ids]
    print(f"in no playlist: {len(skipped)}")
    for t in skipped:
        print(f"  {t.get('artist')} | {t.get('album')!r} | {t.get('title')}")

    claims = {}
    for pl in out:
        for tid in pl["track_ids"]:
            claims.setdefault(tid, []).append(pl["name"])
    shared = {tid: names for tid, names in claims.items() if len(names) > 1}
    if shared:
        print(f"in MORE THAN ONE playlist: {len(shared)}")
        for tid, names in shared.items():
            print(f"  {' + '.join(names)} | {tid}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
