library;

import 'dart:convert';
import 'dart:io';

import 'track.dart';

enum TagField { title, artist, album }

String _keyOf(TagField f) => switch (f) {
      TagField.title => 'title',
      TagField.artist => 'artist',
      TagField.album => 'album',
    };

TagField? tagFieldFromKey(String key) {
  for (final f in TagField.values) {
    if (_keyOf(f) == key) return f;
  }
  return null;
}

String tagFieldLabel(TagField f) => switch (f) {
      TagField.title => 'Title',
      TagField.artist => 'Artist',
      TagField.album => 'Album',
    };

class TagOverrides {
  TagOverrides([Map<String, Map<String, String>>? raw])
      : _byTrack = {
          for (final e in (raw ?? const {}).entries)
            e.key: {...e.value},
        };

  final Map<String, Map<String, String>> _byTrack;

  bool get isEmpty => _byTrack.isEmpty;
  int get length => _byTrack.length;

  int get fieldCount =>
      _byTrack.values.fold(0, (sum, fields) => sum + fields.length);

  Map<String, String> forTrack(String trackId) =>
      Map.unmodifiable(_byTrack[trackId] ?? const {});

  Map<String, Map<String, String>> get all => Map.unmodifiable({
        for (final e in _byTrack.entries) e.key: Map.unmodifiable(e.value),
      });

  void set(String trackId, TagField field, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      clearField(trackId, field);
      return;
    }
    (_byTrack[trackId] ??= {})[_keyOf(field)] = trimmed;
  }

  void clearField(String trackId, TagField field) {
    final fields = _byTrack[trackId];
    if (fields == null) return;
    fields.remove(_keyOf(field));
    if (fields.isEmpty) _byTrack.remove(trackId);
  }

  void clearTrack(String trackId) => _byTrack.remove(trackId);

  void clearAll() => _byTrack.clear();

  Track apply(Track t) {
    final fields = _byTrack[t.id];
    if (fields == null || fields.isEmpty) return t;
    return t.withMetadata(
      title: fields['title'],
      artist: fields['artist'],
      album: fields['album'],
    );
  }

  List<Track> applyAll(List<Track> tracks) =>
      [for (final t in tracks) apply(t)];

  int prune(Set<String> libraryIds) {
    final before = _byTrack.length;
    _byTrack.removeWhere((id, _) => !libraryIds.contains(id));
    return before - _byTrack.length;
  }

  Map<String, Object?> toJson() => {
        'overrides': {
          for (final e in _byTrack.entries)
            if (e.value.isNotEmpty) e.key: {...e.value},
        },
      };

  static TagOverrides decode(String source) {
    try {
      final raw = jsonDecode(source);
      if (raw is! Map) return TagOverrides();
      final map = raw['overrides'];
      if (map is! Map) return TagOverrides();
      final out = <String, Map<String, String>>{};
      map.forEach((trackId, fields) {
        if (trackId is! String || fields is! Map) return;
        final clean = <String, String>{};
        fields.forEach((k, v) {
          if (k is! String || v is! String) return;

          if (tagFieldFromKey(k) == null) return;
          if (v.trim().isEmpty) return;
          clean[k] = v.trim();
        });
        if (clean.isNotEmpty) out[trackId] = clean;
      });
      return TagOverrides(out);
    } on FormatException {
      return TagOverrides();
    }
  }
}

class TagOverrideStore {
  TagOverrideStore(this.file);

  final File file;

  Future<TagOverrides> load() async {
    if (!file.existsSync()) return TagOverrides();
    try {
      return TagOverrides.decode(await file.readAsString());
    } on FileSystemException {
      return TagOverrides();
    }
  }

  Future<void> save(TagOverrides overrides) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(overrides.toJson()));
  }
}
