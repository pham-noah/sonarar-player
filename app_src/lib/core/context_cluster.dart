/// The context the app is in — one object, because it was six fields agreeing by
/// memory.
///
/// `AppState` carried the rules the user wrote, the rules derived from their places,
/// the places themselves, the manual mode and the band it was entered at, and the
/// context that was last read. Every one of them had to be recomputed whenever
/// another changed, and forgetting a recompute is invisible: the app keeps the right
/// skin and the wrong playlist.
///
/// So the cluster derives what it can: [rules] is always [writtenRules] with the
/// place rules folded in, and nothing outside can set it. What the cluster does not
/// decide is what follows from a context — the skin and the queue — because those
/// belong to the state above; [update] hands its caller the context, the playlist
/// context and the rule that matched, and the caller acts on them.
library;

import '../context/places.dart';
import '../rules/context_rules.dart';
import '../rules/place_rules.dart';
import '../rules/rules_engine.dart' show PlaylistContext;
import '../theme/skin_policy.dart' show ContextBand, ManualMode, PlayContext;

/// What one [ContextCluster.update] decided.
class ContextDecision {
  const ContextDecision({
    required this.context,
    required this.playlist,
    required this.rule,
    required this.bandChanged,
  });

  /// The incoming context, with the manual mode applied if one is on.
  final PlayContext context;

  /// What the playlist side reads.
  final PlaylistContext playlist;

  /// The first rule that matches [playlist], or null.
  final ContextRule? rule;

  /// True when the clock crossed a band since the previous reading, which is what
  /// puts a manually chosen mode back in the clock's hands.
  final bool bandChanged;
}

class ContextCluster {
  ContextCluster({ContextRules? rules, PlaceBook? places})
      : _writtenRules = rules ?? ContextRules.empty,
        _places = places ?? PlaceBook.empty {
    _rules = withPlaceRules(_writtenRules, _places);
  }

  ContextRules _writtenRules;

  /// What the user wrote, before the places add their own.
  ContextRules get writtenRules => _writtenRules;

  late ContextRules _rules;

  /// What the app matches against: [writtenRules] with the place rules folded in.
  /// Derived, so it cannot disagree with its inputs.
  ContextRules get rules => _rules;

  PlaceBook _places;
  PlaceBook get places => _places;

  ManualMode? _manualMode;

  /// The mode the user pinned, if any. Its band wins over the clock's.
  ManualMode? get manualMode => _manualMode;

  ContextBand? _manualBandAtEntry;

  PlaylistContext? _playlistCtx;
  PlaylistContext? get playlistContext => _playlistCtx;

  PlayContext? _lastContext;

  /// The last context read, after the manual mode was applied.
  PlayContext? get lastContext => _lastContext;

  void setRules(ContextRules rules) {
    _writtenRules = rules;
    _rules = withPlaceRules(_writtenRules, _places);
  }

  void setPlaces(PlaceBook book) {
    _places = book;
    _rules = withPlaceRules(_writtenRules, _places);
  }

  /// True when a mode was pinned. False when there is no context to pin it to yet,
  /// which is what the app's own guard used to be.
  bool enterMode(ManualMode mode) {
    final base = _lastContext;
    if (base == null) return false;
    _manualMode = mode;
    _manualBandAtEntry = base.band;
    return true;
  }

  /// True when a mode was pinned and has now been let go.
  bool exitMode() {
    if (_manualMode == null) return false;
    _manualMode = null;
    _manualBandAtEntry = null;
    return true;
  }

  /// Records the playlist context the queue was planned from.
  void setPlaylistContext(PlaylistContext? ctx) {
    _playlistCtx = ctx;
  }

  /// Reads [incoming], applies the manual mode (dropping it when the clock has
  /// crossed into another band), and records the result.
  ContextDecision update(PlayContext incoming, {required bool honourClock}) {
    final clockBand = incoming.band;
    if (_manualMode != null &&
        _manualBandAtEntry != null &&
        clockBand != _manualBandAtEntry) {
      _manualMode = null;
      _manualBandAtEntry = null;
    }

    final ctx = _manualMode == null
        ? incoming
        : PlayContext(
            band: _manualMode!.band,
            localHour: incoming.localHour,
            mode: _manualMode,
            placeId: incoming.placeId,
            sky: incoming.sky,
            whereabouts: incoming.whereabouts,
          );

    final bandChanged = _lastContext != null && _lastContext!.band != ctx.band;
    _lastContext = ctx;

    final playlist = PlaylistContext(
      band: ctx.band,
      sky: ctx.sky,
      whereabouts: ctx.whereabouts,
      localHour: ctx.localHour,
      mode: ctx.mode,
      placeId: ctx.placeId,
    );
    _playlistCtx = playlist;

    return ContextDecision(
      context: ctx,
      playlist: playlist,
      rule: _rules.firstMatch(playlist, honourClock: honourClock),
      bandChanged: bandChanged,
    );
  }
}
