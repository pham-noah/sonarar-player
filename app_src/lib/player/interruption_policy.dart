/// What an audio-focus event means for playback.
///
/// The rules are a pure function: give it the event and the two facts that
/// matter, and it answers with the one thing the engine should do.
///
/// The two facts:
///
///  * `pausedByInterruption` — did the platform pause this, or did the user?
///    A pause the user asked for must stay paused when the call ends.
///  * `wantPlay` — does the app still intend to be playing? An interruption that
///    arrived after a pause must not start music.
library;

import 'package:audio_session/audio_session.dart';

enum InterruptionAction {
  /// Lower the level: a notification, a satnav prompt.
  duck,

  /// Stop, and remember the platform did it rather than the user.
  pause,

  /// The interruption is over and the level goes back to the user's own.
  restore,

  /// The interruption is over and the app still wanted to play.
  resume,

  /// Nothing to do.
  none,
}

/// The one action [type] calls for, given whether the interruption is beginning,
/// whether the platform was already the reason playback is paused, and whether the
/// app still wants to be playing.
InterruptionAction interruptionActionFor({
  required bool begin,
  required AudioInterruptionType type,
  required bool pausedByInterruption,
  required bool wantPlay,
}) {
  switch (type) {
    case AudioInterruptionType.duck:
      // A duck never changes whether music is playing, so it is the same action
      // whichever end of the event it is — the level goes down, or back up.
      return begin ? InterruptionAction.duck : InterruptionAction.restore;

    case AudioInterruptionType.pause:
      if (begin) return InterruptionAction.pause;
      // Only resume what the interruption itself stopped, and only if the app had
      // not since been told to stop.
      return pausedByInterruption && wantPlay
          ? InterruptionAction.resume
          : InterruptionAction.none;

    case AudioInterruptionType.unknown:
      // An unknown interruption is treated as a pause when it begins, because
      // silence is the safe default. Its end is not treated as a resume: too much
      // would have to be true for that to be right.
      return begin ? InterruptionAction.pause : InterruptionAction.none;
  }
}
