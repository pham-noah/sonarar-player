# Sonarar — adversarial QA pass

**Date:** 2026-11-09 · **Build:** `0.3.6+36` (working tree, `9a99bc1`) · **Flutter:** 3.47.6 / Dart 3.13.5
**Probe suite:** `app_src/test/adversarial/` — 159 tests, tag `adversarial`
**First pass:** 135 passed · **21 failed (real defects)**
**After the fix pass:** 159/159 green; full suite **2,130 passed, 4 skipped, 0 failed**;
`flutter analyze --fatal-infos`: 0 issues. Every finding is fixed — see *Fixes*.

Run only the probes:

```bash
cd app_src
flutter test --tags adversarial
```

## Baseline (before the probes)

| Check | Result |
|---|---|
| `flutter analyze --fatal-infos` | 0 issues (also 0 after adding the probes) |
| `flutter test` (existing suite) | **1,971 passed, 4 skipped, 0 failed** |
| `flutter build apk --debug --target-platform android-x64` | builds (`build/app/outputs/flutter-apk/app-debug.apk`) |
| On-device run | **blocked** — the x86_64 AVD cannot start on this host: *"x86_64 emulation currently requires hardware acceleration … hypervisor driver is not installed"*. No arm64 device attached. |

## Findings

### S1 — a half-written `library_manifest.json` bricks the boot

`LibraryRepository.load()` catches only `FileSystemException`
(`lib/library/library_repository.dart:62-73`). `Track.listFromManifest()` lets `FormatException`
(truncated JSON) and `TypeError` (wrong-typed field) escape, and `_load()` is started with
`unawaited(_load())` in `initState` (`lib/main.dart:952`) with no guard, so the boot sequence dies at
`reading your library` (`lib/core/bootstrapper.dart:43-52`) and the app never leaves the boot screen.

This is the realistic one: `sync_library.py` pushes files over adb, and the README itself warns that
a download can stop halfway.

Repro: `manifest_hostility_test.dart` → *truncated JSON does not escape load()*.

### High — one wrong-typed manifest field loses the whole library

`Track.fromJson` (`lib/library/track.dart:76-101`) casts unguarded:

| Field | Value that throws | Error |
|---|---|---|
| `gain_db` | `"loud"` | `TypeError: String is not num?` |
| `romaji` | `5` | `TypeError: int is not String?` |
| `variant` / `variant_of` | `7` | `TypeError` |
| `duration_s` | `1e400` (JSON → Infinity) or `1e308` | `UnsupportedError: Infinity or NaN toInt` |

Repros: `manifest_hostility_test.dart` (4 tests) and the 500-document random-JSON fuzz in the same file.

### High — two more state files can kill the boot the same way

| Store | Line | Throws on |
|---|---|---|
| `loop_points.json` | `lib/playback/loop_points.dart:68` | `"loop_count": "3"` |
| `bonds.json` | `lib/library/bonds.dart:38-39` | `"completion_points": "6"` |

Both are read during `opening your saved state` / `restoring your place`; the `TypeError` is not in
their `on FormatException` clauses. Repros: `saved_state_stores_test.dart`.

Everything else in that family held: places, personalization, tag overrides, snapshot, rules,
bookmarks, play log, playlist store — all corrupt shapes come back as defaults.

### High — lyrics can throw out of `forTrack()`

`lib/library/lyrics.dart`:

- `:435` / `:426` — `map['syncedLyrics'] as String?` on an LRCLIB row that is not a string →
  `TypeError`; `_fetch` only catches `SocketException`, `ClientException`, `FormatException`.
- `:476-477` — a cache file whose line entry is `["not-a-number", 5]` → `TypeError`;
  `_readCache` only catches `FormatException` / `FileSystemException`.
- `:59` — `Duration(milliseconds: ms.round())` with `[1e308:00]` → `UnsupportedError`. One garbage
  timestamp line rejects the whole lyrics file.

Repro: `lyrics_hostility_test.dart` (4 of 5 tests fail).

### High (latent) — update digest is taken from the wrong APK

`_digestIn()` (`lib/update/update_service.dart:152`) returns the **first** `sha256:` in the release
body, whichever asset was chosen. When a release publishes both `…-arm64-lite.apk` and
`…-arm64-full.apk` with a digest each, the full build downloads the full APK, compares it against the
lite digest, deletes it, and never installs. Today's releases publish one digest, so this is a trap
armed for the first two-asset release.

Repro: `update_hostility_test.dart` → *the full build is offered to a build that carries its engine*.

### Medium — paths from a manifest or a track id are not contained

`LibraryRepository._underRoot` (`:44-47`) and the lyrics cache path (`lyrics.dart:458-462`) join
strings without normalising, so:

- manifest `"file": "../outside.mp3"` resolves outside the library root (and `cover` likewise —
  the app will open/read/decode any path the manifest names);
- a track id `../../escape` writes the lyrics cache outside `cache/lyrics/`.

Repros: `manifest_hostility_test.dart` → *a manifest cannot point a track outside the library root*;
`lyrics_hostility_test.dart` → *a track id cannot write its cache outside the cache folder*.

### Medium — the queue and the manifest accept duplicate ids

- `PlayQueue._insert` (`lib/player/queue.dart:331-375`) does not dedupe **within** the arriving list,
  and `replaceSource` (`:220-234`) does not dedupe at all, so `promoteToNext([t5, t5])` puts `t5` in
  twice. The queue's design rests on one entry per id (`jumpTo`, `restoreOrder`, `replaceCurrent`).
- `Track.listFromManifest` (`track.dart:103-112`) keeps two tracks with the same `id`; the second is
  unreachable by id and makes `jumpTo`/playlist membership ambiguous.

Repros: `queue_fuzz_test.dart` (2 tests), `manifest_hostility_test.dart` → *duplicate ids*.

### Low

- Negative `duration_s` is kept as a negative `Duration` (−12 s) — `track.dart:84`.
- `playlists.json` keeps empty-string track ids (`playlists.dart:91`), inflating a playlist with an
  entry that can never resolve — `saved_state_hostility_test.dart`.
- Prerelease tags (`v9.9.9-beta.1`) are offered as updates like any release — no prerelease filter.
- `README.md:30` still advertises **0.3.1 (versionCode 31)** while `pubspec.yaml` is `0.3.6+36`.
- The existing boot harness never finished booting: `shell_harness_test.dart` stalled at `2%`
  because the boot steps do real disk I/O inside the widget test's fake clock; with real-time pumps
  it reached `74%` and hung on a cached asset future, and an unmocked pigeon channel
  (`dev.flutter.pigeon.…WakelockPlusApi.toggle`) surfaced as `channel-error`. Tests claiming *"the
  shell reaches its LOADED state"* only asserted that `HomeShell` existed, so boot coverage was
  weaker than it read. **Fixed** — see the Fixes table.

## What held up

- **Prefs** — 18 hostile documents (NaN, ±Infinity, 2⁶², wrong types, unknown locale, non-string keys):
  no throw, values clamped, unknown locale falls back to the system, save→load round-trips.
- **Queue** — 12 seeds × 500 random edit ops (next/prev/jump/move/remove/insert/clear/promote/
  replace/restore/shuffle/replaceSource) with the full invariant set checked after **every** op:
  index in range, `current == order[index]`, `upcoming`/`played` are exact slices, ids unique,
  engine-staleness exactly on reorders. Zero violations.
- **Update check** — non-map bodies, junk assets, non-numeric sizes, oversized build numbers,
  uppercase/short digests, missing APKs: silence instead of a crash; short downloads and digest
  mismatches are deleted.
- **Layout at large text** — 72 checks: first-run and settings at 320 / 360 / 412 dp × 1.0 / 1.3 /
  1.6 / 2.0× text × 5 languages. Text scaling verified to really apply (title 49 px → 97 px).
  No overflow exceptions.
- **State stores** — loop points (apart from the cast above), bonds, tags, personalization,
  snapshot, rules, bookmarks, play log: broken lines are skipped, junk roots read as defaults.

## Fixes

Every finding above is fixed in the same pass; the probes are the regression tests.

| Finding | Change |
|---|---|
| S1 boot stall on a corrupt manifest | `LibraryRepository.load()` catches any parse failure and reads as empty; `_load()` wraps the whole boot sequence, logs `[Sonarar][BOOT] failed`, and still shows the shell instead of the progress screen (`lib/main.dart`) |
| Manifest field casts | `Track.durationOf` / `gainOf` / `tagOf` accept only finite, sane values and default the rest; `listFromManifest` skips entries it cannot read instead of failing the file |
| Duplicate manifest ids | first entry wins, the rest are logged and dropped |
| `loop_points.json` / `bonds.json` casts | `is num` checks instead of `as num?` |
| Lyrics row types, cache types, timestamp overflow | `_text()` reads only strings; cached lines are type-checked and range-checked; stamps past 100 h are refused rather than rounded |
| Lyrics cache path | unsafe track ids are hashed, so the cache cannot be written outside `lyrics/` |
| Update digest vs asset | `_digestIn` takes the digest on the chosen asset's line (or its `full`/`lite` line); an ambiguous body yields null instead of another file's digest |
| Prerelease self-install | `vX.Y.Z-…` tags are not offered by the automatic check |
| Duplicate queue ids | `PlayQueue` dedupes on construction, `replaceSource` and every `_insert` |
| Manifest path traversal | `_underRoot` normalises and returns null when a path climbs out; `absoluteFor`/`coverPathFor` then report "not found" |
| Empty playlist ids | filtered when a playlist is decoded |
| Negative durations | clamped to zero |
| README version drift | Install section says 0.3.6 (versionCode 36) |
| Boot harness never booted | `shell_harness_test.dart` now pumps real time until `debugLoading` is false, clears the asset cache between tests, and mocks the pigeon wakelock channel on its `BasicMessageChannel`; the loaded-state test asserts the boot actually finished |

The boot harness (`shell_harness_test.dart`) is unchanged — it is a test-infrastructure limitation,
not app behaviour; the probes avoid it by measuring screens directly.
