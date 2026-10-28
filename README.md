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

Download the latest APK from [Releases](../../releases) and open it on the device.
Latest: **0.1.1** (versionCode 12). Android 7.0+ (API 24), arm64-v8a, package `com.noah.sonarar`,
signed with the project key.
An [F-Droid recipe](store/fdroid/com.noah.sonarar.yml) exists for a store-signed build.

## Features

- **Playback** — local files through Android's media session, with lock-screen and notification
  controls, gapless playback, crossfade up to 12s, a fading sleep timer, queue editing, and per-track
  bookmarks and loop points.
- **Library** — playlists you build, merging two with Fusion, browsing by playlist, artist and song,
  search and swipe actions, a compendium of everything with how much you have heard, listening history
  by day and hour, and lyrics with romaji for Japanese and Korean tracks.
- **Look** — six skins (Abyss, Amber, Crimson, Minimal, Mono, Bloom), three layout families (Persona,
  Solid, Glass), and a visualiser driven by per-track spectrum data.
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

## Privacy

No permission is requested at launch, and declining any of them leaves the app working. With Places
off, the GPS is never touched.

The build contains no analytics, tracking or advertising. Its only network calls are weather
(`api.open-meteo.com`), a coarse position fallback (`ipapi.co`), nearby places (Overpass), and YouTube
downloads on request. None of them carry an account.

## Licence

GPL-3.0-or-later, because `youtubedl-android` is GPL-3.0. Third-party notices in [NOTICE.md](NOTICE.md),
licence text in [LICENSE](LICENSE).
