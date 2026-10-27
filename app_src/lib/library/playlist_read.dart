library;

import 'dart:convert';

class PlaylistVideo {
  const PlaylistVideo({
    required this.id,
    required this.title,
    this.author = '',
    this.duration,
  });

  final String id;
  final String title;
  final String author;

  final Duration? duration;

  String get thumbnailUrl => 'https://i.ytimg.com/vi/$id/mqdefault.jpg';
}

Future<List<PlaylistVideo>> readPlaylistVideos({
  required String playlistId,
  required Future<String?> Function(String url) fetch,
  int max = 400,
}) async {
  final out = <PlaylistVideo>[];
  final seen = <String>{};
  String? continuation;

  while (out.length < max) {
    final url = continuation == null
        ? 'https://www.youtube.com/playlist?list=$playlistId&hl=en'
        : 'https://www.youtube.com/youtubei/v1/browse?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';
    final body = await fetch(url);
    if (body == null || body.isEmpty) break;

    final root = _initialDataIn(body) ?? _decodeJson(body);
    if (root == null) break;

    final found = _videosIn(root);
    if (found.isEmpty) break;

    var fresh = 0;
    for (final v in found) {
      if (seen.add(v.id)) {
        out.add(v);
        fresh++;
      }
    }

    final next = _continuationIn(root);

    if (fresh == 0 || next == null || next == continuation) break;
    continuation = next;
  }

  return out;
}

List<PlaylistVideo> _videosIn(Object? node) {
  final modern = _lockupsIn(node);
  if (modern.isNotEmpty) return modern;
  return _renderersIn(node);
}

List<PlaylistVideo> _lockupsIn(Object? node) {
  final text = _asText(node);
  if (text == null || !text.contains('"lockupViewModel"')) return const [];

  final out = <PlaylistVideo>[];
  final seen = <String>{};
  final chunks = text.split('"lockupViewModel"');
  for (var i = 1; i < chunks.length; i++) {
    final chunk = chunks[i];
    final id = RegExp(r'i\.ytimg\.com/vi/([A-Za-z0-9_-]{11})/')
        .firstMatch(chunk)
        ?.group(1);
    if (id == null || !seen.add(id)) continue;
    out.add(PlaylistVideo(
      id: id,
      title: _field(chunk, r'"title":\{"content":"((?:[^"\\]|\\.)*)"') ?? id,
      author: _field(chunk, r'"a11yLabel":"Go to channel ((?:[^"\\]|\\.)*)"') ?? '',
      duration: _durationOf(_field(chunk, r'"thumbnailBadgeViewModel".{0,400}?"text":"(\d{1,2}:\d{2}(?::\d{2})?)"',
          dotAll: true)),
    ));
  }
  return out;
}

String? _field(String s, String pattern, {bool dotAll = false}) {
  final m = RegExp(pattern, dotAll: dotAll).firstMatch(s);
  if (m == null) return null;

  try {
    return jsonDecode('"${m.group(1)!}"') as String;
  } catch (_) {
    return m.group(1);
  }
}

List<PlaylistVideo> _renderersIn(Object? node) {
  final out = <PlaylistVideo>[];
  void walk(Object? n) {
    if (n is List) {
      for (final e in n) {
        walk(e);
      }
      return;
    }
    if (n is! Map) return;
    final r = n['playlistVideoRenderer'];
    if (r is Map) {
      final id = r['videoId'];
      if (id is String && id.isNotEmpty) {
        out.add(PlaylistVideo(
          id: id,
          title: _text(r['title']) ?? id,
          author: _text(r['shortBylineText']) ?? _text(r['ownerText']) ?? '',
          duration: _durationOf(_text(r['lengthText'])),
        ));
      }
    }
    for (final v in n.values) {
      walk(v);
    }
  }

  walk(node);
  return out;
}

String? _continuationIn(Object? node) {
  String? found;
  void walk(Object? n) {
    if (found != null) return;
    if (n is List) {
      for (final e in n) {
        walk(e);
      }
      return;
    }
    if (n is! Map) return;
    final c = n['continuationCommand'];
    if (c is Map && c['token'] is String) {
      found = c['token'] as String;
      return;
    }
    for (final v in n.values) {
      walk(v);
    }
  }

  walk(node);
  return found;
}

Duration? _durationOf(String? text) {
  if (text == null) return null;
  final parts = text.trim().split(':');
  if (parts.isEmpty || parts.length > 3) return null;
  var seconds = 0;
  for (final p in parts) {
    final n = int.tryParse(p.trim());
    if (n == null) return null;
    seconds = seconds * 60 + n;
  }
  return Duration(seconds: seconds);
}

Map<String, dynamic>? _initialDataIn(String html) {
  for (final marker in ['var ytInitialData = ', 'ytInitialData = ', 'window["ytInitialData"] = ']) {
    final at = html.indexOf(marker);
    if (at < 0) continue;
    final start = html.indexOf('{', at);
    if (start < 0) continue;
    var depth = 0;
    var inStr = false;
    var esc = false;
    for (var i = start; i < html.length; i++) {
      final c = html[i];
      if (inStr) {
        if (esc) {
          esc = false;
        } else if (c == r'\') {
          esc = true;
        } else if (c == '"') {
          inStr = false;
        }
        continue;
      }
      if (c == '"') {
        inStr = true;
      } else if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) return _decodeJson(html.substring(start, i + 1));
      }
    }
  }
  return null;
}

Map<String, dynamic>? _decodeJson(String text) {
  try {
    final d = jsonDecode(text);
    return d is Map<String, dynamic> ? d : null;
  } catch (_) {
    return null;
  }
}

String? _asText(Object? node) {
  try {
    return jsonEncode(node);
  } catch (_) {
    return null;
  }
}

String? _text(Object? node) {
  if (node is! Map) return null;
  final simple = node['simpleText'];
  if (simple is String) return simple;
  final runs = node['runs'];
  if (runs is List) {
    final b = StringBuffer();
    for (final r in runs) {
      if (r is Map && r['text'] is String) b.write(r['text']);
    }
    return b.isEmpty ? null : b.toString();
  }
  return null;
}
