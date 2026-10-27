library;

import 'dart:convert';
import 'dart:io';

import '../art/art_focus.dart';

const Duration kResumeStaleAfter = Duration(days: 30);

class PlaybackSnapshot {
  const PlaybackSnapshot({
    required this.trackId,
    required this.positionMs,
    required this.queueIds,
    required this.queueIndex,
    required this.shuffle,
    required this.artKey,
    this.disbanded = false,
    this.repeat = 'off',
    this.queueMode = 'dynamic',
    required this.savedAt,
    this.volume = 1.0,
    this.artFocus = const {},
  });

  final String trackId;
  final int positionMs;
  final List<String> queueIds;
  final int queueIndex;
  final bool shuffle;

  final String repeat;

  final String queueMode;

  final bool disbanded;

  final String artKey;

  final DateTime savedAt;

  final double volume;

  final Map<String, ArtFocus> artFocus;

  bool get isStale =>
      DateTime.now().difference(savedAt) > kResumeStaleAfter;

  Map<String, dynamic> toJson() => {
        'track_id': trackId,
        'position_ms': positionMs,
        'queue_ids': queueIds,
        'queue_index': queueIndex,
        'shuffle': shuffle,
        'repeat': repeat,
        'queue_mode': queueMode,

        'character_key': artKey,
        'saved_at': savedAt.toIso8601String(),
        'volume': volume,
        if (disbanded) 'disbanded': true,

        if (artFocus.isNotEmpty)
          'art_focus': {
            for (final e in artFocus.entries) e.key: e.value.toJson(),
          },
      };

  static PlaybackSnapshot? fromJson(Map<String, dynamic> json) {
    final trackId = json['track_id'];

    final disbanded = json['disbanded'] == true;
    if (trackId is! String || (trackId.isEmpty && !disbanded)) return null;

    final rawQueue = json['queue_ids'];
    final queue = rawQueue is List
        ? rawQueue.whereType<String>().toList(growable: false)
        : const <String>[];

    return PlaybackSnapshot(
      trackId: trackId,
      disbanded: disbanded,
      positionMs: (json['position_ms'] as num?)?.toInt() ?? 0,
      queueIds: queue,
      queueIndex: (json['queue_index'] as num?)?.toInt() ?? 0,
      shuffle: json['shuffle'] == true,

      queueMode: json['queue_mode'] == 'fixed' ? 'fixed' : 'dynamic',
      repeat: switch ((json['repeat'] ?? '').toString()) {
        'all' => 'all',
        'one' => 'one',
        _ => 'off',
      },
      artKey: (json['character_key'] ?? '').toString(),
      savedAt: DateTime.tryParse((json['saved_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),

      volume: ((json['volume'] as num?)?.toDouble() ?? 1.0).clamp(0.0, 1.0),

      artFocus: _readArtFocus(json['art_focus']),
    );
  }

  static Map<String, ArtFocus> _readArtFocus(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, ArtFocus>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key is! String || key.isEmpty) continue;
      final focus = ArtFocus.fromJson(entry.value);
      if (focus != null) out[key] = focus;
    }
    return out;
  }
}

class SnapshotStore {
  SnapshotStore({required this.directory});

  final String directory;

  static const int schemaVersion = 1;

  File get _file => File('$directory/playback_state.json');

  Future<void> save(PlaybackSnapshot snap) async {
    try {
      final dir = Directory(directory);
      if (!await dir.exists()) await dir.create(recursive: true);
      await _file.writeAsString(jsonEncode({
        'version': schemaVersion,
        ...snap.toJson(),
      }));
    } on FileSystemException {
      // ignore: empty_catches
    }
  }

  Future<PlaybackSnapshot?> load() async {
    try {
      if (!await _file.exists()) return null;
      final raw = jsonDecode(await _file.readAsString());
      if (raw is! Map<String, dynamic>) return null;
      if (raw['version'] != schemaVersion) return null;
      return PlaybackSnapshot.fromJson(raw);
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      if (await _file.exists()) await _file.delete();
    } on FileSystemException {
      // ignore: empty_catches
    }
  }
}
