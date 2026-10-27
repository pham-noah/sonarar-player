library;

import '../theme/skin_policy.dart';

import 'rules_engine.dart';

typedef ContextFingerprint = ({
  ContextBand band,
  Sky sky,
  Whereabouts whereabouts,
  String? placeId,
  ManualMode? mode,
});

ContextFingerprint fingerprint(PlaylistContext ctx) => (
      band: ctx.band,
      sky: ctx.sky,
      whereabouts: ctx.whereabouts,
      placeId: ctx.placeId,
      mode: ctx.mode,
    );

bool contextChanged(PlaylistContext? previous, PlaylistContext next) {
  if (previous == null) return true;
  return fingerprint(previous) != fingerprint(next);
}
