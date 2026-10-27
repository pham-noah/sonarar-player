"""Verify the PORT of build_spectrum.py's maths, without numpy.

WHAT THIS PROVES AND WHAT IT CANNOT
    The Kotlin in `SpectrumBridge.kt` cannot run on this machine, so its FFT and band maths are reimplemented
    here in the SAME structure the Kotlin uses (bin-range averaging, per-band peak, 0.6 power, truncate) and
    compared byte-for-byte against a spectrum the HOST tool built from the same audio.

    A match means the port is arithmetically right. It does NOT prove Android's decoder hands back the same
    samples ffmpeg does — that is a separate claim and this script cannot make it.

    The source here is the Opus the host analysed. The downloads are m4a, so the decoder path differs on the
    device; matching on Opus still settles the maths, which is the part most likely to be wrong.
"""
import json
import math
import subprocess
import sys
from pathlib import Path

SAMPLE_RATE = 8000
FFT_SIZE = 1024
FPS = 20
EDGES = [20, 60, 120, 250, 500, 1000, 2000, 4000]

FFMPEG = "/home/noah/.hermes/tools/ffmpeg-9.0.1-linux-x64/bin/ffmpeg"
ROOT = Path("/mnt/c/Users/noah/Music/Sonarar")

def decode(path: Path):
    """Mono float32 at 8 kHz — the same thing `build_spectrum.py` asks ffmpeg for."""
    out = subprocess.run(
        [FFMPEG, "-v", "error", "-i", str(path),
         "-f", "f32le", "-ac", "1", "-ar", str(SAMPLE_RATE), "-"],
        capture_output=True, check=True).stdout
    import array
    a = array.array("f")
    a.frombytes(out)
    return a

def fft_inplace(re, im):
    """Iterative radix-2 FFT — a mirror of the Kotlin one, so the STRUCTURE matches too."""
    n = len(re)
    j = 0
    for i in range(1, n):
        bit = n >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j |= bit
        if i < j:
            re[i], re[j] = re[j], re[i]
            im[i], im[j] = im[j], im[i]
    ln = 2
    while ln <= n:
        ang = -2.0 * math.pi / ln
        w_re, w_im = math.cos(ang), math.sin(ang)
        i = 0
        while i < n:
            cur_re, cur_im = 1.0, 0.0
            for k in range(ln // 2):
                u_re, u_im = re[i + k], im[i + k]
                v_re = re[i + k + ln // 2] * cur_re - im[i + k + ln // 2] * cur_im
                v_im = re[i + k + ln // 2] * cur_im + im[i + k + ln // 2] * cur_re
                re[i + k], im[i + k] = u_re + v_re, u_im + v_im
                re[i + k + ln // 2], im[i + k + ln // 2] = u_re - v_re, u_im - v_im
                nxt = cur_re * w_re - cur_im * w_im
                cur_im = cur_re * w_im + cur_im * w_re
                cur_re = nxt
            i += ln
        ln <<= 1

def ceil_div(a, b):
    return 0 if a <= 0 else (a + b - 1) // b

def spectrum(samples):
    """The Kotlin's maths, in Python. Returns bytes."""
    n = len(samples)
    hop = SAMPLE_RATE // FPS
    window = [0.5 - 0.5 * math.cos(2 * math.pi * i / (FFT_SIZE - 1)) for i in range(FFT_SIZE)]

    bands = []
    for b in range(len(EDGES) - 1):
        k_lo = max(0, min(ceil_div(EDGES[b] * FFT_SIZE, SAMPLE_RATE), FFT_SIZE // 2))
        k_hi = max(0, min(ceil_div(EDGES[b + 1] * FFT_SIZE, SAMPLE_RATE), FFT_SIZE // 2 + 1))
        bands.append((k_lo, k_hi))

    frames = (n - FFT_SIZE) // hop + 1
    if frames <= 0:
        return b""
    out_rows = []
    for row in range(frames):
        start = row * hop
        re = [samples[start + i] * window[i] for i in range(FFT_SIZE)]
        im = [0.0] * FFT_SIZE
        fft_inplace(re, im)
        vals = []
        for (k_lo, k_hi) in bands:
            s = 0.0
            c = 0
            for k in range(k_lo, min(k_hi, FFT_SIZE // 2 + 1)):
                s += math.sqrt(re[k] * re[k] + im[k] * im[k])
                c += 1
            vals.append(0.0 if c == 0 else s / c)
        out_rows.append(vals)

    nb = len(bands)
    peaks = []
    for col in range(nb):
        m = 0.0
        for row in range(frames):
            if out_rows[row][col] > m:
                m = out_rows[row][col]
        peaks.append(1.0 if m <= 0 else m)

    buf = bytearray()
    for row in range(frames):
        for col in range(nb):
            v = (out_rows[row][col] / peaks[col]) ** 0.6
            buf.append(max(0, min(255, int(v * 255))))
    return bytes(buf)

def main():
    manifest = json.load(open(ROOT / "library_manifest.json"))
    tracks = manifest["tracks"] if isinstance(manifest, dict) else manifest
    have = {p.stem for p in (ROOT / "spectrum").glob("*.bin")}

    tried = 0
    for t in tracks:
        tid = t.get("id")
        if tid not in have:
            continue
        audio = ROOT / t["file"]
        if not audio.exists():
            continue
        expected = (ROOT / "spectrum" / f"{tid}.bin").read_bytes()
        samples = decode(audio)
        got = spectrum(samples)
        same_len = len(got) == len(expected)
        exact = got == expected if same_len else False

        near = None
        if same_len:
            near = sum(1 for a, b in zip(got, expected) if abs(a - b) <= 1)
            near_pct = 100.0 * near / len(got)
        else:
            near_pct = 0.0
        print(f"{tid}  ours={len(got)}B host={len(expected)}B "
              f"exact={exact} within1={near_pct:.2f}%")
        if same_len and not exact:
            diffs = [(i, a, b) for i, (a, b) in enumerate(zip(got, expected)) if a != b][:5]
            print(f"    first diffs (i, ours, host): {diffs}")
        tried += 1
        if tried >= 5:
            break
    if tried == 0:
        print("no tracks with both audio and a host spectrum were found")
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
