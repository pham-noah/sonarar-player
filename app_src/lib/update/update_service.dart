library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../core/build_info.dart';

/// A release the user could move to.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.build,
    required this.apkUrl,
    required this.notesUrl,
    required this.sizeBytes,
    this.sha256,
    this.notes = '',
  });

  final String version;

  /// versionCode from the release name, e.g. `0.2.1+21`. Compared, never shown.
  final int build;

  final String apkUrl;
  final String notesUrl;
  final int sizeBytes;

  /// Digest published in the release notes as `sha256: <hex>`. Null when the
  /// release did not publish one; the download is then accepted on size alone.
  final String? sha256;

  /// The release body, as GitHub holds it (markdown). Shown in the update sheet
  /// so the offer says what changed; empty when the release has none.
  final String notes;

  String get label => 'v$version';

  /// What to put in front of the reader: the note's first paragraph-ish slice,
  /// with the markdown headings and links left in rather than half-stripped.
  String get notesPreview {
    final trimmed = notes.trim();
    if (trimmed.isEmpty) return '';
    const limit = 500;
    return trimmed.length <= limit ? trimmed : '${trimmed.substring(0, limit).trimRight()}…';
  }
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
  // What this build answers to. The default is the build's own version, because
  // a caller that forgets it turns a release title without `+NN` into a check
  // that never fires — the version comparison needs both sides.
  String currentVersion = appVersionName,
  /// Whether this build carries its download engine. Decides which asset is
  /// offered; null keeps the old "whatever arm64 APK exists" behaviour.
  bool? engineBundled,
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
    final asset = _apkAsset(body['assets'], engineBundled: engineBundled);
    if (tag is! String || asset == null) return null;
    // `releases/latest` normally hides prereleases, but a beta published without
    // the flag would otherwise be installed over a stable build by itself.
    if (_isPrerelease(tag)) return null;

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
      notes: body['body'] is String ? body['body'] as String : '',
      sha256: _digestIn(body['body'], assetName: asset.$3),
    );
  } catch (_) {
    return null;
  } finally {
    if (client == null) c.close();
  }
}

/// The arm64 build of the *same kind* as this one, when there is one.
///
/// Two builds ship: one with the download engine inside and one without. Offering a
/// lite install the full APK would quietly reinstall the 14 MB the user never wanted,
/// so the asset has to match the build asking — the engine archive is fetched on
/// demand precisely so nobody downloads it by accident.
(String, int, String)? _apkAsset(Object? assets, {bool? engineBundled}) {
  if (assets is! List) return null;
  final apks = [
    for (final a in assets)
      if (a is Map && a['name'] is String && (a['name'] as String).endsWith('.apk'))
        a,
  ];
  if (apks.isEmpty) return null;

  bool named(Map a, String token) => (a['name'] as String).contains(token);
  final arm64 = apks.where((a) => named(a, 'arm64')).toList();
  final pool = arm64.isNotEmpty ? arm64 : apks;

  // A build that fetches its engine takes the lite asset; a full build takes the
  // plain one. Falling back to whatever exists keeps an older release usable.
  var chosen = pool.first;
  if (engineBundled != null) {
    final want = engineBundled ? 'full' : 'lite';
    final match = pool.where((a) => named(a, want)).toList();
    if (match.isNotEmpty) chosen = match.first;
  }
  final url = chosen['browser_download_url'];
  if (url is! String) return null;
  final size = chosen['size'];
  return (url, size is int ? size : 0, chosen['name'] as String);
}

/// The digest a release publishes for [assetName], if it publishes one.
///
/// One digest is unambiguous. A release that publishes two — lite and full —
/// must not have the digest of one checked against the other, which is what a
/// first-match reader did: it deleted the APK it had just downloaded and never
/// offered the update again. With several digests the one on the asset's own
/// line wins, then the one on a `full`/`lite` line matching the asset; an
/// ambiguous body yields null, which accepts the download on size alone rather
/// than on a digest belonging to another file.
String? _digestIn(Object? body, {String? assetName}) {
  if (body is! String) return null;
  final matches = RegExp(
    r'sha-?256[:\s=]+([a-fA-F0-9]{64})',
    caseSensitive: false,
  ).allMatches(body).toList();
  if (matches.isEmpty) return null;
  if (matches.length == 1) return matches.first.group(1)!.toLowerCase();

  /// The digest's own line and the line above it: releases name the file on one
  /// line and put the hash on the next.
  String contextOf(RegExpMatch m) {
    final lineStart = body.lastIndexOf('\n', m.start) + 1;
    final aboveStart = lineStart <= 0
        ? 0
        : body.lastIndexOf('\n', lineStart - 2) + 1;
    var end = body.indexOf('\n', m.end);
    if (end < 0) end = body.length;
    return body.substring(aboveStart, end).toLowerCase();
  }

  String? pick(bool Function(String line) test) {
    for (final match in matches) {
      if (test(contextOf(match))) return match.group(1)!.toLowerCase();
    }
    return null;
  }

  final name = assetName?.toLowerCase();
  if (name != null) {
    final byName = pick((line) => line.contains(name));
    if (byName != null) return byName;
    for (final token in const ['full', 'lite']) {
      if (name.contains(token)) {
        final byToken = pick((line) => line.contains(token));
        if (byToken != null) return byToken;
      }
    }
  }
  return null;
}

/// `v1.2.3-beta.1` is a prerelease, whatever the GitHub flag says.
bool _isPrerelease(String tag) =>
    RegExp(r'^\s*v?\d+\.\d+\.\d+-').hasMatch(tag);

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
    // Size alone cannot tell a wrong build from a right one. When the release
    // publishes a digest, hold the file to it — and say nothing came through
    // rather than hand the installer a file that will fail there instead.
    final expected = update.sha256;
    if (expected != null && expected.isNotEmpty) {
      final actual = sha256.convert(await target.readAsBytes()).toString();
      if (actual != expected) {
        if (target.existsSync()) target.deleteSync();
        return null;
      }
    }
    return target;
  } catch (_) {
    return null;
  } finally {
    if (client == null) c.close();
  }
}
