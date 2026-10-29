# Sonarar

**A local-first music player for Android.** It plays files you already own, works without a network,
and can shape what it plays around your location, the weather and the time of day.

[![License: GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/pham-noah/sonarar-player)](../../releases)

No account, no cloud, no upload, no analytics, no tracking, no advertising.

## Screens

<p align="center">
  <img src="docs/shots/first-run.png" width="230" alt="First run: layout, colours and list style">
  <img src="docs/shots/home.png" width="230" alt="Home: trending, all music, now playing">
  <img src="docs/shots/library.png" width="230" alt="Library: songs with covers, artist and length">
</p>
<p align="center">
  <img src="docs/shots/player.png" width="230" alt="Now playing: cover, transport, up next">
  <img src="docs/shots/settings.png" width="230" alt="Settings: every automatic behaviour is a switch">
</p>

The library pictured is twelve generated tracks — the real one is your own music.

## Install

Take the latest APK from [Releases](../../releases) and open it on the device.

**0.2.0** (versionCode 20) · Android 7.0+ (API 24) · arm64-v8a only · `com.noah.sonarar`

Every release here is signed with the same project key, so they install over each other. A 32-bit
phone cannot run it. The [F-Droid recipe](store/fdroid/com.noah.sonarar.yml) is for a store-signed
build — that signature is not this one, so it cannot upgrade over a GitHub build (uninstall first).

If the file will not install, check its size before blaming the APK: a 97 MB download that stops
halfway gives the same "could not parse the package" message as a bad build. The published assets are
hash-checked against the local build at release time.

## Getting music onto the phone

The app does not import from the device. The library is built on a PC and pushed in a fixed layout,
which is what makes a large collection cheap to scan and keeps covers, gain and spectrum data beside
the audio.

```bash
python3 tools/build_library.py           # dry run: inventory the PC folder into reports/
python3 tools/execute_library.py --resume  # build audio, covers, gain and the manifest
python3 tools/sync_library.py --check    # show what the phone is missing
python3 tools/sync_library.py            # push only the changed files over adb
```

The app reads `library_manifest.json` from the folder its empty state names. `sync_library.py`
compares sizes, never writes to the PC, and deletes from the phone only with `--prune`. It also carries
`spectrum/<id>.bin`, which is what the visualiser draws.

## Features

- **Playback** — local files through Android's media session with lock-screen and notification
  controls, gapless through one engine queue, a fade-in of up to 12s on each new track, a fading sleep
  timer, stop-after-this-track, per-track bookmarks and loop points.
- **Queue** — reorder by dragging, swipe to remove with an undo, clear everything upcoming, save the
  queue as a playlist, "play next" that does not disturb the current track.
- **Library** — playlists you build, Fusion to merge two, browsing by playlist, artist and song, search
  and swipe actions, a compendium of everything with how much you have heard, listening history by day
  and hour, and lyrics with romaji readings: full for Korean, kana-only for Japanese (kanji are shown
  as written, since reading them aloud would mean shipping a 32 MB dictionary).
- **Look** — six skins (Abyss, Amber, Crimson, Minimal, Mono, Bloom), three layout families (Sonar,
  Solid, Glass), and a visualiser driven by per-track spectrum data kept beside the audio in the
  library folder. Tracks without a spectrum file simply show no bars.
- **Personalize** — THEMES first, then LOOK (layout, song list shape, accent), PICTURES (per-place
  pictures and framing), ART (folders on disk) and HOME (section order). Your accent reaches every
  surface, including the sidebar.
- **Themes own the whole look** — skin, layout, accent, backdrop, Home order, every per-place
  picture, the art bundle and its framing. Editing anything edits the theme you are wearing, so
  switching away and back returns your version; the theme file is written once the hand stops
  moving, not on every tick.
- **Recently added** — downloaded music lands on Home in RECENTLY ADDED, newest first. It used to
  live only in Library, because every other Home rail needs play history or a playlist.
- **Art folders** — drop a folder of pictures into `Music/Sonarar/art/` and it becomes a bundle: each
  picture is a frame of that art. RESCAN picks up folders added while the app is open. Open ADJUST to
  drag, zoom, rotate, mirror or fade any picture; the framing is saved beside the pictures, or in the
  look file for the shipped art, and it follows the picture everywhere.
- **Per-place pictures** — every place (Home, Library, Search, Player) can wear its own picture, or
  share the one set everywhere.
- **Optional network** — weather from Open-Meteo, nearby places from Overpass, and YouTube playlist
  downloads through yt-dlp into the same library format.

## Context engine

Six switches, each independent, all off until you turn them on.

| Switch | Effect when enabled |
|---|---|
| **Time of day** | The hour selects the queue and repaints the theme. |
| **Weather** | A live forecast changes what plays; rain has its own lists. |
| **Places** | Saved locations trigger their own playlists on arrival. |
| **Dynamic mix** | The context builds the queue at all; off, only your own lists play. |
| **Weather variants** | A track swaps to its rain or night version mid-queue. |
| **Auto theme** | The skin follows the hour and the weather. |

Three more govern what is recorded: **Learn from skips**, **Play history** (the log behind History and
the Compendium), and **Bonds** (the rank panel inside History). Turning Weather or Places on fetches a
reading immediately rather than at the next interval. **Offline** cuts the network for everything,
downloads included.

## Build from source

Flutter **3.47.6**, Dart **3.13.5**.

```bash
cd app_src
flutter pub get
flutter build apk --release --target-platform=android-arm64
flutter analyze --fatal-infos && flutter test
```

The APK is unsigned unless `android/key.properties` (gitignored) names a `storeFile`,
`storePassword`, `keyAlias` and `keyPassword`. `--target-platform=android-arm64` is not optional: the
default build packages two more ABIs that no phone runs and that make up most of the file size.

## Updates

Sonarar can check GitHub for a newer release and offer it: it downloads the APK and hands it to the
system installer. Nothing is installed silently, and no release is fetched on your behalf beyond that
check. F-Droid builds have the checker compiled out — the store updates the app.

## Privacy

No permission is requested at launch, and declining any of them leaves the app working. Media access
is asked for when the library opens, notifications on the first play. Location is asked for only when
Places is switched on, and with Places off the GPS is never touched. The microphone permission exists
for one thing: the spectrum probe attaches a system `Visualizer`, which Android gates behind it. It is
asked for from that probe screen, never at launch, and playback does not use it.

The build contains no analytics, tracking or advertising. Its only network calls are weather
(`api.open-meteo.com`), a coarse position fallback (`ipapi.co`), nearby places (Overpass), and YouTube
downloads on request. None of them carry an account.

## Licence

GPL-3.0-or-later, because `youtubedl-android` is GPL-3.0. Third-party notices in [NOTICE.md](NOTICE.md),
licence text in [LICENSE](LICENSE).
