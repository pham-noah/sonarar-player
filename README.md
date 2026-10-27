# Sonarar

A personal music player for Android. It plays your own files, works fully offline, and picks what to
play from **where you are** and **what the weather is doing**.

No account, no cloud, no upload. Not a streaming client — a player that already knows what you want.

Package `com.noah.sonarar` · version 0.1.0 · GPL-3.0-or-later

---

## What it does

- **Your library, from your storage.** It reads an on-disk manifest and plays the files it points at.
  Nothing is copied into an app-private cache and nothing is uploaded.
- **Places.** Home, uni, the gym — arriving changes the music, leaving changes it back.
- **Weather.** A real forecast from Open-Meteo (no key, no account). Rain sounds different from a
  clear evening.
- **They are switches, and they ship off.** Weather, time of day, places, the dynamic mix, weather
  variants, the auto theme, learning from skips, play history and the Bonds panel are each their own
  setting. Off — the default — the app is a plain local player: no forecast, no location read, the hour
  does not reshuffle the queue or repaint the theme, nothing is logged, and the queue is whatever you
  put in it.
- **Six skins** — Abyss, Amber, Crimson, Minimal, Mono, Bloom — each with its own palette, type and
  layout.
- **Lyrics**, with romaji readings for Japanese and Korean tracks.
- **A media session**, so playback survives swiping the app away and shows on the lock screen.
- **Optional YouTube download.** Paste a playlist and yt-dlp fetches it into your library. This is the
  one feature that reaches the network by choice.

## Building it

Flutter **3.47.6** / Dart **3.13.5**. Older Flutter cannot build this.

```bash
cd app_src
flutter pub get
flutter build apk --release --target-platform=android-arm64
# build/app/outputs/flutter-apk/app-release.apk
```

The release APK is **unsigned unless a keystore is present**: `android/key.properties` (gitignored) with
`storeFile`, `storePassword`, `keyAlias` and `keyPassword` makes Gradle sign the release; without it the
build produces an unsigned APK, which is what a store like F-Droid wants because it signs its own.
`--target-platform=android-arm64` is not optional: the default build packs three ABIs and the two that
cannot run cost more than the app itself.

## Checks

```bash
cd app_src
flutter analyze --fatal-infos
flutter test
```

Both are green: no analyzer findings, 1539 tests passing.

## Your music

The app reads `/storage/emulated/0/Music/Sonarar` and the `library_manifest.json` beside it. That
manifest is written by the tools in `tools/` — they scan a folder of rips, clean up titles, write
covers, measure loudness and generate the visualiser data.

```bash
python3 tools/build_library.py     # scan and plan; writes only a report
python3 tools/execute_library.py   # transcode, tag, covers, manifest, gain
```

Standard-library Python 3 plus `ffmpeg`/`ffprobe`. Safe to re-run: finished tracks are skipped.

## What is honestly not built

- **There is no folder picker.** The library root is a hardcoded path and nothing in the UI can point
  the app somewhere else. Build the library with the tools above and put it at `Music/Sonarar`, or the
  app opens empty. This is the gap that matters most for anyone installing it fresh.
- **Replay gain is measured but not applied.** Every track carries `gain_db` in the manifest and the
  player never reads it, so a loud master and a quiet one play as mastered.
- **Arrival is detected while the app is open only.** Screen-off geofencing is not in this build;
  Places and weather still resolve normally.
- **Location is a framework reading, not a background service.** If no fix is available the context
  says "not detected" rather than presenting a guess as known.

## Permissions

Nothing is asked for at launch. Location is requested the first time **Places** is switched on and
nothing else reads it, so with Places off the app never touches GPS. Storage is requested when you
open the Library, and notifications when you first press play. Deny any of them and the rest of the
app still runs.

## Network

Four things reach the network, and none of them carry an account: Open-Meteo for weather, ipapi.co for
a coarse position when GPS has none, Overpass for nearby places, and YouTube when you ask for a
download. There is no analytics, no tracking and no ad code.

## Licence

GPL-3.0-or-later, because the app links `youtubedl-android`, which is GPL-3.0. Third-party notices are
in [NOTICE.md](NOTICE.md); the full text is in [LICENSE](LICENSE).
