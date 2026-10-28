library;

import 'dart:math';

import '../library/track.dart';

const int kNoRepeatWindow = 12;

const Duration kSkipThreshold = Duration(seconds: 10);

const Duration kFinishTolerance = Duration(seconds: 5);

enum PlayOutcome {
  skippedEarly,

  skippedLate,

  completed,
}

enum RepeatMode {
  off,

  all,

  one,
}

PlayOutcome classifyOutcome({
  required Duration positionWhenStopped,
  required Duration trackDuration,
  Duration skipThreshold = kSkipThreshold,
}) {
  if (trackDuration <= Duration.zero) return PlayOutcome.skippedEarly;

  final remaining = trackDuration - positionWhenStopped;
  if (remaining <= kFinishTolerance) return PlayOutcome.completed;

  if (positionWhenStopped < skipThreshold) return PlayOutcome.skippedEarly;
  return PlayOutcome.skippedLate;
}

enum InsertPolicy {
  append,

  refuse,

  move,

  blind,
}

class PlayQueue {
  PlayQueue({
    required List<Track> source,
    Random? random,
    bool shuffle = false,
  }) : _random = random ?? Random() {
    _shuffle = shuffle;
    _source = List<Track>.from(source);
    _rebuild();
  }

  final Random _random;
  bool _shuffle = false;
  late List<Track> _source;

  List<Track> _order = const [];

  final List<String> _history = [];

  int _index = 0;

  List<Track> get order => List.unmodifiable(_order);
  int get index => _index;
  bool get isEmpty => _order.isEmpty;
  int get length => _order.length;
  bool get isShuffled => _shuffle;

  int get orderVersion => _orderVersion;
  int _orderVersion = 0;
  void _bumpOrder() => _orderVersion++;

  int _engineOrderVersion = -1;
  bool get engineIsStale => _engineOrderVersion != _orderVersion;
  void markEngineSynced() => _engineOrderVersion = _orderVersion;

  Track? get current => _order.isEmpty ? null : _order[_index];

  List<Track> get upcoming =>
      _order.isEmpty ? const [] : _order.sublist(_index + 1);

  List<Track> get played => _order.isEmpty ? const [] : _order.sublist(0, _index);

  void _startNewPass() {
    _order = _shuffle ? _shuffledOrder() : List<Track>.from(_source);
    _bumpOrder();
  }

  void _rebuild() {
    _order = _shuffle ? _shuffledOrder() : List<Track>.from(_source);
    if (_index >= _order.length) _index = _order.isEmpty ? 0 : _order.length - 1;
    _bumpOrder();
  }

  void _rebuildReset() {
    _index = 0;
    _order = _shuffle ? _shuffledOrder() : List<Track>.from(_source);
    _bumpOrder();
  }

  List<Track> _shuffledOrder() {
    final pool = List<Track>.from(_source);
    if (pool.length <= 1) return pool;

    final recent = _history.length > kNoRepeatWindow
        ? _history.sublist(_history.length - kNoRepeatWindow)
        : List<String>.from(_history);
    final recentSet = recent.toSet();

    final fresh = pool.where((t) => !recentSet.contains(t.id)).toList();
    final stale = pool.where((t) => recentSet.contains(t.id)).toList();
    fresh.shuffle(_random);
    stale.shuffle(_random);

    return [...fresh, ...stale];
  }

  void _rerollKeepingCurrent() {
    final playing = current;
    _rebuild();
    if (playing != null) {
      final at = _order.indexWhere((t) => t.id == playing.id);
      if (at >= 0) _index = at;
    }
  }

  void replaceSource(List<Track> source, {bool keepPlaying = false}) {
    if (!keepPlaying) {
      _source = List<Track>.from(source);
      _rebuildReset();
      return;
    }

    final playing = current;
    _source = List<Track>.from(source);
    _rebuild();
    if (playing != null) {
      final at = _order.indexWhere((t) => t.id == playing.id);
      if (at >= 0) _index = at;
    }
  }

  bool appendSource(List<Track> source) {
    if (source.isEmpty) return false;
    final present = {for (final t in _source) t.id};
    final fresh = [for (final t in source) if (present.add(t.id)) t];
    if (fresh.isEmpty) return false;
    _source.addAll(fresh);

    _rebuild();
    return true;
  }

  void setShuffle(bool value) {
    if (_shuffle == value) return;
    _shuffle = value;

    _rerollKeepingCurrent();
  }

  Track? next({required bool wrap}) {
    final leaving = current;
    if (leaving != null) _history.add(leaving.id);
    if (_order.isEmpty) return null;

    if (_index + 1 >= _order.length) {
      if (!wrap) return null;
      _index = 0;

      _startNewPass();
      return current;
    }

    _index++;
    return current;
  }

  Track? previous() {
    if (_order.isEmpty) return null;
    _index = (_index - 1 + _order.length) % _order.length;
    return current;
  }

  bool jumpTo(String trackId) {
    final at = _order.indexWhere((t) => t.id == trackId);
    if (at < 0) return false;
    _index = at;
    return true;
  }

  bool replaceCurrent(Track replacement) {
    final at = _index;
    if (at < 0 || at >= _order.length) return false;

    final oldId = _order[at].id;
    if (oldId == replacement.id) return false;

    final next = <Track>[];
    for (var i = 0; i < _order.length; i++) {
      if (i == at) {
        next.add(replacement);
        continue;
      }
      if (_order[i].id == replacement.id) continue;
      next.add(_order[i]);
    }
    _order = next;

    _bumpOrder();

    _index = _order.indexWhere((t) => t.id == replacement.id);

    final srcAt = _source.indexWhere((t) => t.id == oldId);
    if (srcAt >= 0) {
      _source[srcAt] = replacement;
    } else {
      _source.add(replacement);
    }

    for (var i = _source.length - 1; i >= 0; i--) {
      if (_source[i].id == replacement.id && i != srcAt) _source.removeAt(i);
    }
    _bumpOrder();
    return true;
  }

  void restoreOrder(List<String> ids) {
    if (ids.isEmpty) return;

    final byId = {for (final t in _source) t.id: t};
    final restored = <Track>[];
    for (final id in ids) {
      final t = byId[id];
      if (t != null) restored.add(t);
    }
    for (final t in _source) {
      if (!restored.any((r) => r.id == t.id)) restored.add(t);
    }

    if (restored.isEmpty) return;
    _order = restored;
    _index = _index.clamp(0, _order.length - 1);
    _bumpOrder();
  }

  void _insert(
    List<Track> tracks, {
    required InsertPolicy policy,
  }) {
    if (tracks.isEmpty) return;

    if (policy != InsertPolicy.blind) {
      final wanted = {for (final t in tracks) t.id};
      if (policy == InsertPolicy.move) {
        final playingId = current?.id;
        final wasAt = _index;
        // Promoting the track that is already playing would pull the index out
        // from under playback; leave it where it is and move the others.
        if (playingId != null && wanted.contains(playingId)) {
          tracks = [for (final t in tracks) if (t.id != playingId) t];
          wanted.remove(playingId);
          if (tracks.isEmpty) return;
        }
        _order.removeWhere((t) => wanted.contains(t.id));
        // Removing tracks ABOVE the current one shifts every index below it, so
        // re-find the playing track instead of trusting the old number.
        final playingAt =
            playingId == null ? -1 : _order.indexWhere((t) => t.id == playingId);
        if (playingAt >= 0) {
          _index = playingAt;
        } else {
          _index = wasAt.clamp(0, _order.isEmpty ? 0 : _order.length - 1);
        }
      } else if (policy == InsertPolicy.refuse) {
        final fresh = [
          for (final t in tracks)
            if (!_order.any((o) => o.id == t.id)) t,
        ];
        tracks = fresh;
        if (tracks.isEmpty) return;
      }
    }

    final at = switch (policy) {
      InsertPolicy.append || InsertPolicy.refuse => _order.length,

      InsertPolicy.move || InsertPolicy.blind =>
        (_index + 1).clamp(0, _order.length),
    };
    _order.insertAll(at, tracks);

    if (policy == InsertPolicy.append || policy == InsertPolicy.refuse) {
      for (final t in tracks) {
        if (!_source.any((s) => s.id == t.id)) _source.add(t);
      }
    }
    _bumpOrder();
  }

  void playNext(Track track) => _insert([track], policy: InsertPolicy.move);

  void promoteToNext(List<Track> tracks) =>
      _insert(tracks, policy: InsertPolicy.move);

  bool append(Track track) {
    if (_order.any((t) => t.id == track.id)) return false;
    _insert([track], policy: InsertPolicy.append);
    return true;
  }

  bool move(int from, int to) {
    if (from < 0 || from >= _order.length) return false;
    if (to < 0 || to >= _order.length) return false;
    if (from == to) return true;

    final playing = current;
    final track = _order.removeAt(from);
    _order.insert(to, track);

    if (playing != null) {
      final at = _order.indexWhere((t) => t.id == playing.id);
      if (at >= 0) _index = at;
    }
    _bumpOrder();
    return true;
  }

  bool remove(String trackId) {
    final at = _order.indexWhere((t) => t.id == trackId);
    if (at < 0) return false;
    final wasCurrent = at == _index;
    _order.removeAt(at);
    _source.removeWhere((t) => t.id == trackId);
    if (_order.isEmpty) {
      _index = 0;
    } else if (wasCurrent) {
      _index = at.clamp(0, _order.length - 1);
    } else if (at < _index) {
      _index -= 1;
    }
    _bumpOrder();
    return true;
  }
}
