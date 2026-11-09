library;

import 'dart:collection';
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

/// A queued track and the place it holds in the unshuffled arrangement.
///
/// [rank] is a sort key, not a second copy of the order: it is the only memory the
/// queue keeps of where the track sat before a shuffle, so that turning shuffle off
/// has something to return to. Because it lives on the entry, the queue has one list
/// of tracks and no membership invariant to keep in sync by hand.
class _Slot {
  _Slot(this.track, this.rank);

  Track track;

  double rank;
}

class PlayQueue {
  PlayQueue({
    required List<Track> source,
    Random? random,
    bool shuffle = false,
  }) : _random = random ?? Random() {
    _shuffle = shuffle;
    final unique = _uniqueById(source);
    _entries.addAll([
      for (var i = 0; i < unique.length; i++) _Slot(unique[i], i.toDouble()),
    ]);
    _arrange();
  }

  /// One entry per track id, first occurrence wins.
  ///
  /// Ids are what `jumpTo`, `restoreOrder` and `replaceCurrent` resolve against, so
  /// a second copy of an id is unreachable and makes edits land on the wrong row.
  static List<Track> _uniqueById(Iterable<Track> tracks) {
    final seen = <String>{};
    return [
      for (final track in tracks)
        if (seen.add(track.id)) track,
    ];
  }

  final Random _random;
  bool _shuffle = false;

  /// The play order, and the only list of tracks this queue holds.
  final List<_Slot> _entries = [];

  final List<String> _history = [];

  int _index = 0;

  List<Track>? _flat;

  /// A live view over a derived list, not a copy per read: this is read from
  /// build methods, and materialising the queue on every call would be a copy
  /// per frame. [_flat] is rebuilt in one place — [_bumpOrder] — so it cannot
  /// disagree with the slots.
  List<Track> get _tracks =>
      _flat ??= [for (final slot in _entries) slot.track];

  List<Track> get order => UnmodifiableListView<Track>(_tracks);

  int get index => _index;
  bool get isEmpty => _entries.isEmpty;
  int get length => _entries.length;
  bool get isShuffled => _shuffle;

  int get orderVersion => _orderVersion;
  int _orderVersion = 0;

  void _bumpOrder() {
    _orderVersion++;
    _flat = null;
  }

  int _engineOrderVersion = -1;
  bool get engineIsStale => _engineOrderVersion != _orderVersion;
  void markEngineSynced() => _engineOrderVersion = _orderVersion;

  Track? get current => _entries.isEmpty ? null : _entries[_index].track;

  List<Track> get upcoming => _entries.isEmpty
      ? const []
      : [for (var i = _index + 1; i < _entries.length; i++) _entries[i].track];

  List<Track> get played => _entries.isEmpty
      ? const []
      : [for (var i = 0; i < _index; i++) _entries[i].track];

  /// Puts the queue into rank order, then shuffles it when that is the mode.
  ///
  /// Every rebuild of the play order goes through here: the ranks are the source
  /// order, with the edits already applied.
  void _arrange() {
    final ordered = [for (var i = 0; i < _entries.length; i++) (i, _entries[i])]
      ..sort((a, b) {
        final byRank = a.$2.rank.compareTo(b.$2.rank);
        // Ties fall back to the current position, so a sort is never the thing
        // that reshuffles two tracks that were told to share a rank.
        return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
      });
    _entries
      ..clear()
      ..addAll([for (final entry in ordered) entry.$2]);

    if (_shuffle) {
      final shuffled = _shuffled(_entries);
      _entries
        ..clear()
        ..addAll(shuffled);
    }

    if (_index >= _entries.length) {
      _index = _entries.isEmpty ? 0 : _entries.length - 1;
    }
    _bumpOrder();
  }

  List<_Slot> _shuffled(List<_Slot> pool) {
    if (pool.length <= 1) return List<_Slot>.of(pool);

    final recent = _history.length > kNoRepeatWindow
        ? _history.sublist(_history.length - kNoRepeatWindow)
        : List<String>.from(_history);
    final recentSet = recent.toSet();

    final fresh = pool.where((s) => !recentSet.contains(s.track.id)).toList();
    final stale = pool.where((s) => recentSet.contains(s.track.id)).toList();
    fresh.shuffle(_random);
    stale.shuffle(_random);

    return [...fresh, ...stale];
  }

  /// Gives the current play order the rank numbers, so it becomes the arrangement
  /// an unshuffle returns to.
  void _renumber() {
    for (var i = 0; i < _entries.length; i++) {
      _entries[i].rank = i.toDouble();
    }
  }

  /// The rank for a track inserted at [at], between its neighbours' ranks.
  double _rankForInsert(int at) {
    final lower = at > 0 ? _entries[at - 1].rank : null;
    final upper = at < _entries.length ? _entries[at].rank : null;

    if (lower == null && upper == null) return 0;
    if (lower == null) return upper! - 1;
    if (upper == null) return lower + 1;

    final mid = (lower + upper) / 2;
    if (mid > lower && mid < upper) return mid;

    // Adjacent doubles with nothing in between: renumbering costs O(n) and buys
    // another fifty insertions in the same gap.
    _renumber();
    return _rankForInsert(at);
  }

  double _nextRank() {
    if (_entries.isEmpty) return 0;
    var highest = _entries.first.rank;
    for (final slot in _entries) {
      if (slot.rank > highest) highest = slot.rank;
    }
    return highest + 1;
  }

  void _rerollKeepingCurrent() {
    final playing = current;
    _arrange();
    if (playing != null) {
      final at = _entries.indexWhere((s) => s.track.id == playing.id);
      if (at >= 0) _index = at;
    }
  }

  void replaceSource(List<Track> source, {bool keepPlaying = false}) {
    final playing = keepPlaying ? current : null;
    final unique = _uniqueById(source);
    _entries
      ..clear()
      ..addAll([
        for (var i = 0; i < unique.length; i++)
          _Slot(unique[i], i.toDouble()),
      ]);
    if (!keepPlaying) _index = 0;
    _arrange();
    if (playing != null) {
      final at = _entries.indexWhere((s) => s.track.id == playing.id);
      if (at >= 0) _index = at;
    }
  }

  bool appendSource(List<Track> source) {
    if (source.isEmpty) return false;
    final present = {for (final slot in _entries) slot.track.id};
    final fresh = [for (final t in source) if (present.add(t.id)) t];
    if (fresh.isEmpty) return false;

    var rank = _nextRank();
    for (final track in fresh) {
      _entries.add(_Slot(track, rank));
      rank += 1;
    }
    _arrange();
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
    if (_entries.isEmpty) return null;

    if (_index + 1 >= _entries.length) {
      if (!wrap) return null;
      _index = 0;

      _arrange();
      return current;
    }

    _index++;
    return current;
  }

  Track? previous() {
    if (_entries.isEmpty) return null;
    _index = (_index - 1 + _entries.length) % _entries.length;
    return current;
  }

  bool jumpTo(String trackId) {
    final at = _entries.indexWhere((s) => s.track.id == trackId);
    if (at < 0) return false;
    _index = at;
    return true;
  }

  /// Swaps the playing track for [replacement] without moving anything.
  ///
  /// One write to the slot that is playing, plus dropping any second copy that was
  /// already queued.
  bool replaceCurrent(Track replacement) {
    final at = _index;
    if (at < 0 || at >= _entries.length) return false;

    final slot = _entries[at];
    if (slot.track.id == replacement.id) return false;

    slot.track = replacement;
    _entries.removeWhere((s) => !identical(s, slot) && s.track.id == replacement.id);

    _bumpOrder();
    _index = _entries.indexOf(slot);
    return true;
  }

  void restoreOrder(List<String> ids) {
    if (ids.isEmpty) return;

    final byId = {for (final slot in _entries) slot.track.id: slot};
    final restored = <_Slot>[];
    final seen = <String>{};
    for (final id in ids) {
      final slot = byId[id];
      if (slot != null && seen.add(slot.track.id)) restored.add(slot);
    }
    for (final slot in _entries) {
      if (seen.add(slot.track.id)) restored.add(slot);
    }

    if (restored.isEmpty) return;
    _entries
      ..clear()
      ..addAll(restored);
    _renumber();
    _index = _index.clamp(0, _entries.length - 1);
    _bumpOrder();
  }

  void _insert(
    List<Track> tracks, {
    required InsertPolicy policy,
  }) {
    if (tracks.isEmpty) return;

    var arriving = _uniqueById(tracks);
    if (policy != InsertPolicy.blind) {
      final wanted = {for (final t in arriving) t.id};
      if (policy == InsertPolicy.move) {
        final playingId = current?.id;
        final wasAt = _index;
        // Promoting the playing track would pull the index out from playback.
        if (playingId != null && wanted.contains(playingId)) {
          arriving = [for (final t in arriving) if (t.id != playingId) t];
          wanted.remove(playingId);
          if (arriving.isEmpty) return;
        }
        _entries.removeWhere((s) => wanted.contains(s.track.id));
        // Removing tracks above the current one shifts every index below it.
        final playingAt = playingId == null
            ? -1
            : _entries.indexWhere((s) => s.track.id == playingId);
        _index = playingAt >= 0
            ? playingAt
            : wasAt.clamp(0, _entries.isEmpty ? 0 : _entries.length - 1);
      } else if (policy == InsertPolicy.refuse) {
        final present = {for (final slot in _entries) slot.track.id};
        arriving = [for (final t in tracks) if (!present.contains(t.id)) t];
        if (arriving.isEmpty) return;
      }
    }

    final at = switch (policy) {
      InsertPolicy.append || InsertPolicy.refuse => _entries.length,

      InsertPolicy.move || InsertPolicy.blind =>
        (_index + 1).clamp(0, _entries.length),
    };

    for (var i = 0; i < arriving.length; i++) {
      _entries.insert(at + i, _Slot(arriving[i], _rankForInsert(at + i)));
    }
    _bumpOrder();
  }

  void playNext(Track track) => _insert([track], policy: InsertPolicy.move);

  void promoteToNext(List<Track> tracks) =>
      _insert(tracks, policy: InsertPolicy.move);

  bool append(Track track) {
    if (_entries.any((s) => s.track.id == track.id)) return false;
    _insert([track], policy: InsertPolicy.append);
    return true;
  }

  bool move(int from, int to) {
    if (from < 0 || from >= _entries.length) return false;
    if (to < 0 || to >= _entries.length) return false;
    if (from == to) return true;

    final playing = current;
    final slot = _entries.removeAt(from);
    _entries.insert(to, slot);

    if (playing != null) {
      final at = _entries.indexWhere((s) => s.track.id == playing.id);
      if (at >= 0) _index = at;
    }
    _bumpOrder();
    return true;
  }

  bool remove(String trackId) {
    final at = _entries.indexWhere((s) => s.track.id == trackId);
    if (at < 0) return false;
    final wasCurrent = at == _index;
    _entries.removeAt(at);
    if (_entries.isEmpty) {
      _index = 0;
    } else if (wasCurrent) {
      _index = at.clamp(0, _entries.length - 1);
    } else if (at < _index) {
      _index -= 1;
    }
    _bumpOrder();
    return true;
  }

  /// Puts a track back where it was — the undo for [remove].
  bool insertAt(int at, Track track) {
    if (_entries.any((s) => s.track.id == track.id)) return false;
    final playing = current;
    final pos = at.clamp(0, _entries.length);
    _entries.insert(pos, _Slot(track, _rankForInsert(pos)));
    final still = playing == null
        ? -1
        : _entries.indexWhere((s) => s.track.id == playing.id);
    _index = still >= 0 ? still : _index.clamp(0, _entries.length - 1);
    _bumpOrder();
    return true;
  }

  /// Drops everything after the playing track; returns how many went.
  int clearUpcoming() {
    if (_index >= _entries.length - 1) return 0;
    final dropped = _entries.length - _index - 1;
    _entries.removeRange(_index + 1, _entries.length);
    _bumpOrder();
    return dropped;
  }
}
