library;

import 'dart:convert';
import 'dart:io';

class Playlist {
  // ignore: prefer_initializing_formals
  Playlist({
    required this.id,
    required String name,
    List<String>? trackIds,
    int? createdAt,
    int? updatedAt,
  })
      // ignore: prefer_initializing_formals
      : _name = name,
        _trackIds = [...?trackIds],
        createdAt = createdAt ?? 0,
        updatedAt = updatedAt ?? createdAt ?? 0;

  final String id;
  String _name;
  final List<String> _trackIds;

  final int createdAt;

  int updatedAt;

  String get name => _name;
  List<String> get trackIds => List.unmodifiable(_trackIds);
  int get length => _trackIds.length;
  bool get isEmpty => _trackIds.isEmpty;

  bool contains(String trackId) => _trackIds.contains(trackId);

  void rename(String name) {
    final trimmed = name.trim();

    if (trimmed.isEmpty || trimmed == _name) return;
    _name = trimmed;
    _touch();
  }

  void _touch() => updatedAt = DateTime.now().millisecondsSinceEpoch;

  bool add(String trackId) {
    if (_trackIds.contains(trackId)) return false;
    _trackIds.add(trackId);
    _touch();
    return true;
  }

  bool remove(String trackId) {
    final gone = _trackIds.remove(trackId);
    if (gone) _touch();
    return gone;
  }

  bool move(int from, int to) {
    if (from < 0 || from >= _trackIds.length) return false;
    if (to < 0 || to >= _trackIds.length) return false;
    if (from == to) return true;
    final id = _trackIds.removeAt(from);
    _trackIds.insert(to, id);
    _touch();
    return true;
  }

  int prune(Set<String> libraryIds) {
    final before = _trackIds.length;
    _trackIds.removeWhere((id) => !libraryIds.contains(id));
    return before - _trackIds.length;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': _name,
        'track_ids': _trackIds,

        if (createdAt > 0) 'created_at': createdAt,
        if (updatedAt > 0) 'updated_at': updatedAt,
      };

  static Playlist? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;
    final raw = json['track_ids'];
    final ids = raw is List
        ? raw.whereType<String>().toList(growable: false)
        : const <String>[];

    final seen = <String>{};
    return Playlist(
      id: id,
      name: name,
      trackIds: [for (final t in ids) if (seen.add(t)) t],
      createdAt: json['created_at'] is num ? (json['created_at']! as num).toInt() : null,
      updatedAt: json['updated_at'] is num ? (json['updated_at']! as num).toInt() : null,
    );
  }
}

/// Lists an earlier build seeded. Kept so an install can drop the ones that resolve to nothing.
const Set<String> kSeedPlaylistIds = {
  'home',
  'gym',
  'uni',
  'commuting',
  'p3r',
  'p4r',
  'p5r',
  'weathering',
  'us_uk',
  'vpop',
  'kpop',
  'jpop',
  'v_acoustic',
  'v_instrumental',
  'v_rain',
  'v_snow',
  'v_arrange',
  'v_long',
  'v_short',
  'v_morning',
  'v_afternoon',
  'v_evening',
};

const Set<String> kContextDrivenListIds = {
  'v_acoustic',
  'v_instrumental',
  'v_rain',
  'v_snow',
  'v_arrange',
  'v_long',
  'v_short',
  'v_morning',
  'v_afternoon',
  'v_evening',
  'home',
  'gym',
  'uni',
  'commuting',
};

abstract interface class PlaylistsView {
  List<Playlist> get all;
  Playlist? byId(String id);
  int get length;
}

class PlaylistList implements PlaylistsView {
  PlaylistList([List<Playlist>? initial]) : _lists = [...?initial];

  String _freshId() {
    final base = 'pl_${DateTime.now().microsecondsSinceEpoch}';
    if (byId(base) == null) return base;
    var n = 2;
    while (byId('${base}_$n') != null) {
      n++;
    }
    return '${base}_$n';
  }

  final List<Playlist> _lists;

  @override
  List<Playlist> get all => List.unmodifiable(_lists);

  @override
  int get length => _lists.length;
  bool get isEmpty => _lists.isEmpty;

  @override
  Playlist? byId(String id) {
    for (final p in _lists) {
      if (p.id == id) return p;
    }
    return null;
  }

  Playlist? byName(String name) {
    final want = name.trim().toLowerCase();
    for (final p in _lists) {
      if (p.name.toLowerCase() == want) return p;
    }
    return null;
  }

  void insert(int at, Playlist playlist) {
    final i = at.clamp(0, _lists.length);
    _lists.insert(i, playlist);
  }

  Playlist create(String name, {String? id, List<String>? trackIds}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('a playlist needs a name');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final playlist = Playlist(
      id: id ?? _freshId(),
      name: trimmed,
      trackIds: trackIds,

      createdAt: now,
      updatedAt: now,
    );
    _lists.add(playlist);
    return playlist;
  }

  Playlist ensure(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('a playlist needs a name');
    final existing = byName(trimmed);
    if (existing != null) return existing;
    return create(trimmed);
  }

  bool addTrack(Playlist playlist, String trackId) =>
      playlist.add(trackId);

  bool delete(String id) {
    final before = _lists.length;
    _lists.removeWhere((p) => p.id == id);
    return _lists.length != before;
  }

  static List<String> artistsOf(Iterable<dynamic> tracks) {
    final byFold = <String, String>{};
    for (final t in tracks) {
      final a = (t.artist as String?)?.trim() ?? '';
      if (a.isEmpty) continue;
      byFold.putIfAbsent(a.toLowerCase(), () => a);
    }
    final out = byFold.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }

  int prune(Set<String> libraryIds) {
    var removed = 0;
    for (final p in _lists) {
      removed += p.prune(libraryIds);
    }
    return removed;
  }

  int dropEmptySeeds() {
    final before = _lists.length;
    _lists.removeWhere((p) => kSeedPlaylistIds.contains(p.id) && p.trackIds.isEmpty);
    return before - _lists.length;
  }
}

class PlaylistStore {
  PlaylistStore(this.file);

  final File file;

  static PlaylistList decode(String source) {
    final raw = jsonDecode(source);
    if (raw is! Map) return PlaylistList();
    final list = raw['playlists'];
    if (list is! List) return PlaylistList();
    final out = <Playlist>[];
    final seenIds = <String>{};
    for (final item in list) {
      if (item is! Map) continue;
      final p = Playlist.fromJson(item.cast<String, Object?>());

      if (p != null && seenIds.add(p.id)) out.add(p);
    }
    return PlaylistList(out);
  }

  Future<PlaylistList> load() async {
    if (!file.existsSync()) return PlaylistList();
    try {
      return PlaylistStore.decode(await file.readAsString());
    } on FormatException {
      return PlaylistList();
    } on FileSystemException {
      return PlaylistList();
    }
  }

  Future<void> save(PlaylistsView lists) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({
      'playlists': [for (final p in lists.all) p.toJson()],
    }));
  }
}
