# Changelog

Release notes for versions before 0.3.0 live on the [GitHub releases page](../../releases).

## 0.3.0 — 2026-11-02

### Languages

English, Tiếng Việt, 日本語, 简体中文 and Suomi. Settings → SYSTEM → INTERFACE →
Language; the sheet is built from `supportedLocales`, so a language is offered
only when its strings exist. The change applies immediately, without a restart.
590 strings, all five locales at parity, guarded by a test that fails on a
missing or unused key.

Caps and letter-spacing are script decisions rather than per-string ones
(`lib/l10n/script.dart`): caseless scripts keep their own case, and tracking
widens for scripts that read badly when set tight.

### The library starts empty

A new install has no songs, and nothing in the app implies otherwise. The
theme-gap machinery that classified albums by their catalogue number as Persona
soundtracks is gone, along with the "no tracks for this theme" message it
produced. Point the app at your own music and it fills.

### No Persona, anywhere

Identifiers, copy and assets that carried the old name are gone: `originOf`,
`fitFor`, `LibraryFit`, `kWhimsicalAlbum`, the six `persona_*.json` theme files
(now named after the skin they define), the preview rows that named real
recordings, `prefs.personaLayer` → `bondsLayer`, and the whole `personar`
namespace — seven MethodChannels and the Kotlin package, now
`com.noah.sonarar`. Saved settings from earlier versions still load: the old
`persona_layer` key and the old `persona` layout value are read, never written.

### Download errors speak the language

The download service no longer stores finished sentences. It reports a kind
(`needsAllFiles`, `cannotWrite`) or a detail string, and the screens put it into
the reader's language — the queue toast, the YouTube row, and the playlist
importer.

### Fixed

The layout preview suite writes PNGs rather than comparing them; a failed write
on a full volume is now reported as a disk error instead of a layout diff.
