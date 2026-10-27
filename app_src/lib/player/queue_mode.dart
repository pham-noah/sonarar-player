library;

import '../library/track.dart';

enum QueueMode {
  dynamic,

  fixed,
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
