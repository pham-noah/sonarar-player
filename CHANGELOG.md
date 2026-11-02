# Changelog

Release notes for versions before 0.3.0 live on the [GitHub releases page](../../releases).

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
