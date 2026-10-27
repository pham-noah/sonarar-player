library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class LyricLine {
  const LyricLine(this.at, this.text);

  final Duration at;
  final String text;

  static LyricLine? parse(String raw) {
    final line = raw.trim();
    if (!line.startsWith('[')) return null;
    final close = line.indexOf(']');
    if (close <= 1) return null;
    final stamp = line.substring(1, close);
    final text = line.substring(close + 1).trim();

    final parts = stamp.split(':');
    if (parts.length < 2) return null;
    final mm = int.tryParse(parts[0]);
    if (mm == null) return null;

    final seconds = parts[1].replaceAll(',', '.');
    final sec = double.tryParse(seconds);
    if (sec == null) return null;

    return LyricLine(
      Duration(milliseconds: mm * 60000 + (sec * 1000).round()),
      text,
    );
  }
}

class Lyrics {
  const Lyrics({
    required this.lines,
    this.plain,
    this.instrumental = false,
    this.source,
  });

  final List<LyricLine> lines;

  final String? plain;

  final bool instrumental;

  final String? source;

  bool get isEmpty => lines.isEmpty && (plain == null || plain!.isEmpty);

  int indexAt(Duration position) {
    var found = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].at <= position) {
        found = i;
      } else {
        break;
      }
    }
    return found;
  }
}

String normaliseQuery(String title) {
  var t = title;

  t = t.replaceAll(RegExp(r'\bcover\b.*$', caseSensitive: false), ' ');

  t = t.replaceAll(RegExp(r'[\(\[]\s*(feat|ft|with)\b.*?[\)\]]', caseSensitive: false), ' ');
  t = t.replaceAll(RegExp(r'\b(feat|ft)\.?\s.*$', caseSensitive: false), ' ');

  final segments = t.split('...').map((e) => e.trim()).where((e) => e.isNotEmpty);
  if (segments.isNotEmpty) {
    t = segments.reduce((a, b) => a.length >= b.length ? a : b);
  }

  t = t.replaceAll(RegExp(r'[\-–—/|]+\s*$'), ' ');

  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

  return t.isEmpty ? title.trim() : t;
}

class LyricsService {
  LyricsService({required this.cacheDirectory, http.Client? client})
      : _client = client ?? http.Client();

  final String? cacheDirectory;
  final http.Client _client;

  final _memory = <String, Lyrics?>{};

  Future<Lyrics?> forTrack({
    required String trackId,
    required String title,
    required String artist,
    bool instrumental = false,
  }) async {
    if (instrumental) {
      return const Lyrics(lines: [], instrumental: true, source: 'variant tag');
    }

    if (_memory.containsKey(trackId)) return _memory[trackId];

    final cached = await _readCache(trackId);
    if (cached != null) {
      _memory[trackId] = cached;
      return cached;
    }

    Lyrics? fetched;
    try {
      fetched = await _fetch(title: title, artist: artist);
    } on SocketException {
      fetched = null;
    } on http.ClientException {
      fetched = null;
    } on FormatException {
      fetched = null;
    }

    if (fetched != null && !fetched.isEmpty) await _writeCache(trackId, fetched);
    _memory[trackId] = fetched;
    return fetched;
  }

  Future<Lyrics?> _fetch({required String title, required String artist}) async {
    final query = {
      'track_name': normaliseQuery(title),
      'artist_name': artist,
    };
    final uri = Uri.https('lrclib.net', '/api/search', query);
    final response = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.isEmpty) return null;

    Map<String, dynamic>? best;
    for (final item in decoded) {
      if (item is! Map) continue;
      if ((item['syncedLyrics'] as String?)?.isNotEmpty ?? false) {
        best = item.cast<String, dynamic>();
        break;
      }
      best ??= item.cast<String, dynamic>();
    }
    if (best == null) return null;

    final synced = best['syncedLyrics'] as String?;
    if (synced != null && synced.isNotEmpty) {
      final lines = <LyricLine>[];
      for (final raw in synced.split('\n')) {
        final line = LyricLine.parse(raw);

        if (line != null && line.text.isNotEmpty) lines.add(line);
      }
      if (lines.isNotEmpty) {
        return Lyrics(lines: lines, source: 'lrclib (synced)');
      }
    }

    final plain = best['plainLyrics'] as String?;
    if (plain != null && plain.isNotEmpty) {
      return Lyrics(lines: const [], plain: plain, source: 'lrclib (plain)');
    }

    return Lyrics(lines: const [], instrumental: false, source: 'not found');
  }

  String? _cachePath(String trackId) {
    final dir = cacheDirectory;
    if (dir == null) return null;
    return '$dir/lyrics/$trackId.json';
  }

  Future<Lyrics?> _readCache(String trackId) async {
    final path = _cachePath(trackId);
    if (path == null) return null;
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      final map = jsonDecode(await file.readAsString());
      if (map is! Map) return null;
      final lines = <LyricLine>[];
      for (final raw in (map['lines'] as List? ?? const [])) {
        if (raw is List && raw.length == 2) {
          lines.add(LyricLine(
            Duration(milliseconds: (raw[0] as num).toInt()),
            raw[1] as String,
          ));
        }
      }
      return Lyrics(
        lines: lines,
        plain: map['plain'] as String?,
        source: map['source'] as String?,
      );
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> _writeCache(String trackId, Lyrics lyrics) async {
    final path = _cachePath(trackId);
    if (path == null) return;
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({
        'source': lyrics.source,
        'plain': lyrics.plain,

        'lines': [
          for (final l in lyrics.lines) [l.at.inMilliseconds, l.text],
        ],
      }));
    } on FileSystemException {
      // ignore: empty_catches
    }
  }
}
