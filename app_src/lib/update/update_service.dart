library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A release the user could move to.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.build,
    required this.apkUrl,
    required this.notesUrl,
    required this.sizeBytes,
  });

  final String version;

  /// versionCode from the release name, e.g. `0.2.1+21`. Compared, never shown.
  final int build;

  final String apkUrl;
  final String notesUrl;
  final int sizeBytes;

  String get label => 'v$version';
}

/// Self-update is a courtesy, not a feature of the music player.
///
/// F-Droid forbids an app that updates itself, so that build compiles the check
/// out with `--dart-define=SONARAR_SELF_UPDATE=false`; nothing here runs then.
const bool kSelfUpdate = bool.fromEnvironment(
  'SONARAR_SELF_UPDATE',
  defaultValue: true,
);

const _repo = 'pham-noah/sonarar-player';

/// Asks GitHub for the newest release and returns it only if it is newer than
/// [currentBuild]. Never throws: a music player that will not open because
/// GitHub was slow is a broken music player.
Future<AppUpdate?> checkForUpdate(
  int currentBuild, {
  String currentVersion = '',
  http.Client? client,
}) async {
  if (!kSelfUpdate) return null;
  final http.Client c = client ?? http.Client();
  try {
    final response = await c.get(
      Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
      headers: const {'Accept': 'application/vnd.github+json'},
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body);
    if (body is! Map) return null;

    final tag = body['tag_name'];
    final name = body['name'];
    final asset = _apkAsset(body['assets']);
    if (tag is! String || asset == null) return null;

    // A release title usually carries the build (`0.2.2+22`); early ones did
    // not, and a check that gives up on those silently never fires. Use the
    // build when it is there, the version when it is not.
    final build = _buildNumber('${name ?? ''} $tag');
    final newer =
        build != null ? build > currentBuild : _isNewer(tag, currentVersion);
    if (!newer) return null;

    return AppUpdate(
      version: tag.replaceFirst('v', ''),
      build: build ?? 0,
      apkUrl: asset.$1,
      sizeBytes: asset.$2,
      notesUrl: body['html_url'] is String ? body['html_url'] as String : '',
    );
  } catch (_) {
    return null;
  } finally {
    if (client == null) c.close();
  }
}

/// The arm64 build, when there is one; otherwise the only APK on the release.
(String, int)? _apkAsset(Object? assets) {
  if (assets is! List) return null;
  final apks = [
    for (final a in assets)
      if (a is Map && a['name'] is String && (a['name'] as String).endsWith('.apk'))
        a,
  ];
  if (apks.isEmpty) return null;
  final arm64 = apks.where((a) => (a['name'] as String).contains('arm64')).toList();
  final chosen = arm64.isNotEmpty ? arm64.first : apks.first;
  final url = chosen['browser_download_url'];
  if (url is! String) return null;
  final size = chosen['size'];
  return (url, size is int ? size : 0);
}

/// True when [tag] names a version above [current].
bool _isNewer(String tag, String current) {
  final a = _semver(tag);
  final b = _semver(current);
  if (a == null || b == null) return false;
  if (a.$1 != b.$1) return a.$1 > b.$1;
  if (a.$2 != b.$2) return a.$2 > b.$2;
  return a.$3 > b.$3;
}

(int, int, int)? _semver(String text) {
  final match = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(text);
  if (match == null) return null;
  return (
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

/// `0.2.1+21` — the part after `+` is the versionCode the phone compares.
int? _buildNumber(String text) {
  final match = RegExp(r'\+(\d+)').firstMatch(text);
  return match == null ? null : int.parse(match.group(1)!);
}

/// Downloads the APK into the user's Downloads folder, reporting progress in
/// 0..1. Returns the file, or null if it could not be fetched whole.
Future<File?> downloadUpdate(
  AppUpdate update,
  Directory downloads, {
  void Function(double)? onProgress,
  http.Client? client,
}) async {
  final http.Client c = client ?? http.Client();
  final target = File('${downloads.path}/Sonarar-${update.version}.apk');
  try {
    final response = await c.send(http.Request('GET', Uri.parse(update.apkUrl)));
    if (response.statusCode != 200) return null;

    final total = response.contentLength ?? update.sizeBytes;
    final sink = target.openWrite();
    var written = 0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        written += chunk.length;
        if (total > 0) onProgress?.call(written / total);
      }
    } finally {
      await sink.close();
    }
    // A short file is a corrupted installer prompt, not an update — and it must
    // not be left in Downloads pretending to be one.
    if (total > 0 && written < total) {
      if (target.existsSync()) target.deleteSync();
      return null;
    }
    return target;
  } catch (_) {
    return null;
  } finally {
    if (client == null) c.close();
  }
}
