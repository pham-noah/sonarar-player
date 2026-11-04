/// The smallest set of edits that turns one engine queue into another.
///
/// Changing a queue entry used to mean handing just_audio a whole new
/// [ConcatenatingAudioSource], which tears the platform player down — the music
/// stops for a moment and comes back where it was. The queue supports being
/// edited in place (`move` was already used for reordering), so the fix is to say
/// what actually changed and apply only that.
///
/// The diff is a pure function on purpose: `insert`/`removeAt`/`move` against a
/// live player cannot be unit-tested, but *which* edits to make can, and that is
/// where an off-by-one would come from.
library;

import 'engine_window.dart';

/// One edit against the engine's queue.
sealed class QueueEdit {
  const QueueEdit();
}

/// Takes the entry at [index] out of the engine's queue.
class QueueRemove extends QueueEdit {
  const QueueRemove(this.index);

  final int index;

  @override
  String toString() => 'remove $index';
}

/// Puts [entry] into the engine's queue at [index].
class QueueInsert extends QueueEdit {
  const QueueInsert(this.index, this.entry);

  final int index;
  final EngineEntry entry;

  @override
  String toString() => 'insert $index ${entry.path}';
}

/// Moves the entry at [from] so it lands at [to].
class QueueMove extends QueueEdit {
  const QueueMove(this.from, this.to);

  final int from;
  final int to;

  @override
  String toString() => 'move $from->$to';
}

/// The edits that turn [from] (the engine's paths, in order) into [to].
///
/// Removals go first, from the end, so the indices of the entries still to come
/// are never shifted by a removal above them. Insertions then walk forward and
/// only add what is missing. Whatever is left out of order is moved into place.
/// Every edit is stated against the list as it stands *when that edit is applied*,
/// which is what lets a caller replay them in order.
List<QueueEdit> queueEditsFor({
  required List<String> from,
  required List<EngineEntry> to,
}) {
  final current = List<String>.from(from);
  final wanted = [for (final e in to) e.path];
  final edits = <QueueEdit>[];

  // 1. Drop what is no longer wanted, from the end backwards.
  final wantedSet = wanted.toSet();
  for (var i = current.length - 1; i >= 0; i--) {
    if (!wantedSet.contains(current[i])) {
      edits.add(QueueRemove(i));
      current.removeAt(i);
    }
  }

  // 2. Add what is missing, in order.
  for (var i = 0; i < wanted.length; i++) {
    if (i >= current.length) {
      edits.add(QueueInsert(i, to[i]));
      current.insert(i, wanted[i]);
      continue;
    }
    if (current[i] != wanted[i] && !current.contains(wanted[i])) {
      edits.add(QueueInsert(i, to[i]));
      current.insert(i, wanted[i]);
    }
  }

  // 3. Anything out of order now is a move. After steps 1 and 2 the two lists hold
  //    the same paths, so every wanted entry is findable at or after i.
  for (var i = 0; i < wanted.length; i++) {
    if (current[i] == wanted[i]) continue;
    final at = current.indexOf(wanted[i], i);
    if (at < 0) continue; // cannot happen once both lists hold the same paths
    edits.add(QueueMove(at, i));
    final moved = current.removeAt(at);
    current.insert(i, moved);
  }

  return edits;
}

/// Where [path] ends up in [to], or -1.
int indexOfPath(List<EngineEntry> to, String path) {
  for (var i = 0; i < to.length; i++) {
    if (to[i].path == path) return i;
  }
  return -1;
}
