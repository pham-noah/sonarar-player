# Sonarar — licence and third-party notices

## What this is

Sonarar's Android build links **youtubedl-android**, which is **GPL-3.0**. Because it is linked into
the app, the app itself is distributed under **GPL-3.0** — that is what the licence requires, and
this file plus `LICENSE` is how the requirement is met.

You may use, study, share and modify it; if you pass it on, pass this file with it; and the source of
the exact build you received is at the repository named in the app's metadata.

## Third-party components

| Component | Licence | What it does here |
|---|---|---|
| **youtubedl-android** (`io.github.junkfood02.youtubedl-android:library` + `:ffmpeg`) | **GPL-3.0** | Runs the bundled Python + yt-dlp + FFmpeg on the phone. **This is the component that makes the app GPL.** Fetched from Maven Central. |
| **yt-dlp** | Unlicense (public domain) | The extractor itself. No conditions. |
| **FFmpeg** (bundled by youtubedl-android) | LGPL/GPL depending on build | Transcodes a download to M4A. |
| **youtube_explode_dart** | MIT | Search only — metadata, no download. |
| **just_audio**, **just_audio_background** | MIT | Playback and the media session. |
| **audio_session**, **wakelock_plus**, **path_provider** | MIT | Playback session and platform plumbing. |
| **flutter_map**, **latlong2** | BSD/MIT | The Places map. |
| **http** | BSD | Weather, IP lookup, POI lookup. |
| **korean_romanization_converter** | MIT | Hangul readings for lyrics. |
| **jp_transliterate** | MIT | Kanji readings for lyrics. |
| **cupertino_icons** | MIT | Icons. |

Every component above other than youtubedl-android is permissive — MIT or BSD — so there is **no
copyleft obligation from any of them**. Exactly one dependency carries the GPL, and it is the one that
makes downloading work.

## Changes in this build

- **Google Play Services is not used.** The location fix comes from this project's own
  `LocationBridge.kt`, on Android's framework `LocationManager`. `geolocator` is not a dependency
  here — it declares `play-services-location` inside its own build.gradle, which cannot be configured
  away.
- **Geofencing (screen-off arrival alerts) is not in this build.** Places and weather still resolve
  while the app is open.
- **The only artwork is one original PNG.** `assets/brand/logo_mark.png` is the app's mark, generated
  by `tools/make_brand.py`. No third-party artwork is bundled.
- youtubedl-android is used as published and is not modified. It is invoked through `ytdlp_flutter`.

## Source

The complete corresponding source of this build, including the changes listed above, is available from
the repository the app was distributed from. There are no modifications to youtubedl-android itself.
