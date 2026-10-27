library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/theme/skin_policy.dart';

void main() {
  test('print the skin for every hour of a clear day', () {
    const p = SkinPolicy();
    final counts = <String, int>{'abyss': 0, 'amber': 0, 'crimson': 0};
    final parts = <String>[];
    for (var h = 0; h < 24; h++) {
      final ctx = PlayContext(
        band: p.bandFor(h), whereabouts: Whereabouts.home, localHour: h);
      final id = p.skinForContext(ctx);
      parts.add('$h=${id.name}');
      counts[id.name] = counts[id.name]! + 1;
    }
    // ignore: avoid_print
    print('SKINMAP ${parts.join(" ")}');
    // ignore: avoid_print
    print('TOTALS ${counts.entries.map((e) => "${e.key}=${e.value}h").join(" ")}');
  });
}
