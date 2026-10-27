library;

import 'dart:convert';
import 'dart:io';

class JsonMapStore<V> {
  JsonMapStore(this.file, {required this.encode, required this.decode});

  final File file;

  final Object Function(V) encode;

  final V? Function(Object?) decode;

  Future<Map<String, V>> load() async {
    if (!file.existsSync()) return {};
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return {};
      final out = <String, V>{};
      raw.forEach((k, v) {
        if (k is! String) return;
        final decoded = decode(v);
        if (decoded != null) out[k] = decoded;
      });
      return out;
    } on FormatException {
      return {};
    } on FileSystemException {
      return {};
    }
  }

  Future<void> save(Map<String, V> values) async {
    await file.parent.create(recursive: true);
    final out = <String, Object>{};
    values.forEach((k, v) => out[k] = encode(v));
    await file.writeAsString(jsonEncode(out));
  }
}

abstract interface class ExclusionIds {
  Set<String> get ids;
  bool contains(String trackId);
}

abstract interface class BookmarkMarks {
  Map<String, Duration> get all;
  Duration? at(String trackId);
  bool has(String trackId);
}

abstract interface class FavoritesView {
  Set<String> get ids;
  List<String> get orderedIds;
  bool contains(String trackId);
}

class ExclusionList implements ExclusionIds {
  ExclusionList([Set<String>? ids]) : _ids = {...?ids};

  final Set<String> _ids;

  @override
  Set<String> get ids => Set.unmodifiable(_ids);

  List<String> get orderedIds => _ids.toList(growable: false);

  int get length => _ids.length;
  bool get isEmpty => _ids.isEmpty;

  @override
  bool contains(String trackId) => _ids.contains(trackId);

  bool exclude(String trackId) => _ids.add(trackId);

  bool include(String trackId) => _ids.remove(trackId);

  void toggle(String trackId) {
    if (!_ids.remove(trackId)) _ids.add(trackId);
  }

  void clear() => _ids.clear();

  int prune(Set<String> libraryIds) {
    final before = _ids.length;
    _ids.removeWhere((id) => !libraryIds.contains(id));
    return before - _ids.length;
  }
}

class FavoritesList implements FavoritesView {
  FavoritesList([Set<String>? ids]) : _ids = {...?ids};

  final Set<String> _ids;

  @override
  Set<String> get ids => Set.unmodifiable(_ids);

  @override
  List<String> get orderedIds => _ids.toList(growable: false);

  int get length => _ids.length;
  bool get isEmpty => _ids.isEmpty;

  @override
  bool contains(String trackId) => _ids.contains(trackId);

  bool toggle(String trackId) {
    if (_ids.remove(trackId)) return false;
    _ids.add(trackId);
    return true;
  }

  bool add(String trackId) => _ids.add(trackId);
  bool remove(String trackId) => _ids.remove(trackId);
  void clear() => _ids.clear();

  int prune(Set<String> libraryIds) {
    final before = _ids.length;
    _ids.removeWhere((id) => !libraryIds.contains(id));
    return before - _ids.length;
  }
}

class BookmarkList implements BookmarkMarks {
  BookmarkList([Map<String, Duration>? marks]) : _marks = {...?marks};

  final Map<String, Duration> _marks;

  @override
  Map<String, Duration> get all => Map.unmodifiable(_marks);
  int get length => _marks.length;
  bool get isEmpty => _marks.isEmpty;

  @override
  Duration? at(String trackId) => _marks[trackId];
  @override
  bool has(String trackId) => _marks.containsKey(trackId);

  void set(String trackId, Duration position) => _marks[trackId] = position;
  void remove(String trackId) => _marks.remove(trackId);
  void clear() => _marks.clear();

  int prune(Set<String> libraryIds) {
    final before = _marks.length;
    _marks.removeWhere(
        (id, pos) => !libraryIds.contains(id) || pos <= Duration.zero);
    return before - _marks.length;
  }
}
