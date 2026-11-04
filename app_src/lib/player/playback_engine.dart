/// What the player asks of an audio engine.
///
/// [AudioEngine] is a real engine: just_audio, audio focus, fades, a platform
/// queue. Almost none of that is what the rest of the app needs to *call*, and a
/// test cannot construct any of it. This is the part the loader and the transport
/// use — the smallest surface that still describes playing a queue of files —
/// so the logic that decides what to play can be tested against a fake.
///
/// The engine owns nothing here: no fades, no loop policy, no interruption rules.
/// Those belong to the layer above, which is why they are absent.
library;

import '../playback/loop_controller.dart';
import 'engine_window.dart';

abstract interface class PlaybackEngine {
  /// Where playback actually is, as the platform reports it.
  Duration get position;

  /// The engine's own answer for how long the current file is, when the library
  /// has no duration for it.
  Duration? get duration;

  bool get isPlaying;

  /// The absolute path the platform is playing now, or null before the first
  /// load. This is how the shell notices the platform moved on its own.
  String? get playingPath;

  /// Loop points for the current track, re-read by the engine on every tick.
  LoopController? loop;

  /// True when the engine already holds exactly this queue, in this order.
  bool queueMatches(List<String> paths);

  /// Hands the engine a window of the queue and starts at [initialIndex].
  Future<bool> setQueue(List<EngineEntry> items, {required int initialIndex});

  /// Plays one file on its own, with no queue behind it.
  Future<bool> loadAndPlay(
    String absolutePath, {
    Duration? startAt,
    bool autoPlay,
    String title,
    String artist,
    String album,
    Uri? coverUri,
  });

  /// Moves within the queue the engine already holds.
  Future<void> seekToIndex(int index);

  /// Whether the engine's own window has anywhere to go. The queue behind it may
  /// be longer; that is [canStepOutsideEngine]'s question.
  bool get hasNext;

  bool get hasPrevious;

  Future<void> skipNext();

  Future<void> skipPrevious();

  Future<void> seek(Duration to);

  Future<void> play();

  Future<void> pause();

  Future<void> setVolume(double volume);
}
