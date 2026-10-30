library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class LyricLine {
  const LyricLine(this.at, this.text);

  final Duration at;
  final String text;

  static LyricLine? parse(String raw) {
    final all = parseAll(raw);
    return all.isEmpty ? null : all.first;
  }

  /// A line can carry several stamps: `[00:12][00:45]x`. Stamps: mm:ss,
  /// mm:ss.cs or hh:mm:ss.
  static List<LyricLine> parseAll(String raw) {
    var rest = raw.trim();
    if (!rest.startsWith('[')) return const [];

    final stamps = <Duration>[];
    while (rest.startsWith('[')) {
      final close = rest.indexOf(']');
      if (close <= 1) return const [];
      final at = _stamp(rest.substring(1, close));
      // A bracket head that is not a stamp is a tag, not half a timed line.
      if (at == null) return const [];
      stamps.add(at);
      rest = rest.substring(close + 1);
    }
    if (stamps.isEmpty) return const [];

    final text = rest.trim();
    return [for (final at in stamps) LyricLine(at, text)];
  }

  static Duration? _stamp(String stamp) {
    final parts = stamp.split(':');
    if (parts.length < 2 || parts.length > 3) return null;

    final nums = <double>[];
    for (final part in parts) {
      // "-00" parses to -0.0, which is not < 0: check the sign as text.
      if (part.trimLeft().startsWith('-')) return null;
      final v = double.tryParse(part.replaceAll(',', '.'));
      if (v == null) return null;
      nums.add(v);
    }

    final ms = nums.length == 2
        ? nums[0] * 60000 + nums[1] * 1000
        : nums[0] * 3600000 + nums[1] * 60000 + nums[2] * 1000;
    if (ms.isNaN || ms < 0) return null;
    return Duration(milliseconds: ms.round());
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

/// YouTube titles arrive dressed: "Artist - Song（OFFICIAL VIDEO）", "Song [MV]",
/// "Song (Lyric Video)". None of that is in LRCLIB's index, so it is stripped
/// before asking — and a leading "Artist - " is dropped too, because the artist
/// is already sent as its own field.
String normaliseQuery(String title) {
  var t = title;

  // Full-width punctuation is what Japanese uploads use; the ASCII rules below
  // never fired on it.
  t = t.replaceAll('（', '(').replaceAll('）', ')');
  t = t.replaceAll('【', '[').replaceAll('】', ']');
  t = t.replaceAll('　', ' ');

  t = t.replaceAll(
    RegExp(
      r'[\(\[]\s*(official\s*)?(music\s*)?(video|audio|mv|m/v|lyric\s*video|'
      r'lyrics?|visuali[sz]er|live|full\s*ver\.?|short\s*ver\.?)'
      r'\s*[\)\]]',
      caseSensitive: false,
    ),
    ' ',
  );
  t = t.replaceAll(
    RegExp(
      r'\b(official\s*)?(music\s*)?video\b.*$|\bofficial\s*audio\b.*$|'
      r'\b(mv|m/v)\b.*$|\blyric\s*video\b.*$',
      caseSensitive: false,
    ),
    ' ',
  );

  // "Song (feat. X)" is the same song; the guest does not change the lyric.
  t = t.replaceAll(
    RegExp(r'[\\(\[]?\s*\b(feat\.?|ft\.?|featuring)\s+[^)\]\n]*[)\]]?',
        caseSensitive: false),
    ' ',
  );
  // "Song - Remastered 2011", "Song (Remaster)", "Song - Single Version".
  t = t.replaceAll(
    RegExp(
      r'[-–—\(\[]\s*(\d{4}\s*)?(digital(ly)?\s*)?(re)?master(ed)?(\s*\d{4})?\s*[)\)\]]?',
      caseSensitive: false,
    ),
    ' ',
  );
  t = t.replaceAll(
    RegExp(
      r'[-–—\(\[]\s*(single|album|bonus track|radio edit|explicit)\s*(version|edit)?\s*[)\)\]]?',
      caseSensitive: false,
    ),
    ' ',
  );

  t = t.replaceAll(RegExp(r'\bcover\b.*$', caseSensitive: false), ' ');

  t = t.replaceAll(RegExp(r'[\(\[]\s*(feat|ft|with)\b.*?[\)\]]', caseSensitive: false), ' ');
  t = t.replaceAll(RegExp(r'\b(feat|ft)\.?\s.*$', caseSensitive: false), ' ');

  final segments = t.split('...').map((e) => e.trim()).where((e) => e.isNotEmpty);
  if (segments.isNotEmpty) {
    t = segments.reduce((a, b) => a.length >= b.length ? a : b);
  }

  final dashed = RegExp(r'^(.{2,40}?)\s+[-–—]\s+(.+)$').firstMatch(t);
  if (dashed != null && dashed.group(2)!.trim().length >= 2) {
    t = dashed.group(2)!;
  }

  t = t.replaceAll(RegExp(r'[\-–—/|]+\s*$'), ' ');

  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

  return t.isEmpty ? title.trim() : t;
}

/// "ヨルシカ / n-buna Official" is a channel, not an artist. LRCLIB indexes the
/// artist, so the channel decorations are cut before the query.
String cleanArtist(String artist) {
  var a = artist;
  for (final sep in const [' / ', '/', ' & ', '&', ' x ', ' × ', ',', ' - ']) {
    final at = a.indexOf(sep);
    if (at > 0) a = a.substring(0, at);
  }
  a = a.replaceAll(
    RegExp(
      r'\b(official\s*channel|official|vevo|topic|music|channel|records)\b',
      caseSensitive: false,
    ),
    ' ',
  );
  a = a.replaceAll(RegExp(r'\s+'), ' ').trim();
  return a.isEmpty ? artist.trim() : a;
}

/// Every way an upload title might be the song title. LRCLIB indexes songs, not
/// videos: "April Encounter - 很美味 (Hen Meiwei)《当我飞奔向你》Chi/Eng/Pinyin
/// lyrics" has to be read down to "April Encounter" before it will match.
Iterable<String> queryReadings(String raw) sync* {
  final t = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return;

  // Cut the trailing show name, romanisation and "lyrics" tags in one go.
  final bare = t
      .replaceAll(RegExp(r'\s*[\(\[《【〈][^\)\]》】〉]*[\)\]》】〉]'), ' ')
      .replaceAll(
        RegExp(
          r'\s*\b(lyrics?|lyric video|eng(lish)?\s*sub|chi/eng(/pinyin)?|'
          r'han/rom/eng|color coded|official( video)?|audio|mv|hd)\b.*$',
          caseSensitive: false,
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final seen = <String>{};
  for (final piece in <String>[
    bare,
    ...t.split(RegExp(r'\s+[-–—|]\s+')),
    ...bare.split(RegExp(r'\s+[-–—|]\s+')),
  ]) {
    final read = piece
        .replaceAll(RegExp(r'[\-–—/|]+\s*$'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (read.length < 2) continue;
    if (seen.add(read.toLowerCase())) yield read;
  }
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
    Duration? duration,
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
      fetched = await _fetch(
        title: title,
        artist: artist,
        duration: duration,
      );
    } on SocketException {
      fetched = null;
    } on http.ClientException {
      fetched = null;
    } on FormatException {
      fetched = null;
    }

    if (fetched != null && !fetched.isEmpty) {
      await _writeCache(trackId, fetched);
      _memory[trackId] = fetched;
    }
    return fetched;
  }

  Future<Lyrics?> _fetch({
    required String title,
    required String artist,
    Duration? duration,
  }) async {
    final who = cleanArtist(artist);

    // An upload title is not a song title. "April Encounter - 很美味 (Hen Meiwei)
    // 《当我飞奔向你》Chi/Eng/Pinyin lyrics" is one song written five ways, and
    // the old rule — keep what follows the dash — threw away the only part
    // LRCLIB knows. Every plausible reading is tried, best first.
    final candidates = <String>{normaliseQuery(title)};
    for (final read in queryReadings(title)) {
      candidates.add(read);
    }
    candidates.removeWhere((c) => c.trim().isEmpty);

    Map<String, dynamic>? hit;
    for (final wanted in candidates) {
      hit = _bestOf(
        await _search({
          'track_name': wanted,
          if (who.isNotEmpty) 'artist_name': who,
        }),
        title: wanted,
        artist: who,
        duration: duration,
      );
      // The channel name is usually not the artist, so the strict query fails
      // on anything uploaded by a fan account. Title alone is the second read.
      // Title alone means title alone: keeping the channel name here rejected
      // every fan upload, because LRCLIB files the song under its real artist.
      hit ??= _bestOf(
        await _search({'track_name': wanted}),
        title: wanted,
        artist: '',
        duration: duration,
      );
      if (hit != null) break;
    }

    if (hit == null) {
      return Lyrics(lines: const [], instrumental: false, source: 'not found');
    }

    // LRCLIB tags instrumentals; saying "no lyrics" for one is a wrong answer.
    if (hit['instrumental'] == true &&
        ((hit['syncedLyrics'] as String?)?.isEmpty ?? true) &&
        ((hit['plainLyrics'] as String?)?.isEmpty ?? true)) {
      return const Lyrics(lines: [], instrumental: true, source: 'lrclib');
    }

    final synced = hit['syncedLyrics'] as String?;
    if (synced != null && synced.isNotEmpty) {
      final lines = <LyricLine>[];
      for (final raw in synced.split('\n')) {
        for (final line in LyricLine.parseAll(raw)) {
          if (line.text.isNotEmpty) lines.add(line);
        }
      }
      // Out-of-sequence repeated-stamp lines would never advance the highlight.
      lines.sort((a, b) => a.at.compareTo(b.at));
      if (lines.isNotEmpty) {
        return Lyrics(lines: lines, source: 'lrclib (synced)');
      }
    }

    final plain = hit['plainLyrics'] as String?;
    if (plain != null && plain.isNotEmpty) {
      return Lyrics(lines: const [], plain: plain, source: 'lrclib (plain)');
    }

    return Lyrics(lines: const [], instrumental: false, source: 'not found');
  }

  /// LRCLIB answers 429/503 when it is busy. Treating that as "this song has no
  /// lyrics" is why some tracks came up empty and stayed empty for the session.
  Future<List<dynamic>> _search(Map<String, String> query) async {
    final uri = Uri.https('lrclib.net', '/api/search', query);
    for (var attempt = 0; attempt < 6; attempt++) {
      try {
        final response =
            await _client.get(uri).timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          return decoded is List ? decoded : const [];
        }
        if (response.statusCode != 429 && response.statusCode < 500) {
          return const [];
        }
      } on SocketException {
        // Retried below.
      } on http.ClientException {
        // Retried below.
      } on TimeoutException {
        // Retried below.
      } on FormatException {
        return const [];
      }
      await Future<void>.delayed(
        Duration(milliseconds: 500 * (attempt + 1) + (attempt * 137)),
      );
    }
    // Every attempt hit a busy or unreachable server. Returning an empty list
    // here made a 503 look like "this song has no lyrics" and cached it.
    return const [];
  }

  /// The best row for this song, and only when it really is this song: a
  /// title-only search happily returns a different song by the same artist,
  /// and wrong lyrics are worse than none.
  Map<String, dynamic>? _bestOf(
    List<dynamic> rows, {
    required String title,
    required String artist,
    Duration? duration,
  }) {
    Map<String, dynamic>? synced;
    Map<String, dynamic>? plain;
    // Same song, different cut: a video that carries the track plus three
    // minutes of the drama it soundtracked. Better lyrics than none.
    Map<String, dynamic>? farSynced;
    Map<String, dynamic>? farPlain;
    for (final row in rows) {
      if (row is! Map) continue;
      final map = row.cast<String, dynamic>();
      final name = normaliseQuery('${map['trackName'] ?? ''}');
      // Always: a row whose title is a different song is not this song, no
      // matter how well the artist field matches.
      if (!_sameTitle(name, title)) continue;
      final by = cleanArtist('${map['artistName'] ?? ''}');
      final artistOk = artist.isEmpty ||
          by.isEmpty ||
          _sameTitle(by, artist) ||
          by.toLowerCase().contains(artist.toLowerCase()) ||
          artist.toLowerCase().contains(by.toLowerCase());
      if (!artistOk) continue;
      // Two versions of one song can share a title and an artist — the live
      // take, the remaster, the sped-up edit. The length tells them apart.
      final seconds = map['duration'];
      if (duration != null && seconds is num && seconds > 0) {
        final gap = (seconds - duration.inSeconds).abs();
        // A video that opens on dialogue runs minutes longer than the track it
        // contains. Short songs get a floor, long ones a proportional window.
        final window = duration.inSeconds < 90 ? 20 : duration.inSeconds * 0.2;
        if (gap > window) {
          final hasSynced = (map['syncedLyrics'] as String?)?.isNotEmpty ?? false;
          if (hasSynced) {
            farSynced ??= map;
          } else if ((map['plainLyrics'] as String?)?.isNotEmpty ?? false) {
            farPlain ??= map;
          }
          continue;
        }
      }
      final hasSynced = (map['syncedLyrics'] as String?)?.isNotEmpty ?? false;
      if (hasSynced) {
        synced ??= map;
      } else if ((map['plainLyrics'] as String?)?.isNotEmpty ?? false) {
        plain ??= map;
      }
    }
    return synced ?? plain ?? farSynced ?? farPlain;
  }

  /// Same song title across the punctuation and spacing the two sides disagree
  /// about: "あぶく（OFFICIAL VIDEO）" against "あぶく".
  bool _sameTitle(String a, String b) {
    String squeeze(String v) => v
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\u3000]+'), '')
        .replaceAll(RegExp(r'[\p{P}\p{S}]', unicode: true), '');
    final x = squeeze(a);
    final y = squeeze(b);
    if (x.isEmpty || y.isEmpty) return false;
    return x == y || x.contains(y) || y.contains(x);
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
