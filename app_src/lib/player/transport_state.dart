/// The transport's state, as one state instead of five booleans.
///
/// The engine used to carry `_wantPlay`, `_playOutstanding`, `_playRetries`,
/// `_skipRequested` and `_suppressNextCompletion` as independent flags, so every
/// combination of them was representable — including ones that cannot happen: a skip
/// that is not playing, a retry count for a play that was never issued, a
/// suppressed completion with nothing to suppress. This says which combinations are
/// real and makes the rest unrepresentable.
///
/// What each flag was for, written down before it was removed:
///
/// - `_wantPlay` — the app's intent. It survives a queue load (the platform will
///   start when it is ready) and is cleared by a pause, by giving up on a play that
///   never started, and by a completion. It is the answer to "should sound be
///   coming out of this?".
/// - `_playOutstanding` — a `play()` was issued and the platform has not confirmed
///   playing yet. Without it a state event that arrives mid-load looks like "the
///   platform stopped" and the request is dropped.
/// - `_playRetries` — how many times a play has been reissued since the last
///   confirmation. just_audio occasionally ignores the first play while it is still
///   preparing, so the request is reissued a bounded number of times.
/// - `_skipRequested` — the platform is about to report a source change that we
///   caused. Without it a skip is indistinguishable from the platform moving on its
///   own, and the intent to play gets taken from the state of a player that has not
///   finished moving.
/// - `_suppressNextCompletion` — just_audio reports a completion for the item it was
///   moved away from. That completion belongs to a track nobody finished, so it must
///   not be counted as one ending.
library;

import 'playback_intent.dart';

enum TransportPhase {
  /// Nothing is wanted: never started, paused, stopped, or ended.
  idle,

  /// A play request is in flight and the platform has not confirmed it.
  requested,

  /// Playing is wanted and nothing is outstanding: the platform agreed, or a queue
  /// was just handed over and play is expected to follow.
  active,

  /// The platform was told to move, and has not reported the move yet.
  skipping,
}

class TransportState {
  TransportPhase _phase = TransportPhase.idle;

  /// Only meaningful in [TransportPhase.requested]: how many times the play has
  /// been reissued. Reset when a request is confirmed or abandoned.
  int _retries = 0;

  /// The next completion belongs to a track we moved away from, not one that
  /// ended. This is a debt owed by just_audio after a source change, so it is not a
  /// phase: a source change can happen while playing, while paused, or while
  /// skipping, and in all three the same completion follows.
  bool _owesCompletion = false;

  TransportPhase get phase => _phase;

  /// Should sound be coming out? True while a play is in flight, while playing is
  /// wanted, and while a skip we asked for is landing — a skip means "carry on".
  bool get wantsPlay =>
      _phase == TransportPhase.requested ||
      _phase == TransportPhase.active ||
      _phase == TransportPhase.skipping;

  /// A `play()` has been issued and nothing has confirmed it yet.
  bool get isOutstanding => _phase == TransportPhase.requested;

  /// The next source change is one we asked for.
  bool get isSkipping => _phase == TransportPhase.skipping;

  /// How many times the outstanding play has been reissued.
  int get retries => _retries;

  bool get owesCompletion => _owesCompletion;

  /// The app wants to play: either it has just asked the platform, or a queue was
  /// handed over and play is expected to follow.
  void onPlayRequested() {
    _phase = TransportPhase.requested;
    _retries = 0;
  }

  /// Playing is wanted, but no request is in flight: a queue was handed over and
  /// the platform will start on its own once it is ready, or an interruption ended
  /// and the sound comes back.
  void noteIntent() {
    if (_phase != TransportPhase.skipping) _phase = TransportPhase.active;
  }

  void onPauseRequested() {
    _phase = TransportPhase.idle;
    _retries = 0;
  }

  /// A skip was asked for. The intent to play is not re-decided until the platform
  /// reports where it went.
  void onSkipRequested() {
    _phase = TransportPhase.skipping;
  }

  /// The platform is playing or not, and that is the end of the matter for now.
  void stopRequested() {
    _phase = TransportPhase.idle;
    _retries = 0;
  }

  /// The platform reported a different item.
  ///
  /// [ours] is true when the move is one this app asked for. When it is not, the
  /// intent is taken from the platform, because a source change it made on its own
  /// is the only evidence there is about what it intends to do next.
  void onSourceChanged({
    required bool platformMoved,
    required bool platformPlaying,
    required bool platformCompleted,
  }) {
    if (!platformMoved) return;

    if (_phase == TransportPhase.skipping) {
      _phase = TransportPhase.active;
    } else if (!platformCompleted) {
      _phase = platformPlaying ? TransportPhase.active : TransportPhase.idle;
    }

    // Whatever moved it, the completion that follows belongs to the item that was
    // left behind.
    _owesCompletion = true;
  }

  /// What to do about the platform's current playing state.
  PlayAction actionFor({required bool playing, required bool loading}) =>
      nextPlayAction(
        playing: playing,
        outstanding: isOutstanding,
        retries: _retries,
        completed: false,
        loading: loading,
      );

  /// Records what [actionFor] said was done.
  void apply(PlayAction action) {
    switch (action) {
      case PlayAction.reissuePlay:
        _retries++;
      case PlayAction.giveUp:
        _phase = TransportPhase.idle;
        _retries = 0;
      case PlayAction.adoptPlaying:
        _phase = TransportPhase.active;
        _retries = 0;
      case PlayAction.adoptStopped:
        _phase = TransportPhase.idle;
      case PlayAction.none:
        break;
    }
  }

  /// A completion arrived. True when it is a track that actually ended.
  ///
  /// A skipped track, and a load that failed, both produce one; neither is a track
  /// finishing, and counting them would advance the queue past a song nobody heard.
  bool onCompletedEvent({required bool loadFailed}) {
    final counts = shouldReportCompletion(
      loadFailed: loadFailed,
      suppressNext: _owesCompletion,
    );
    _owesCompletion = false;
    if (loadFailed) _phase = TransportPhase.idle;
    if (!counts) return false;

    _phase = TransportPhase.idle;
    return true;
  }
}
