library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/core/prefs.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/player_screen.dart';
import 'package:sonarar/theme/layout.dart';

Track _t() => Track(
      id: 'a',
      title: 'Beneath the Mask',
      artist: 'ATLUS Sound Team',
      album: 'Persona 5',
      duration: const Duration(minutes: 4),
      file: 'a.opus',
      cover: '',
      gainDb: null);

Future<void> _pump(WidgetTester tester, LayoutKind layout) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final state = AppState();
  state.attachLibrary([_t()]);
  state.setLayout(layout);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: PlayerScreen(
        state: state,
        track: _t(),
        onPlayPause: () {},
        onSeek: (_) {},
        onVolume: (_) {},
        onCycleRepeat: () {},
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final layout in [LayoutKind.sonar, LayoutKind.solid, LayoutKind.glass]) {
    testWidgets('${layout.name}: the title and the artist are each drawn ONCE',
        (tester) async {
      await _pump(tester, layout);

      expect(find.text('Beneath the Mask'), findsOneWidget,
          reason: 'the title is drawn twice on ${layout.name}');
      expect(find.text('ATLUS Sound Team'), findsOneWidget,
          reason: 'the artist is drawn twice on ${layout.name}');
    });
  }

  group('the dead look keys are gone', () {
    test('art and palette are not written any more', () {
      const saved = AppPrefs(languageSkinId: 'mono', skinId: 'p5r');
      final json = saved.toJson();

      expect(json.containsKey('art_skin'), isFalse,
          reason: 'the art key outlived the art picker');
      expect(json.containsKey('palette_index'), isFalse,
          reason: 'the palette key outlived the palette picker');
    });

    test('an old file carrying them still loads, ignoring them', () {
      final restored = AppPrefs.fromJson(const {
        'art_skin': 'p3r',
        'palette_index': 2,
        'language_skin': 'mono',
      });
      expect(restored.languageSkinId, 'mono');
      expect(restored.skinId, isNull);
    });
  });
}
