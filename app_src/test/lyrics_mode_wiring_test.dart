@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/lyrics.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/player_screen.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/widgets/framed_art.dart';
import 'package:sonarar/widgets/lyrics_view.dart';

Track _t() => Track(
      id: 'a',
      title: 'Rivers In the Desert',
      artist: 'ATLUS Sound Team',
      album: 'P5',
      duration: const Duration(minutes: 4),
      file: 'a.opus',
      cover: '',
      gainDb: null,
    );

Lyrics _sheet() => Lyrics(
      lines: [for (var i = 0; i < 10; i++) LyricLine(Duration(seconds: i), 'line number $i')],
      source: 'test',
    );

Widget _host({
  required Duration at,
  required ScrollController controller,
  required ValueChanged<Duration> onSeek,
  required VoidCallback onExit,
  required VoidCallback onSwipeNext,
  required VoidCallback onSwipePrevious,
}) =>
    MaterialApp(
      home: Material(
        child: PlayerScreen(
          state: AppState(),
          track: _t(),
          lyricsMode: true,
          lyrics: _sheet(),
          onSeek: onSeek,
          onSwipeNext: onSwipeNext,
          onSwipePrevious: onSwipePrevious,
          lyricsContent: LyricsView(
            skin: kSkinCrimson,
            lyrics: _sheet(),
            position: at,
            controller: controller,
            onExit: onExit,
            onSeek: onSeek,
          ),
        ),
      ),
    );

Widget _figureHost({required bool lyricsMode}) => MaterialApp(
      home: Material(
        child: PlayerScreen(
          state: AppState(),
          track: _t(),
          lyricsMode: lyricsMode,
          lyrics: _sheet(),
          lyricsContent: lyricsMode
              ? LyricsView(
                  skin: kSkinAbyss,
                  lyrics: _sheet(),
                  position: const Duration(seconds: 3),
                  controller: ScrollController(),
                  onExit: () {},
                )
              : null,
        ),
      ),
    );

void main() {
  testWidgets('the art dissolves in the PLAYER but NOT in lyrics mode', (tester) async {
    await tester.pumpWidget(_figureHost(lyricsMode: false));
    await tester.pumpAndSettle();

    if (tester.widgetList<FramedArt>(find.byType(FramedArt, skipOffstage: false)).isEmpty) {
      markTestSkipped('no art in this build, so there is no dissolve to measure');
      return;
    }
    expect(find.byType(ShaderMask), findsWidgets,
        reason: 'the player lost the dissolve he said he likes');

    await tester.pumpWidget(_figureHost(lyricsMode: true));
    await tester.pumpAndSettle();
    expect(find.byType(ShaderMask, skipOffstage: false), findsNothing,
        reason: 'the dissolve is still on the art in lyrics mode — that is the dark thing he does not want '
            'behind words');
  });

  testWidgets('the words sit on a SLIGHTLY darkened page, not a lid', (tester) async {
    await tester.pumpWidget(_figureHost(lyricsMode: true));
    await tester.pumpAndSettle();
    final washes = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .map((c) => c.color.a)
        .where((a) => a > 0.01 && a < 0.9)
        .toList();
    expect(washes, isNotEmpty,
        reason: 'there is no wash at all — the page is not darkened');
    expect(washes.any((a) => a > 0.15 && a <= 0.45), isTrue,
        reason: 'the wash is not SLIGHT — either gone or heavy enough to be a lid (found: $washes)');

    final artOpacities = tester
        .widgetList<FramedArt>(find.byType(FramedArt))
        .map((a) => a.opacity)
        .toList();

    if (artOpacities.isEmpty) {
      markTestSkipped('no art in this build, so the double-dimming check has nothing to measure');
      return;
    }
    expect(artOpacities, contains(1.0),
        reason: 'the art is being dimmed as well as the page — that is the double-dimming bug');
  });

  testWidgets('tapping a line does NOT leave the sync button up', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(
      at: const Duration(seconds: 3),
      controller: controller,
      onSeek: (_) {},
      onExit: () {},
      onSwipeNext: () {},
      onSwipePrevious: () {},
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('line number 6'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('line number 6'));
    await tester.pumpAndSettle();

    expect(controller.offset, closeTo(6 * kLyricSlot, 1.0),
        reason: 'the sheet did not recenter on the tapped line');
    expect(find.byKey(const Key('lyrics-sync')), findsNothing,
        reason: 'the sync button appeared after a tap even though the view IS synced — the recenter was '
            'mistaken for the reader browsing');
  });

  testWidgets('opening mid-song shows the CURRENT line, with no scroll from the top',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(
      at: const Duration(seconds: 7),
      controller: controller,
      onSeek: (_) {},
      onExit: () {},
      onSwipeNext: () {},
      onSwipePrevious: () {},
    ));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(controller.offset, closeTo(7 * kLyricSlot, 2.0),
        reason: 'the sheet started at the top and was scrolling to the current line — his ask is that it '
            'simply OPENS at the current time');
  });
}
