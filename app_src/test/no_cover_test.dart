library;

// A track with no cover file has nothing to draw, and for a long time the app
// drew exactly that: nothing. On the player it was a 156 dp void inside a teal
// border, on the mini player a 40 dp one, and on a list row a bare panel. A
// void reads as "the picture failed to load", which is a promise the app then
// breaks forever, because there is no picture to load.
//
// `NoCover` is the one answer: the skin's panel plus a dimmed note glyph. These
// tests hold it to that shape, and hold the callers to actually using it, so a
// future refactor cannot quietly go back to `ColoredBox`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/track.dart';
// material.dart exports its own RepeatMode; the player's one is the queue's.
import 'package:sonarar/player/queue.dart' as queue;
import 'package:sonarar/screens/mini_player.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/widgets/cover_button.dart';
import 'package:sonarar/widgets/cover_play_button.dart';
import 'package:sonarar/widgets/no_cover.dart';

Track _t() => Track(
  id: 'no-cover',
  title: 'A track with no picture',
  artist: 'Nobody',
  album: 'Nothing',
  duration: const Duration(seconds: 200),
  file: 'no-cover.opus',
  cover: '',
  gainDb: 0,
);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    backgroundColor: Colors.black,
    body: Center(child: child),
  ),
);

void main() {
  final skin = skinFor(SkinId.crimson);

  testWidgets('the shared placeholder draws a note, not a void', (
    tester,
  ) async {
    await tester.pumpWidget(_host(NoCover(skin: skin, size: 156)));
    await tester.pump();

    final note = find.byIcon(Icons.music_note_rounded);
    expect(
      note,
      findsOneWidget,
      reason:
          'NoCover must draw Icons.music_note_rounded; a placeholder with no '
          'glyph is the void this widget exists to replace.',
    );

    final box = tester.getSize(find.byType(NoCover));
    final glyph = tester.getSize(note);
    expect(
      glyph.width,
      lessThan(box.width * 0.5),
      reason:
          'The glyph must stay a mark inside the panel (<= half its width), '
          'not a picture-sized icon that reads as the cover itself.',
    );
  });

  testWidgets('the player cover falls back to the placeholder', (tester) async {
    await tester.pumpWidget(
      _host(
        CoverButton(
          skin: skin,
          cover: null,
          playing: false,
          onPlayPause: () {},
          size: 156,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byType(NoCover),
      findsOneWidget,
      reason:
          'CoverButton with a null cover painted a flat ColoredBox(skin.panel); '
          'it must draw NoCover instead.',
    );
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
  });

  testWidgets('a list cover with no icon still says what it is', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CoverPlayButton(skin: skin, cover: null, size: 56, onTogglePlay: () {}),
      ),
    );
    await tester.pump();

    expect(
      find.byType(NoCover),
      findsOneWidget,
      reason:
          'CoverPlayButton without a fallbackIcon returned a bare panel; the '
          'shared placeholder is what a caller gets when it names no icon.',
    );
  });

  testWidgets('the mini player cover falls back too', (tester) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 360,
          height: 64,
          child: MiniPlayer(
            skin: skin,
            track: _t(),
            cover: null,
            playing: false,
            onPlayPause: () {},
            onCycleRepeat: () {},
            repeatMode: queue.RepeatMode.off,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byType(NoCover),
      findsOneWidget,
      reason:
          'The mini player cover used ColoredBox(skin.background) for a track '
          'with no picture; it must use NoCover so both players agree.',
    );
  });
}
