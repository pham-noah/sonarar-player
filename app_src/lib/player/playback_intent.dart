library;

enum PlayAction {
  none,

  reissuePlay,

  giveUp,

  adoptStopped,

  adoptPlaying,
}

const int kMaxPlayRetries = 6;

PlayAction nextPlayAction({
  required bool playing,
  required bool outstanding,
  required int retries,
  required bool completed,
  bool loading = false,
  int maxRetries = kMaxPlayRetries,
}) {
  if (completed) return PlayAction.none;

  if (playing) {
    return PlayAction.adoptPlaying;
  }

  if (loading) return PlayAction.none;

  if (outstanding) {
    return retries < maxRetries ? PlayAction.reissuePlay : PlayAction.giveUp;
  }

  return PlayAction.adoptStopped;
}

bool shouldReportCompletion({
  required bool loadFailed,
  required bool suppressNext,
}) {
  if (loadFailed) return false;
  if (suppressNext) return false;
  return true;
}
