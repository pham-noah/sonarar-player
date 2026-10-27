library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/art/skin_art.dart';
import 'package:sonarar/theme/skin.dart' show SkinId;
import 'package:sonarar/core/prefs.dart';

void main() {
  group('the preference survives, and is additive', () {
    test('defaults to on — that is the behaviour he asked for', () {
      expect(AppPrefs.initial.cycleCharacterArt, isTrue);
    });

    test('round-trips through JSON', () {
      final off = AppPrefs.initial.copyWith(cycleCharacterArt: false);
      final back = AppPrefs.fromJson(off.toJson());
      expect(back.cycleCharacterArt, isFalse);
      expect(AppPrefs.fromJson(AppPrefs.initial.toJson()).cycleCharacterArt,
          isTrue);
    });

    test('a prefs file written before this existed still loads', () {
      final old = {
        'resume_on_launch': true,
        'crossfade_seconds': 3,
        'gapless_playback': false,
        'allow_network': false,
      };
      final p = AppPrefs.fromJson(old);
      expect(p.cycleCharacterArt, isTrue, reason: 'falls back to the default');

      expect(p.resumeOnLaunch, isTrue);
      expect(p.crossfadeSeconds, 3);
      expect(p.gaplessPlayback, isFalse);
      expect(p.allowNetwork, isFalse);
    });

    test('a corrupt value does not take the app down', () {
      final p = AppPrefs.fromJson({'cycle_character_art': 'yes please'});
      expect(p.cycleCharacterArt, isTrue);
    });
  });

  group('the cycle steps through the skin\'s own set', () {
    test('it walks every piece before repeating any', () {
      final set = kArtAbyss;
      expect(set.length, greaterThan(2), reason: 'the fixture must have pieces');

      var index = 0;
      final seen = <String>{set.atOrNull(index)!.key};
      for (var i = 0; i < set.length - 1; i++) {
        index = set.nextIndex(index);
        seen.add(set.atOrNull(index)!.key);
      }
      expect(seen.length, set.length,
          reason: 'one pass shows every character exactly once');
    });

    test('it wraps rather than stopping at the end', () {
      final set = kArtAbyss;
      final last = set.length - 1;
      expect(set.nextIndex(last), 0);
      expect(set.previousIndex(0), last);
    });

    test('an empty set does not crash', () {
      const empty = SkinArtSet(SkinId.abyss, []);
      expect(empty.nextIndex(0), 0);
      expect(empty.previousIndex(0), 0);
      expect(empty.atOrNull(0), isNull);
    });
  });
}
