# Changelog

Release notes for versions before 0.3.0 live on the [GitHub releases page](../../releases).

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
