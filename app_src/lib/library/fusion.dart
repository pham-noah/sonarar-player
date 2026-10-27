library;

import 'playlists.dart';

enum FusionMode {
  interleave,
  append,
  intersection;

  String get label => switch (this) {
        FusionMode.interleave => 'Interleave',
        FusionMode.append => 'One after the other',
        FusionMode.intersection => 'Only what they share',
      };

  String get blurb => switch (this) {
        FusionMode.interleave =>
          'Alternates between the two, so the mix is genuinely both.',
        FusionMode.append => 'All of the first, then all of the second.',
        FusionMode.intersection => 'Just the tracks both lists have.',
      };
}

List<String> fuseIds(
  List<String> a,
  List<String> b, {
  FusionMode mode = FusionMode.interleave,
}) {
  switch (mode) {
    case FusionMode.intersection:
      final inB = b.toSet();
      final seen = <String>{};
      return [
        for (final id in a)
          if (inB.contains(id) && seen.add(id)) id,
      ];

    case FusionMode.append:
      final seen = <String>{};
      return [
        for (final id in [...a, ...b])
          if (seen.add(id)) id,
      ];

    case FusionMode.interleave:
      final out = <String>[];
      final seen = <String>{};
      final maxLen = a.length > b.length ? a.length : b.length;
      for (var i = 0; i < maxLen; i++) {
        if (i < a.length && seen.add(a[i])) out.add(a[i]);
        if (i < b.length && seen.add(b[i])) out.add(b[i]);
      }
      return out;
  }
}

Playlist? fusePlaylists(
  PlaylistList into,
  Playlist a,
  Playlist b, {
  required String name,
  FusionMode mode = FusionMode.interleave,
  String? id,
}) {
  final ids = fuseIds(a.trackIds, b.trackIds, mode: mode);
  if (ids.isEmpty) return null;
  return into.create(name, id: id, trackIds: ids);
}

int fusionSize(
  List<String> a,
  List<String> b, {
  FusionMode mode = FusionMode.interleave,
}) =>
    fuseIds(a, b, mode: mode).length;
