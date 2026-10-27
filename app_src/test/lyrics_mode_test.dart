@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/lyrics.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/player_screen.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/widgets/lyrics_view.dart';

Track _t() => Track(
      id: 'a', title: 'Rivers In the Desert', artist: 'ATLUS Sound Team',
      album: 'P5', duration: const Duration(minutes: 4), file: 'a.opus',
      cover: '', gainDb: null,
    );

Lyrics _synced() => Lyrics(lines: const [
      LyricLine(Duration(seconds: 10), 'It is now, or it is never'),
      LyricLine(Duration(seconds: 20), 'and I have got to make my decision'),
      LyricLine(Duration(seconds: 30), 'so what will it be'),
    ], source: 'test');

Widget _player({required bool mode, Lyrics? lyrics}) => MaterialApp(
      home: Material(
        child: PlayerScreen(
          state: AppState(),
          track: _t(),
          lyricsMode: mode,
          lyrics: lyrics,
          lyricsContent: mode
              ? LyricsView(
                  skin: kSkinCrimson,
                  lyrics: lyrics,
                  position: const Duration(seconds: 22),
                  controller: ScrollController(),
                  onExit: () {},
                )
              : null,
        ),
      ),
    );

void main() {
  group('the mode hides the player', () {
    testWidgets('the words are drawn', (tester) async {
      await tester.pumpWidget(_player(mode: true, lyrics: _synced()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lyrics-mode')), findsOneWidget);
    });

    testWidgets('the transport is NOT — every ui is hidden', (tester) async {
      await tester.pumpWidget(_player(mode: true, lyrics: _synced()));
      await tester.pumpAndSettle();
      expect(find.byKey(PlayerScreen.transportKey), findsNothing);
    });

    testWidgets('off by default: the player is exactly as it was', (tester) async {
      await tester.pumpWidget(_player(mode: false, lyrics: _synced()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lyrics-mode')), findsNothing);
      expect(find.byKey(PlayerScreen.transportKey), findsOneWidget);
    });
  });

  group('the highlight follows the position', () {
    testWidgets('the line at 22s is louder than the ones around it',
        (tester) async {
      await tester.pumpWidget(_player(mode: true, lyrics: _synced()));
      await tester.pumpAndSettle();

      final current = tester.widget<Text>(
        find.text('and I have got to make my decision'),
      );
      final earlier = tester.widget<Text>(find.text('It is now, or it is never'));
      expect(current.style!.fontSize!, greaterThan(earlier.style!.fontSize!),
          reason: 'the current line is not emphasised');
      expect(current.style!.fontWeight, FontWeight.w900);
    });

    testWidgets('the words are WHITE, not a skin colour', (tester) async {
      await tester.pumpWidget(_player(mode: true, lyrics: _synced()));
      await tester.pumpAndSettle();
      final current = tester.widget<Text>(
        find.text('and I have got to make my decision'),
      );
      expect(current.style!.color, Colors.white);
    });

    testWidgets('every line is CENTRED on the screen', (tester) async {
      await tester.pumpWidget(_player(mode: true, lyrics: _synced()));
      await tester.pumpAndSettle();

      final inView = find.descendant(
        of: find.byKey(const Key('lyrics-mode')),
        matching: find.byType(Text),
      );
      final texts = tester.widgetList<Text>(inView).where((t) => (t.data ?? '').isNotEmpty);
      expect(texts, isNotEmpty);
      for (final text in texts) {
        expect(text.textAlign, TextAlign.center, reason: '"${text.data}" is not centred');
      }
    });

    testWidgets('lines BEFORE the position recede, lines after stay legible',
        (tester) async {
      await tester.pumpWidget(_player(mode: true, lyrics: _synced()));
      await tester.pumpAndSettle();
      final past = tester.widget<Text>(find.text('It is now, or it is never'));
      final ahead = tester.widget<Text>(find.text('so what will it be'));
      expect(past.style!.color!.a, lessThan(ahead.style!.color!.a),
          reason: 'a spent line should be dimmer than an upcoming one');
    });
  });

  group('it says something true when there are no words', () {
    testWidgets('an instrumental says so, because the app KNOWS', (tester) async {
      await tester.pumpWidget(_player(
        mode: true,
        lyrics: const Lyrics(lines: [], instrumental: true),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('instrumental'), findsOneWidget);
    });

    testWidgets('a failed lookup is worded differently from an instrumental',
        (tester) async {
      await tester.pumpWidget(_player(mode: true, lyrics: null));
      await tester.pumpAndSettle();
      expect(find.textContaining('No lyrics found'), findsOneWidget);
    });
  });

  group('the row', () {
    testWidgets('it leads to the mode', (tester) async {
      var opened = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LyricsRow(skin: kSkinCrimson, onOpen: () => opened++),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LyricsRow.rowKey));
      expect(opened, 1);
    });

    testWidgets('its subtitle tells the truth BEFORE the press', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LyricsRow(
            skin: kSkinCrimson,
            onOpen: () {},
            known: const Lyrics(lines: [], instrumental: true),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('no words'), findsOneWidget);
    });
  });
}
