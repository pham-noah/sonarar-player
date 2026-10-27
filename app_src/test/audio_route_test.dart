library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/player/audio_route.dart';
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/skin.dart';

void main() {
  group('AudioOutput parsing', () {
    test('a complete entry round-trips', () {
      final o = AudioOutput.fromMap(const {
        'id': 7,
        'name': 'WH-1000XM4',
        'kind': 'bluetooth',
        'active': true,
      });
      expect(o, isNotNull);
      expect(o!.id, 7);
      expect(o.name, 'WH-1000XM4');
      expect(o.kind, 'bluetooth');
      expect(o.active, isTrue);
    });

    test('a malformed entry is DROPPED, not thrown on', () {
      expect(AudioOutput.fromMap(null), isNull);
      expect(AudioOutput.fromMap('bluetooth'), isNull);
      expect(AudioOutput.fromMap(const {'id': 'seven', 'name': 'x', 'kind': 'usb'}), isNull);
      expect(AudioOutput.fromMap(const {'id': 1, 'name': 2, 'kind': 'usb'}), isNull);
      expect(AudioOutput.fromMap(const {'id': 1, 'name': 'x'}), isNull);
    });

    test('a missing active flag reads as NOT active, which is the safe direction', () {
      final o = AudioOutput.fromMap(const {'id': 1, 'name': 'Phone', 'kind': 'speaker'});
      expect(o!.active, isFalse);
    });

    test('equality includes the live flag, so a change is a change', () {
      const a = AudioOutput(id: 1, name: 'Phone', kind: 'speaker', active: true);
      const b = AudioOutput(id: 1, name: 'Phone', kind: 'speaker', active: false);
      expect(a == b, isFalse);
      expect(a == const AudioOutput(
            id: 1,
            name: 'Phone',
            kind: 'speaker',
            active: true,
          ), isTrue);
    });
  });

  group('the mini player floats with the tab bar', () {
    test('Persona docks both, so its player is unchanged', () {
      expect(ScreenLayout.persona.tabBarIsFloating, isFalse);
      expect(ScreenLayout.persona.miniPlayerIsFloating, isFalse);
    });

    test('the plain layouts float BOTH — that is the bug he reported', () {
      expect(ScreenLayout.plain.tabBarIsFloating, isTrue);
      expect(ScreenLayout.plain.miniPlayerIsFloating, isTrue);
    });

    test('every layout agrees — derived, never set independently', () {
      for (final layout in LayoutKind.values) {
        final p = presentationFor(layout, skinFor(SkinId.crimson));
        expect(p.arrangement.miniPlayerIsFloating,
            p.arrangement.tabBarIsFloating,
            reason: '${layout.name} lets the player and the tab bar disagree');
      }
    });
  });
}
