library;

import 'playlists.dart';
import 'track.dart';
import 'variants.dart';

const String kVariantsId = '__variants__';

const String kVariantsName = 'Variants';

String variantsBlurb(int recordings, int families) {
  if (recordings == 0) return 'No track in the library has a second recording yet.';
  return '$recordings recording${recordings == 1 ? '' : 's'} '
      'across $families song${families == 1 ? '' : 's'}.';
}

List<Track> variantRecordings(List<Track> library) {
  final families = <String, List<Track>>{};
  for (final t in library) {
    (families[variantGroupKey(t)] ??= []).add(t);
  }

  final out = <Track>[];

  final seen = <String>{};
  for (final t in library) {
    final key = variantGroupKey(t);
    if (!seen.add(key)) continue;
    final members = families[key]!;
    if (members.length < 2) continue;
    out.addAll(members);
  }
  return out;
}

int variantFamilyCount(List<Track> library) {
  final families = <String, int>{};
  for (final t in library) {
    final key = variantGroupKey(t);
    families[key] = (families[key] ?? 0) + 1;
  }
  return families.values.where((n) => n > 1).length;
}

Playlist? variantsPlaylist(List<Track> library) {
  final tracks = variantRecordings(library);
  if (tracks.isEmpty) return null;
  return Playlist(
    id: kVariantsId,
    name: kVariantsName,
    trackIds: [for (final t in tracks) t.id],
  );
}
