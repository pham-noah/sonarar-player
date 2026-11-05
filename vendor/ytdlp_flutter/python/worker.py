"""yt-dlp job worker for ytdlp_flutter (iOS embedded CPython).

Serves jobs over a file protocol rooted at $YTDLP_WORKER_DIR:

  jobs/<id>.json          job request (written atomically by Dart)
  out/<id>.progress.json  progress snapshots (written by this worker)
  out/<id>.result.json    terminal result (written by this worker)
  out/<id>.cancel         cancel flag (written by Dart)
  out/worker.alive        heartbeat (touched by this loop)

Jobs:
  {"id": str, "op": "info",     "url": str}
  {"id": str, "op": "download", "url": str, "output_dir": str,
   "format": str}

yt-dlp itself is imported from the zipapp at $YTDLP_PYZ (bundled with the
app; stdlib-only otherwise). No FFmpeg exists on iOS, so download jobs must
use single-stream format selectors (the default bestaudio/best is fine).
"""

import json
import os
import sys
import time
import traceback

ROOT = os.environ["YTDLP_WORKER_DIR"]
JOBS = os.path.join(ROOT, "jobs")
OUT = os.path.join(ROOT, "out")
os.makedirs(JOBS, exist_ok=True)
os.makedirs(OUT, exist_ok=True)

_pyz = os.environ.get("YTDLP_PYZ")
if _pyz and _pyz not in sys.path:
    sys.path.insert(0, _pyz)

import yt_dlp  # noqa: E402


class Cancelled(Exception):
    pass


def _write_json(path, obj):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(obj, f)
    os.replace(tmp, path)  # atomic: readers never see a partial file


def _touch_alive():
    _write_json(os.path.join(OUT, "worker.alive"), {"t": time.time()})


def _info_subset(info):
    return {
        "id": info.get("id"),
        "title": info.get("title"),
        "duration": info.get("duration"),
        "uploader": info.get("uploader"),
        "thumbnail": info.get("thumbnail"),
        "webpage_url": info.get("webpage_url"),
        "ext": info.get("ext"),
    }


def _base_opts():
    return {
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        # iOS bundles no ffmpeg; never attempt merges or post-processing.
        "prefer_ffmpeg": False,
    }


def handle_info(job):
    with yt_dlp.YoutubeDL(_base_opts()) as ydl:
        info = ydl.extract_info(job["url"], download=False)
        return _info_subset(ydl.sanitize_info(info))


def handle_download(job):
    job_id = job["id"]
    cancel_flag = os.path.join(OUT, job_id + ".cancel")
    progress_path = os.path.join(OUT, job_id + ".progress.json")
    last_write = [0.0]

    def hook(d):
        if os.path.exists(cancel_flag):
            raise Cancelled()
        if d.get("status") != "downloading":
            return
        now = time.time()
        if now - last_write[0] < 0.25:  # throttle disk writes
            return
        last_write[0] = now
        _write_json(progress_path, {
            "downloaded": d.get("downloaded_bytes"),
            "total": d.get("total_bytes") or d.get("total_bytes_estimate"),
            "eta": d.get("eta"),
        })

    opts = _base_opts()
    opts.update({
        "format": job.get("format", "bestaudio/best"),
        "outtmpl": os.path.join(job["output_dir"], "%(id)s.%(ext)s"),
        "progress_hooks": [hook],
    })
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(job["url"], download=True)
        info = ydl.sanitize_info(info)
        filepath = None
        downloads = info.get("requested_downloads") or []
        if downloads:
            filepath = downloads[0].get("filepath")
        if not filepath:
            filepath = ydl.prepare_filename(info)
        result = _info_subset(info)
        result["filepath"] = filepath
        return result


def process(job):
    job_id = job.get("id", "unknown")
    result_path = os.path.join(OUT, job_id + ".result.json")
    cancel_flag = os.path.join(OUT, job_id + ".cancel")
    try:
        if job["op"] == "info":
            data = handle_info(job)
        elif job["op"] == "download":
            data = handle_download(job)
        else:
            raise ValueError("unknown op: %r" % job.get("op"))
        _write_json(result_path, {"ok": True, "data": data})
    except Cancelled:
        _write_json(result_path,
                    {"ok": False, "cancelled": True, "error": "cancelled"})
    except Exception as e:  # noqa: BLE001 — every failure must reach Dart
        _write_json(result_path, {
            "ok": False,
            "error": str(e),
            "trace": traceback.format_exc(),
        })
    finally:
        if os.path.exists(cancel_flag):
            os.remove(cancel_flag)


def main():
    _touch_alive()
    last_alive = time.time()
    while True:
        now = time.time()
        if now - last_alive > 2:
            last_alive = now
            _touch_alive()
        for name in sorted(os.listdir(JOBS)):
            if not name.endswith(".json"):
                continue
            path = os.path.join(JOBS, name)
            try:
                with open(path) as f:
                    job = json.load(f)
            except (OSError, ValueError):
                continue  # mid-rename or malformed; retry next tick
            os.remove(path)
            process(job)
        time.sleep(0.2)


if __name__ == "__main__":
    main()
