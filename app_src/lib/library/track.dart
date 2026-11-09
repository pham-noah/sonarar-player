library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

import 'variants.dart';

enum QueueSource {
  fixed,

  live,

  automatic,
}

class Track {
  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.file,
    this.variantOf,
    this.variantTag,
    required this.cover,
    required this.gainDb,
    this.romaji,
  }) : searchBlob =
            '$title $artist $album $file ${romaji ?? ''}'.toLowerCase();

  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;

  final String? romaji;

  final String file;

  final String? variantOf;

  final String? variantTag;

  final String cover;

  final double? gainDb;

  final String searchBlob;

  Track withMetadata({String? title, String? artist, String? album}) => Track(
        id: id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album ?? this.album,
        duration: duration,
        file: file,
        cover: cover,
        gainDb: gainDb,

        romaji: romaji,
        variantOf: variantOf,
        variantTag: variantTag,
      );

  bool matches(String query) => matchesTerms(searchTerms(query));

  static List<String> searchTerms(String query) {
    final q = query.trim().toLowerCase();
    return q.isEmpty ? const [] : q.split(RegExp(r'\s+'));
  }

  bool matchesTerms(List<String> terms) =>
      terms.isEmpty || terms.every(searchBlob.contains);

  /// Longer than any real recording; also far below the point where
  /// `Duration(microseconds:)` overflows.
  static const int maxDurationMs = 100 * Duration.millisecondsPerDay;

  /// A finite, positive number of seconds, or unknown. `-12`, `"long"` and
  /// `1e400` all read as unknown instead of bringing the library down.
  static Duration durationOf(Object? raw) {
    if (raw is! num || !raw.isFinite) return Duration.zero;
    final ms = raw * 1000;
    if (!ms.isFinite || ms <= 0) return Duration.zero;
    if (ms >= maxDurationMs) return const Duration(milliseconds: maxDurationMs);
    return Duration(milliseconds: ms.round());
  }

  static double? gainOf(Object? raw) =>
      raw is num && raw.isFinite ? raw.toDouble() : null;

  static String? tagOf(Object? raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Track fromJson(Map<String, dynamic> json) {
    final romaji = tagOf(json['romaji']);
    final variant = tagOf(json['variant']);
    return Track(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled').toString(),
      artist: (json['artist'] ?? 'Unknown Artist').toString(),
      album: (json['album'] ?? '').toString(),
      duration: durationOf(json['duration_s']),
      file: (json['file'] ?? '').toString(),
      cover: (json['cover'] ?? '').toString(),
      gainDb: gainOf(json['gain_db']),

      romaji: romaji,
      variantOf: tagOf(json['variant_of']),
      variantTag: isKnownVariantTag(variant) ? variant : null,
    );
  }

  /// Parses a manifest without trusting a single field in it.
  ///
  /// A manifest that cannot be read is an empty library, not a crash. Duplicate
  /// ids would make `jumpTo`, playlists and the queue disagree about which track
  /// they mean, so the first one wins and the rest are reported.
  static List<Track> listFromManifest(String manifestJson) {
    final root = jsonDecode(manifestJson);
    if (root is! Map) return const [];
    final raw = root['tracks'];
    if (raw is! List) return const [];

    final out = <Track>[];
    final seen = <String>{};
    for (final entry in raw) {
      if (entry is! Map) continue;
      final Track track;
      try {
        track = Track.fromJson(entry.cast<String, dynamic>());
      } catch (e) {
        debugPrint('[Sonarar][LIB] skipping unreadable track entry: $e');
        continue;
      }
      if (track.file.isEmpty) continue;
      if (!seen.add(track.id)) {
        debugPrint('[Sonarar][LIB] duplicate track id "${track.id}" ignored');
        continue;
      }
      out.add(track);
    }
    return List<Track>.unmodifiable(out);
  }
}
