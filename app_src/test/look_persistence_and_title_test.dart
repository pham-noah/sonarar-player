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
  for (final layout in [LayoutKind.persona, LayoutKind.solid, LayoutKind.glass]) {
    testWidgets('${layout.name}: the title and the artist are each drawn ONCE',
        (tester) async {
      await _pump(tester, layout);

      expect(find.text('Beneath the Mask'), findsOneWidget,
          reason: 'the title is drawn twice on ${layout.name}');
      expect(find.text('ATLUS Sound Team'), findsOneWidget,
          reason: 'the artist is drawn twice on ${layout.name}');
    });
  }

  group('the look choices are persisted', () {
    test('art set, words and palette survive a round trip through the file', () {
      const saved = AppPrefs(
        artSkinId: 'p3r',
        languageSkinId: 'mono',
        skinId: 'p5r',
      );
      final restored = AppPrefs.fromJson(saved.toJson());

      expect(restored.artSkinId, 'p3r');
      expect(restored.languageSkinId, 'mono');
      expect(restored.skinId, 'p5r');
    });

    test('an older file with none of the keys gets "follow the palette", not a wrong value',
        () {
      final restored = AppPrefs.fromJson(const {'layout_id': 'solid'});
      expect(restored.artSkinId, isNull);
      expect(restored.languageSkinId, isNull);
      expect(restored.skinId, isNull);
    });

    test('"follow the palette" can be written back to null', () {
      const worn = AppPrefs(artSkinId: 'p3r');
      expect(worn.copyWith(clearArtSkin: true).artSkinId, isNull);

      expect(worn.copyWith(showFps: true).artSkinId, 'p3r');
    });
  });
}
