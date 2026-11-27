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

/// A POST, for the continuation pages.
///
/// YouTube answers the browse endpoint 405 to anything but a POST, so a reader
/// holding only [readPlaylistVideos]'s `fetch` could never see past the first
/// hundred tracks — which is exactly what an imported playlist used to be.
typedef PlaylistPost = Future<String?> Function(String url, String body);

Future<List<PlaylistVideo>> readPlaylistVideos({
  required String playlistId,
  required Future<String?> Function(String url) fetch,
  PlaylistPost? post,
  int max = 400,
}) async {
  final out = <PlaylistVideo>[];
  final seen = <String>{};

  var page = await fetch('https://www.youtube.com/playlist?list=$playlistId&hl=en');

  // The page carries everything the next request needs: the key its own browse
  // endpoint wants and the client version the rest of the payload is built for.
  // A key pasted in here would be a secret in the repo, and a stale one.
  final key = page == null ? null : _innertubeKeyIn(page);
  final clientVersion = page == null ? null : _clientVersionIn(page);
  final browseUrl = key == null
      ? null
      : 'https://www.youtube.com/youtubei/v1/browse?key=$key';

  String? continuation;

  while (out.length < max) {
    if (page == null || page.isEmpty) break;

    final root = _initialDataIn(page) ?? _decodeJson(page);
    if (root == null) break;

    final items = _playlistItemsIn(root);
    if (items.isEmpty) break;

    final found = _videosIn(items);
    if (found.isEmpty) break;

    var fresh = 0;
    for (final v in found) {
      if (seen.add(v.id)) {
        out.add(v);
        fresh++;
      }
    }

    final next = _continuationIn(items);

    if (fresh == 0 || next == null || next == continuation) break;
    continuation = next;

    if (post == null || browseUrl == null || clientVersion == null) break;
    page = await post(browseUrl, _browseBody(next, clientVersion));
  }

  return out;
}

/// The playlist's own rows — the one list in the payload that holds them.
///
/// Both a playlist page and every continuation page carry more than the
/// playlist: sidebars and "recommended" shelves are full of eleven-character
/// video ids that look exactly like tracks. Reading the whole document pulled
/// videos in that were never in the list, so a 110-track playlist imported as
/// 141. The rows live in one `itemSectionRenderer` on a page and in the appended
/// continuation items on every page after it.
List<Object?> _playlistItemsIn(Object? root) {
  if (root is! Map) return const [];

  final actions = root['onResponseReceivedActions'];
  if (actions is List) {
    for (final a in actions) {
      if (a is! Map) continue;
      for (final key in const [
        'appendContinuationItemsAction',
        'reloadContinuationItemsCommand',
      ]) {
        final append = a[key];
        if (append is Map) {
          final items = append['continuationItems'];
          if (items is List && items.isNotEmpty) return items;
        }
      }
    }
  }

  final sectionList = _firstMap(root, 'sectionListRenderer');
  final sections = sectionList?['contents'];
  if (sections is List) {
    for (final s in sections) {
      final items = _firstMap(s, 'itemSectionRenderer')?['contents'];
      if (items is List && items.isNotEmpty) return items;
    }
  }

  // An older payload shape: the rows are already renderers at the top level.
  final renderers = _firstList(root, 'playlistVideoListRenderer');
  if (renderers != null) return renderers;

  return const [];
}

/// The first map under [node] that carries [key], depth first, in document order.
Map<String, dynamic>? _firstMap(Object? node, String key) {
  if (node is Map) {
    final v = node[key];
    if (v is Map) return Map<String, dynamic>.from(v);
    for (final child in node.values) {
      final hit = _firstMap(child, key);
      if (hit != null) return hit;
    }
  } else if (node is List) {
    for (final child in node) {
      final hit = _firstMap(child, key);
      if (hit != null) return hit;
    }
  }
  return null;
}

/// The `contents` list of the first [key] renderer under [node].
List<Object?>? _firstList(Object? node, String key) {
  final renderer = _firstMap(node, key);
  final contents = renderer?['contents'];
  return contents is List ? contents : null;
}

String? _innertubeKeyIn(String html) =>
    RegExp(r'"INNERTUBE_API_KEY"\s*:\s*"([^"]+)"').firstMatch(html)?.group(1);

String? _clientVersionIn(String html) =>
    RegExp(r'"INNERTUBE_CLIENT_VERSION"\s*:\s*"([^"]+)"').firstMatch(html)?.group(1);

String _browseBody(String token, String clientVersion) => jsonEncode({
  'context': {
    'client': {
      'clientName': 'WEB',
      'clientVersion': clientVersion,
      'hl': 'en',
    },
  },
  'continuation': token,
});

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
