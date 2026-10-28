library;

import 'dart:convert';
import 'dart:io';

import 'package:ytdlp_flutter/ytdlp_flutter.dart';

import 'playlists.dart';
import 'track.dart';

const String kDownloadedId = 'downloaded';
const String kDownloadedName = 'Downloaded';

class DownloadedTrack {
  const DownloadedTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationSeconds,
    required this.fileName,
    required this.coverName,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationSeconds;

  final String fileName;

  final String coverName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'duration_s': durationSeconds,
        'file': fileName,
        'cover': coverName,
        'gain_db': null,

        'romaji': null,
        'variant_of': null,
        'variant': null,
      };
}

Future<bool> addToManifest({
  required File manifest,
  required DownloadedTrack track,
}) async {
  try {
    // A phone that has never held a library has no manifest yet. Refusing the
    // write because of that is how a download lands on disk and never shows up.
    Map<String, dynamic> raw;
    if (await manifest.exists()) {
      final decoded = jsonDecode(await manifest.readAsString());
      if (decoded is! Map<String, dynamic>) return false;
      raw = decoded;
    } else {
      await manifest.parent.create(recursive: true);
      raw = <String, dynamic>{'tracks': <dynamic>[]};
    }

    final tracks = raw['tracks'];
    if (tracks is! List) return false;

    var changed = false;
    for (var i = 0; i < tracks.length; i++) {
      final t = tracks[i];
      if (t is Map && (t['id'] ?? '').toString() == track.id) {
        final fresh = track.toJson();

        if (jsonEncode(t) != jsonEncode(fresh)) {
          tracks[i] = fresh;
          changed = true;
        }
        break;
      }
    }

    if (!changed) {
      final known = tracks.any((t) => t is Map && (t['id'] ?? '').toString() == track.id);
      if (!known) {
        tracks.add(track.toJson());
        changed = true;
      }
    }

    if (!changed) return false;
    await manifest.writeAsString(jsonEncode(raw));
    return true;
  } catch (_) {
    return false;
  }
}

Future<DownloadedTrack?> describeDownload({
  required File audio,
  required String videoTitle,
  required String channel,
  required String videoId,
  required Directory downloadDir,
  required Future<List<int>?> Function(String url) fetchThumbnail,
  String? thumbnailUrl,

  required int durationSeconds,
}) async {
  final title = cleanYoutubeTitle(videoTitle);

  var coverName = '';
  if (thumbnailUrl != null) {
    try {
      final bytes = await fetchThumbnail(thumbnailUrl);
      if (bytes != null && bytes.isNotEmpty) {
        final f = File('${downloadDir.path}/$videoId.jpg');
        await f.writeAsBytes(bytes);
        coverName = 'Downloaded/$videoId.jpg';
      }
    } catch (_) {
    }
  }

  return DownloadedTrack(
    id: videoId,
    title: title,
    artist: channel,
    album: 'Downloaded',
    durationSeconds: durationSeconds,
    fileName: 'Downloaded/${audio.uri.pathSegments.last}',
    coverName: coverName,
  );
}

String cleanYoutubeTitle(String raw) {
  // Japanese uploads bracket their tags with full-width punctuation, which the
  // patterns below would miss: あぶく（OFFICIAL VIDEO） kept its tag.
  var t = raw
      .replaceAll('（', '(')
      .replaceAll('）', ')')
      .replaceAll('［', '[')
      .replaceAll('］', ']')
      .replaceAll('【', '(')
      .replaceAll('】', ')')
      .replaceAll('　', ' ');

  const noise = [
    r'\s*[\(\[]\s*official\s*(music\s*)?video\s*[\)\]]',
    r'\s*[\(\[]\s*official\s*audio\s*[\)\]]',
    r'\s*[\(\[]\s*lyric[s]?\s*video\s*[\)\]]',
    r'\s*[\(\[]\s*lyrics?\s*[\)\]]',
    r'\s*[\(\[]\s*audio\s*[\)\]]',
    r'\s*[\(\[]\s*hd\s*[\)\]]',
    r'\s*[\(\[]\s*4k\s*[\)\]]',
    r'\s*[\(\[]\s*visualizer\s*[\)\]]',
    r'\s*[\(\[]\s*music\s*video\s*[\)\]]',
    r'\s*[\(\[]\s*explicit\s*[\)\]]',
  ];
  for (final p in noise) {
    t = t.replaceAll(RegExp(p, caseSensitive: false), '');
  }

  t = t.replaceAll(RegExp(r'\s*-\s*Topic\s*$', caseSensitive: false), '');

  t = t.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  return t.isEmpty ? raw : t;
}

Future<List<int>?> httpGetBytes(String url) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(url));
    final res = await req.close();
    if (res.statusCode != 200) return null;
    final out = <int>[];
    await for (final chunk in res) {
      out.addAll(chunk);
    }
    return out;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

String? progressLabel(YtdlpProgress p) {
  if (p.fraction != null) return '${(p.fraction! * 100).round()}%';
  final got = p.downloadedBytes;
  if (got != null && got > 0) return '${(got / 1048576).toStringAsFixed(1)} MB';
  return null;
}

bool isDownloaded(Track t) =>
    t.file.startsWith('Downloaded/') || t.file.startsWith('Downloaded\\');

Playlist downloadedPlaylist(List<Track> library) {
  final ids = [for (final t in library) if (isDownloaded(t)) t.id];
  return Playlist(id: kDownloadedId, name: kDownloadedName, trackIds: ids);
}

Future<int?> removeDownload({
  required Track track,
  required String libraryRoot,
  required File manifest,
}) async {
  if (!isDownloaded(track)) return null;
  final sep = Platform.pathSeparator;
  var freed = 0;

  try {
    if (await manifest.exists()) {
      final raw = jsonDecode(await manifest.readAsString());
      if (raw is Map<String, dynamic>) {
        final tracks = raw['tracks'];
        if (tracks is List) {
          tracks.removeWhere((t) => t is Map && (t['id'] ?? '').toString() == track.id);
          await manifest.writeAsString(jsonEncode(raw));
        }
      }
    }
  } catch (_) {
    return null;
  }

  for (final rel in [track.file, track.cover]) {
    if (rel.isEmpty) continue;
    try {
      final f = File('$libraryRoot$sep${rel.replaceAll('/', sep)}');
      if (await f.exists()) {
        freed += await f.length();
        await f.delete();
      }
    } catch (_) {}
  }
  return freed;
}
