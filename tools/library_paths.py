"""Shared, machine-agnostic path resolution for the PersonaR tools.

The build/handoff tools used to hardcode Noah's machine into their paths:

    SOURCE_DIR = /mnt/c/Users/Noah/Music
    ADB        = .../Noah/AppData/Local/Android/Sdk/platform-tools/adb.exe

That works on one machine and is wrong the moment the scripts move to someone
else's — e.g. a friend building their own library. These helpers resolve the
same paths dynamically and NEVER require a username, so any number of people
can use the exact same copy of the tools. Resolution priority is always:

  1. an explicit CLI value, when the caller passes one  (--source / --adb / ...)
  2. an environment override:  PERSONAR_SOURCE_DIR / PERSONAR_PROJECT_DIR /
     PERSONAR_ADB
  3. the conventional location for the current user, derived from the OS —
     ``Path.home()/Music`` becomes ``C:\\Users\\<you>\\Music`` on Windows, with
     the platform filling in the name, so nobody types or hardcodes one
  4. a historical fallback (kept so nothing crashes on an unusual setup)

Every helper returns without raising and only rejects a path later, with a
clear message, so the tools keep their "refuse rather than guess" behaviour.
"""

from __future__ import annotations

import os
import shutil
from pathlib import Path

_LEGACY_SOURCE = "/mnt/c/Users/Noah/Music"
_LEGACY_PROJECT = "~/Documents/PersonaR"
_LEGACY_ADB = "/mnt/c/Users/Noah/AppData/Local/Android/Sdk/platform-tools/adb.exe"

def source_dir(explicit=None) -> Path:
    """The music folder to scan / build from (SOURCE_DIR).

    Resolution: ``--source`` > ``PERSONAR_SOURCE_DIR`` > ``~/Music`` on the
    current user's machine (Windows: ``%USERPROFILE%\\Music``, resolved by the
    OS so no username is involved) > a WSL ``/mnt/c`` fallback > legacy default.
    """
    picked = _first_set([explicit, os.environ.get("PERSONAR_SOURCE_DIR")])
    if picked is not None:
        return Path(os.path.expandvars(str(picked))).expanduser()
    for candidate in _candidate_sources():
        if candidate.is_dir():
            return candidate
    return Path(_LEGACY_SOURCE)

def project_dir(explicit=None) -> Path:
    """The shared workspace folder that ``reports/`` lives under.

    Both ``build_library.py`` and ``execute_library.py`` use this helper, so the
    half that writes the plan and the half that reads it always agree, no matter
    where the scripts were placed. Resolution: ``--project`` > ``PERSONAR_PROJECT_DIR``.
    """
    picked = _first_set([explicit, os.environ.get("PERSONAR_PROJECT_DIR")])
    if picked is not None:
        return Path(os.path.expandvars(str(picked))).expanduser()
    return Path(os.path.expandvars(_LEGACY_PROJECT)).expanduser()

def adb(explicit=None) -> str:
    """A usable adb binary.

    Resolution: ``--adb`` > ``PERSONAR_ADB`` > ``adb`` already on PATH > legacy
    fallback. Returns a string path; an explicit value is checked for existence
    by the caller.
    """
    picked = _first_set([explicit, os.environ.get("PERSONAR_ADB")])
    if picked is not None:
        return os.fspath(Path(os.path.expandvars(str(picked))).expanduser())
    found = shutil.which("adb")
    if found:
        return found

    win_default = (Path(os.path.expandvars("%LOCALAPPDATA%"))
                   / "Android" / "Sdk" / "platform-tools" / "adb.exe")
    if win_default.is_file():
        return os.fspath(win_default)
    return os.fspath(Path(_LEGACY_ADB))

def _first_set(values):
    for value in values:
        if value:
            return value
    return None

def _candidate_sources() -> list[Path]:
    """Conventional music folders, most specific first, deduplicated."""
    seen: set[str] = set()
    out: list[Path] = []

    def add(path: Path) -> None:
        path = path.expanduser()
        key = os.path.normcase(os.fspath(path))
        if path.is_dir() and key not in seen:
            seen.add(key)
            out.append(path)

    add(Path.home() / "Music")

    wsl_user = os.environ.get("USER") or os.environ.get("LOGNAME")
    if wsl_user:
        add(Path("/mnt/c/Users") / wsl_user / "Music")
    users = Path("/mnt/c/Users")
    if users.is_dir():
        for entry in sorted(users.iterdir()):
            if entry.is_dir():
                add(entry / "Music")

    add(Path(_LEGACY_SOURCE))
    return out
