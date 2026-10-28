library;

import '../library/track.dart';
import 'queue.dart';

enum QueueMode {
  dynamic,

  fixed,
}

/// Whether a manual Next/Previous has somewhere to go once the ENGINE has run
/// out of sources — its queue is only a window of the real one. Repeat All is
/// the one case where the app queue wraps instead of stopping.
bool canStepOutsideEngine(
  PlayQueue? queue, {
  required bool repeatAll,
  required bool forward,
}) {
  final q = queue;
  if (q == null || q.isEmpty) return false;
  return forward ? (q.index + 1 < q.length || repeatAll) : (q.index > 0 || repeatAll);
}

List<Track> queueForPlayedTrack({
  required Track track,
  required QueueMode mode,
  required List<Track> contextMix,
}) {
  if (mode == QueueMode.fixed) return [track];

  final already = contextMix.any((t) => t.id == track.id);
  return already ? contextMix : [track, ...contextMix];
}

AutoAdvanceMode advanceFor({
  required QueueMode mode,
  required bool repeatOne,
  required bool repeatAll,
  required bool hasNext,
}) {
  if (repeatOne) return AutoAdvanceMode.replay;
  if (hasNext) return AutoAdvanceMode.next;
  if (mode == QueueMode.fixed) return AutoAdvanceMode.stop;
  if (repeatAll) return AutoAdvanceMode.next;
  return AutoAdvanceMode.stop;
}

enum AutoAdvanceMode { next, replay, stop }
