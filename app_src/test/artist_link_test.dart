@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/screens/player_screen.dart';
import 'package:sonarar/theme/skin.dart';

Track _t(String id, String title, String artist) => Track(
      id: id,
      title: title,
      artist: artist,
      album: 'Persona 5',
      duration: const Duration(minutes: 4),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

void main() {
  group('the player emits the artist', () {
    testWidgets('tapping the artist name reports it', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Material(
          child: PlayerScreen(
            state: AppState(),
            track: _t('a', 'Rivers In the Desert', 'ATLUS Sound Team'),
            onArtist: tapped.add,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ATLUS Sound Team'));
      await tester.pumpAndSettle();
      expect(tapped, ['ATLUS Sound Team']);
    });

    testWidgets('with NO handler the name is plain text, not a dead target',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Material(
          child: PlayerScreen(
            state: AppState(),
            track: _t('a', 'Rivers In the Desert', 'ATLUS Sound Team'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ATLUS Sound Team'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('the library opens the requested artist', () {
    Future<void> pump(WidgetTester tester, {String? artistRequest}) async {
      await tester.pumpWidget(MaterialApp(
        home: Material(
          child: LibraryScreen(
            tracks: [
              _t('a', 'Rivers In the Desert', 'ATLUS Sound Team'),
              _t('b', 'Last Surprise', 'ATLUS Sound Team'),
              _t('c', 'Some Other Song', 'RADWIMPS'),
            ],
            coverPathFor: (_) => null,
            skin: kSkinCrimson,
            artistRequest: artistRequest,
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('it switches to ARTISTS and opens the named one', (tester) async {
      await pump(tester, artistRequest: 'RADWIMPS');

      expect(find.text('RADWIMPS'), findsWidgets,
          reason: 'the artist was not opened');
      expect(find.text('Some Other Song'), findsOneWidget,
          reason: "another artist's songs are showing");
    });

    testWidgets('only THAT artist comes back', (tester) async {
      await pump(tester, artistRequest: 'ATLUS Sound Team');
      expect(find.text('Rivers In the Desert'), findsOneWidget);
      expect(find.text('Last Surprise'), findsOneWidget);
      expect(find.text('Some Other Song'), findsNothing);
    });

    testWidgets('a new request for a DIFFERENT artist is acted on', (tester) async {
      await pump(tester, artistRequest: 'ATLUS Sound Team');
      expect(find.text('Some Other Song'), findsNothing);

      await tester.pumpWidget(MaterialApp(
        home: Material(
          child: LibraryScreen(
            tracks: [
              _t('a', 'Rivers In the Desert', 'ATLUS Sound Team'),
              _t('c', 'Some Other Song', 'RADWIMPS'),
            ],
            coverPathFor: (_) => null,
            skin: kSkinCrimson,
            artistRequest: 'RADWIMPS',
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Some Other Song'), findsOneWidget,
          reason: 'a second request was ignored');
      expect(find.text('Rivers In the Desert'), findsNothing);
    });
  });
}
