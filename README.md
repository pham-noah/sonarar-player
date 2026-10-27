# Sonarar

A personal music player for Android. It plays your own files, works fully offline, and — if you ask it
to — picks what to play from **where you are** and **what the weather is doing**.

No account, no cloud, no upload. Not a streaming client.

Package `com.noah.sonarar` · version **0.2.0** · GPL-3.0-or-later

---

## Install

Download `Sonarar-0.2.0-arm64.apk` from [Releases](../../releases) and open it. arm64 phones, Android 7
or newer. It is signed with its own key and installs directly — no store, no account.

**It opens empty, by design.** There is no folder picker yet: the app reads `Music/Sonarar` and a
manifest beside it, and that manifest is built by the tools in this repository. Until you build one,
there is nothing to play. See [Your music](#your-music).

## What it does

- **Your library, from your storage.** It reads an on-disk manifest and plays the files it points at.
  Nothing is copied into an app-private cache and nothing is uploaded.
- **Six skins** — Abyss, Amber, Crimson, Minimal, Mono, Bloom — each with its own palette, type and
  layout.
- **Lyrics**, with romaji readings for Japanese and Korean tracks.
- **A media session**, so playback survives swiping the app away and shows on the lock screen.
- **Playlists, queue and history** — create, reorder, queue next, see what you have actually listened to.
- **Optional YouTube download.** Paste a playlist and yt-dlp fetches it into your library.

## Everything automatic is a switch, and every switch starts off

Out of the box this is a plain local player. Each of these is its own setting; turn on only what you
want the app deciding for you.

**Context**
- **Time of day** — the hour picks the queue and repaints the theme.
- **Weather** — a real forecast from Open-Meteo (no key, no account); rain changes what plays.
- **Places** — home, uni, the gym; arriving changes the music, leaving changes it back.
- **Dynamic mix** — the context builds the queue at all. Off, you play your own lists.

**Refinements**
- **Weather variants** — a track swaps to its rain or night version mid-queue.
- **Auto theme** — the skin follows the hour and the weather.
- **Learn from skips** — the queue remembers what you accept at that time of day.

**Records**
- **Play history** — writes every listen. Off, History and the Compendium have nothing to show.
- **Bonds** — the rank panel inside History.

Switching **weather** or **places** on reads them immediately, not at the next timer tick. **Offline**
remains a separate master switch: it cuts the network for everything, downloads included.

## Your music

The app reads `/storage/emulated/0/Music/Sonarar` and the `library_manifest.json` beside it. The tools
here build that from a folder of rips — they clean up titles, write covers, measure loudness and
generate the visualiser data.

```bash
python3 tools/build_library.py     # scan and plan; writes only a report
python3 tools/execute_library.py   # transcode, tag, covers, manifest, gain
```

Standard-library Python 3 plus `ffmpeg`/`ffprobe`. Safe to re-run: finished tracks are skipped. Paths
resolve from `--source` / `--project` flags, then `PERSONAR_*` environment variables, then your user
`Music` folder — nothing is hardcoded to one machine.

## Build it

Flutter **3.47.6** / Dart **3.13.5**. Older Flutter cannot build this.

```bash
cd app_src
flutter pub get
flutter build apk --release --target-platform=android-arm64
# build/app/outputs/flutter-apk/app-release.apk
```

The release APK is **unsigned unless a keystore is present**: `android/key.properties` (gitignored) with
`storeFile`, `storePassword`, `keyAlias` and `keyPassword` makes Gradle sign the release. Without it the
build produces an unsigned APK, which is what a store like F-Droid wants, because it signs its own.

`--target-platform=android-arm64` is not optional: the default build packs three ABIs and the two that
cannot run cost more than the app itself.

## Checks

```bash
cd app_src
flutter analyze --fatal-infos
flutter test
```

Both are green: no analyzer findings, **1550 tests** passing.

## Permissions

Nothing is asked for at launch. Location is requested the first time **Places** is switched on, and
nothing else reads it — with Places off the app never touches GPS. Storage is requested when you open
the Library, notifications on your first play. Deny any of them and the rest of the app still runs.

## Network

Four things reach the network, and none of them carry an account: Open-Meteo for weather, ipapi.co for
a coarse position when GPS has none, Overpass for nearby places, and YouTube when you ask for a
download. There is no analytics, no tracking and no ad code.

## What is honestly not built

- **No folder picker.** The library root is a hardcoded path and nothing in the UI can point the app
  somewhere else. This is the next version's work, and the reason a fresh install is empty.
- **Replay gain is measured but not applied.** Every track carries `gain_db` in the manifest and the
  player never reads it, so a loud master and a quiet one play as mastered.
- **Arrival is detected while the app is open only.** Screen-off geofencing is not in this build;
  Places and weather still resolve normally.
- **Location is a framework reading, not a background service.** If no fix is available the context
  says "not detected" rather than presenting a guess as known.

## Licence

GPL-3.0-or-later, because the app links `youtubedl-android`, which is GPL-3.0. Third-party notices are
in [NOTICE.md](NOTICE.md); the full text is in [LICENSE](LICENSE).
