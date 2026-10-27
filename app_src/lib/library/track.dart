library;

import 'variants.dart';

import 'dart:convert';

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

  static Track fromJson(Map<String, dynamic> json) {
    final rawDuration = json['duration_s'];
    return Track(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled').toString(),
      artist: (json['artist'] ?? 'Unknown Artist').toString(),
      album: (json['album'] ?? '').toString(),
      duration: Duration(
        milliseconds: ((rawDuration is num ? rawDuration : 0) * 1000).round(),
      ),
      file: (json['file'] ?? '').toString(),
      cover: (json['cover'] ?? '').toString(),
      gainDb: (json['gain_db'] as num?)?.toDouble(),

      romaji: (json['romaji'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['romaji'] as String).trim(),

      variantOf: (json['variant_of'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['variant_of'] as String).trim(),
      variantTag: isKnownVariantTag((json['variant'] as String?)?.trim())
          ? (json['variant'] as String).trim()
          : null,
    );
  }

  static List<Track> listFromManifest(String manifestJson) {
    final root = jsonDecode(manifestJson) as Map<String, dynamic>;
    final raw = root['tracks'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Track.fromJson)
        .where((t) => t.file.isNotEmpty)
        .toList(growable: false);
  }
}
