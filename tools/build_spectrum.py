"""Build a spectrum file per track, for the player's visualiser.

WHY THIS EXISTS, AND WHY IT IS NOT DONE ON THE PHONE
    A visualiser that reacts to the ACTUAL music needs the audio signal, and the app's player
    (`just_audio`) does not hand it out — Android's Visualizer API needs RECORD_AUDIO and is blocked
    for apps that are not the active media session, and it does not exist on Windows at all.

    The library is OURS, though. So the spectrum is computed HERE, once, and shipped beside the audio.
    Measured on a real track: a 175s Opus decodes in 0.72s and its FFT takes 0.08s — 2200x realtime —
    and the result is about 10 KB per track, so the whole library is a few MB.

    That makes this a real analyser rather than a decorative animation: every bar is the actual
    frequency content of the actual song, and it works identically on Android and Windows with no
    plugin, no permission and no native code.

FORMAT
    One byte per band, 0-255, `frames_per_second` frames a second, mono PCM decimated to 8 kHz before
    the transform. Raw bytes rather than JSON or PNG: it is read once per track in Dart, a 10 KB file
    of bytes needs no parser, and 8-bit is enough for a bar height.

    <library>/spectrum/<id>.bin

    The bands are LOG-spaced, because a linear split puts almost every bar in the bass — that is the
    difference between a spectrum that looks like the song and one that looks like a metronome.

WHAT IT DOES NOT DO
    No loudness normalisation against other tracks. Bars that peak at a different point per track is
    the honest reading of a library with genuinely different masters, and normalising would make a
    quiet track look as loud as a loud one.

USAGE
    python3 tools/build_spectrum.py                     # everything missing or stale
    python3 tools/build_spectrum.py --check             # report only, build nothing
    python3 tools/build_spectrum.py --force             # rebuild all
    python3 tools/build_spectrum.py --source /path/Music # a specific library

    Needs Python, numpy and ffmpeg (on PATH). Paths resolve dynamically via
    library_paths.py — the library analysed is <source>/PersonaR, so the same
    copy works on any machine, no usernames involved."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import library_paths  # noqa: E402

import numpy as np

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

SAMPLE_RATE = 8_000
FFT_SIZE = 1024

FRAMES_PER_SECOND = 20

BAND_EDGES = [20, 60, 120, 250, 500, 1_000, 2_000, 4_000]

def ffmpeg_path() -> str:
    """ffmpeg from wherever this machine keeps it."""
    for candidate in (
        "/home/noah/.hermes/tools/ffmpeg-9.0.1-linux-x64/bin/ffmpeg",
        "ffmpeg",
    ):
        try:
            subprocess.run(
                [candidate, "-version"],
                capture_output=True,
                check=True,
            )
            return candidate
        except (OSError, subprocess.CalledProcessError):
            continue
    raise SystemExit("ffmpeg not found — needed to decode Opus")

def decode(path: Path, ffmpeg: str) -> np.ndarray:
    """The file as mono float32 at SAMPLE_RATE."""
    out = subprocess.run(
        [
            ffmpeg, "-v", "error",
            "-i", str(path),
            "-ac", "1",
            "-ar", str(SAMPLE_RATE),
            "-f", "f32le",
            "-",
        ],
        capture_output=True,
        check=True,
    )
    return np.frombuffer(out.stdout, dtype="<f4").astype(np.float32)

def spectrum(samples: np.ndarray) -> bytes:
    """One byte per band per frame, 0-255."""
    hop = SAMPLE_RATE // FRAMES_PER_SECOND
    if len(samples) < FFT_SIZE:
        return b""

    window = np.hanning(FFT_SIZE).astype(np.float32)
    freqs = np.fft.rfftfreq(FFT_SIZE, 1 / SAMPLE_RATE)
    masks = [
        (freqs >= lo) & (freqs < hi) for lo, hi in zip(BAND_EDGES, BAND_EDGES[1:])
    ]

    frames = np.empty((len(range(0, len(samples) - FFT_SIZE, hop)), len(masks)), dtype=np.float32)
    for row, i in enumerate(range(0, len(samples) - FFT_SIZE, hop)):
        mag = np.abs(np.fft.rfft(samples[i:i + FFT_SIZE] * window))
        for col, mask in enumerate(masks):
            frames[row, col] = mag[mask].mean() if mask.any() else 0.0

    peak = frames.max(axis=0)
    peak[peak <= 0] = 1.0
    normalised = np.power(frames / peak, 0.6)
    return np.clip(normalised * 255, 0, 255).astype(np.uint8).tobytes()

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="report only")
    parser.add_argument("--force", action="store_true", help="rebuild everything")
    parser.add_argument("--source", metavar="DIR",
                        help="music folder whose PersonaR library to analyse "
                             "(default: auto-detected)")
    args = parser.parse_args()

    library = library_paths.source_dir(args.source) / "Sonarar"
    manifest_path = library / "library_manifest.json"

    if not manifest_path.exists():
        print(f"no manifest at {manifest_path}", file=sys.stderr)
        return 1

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    tracks = manifest["tracks"] if isinstance(manifest, dict) else manifest

    out_dir = library / "spectrum"
    out_dir.mkdir(exist_ok=True)

    ffmpeg = ffmpeg_path()
    built = skipped = failed = 0

    for track in tracks:
        src = library / track["file"]
        dst = out_dir / f"{track['id']}.bin"

        if not args.force and dst.exists():

            skipped += 1
            continue

        if not src.exists():
            print(f"  missing audio: {track['file']}", file=sys.stderr)
            failed += 1
            continue

        if args.check:
            print(f"  would build {track['id']}  ({track['title']})")
            built += 1
            continue

        try:
            data = spectrum(decode(src, ffmpeg))
        except subprocess.CalledProcessError as e:
            print(f"  decode failed: {track['file']}: {e}", file=sys.stderr)
            failed += 1
            continue

        if not data:
            print(f"  too short: {track['file']}", file=sys.stderr)
            failed += 1
            continue

        dst.write_bytes(data)
        built += 1

    verb = "would build" if args.check else "built"
    print(f"{verb} {built}, {skipped} already present, {failed} failed")
    if not args.check and built:
        total = sum(f.stat().st_size for f in out_dir.glob("*.bin"))
        print(f"spectrum dir: {total / 1_048_576:.1f} MB, {len(list(out_dir.glob('*.bin')))} files")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
