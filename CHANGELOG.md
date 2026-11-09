# Changelog

Release notes for versions before 0.3.0 live on the [GitHub releases page](../../releases).

## 0.3.7 — 2026-11-09

### Fixed

- **A half-written library cannot freeze the app any more.** A truncated or wrong-typed
  `library_manifest.json` used to throw out of the library read, and the boot sequence that
  called it was not guarded, so the app sat on "reading your library" forever. The manifest
  reader now skips what it cannot understand (first duplicate id wins), the repository treats
  an unreadable manifest as an empty library, and the boot sequence catches any step that
  fails and still shows the shell.
- **The same tolerance for the files read at launch.** A `"loop_count": "3"` in
  `loop_points.json` or a `"completion_points": "6"` in `bonds.json` threw at boot; both read
  as defaults now. Lyrics survive a row whose fields are not strings, a cache entry whose
  values are not numbers, and a timestamp like `[1e308:00]` (refused instead of overflowing);
  a cached lyric file is written inside `lyrics/` even when the track id is a path.
- **The update check offers the right digest.** When a release published a digest for more
  than one APK, the first one was used for whichever build was offered, so the other build
  deleted its own download and never updated. The digest is now taken from the offered
  asset's line (or its `full`/`lite` line), and an ambiguous body verifies on size alone
  rather than against another file's hash. Prerelease tags are no longer auto-installed.
- **Ids and paths are unique and contained.** The queue dedupes on construction, on
  `replaceSource` and on every insert; a manifest cannot name a file outside the library
  folder; a playlist no longer keeps empty track ids; a negative duration reads as unknown.
- The README's install line names the build it actually ships.

### Verified

- `flutter analyze`: 0 issues. `flutter test`: 2,130 passed, 4 skipped, 0 failed —
  including 159 adversarial probes (`flutter test --tags adversarial`) over hostile
  manifests, queues, caches, prefs, playlists, release documents and layouts at 2× text.
- The boot harness now really boots: every test in `shell_harness_test.dart` reaches
  `boot 100% ready` and the loaded-state assertion checks the splash is gone.

## 0.3.6 — 2026-11-06

### Fixed

- **The engine install no longer deletes itself.** The download arrived, matched its
  checksum and unpacked — and then the library threw "Failed to initialize" and took it
  away again. The staleness marker ytdl-android checks is not a version string: it is
  the byte length of `libpython.zip.so` in the APK's native lib directory, and a lite
  build removes that archive to stay small, so the marker read `0`. Writing our own
  archive's length made every lite install look stale; the library deleted the payload
  just unpacked and tried to unzip a file that was not in the APK. The marker now
  records what the library will actually see, so it keeps the payload we installed.

  This was arm64-only because arm64 is the ABI the lite build strips the archive from —
  on x86_64 the bundled archive happened to make the marker line up.

### Verified

- Reproduced on an x86_64 emulator by removing the bundled archive from the build, so
  it had the phone's exact shape (0 archives in the APK): launch logged
  `engine not bundled (failed to initialize)`, the tap downloaded and installed
  (`engine installed from libpython.zip.so (14302766 bytes); library marker 0`), and
  `yt-dlp update: DONE` followed — the engine running.
- `flutter analyze`: 0 issues. `flutter test`: 1,971 passed, 0 failed.


## 0.3.5 — 2026-11-06

### Fixed

- **Panel text survives a bright cover.** In Glass the sheet's fill is a white wash at
  20%, and a wash only reads while the room under it is dark — so over a bright album
  cover the sheet went pale and the near-white text disappeared into it. The sheet now
  carries the room's own colour under the wash, held almost solid, which is the same
  colour on any backdrop. Both glass skins are tested for AA text against it.
- **The engine fetch retries a short read** before giving up. A reset connection hands
  back half an archive; the checksum is the only thing that notices, and "the fetch
  failed" is a poor answer to a carrier hiccup. `EngineLoader` re-reads once.
- **A failed engine install says which stage failed.** `DownloadManager.engineFailure`
  records one of: no archive for the ABI, a checksum mismatch, a cut-short download, an
  archive that would not install, or the plugin's own `engineError` — and the search
  banner prints it under the sentence, so a report of "it didn't work" carries the
  reason with it.
- **An old engine payload that cannot be deleted no longer blocks the install.** The
  plugin used to abort; it now unpacks over it.
- The download buffer is filled once instead of copied on every chunk — 14 MB collected
  in 64 KB pieces was gigabytes of copying that read as a hang.

### Verified

- `flutter analyze`: 0 issues. `flutter test`: 1,971 passed, 0 failed.
- On an x86_64 emulator the whole fetch path works: the tap downloads the 14,302,766-
  byte archive, matches its pinned sha256, and unpacks it (`engine installed from
  libpython.zip.so`). Whatever fails on arm64 now names its stage on screen.


## 0.3.4 — 2026-11-06

### Fixed

- **Glass panels read like panels again.** The queue was the odd one out: it painted the
  room's background over the frosted sheet, so it was a flat black box under a grey
  header, and its rows were black cards on glass. The sheet is the surface now, and the
  rows sit on it the way This Track and Audio always did. Panels also hold more of their
  own colour, so text no longer competes with the player moving underneath.
- **"Clear upcoming" is just "Clear".** It sits under a header that already says UP NEXT,
  on the only screen it appears. The other five languages lose the same redundancy.

### Changed

- **Queue edits stopped redrawing the app.** A reorder, a removal, a shuffle or a repeat
  change now repaints the queue and the player only, instead of rebuilding the whole
  shell — the shell had been compensating by hand with its own `setState` after every
  shuffle, which is what a missing distinction looks like.

### Under the hood

The five refactors from the 0.4 plan, each with its own tests:

- `PlayQueue` keeps one list of tracks instead of a play order and a shadow source list
  edited in parallel, so a track cannot be in one and missing from the other. Clearing
  what is up next is final now; a play-next survives a shuffle toggle.
- `AppPrefs` states each key once — default, decoder, range, old name — and `fromJson`
  and `copyWith` resolve through the same table, so a value cannot be clamped on one
  path and not the other.
- The transport's five booleans are one state with four phases, and each flag's reason
  is written down where it is now enforced.
- `AppState`'s bonds and context domains are objects that derive what they can, the
  context's rules from the places they come from.
- `main._load()` is a list of named boot steps, with the phase log generated rather than
  printed by hand.

### Verified on an emulator

A debug x86_64 build, Glass: the boot log still prints the same seven phases with their
timings; shuffle from the mini player and repeat from the player repaint from the queue
notifier alone; removing a queue row closes the list up, UNDO restores it to the same
slot, and a skip moves the title, the up-next line and the queue badge.


## 0.3.3 — 2026-11-05

### Changed

- **The APK is 15 MB instead of 62.** 36 MB of it was ffmpeg for a step the downloads
  never ran, and 14 MB was a CPython runtime for yt-dlp. ffmpeg is gone (the download
  path asks for one audio stream and keeps its container), and the interpreter is
  fetched **once, on the first download** — after which this build behaves exactly like
  the old 62 MB one. One APK for everyone; no lite/full split to choose between.
- **The engine archive matches the device.** arm64 and x86_64 archives are published
  and picked by ABI, so x86 tablets, Chromebooks and emulators work too.

### Fixed

- **Downloads could not run at all in a build without the bundled engine**, and the
  install path had a bug that only appears on a real download: `ZipInputStream` writes
  a symlink as a text file, so the interpreter's `libz.so.1` became 13 bytes and Python
  died with `zlib not available`. Installs recreate symlinks now.
- **Persona's first-run colour chips stored a preference that layout never read** —
  pressing CRIMSON moved the selection and left every accent cyan. Persona writes
  `skinId`; Solid and Glass keep their palette index.
- **An update would have reinstalled the engine a lite user avoided**: the release now
  offers the asset matching the build that asked.

### Verified on a device

A fresh install of this APK on an x86_64 emulator: search rows offer "Set up downloads",
one tap installs the engine, the rows become download controls, and a track lands on
disk (6 MB webm + cover + manifest entry) with ffmpeg absent throughout.

## 0.3.2 — 2026-11-04

### Added

- **A real update screen.** The offer used to be a strip you tapped, which downloaded
  immediately and threw the file at the system installer — no notes, no size, no
  progress worth watching, and nothing to say when a download failed. It is now a
  sheet: what version is out, what changed in it, how big it is, then Download with a
  progress bar, then **Install**. Settings → CHECK FOR UPDATES NOW opens the same
  sheet, so both entry points answer the same way.
- **Release notes reach the app.** The check always fetched the release body and then
  dropped it on the floor; it is shown now, trimmed to a readable slice.

### Changed

- **The update strip is on every layout.** It was mounted only in the docked shell
  frame, so Solid and Glass — which float their bars — showed no offer *and never ran
  the automatic check at all*, because the check lived inside that widget.
- **The first run picks its colours for real.** The colour chips were drawn with an
  empty tap handler and a selection pinned to the first palette, and there was nowhere
  to store the choice anyway: the layout was applied with a palette index of 0 on every
  preference change. The palette is a preference now and survives.

### Fixed

- **A queue edit no longer stops the music for a moment.** Changing the queue (add,
  remove, reorder, play next) reloaded the whole engine queue — handing just_audio a
  brand new source, which tears the platform player down. The queue is edited in place
  now: only the entries that actually changed are inserted, removed or moved.
- **A queue change that leaves the track alone no longer rewinds it.** When the engine
  already held the same queue, the loader seeked the playing track to zero and back to
  its position, which sounded like the same stutter from a different line.
- **The first run wears the layout you picked.** The screen was built outside the
  presentation scope, so the START button kept the old palette's accent while the
  background followed.
- **The retitled library cannot go stale.** The tag overrides, the library as the disk
  reports it, and the retitled copy were three fields kept in sync by hand; one missed
  call and the app painted yesterday's titles.

### Internal

- The diagnostics log now receives everything the app logs. It only hooked
  `debugPrint`, while 45 call sites used `print` — every audio load failure and boot
  timing went to logcat and never into the log the diagnostics screen reads.
- Twelve swallowed exceptions now report what failed instead of vanishing, including
  every state write, which used to fail silently.
- One `AutoAdvance` enum instead of two identical ones.
- Playback, loading, the engine window, the ticker, the fade and the interruption rules
  were lifted out of the widget and are covered by unit tests that need neither a
  device nor an audio stack: 1,785 of them, up from 1,759.
- CI: analyze and the full suite run on every push and pull request.

## 0.3.1 — 2026-11-02

### Changed

- **The check row is named for what it does** — "CHECK FOR UPDATES NOW", in all five
  languages. It sat directly under the CHECK FOR UPDATES switch with a label that did
  not say which of the two ran a check.

## 0.3.0 — 2026-11-02

### Added

- **Five languages** — English, Tiếng Việt, Suomi, 简体中文 and 日本語. Chosen in
  Settings → SYSTEM → INTERFACE → Language, or followed from the phone. The change
  applies immediately, without a restart.
- **Per-script typography** — capitals and letter-spacing follow the script being
  drawn. Japanese, Chinese, Korean and Thai are neither upper-cased nor tracked.
- **Every screen speaks** — 590 strings across the five locales: toasts, the deep
  panels, rule explanations, places and weather, history, the compendium, library,
  player, queue, imports, YouTube search, diagnostics and first run.
- **Download errors** say which problem it is — a missing all-files grant, or a
  folder that cannot be written — in the reader's language, in the queue toast, on
  the YouTube row and in the playlist importer.

### Changed

- **The library starts empty.** A new install holds no songs, and nothing in the
  app reads as though music is missing.
- **The playlist importer's status line** is one localized summary of added,
  skipped and failed counts instead of an English sentence.

### Fixed

- **The update check compared the wrong version.** The build reported 0.2.5 while
  the package said 0.3.0, so a newer build could look like the one already
  installed.
- **The title normaliser cut short tokens out of track titles** — any title
  containing a bare alphanumeric suffix such as "P5" lost it before matching
  duplicates.
- **A failed preview write no longer reads as a layout change.** The preview suite
  writes images instead of comparing them, and a full disk is now reported as a
  disk error.
