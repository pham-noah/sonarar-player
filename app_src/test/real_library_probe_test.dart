@Tags(['slow'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/rules/rules_engine.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/skin_policy.dart';

String _short(String s, [int n = 22]) =>
    s.length <= n ? s : '${s.substring(0, n)}…';

void main() {
  test('probe the real library', () {
    final manifest = File('test/fixtures/library_manifest.json');
    if (!manifest.existsSync()) {
      // ignore: avoid_print
      print('NO FIXTURE — skipping probe');
      return;
    }
    final lib = Track.listFromManifest(manifest.readAsStringSync());
    const engine = RulesEngine();

    // ignore: avoid_print
    print('LIBRARY total=${lib.length}');

    for (final (hour, name) in const [
      (0, 'darkHour'),
      (3, 'night'),
      (8, 'morning'),
      (14, 'afternoon'),
      (19, 'evening'),
    ]) {
      final band = const SkinPolicy().bandFor(hour);
      final ctx = PlaylistContext(
          band: band, whereabouts: Whereabouts.home, sky: Sky.unknown, localHour: hour);
      final out = engine.playlist(lib, ctx);

      // ignore: avoid_print
      print('$name hr=$hour band=${band.name} out=${out.length} library=${lib.length}');
      // ignore: avoid_print
      print('   TOP5 ${out.take(5).map((t) => "${_short(t.title)}(${t.duration.inSeconds}s)").join(" | ")}');
    }

    for (final s in SkinId.values) {
      // ignore: avoid_print
      print('FIT ${s.name} -> ${engine.fitFor(lib, s).summary}');
    }

    for (final band in ContextBand.values) {
      final ctx = PlaylistContext(
          band: band, whereabouts: Whereabouts.home, sky: Sky.unknown, localHour: 12);
      expect(engine.playlist(lib, ctx), isNotEmpty,
          reason: 'band ${band.name} produced an empty playlist');
    }
  });
}
