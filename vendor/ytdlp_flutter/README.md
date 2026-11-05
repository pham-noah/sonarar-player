# ytdlp_flutter

Run [yt-dlp](https://github.com/yt-dlp/yt-dlp) **on-device** from Flutter.

yt-dlp re-implements YouTube's player-JS transforms (n-token, signatures)
and ships extractor updates weekly — the two things that break every
reimplementation library (youtube_explode, youtubei.js). This plugin runs
the real thing on each platform instead of porting it:

| Platform | Engine | yt-dlp updates | Status |
|---|---|---|---|
| Android | [youtubedl-android](https://github.com/JunkFood02/youtubedl-android) (bundled Python 3.8 + FFmpeg) | ✅ auto-updates at init (+ `Ytdlp.update()`) | Ready |
| macOS | Embedded CPython 3.13 in-process (same worker as iOS), yt-dlp zipapp bundled at `pod install` | ❌ ship app updates (sandbox) | Ready |
| iOS | Embedded CPython 3.13 ([Python-Apple-support](https://github.com/beeware/Python-Apple-support)) + bundled yt-dlp zipapp | ❌ ship app updates (App Store 2.5.2) | **Experimental** |

## Usage

```dart
import 'package:ytdlp_flutter/ytdlp_flutter.dart';

await Ytdlp.init(); // idempotent; first call downloads/extracts the engine

final info = await Ytdlp.getVideoInfo('https://youtu.be/0wemf5SZkW4');
print('${info.title} (${info.durationSeconds}s)');

final path = await Ytdlp.downloadAudio(
  url: 'https://youtu.be/0wemf5SZkW4',
  outputDir: '/path/to/dir',
  taskId: 'my-task',
  onProgress: (p) => print(p), // bytes/fraction/eta
);
// path -> /path/to/dir/0wemf5SZkW4.m4a (native container, no re-encode)

await Ytdlp.cancel('my-task');
await Ytdlp.update(); // Android only
```

By default the best **single audio stream** is downloaded in its native
container (m4a/webm) — no FFmpeg needed. Pass `audioFormat: 'm4a'` to
transcode via FFmpeg (**Android only**; iOS bundles no FFmpeg and on macOS
you'd need one on `PATH`).

## Android setup

- `minSdk 24`.
- In your app's `AndroidManifest.xml` `<application>` tag, add
  `android:extractNativeLibs="true"` (youtubedl-android requirement).
- APK size: the bundled Python/ffmpeg add ~30 MB per ABI — use
  `--split-per-abi` or app bundles.

## macOS setup

- Entitlements: `com.apple.security.network.client` (and file access to
  wherever you point `outputDir`).
- `pod install` fetches everything automatically (BeeWare Python.framework
  ~50 MB download, the yt-dlp `.pyz`, a CA bundle). The stdlib lives inside
  the vendored framework, so unlike iOS **no Xcode build phase is needed**.
- Why in-process instead of running a yt-dlp binary: sandboxed apps cannot.
  Runtime-downloaded binaries get quarantined (exec fails with EPERM, and
  the sandbox forbids stripping the xattr), and even a bundled PyInstaller
  onefile binary dies at `semctl` — App Sandbox denies SysV semaphores.
- No `Ytdlp.update()`: bump the bundled yt-dlp per release with
  `FORCE=1 macos/scripts/fetch_deps.sh`.
- The Process-based `YtdlpMacos` class (self-updating standalone binary in
  Application Support) still exists for **unsandboxed** hosts and the
  plugin's own `flutter test` live test.

## iOS setup (experimental)

`pod install` fetches everything automatically (Python.xcframework ~100 MB
download, the yt-dlp `.pyz`, and a CA bundle) via the podspec's
`prepare_command`. Two manual Xcode steps remain on the **Runner** target —
they mirror BeeWare's documented usage and can't live in a podspec:

1. Add a final **Run Script** phase (uncheck "Based on dependency
   analysis"):

   ```sh
   sh "$PODS_ROOT/../.symlinks/plugins/ytdlp_flutter/ios/scripts/install_python_stdlib.sh"
   ```

   This copies the SDK-matching Python stdlib into the app bundle and
   converts/signs the binary stdlib modules as frameworks (iOS refuses to
   load unsigned `.so` files on device).

2. Build once on a simulator first if you want to sanity-check without
   signing hardware modules.

Known constraints on iOS:

- No `Ytdlp.update()`: App Store rule 2.5.2 forbids downloading executable
  code, so yt-dlp updates ship with your app (re-run
  `FORCE=1 ios/scripts/fetch_deps.sh` before release builds to bump the
  bundled `.pyz`).
- No FFmpeg: stick to single-stream format selectors (the default is).
- App size grows by roughly 20–40 MB (interpreter + stdlib + yt-dlp).

## Why the engines differ per platform

See `docs/youtube-extraction-learnings.md` in the consuming app (Notely)
for the full failure history that motivated this plugin: YouTube's
n-parameter throttling serves 0 bytes to naive extractors, a hard 403 cap
hits past 1 MB, all web surfaces moved to SABR (no downloadable URLs), and
datacenter IPs are hard bot-flagged. Running the real yt-dlp from the
user's residential IP sidesteps all four.

## Testing

`test/macos_live_test.dart` is a live smoke test (network, ~35 MB binary +
a 32 MB video):

```sh
LIVE=1 flutter test test/macos_live_test.dart
```

The regression video is `0wemf5SZkW4` (32 MB) on purpose — small videos
(<1 MB) succeed even with broken extractors and prove nothing.

## License

MIT © statecs. yt-dlp is Unlicense/public domain; youtubedl-android is
GPL-3.0 — review license compatibility for your distribution before
shipping (the Android artifact links GPL code into your app).
