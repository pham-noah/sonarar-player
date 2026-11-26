library;

// A music player is a thing you use with your ears, so it has to work with your
// ears: a blind user pressing "next" had no way to know what started. The player
// labels describe the buttons ("Next", "Pause"), never the song, and the cover
// carries no text, so skipping five tracks was five silent changes.
//
// `SemanticsService.announce` was called in zero places in `lib/`. This test
// captures the platform announcement and pins both halves: exactly one per
// change, naming the track that started, in the locale in force — and none when
// the same track is merely re-notified, which the player does constantly when
// the position ticks.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/l10n/app_localizations.dart';
import 'package:sonarar/widgets/now_playing_announcer.dart';

Track _t(String id, String title, String artist) => Track(
    id: id,
    title: title,
    artist: artist,
    album: 'Persona 3 Reload',
    duration: const Duration(seconds: 208),
    file: '$id.opus',
    cover: '',
    gainDb: -3.0);

void main() {
  late List<String> spoken;

  setUp(() {
    spoken = [];
    // `SystemChannels.accessibility` is a BasicMessageChannel, so the announcement
    // arrives as a decoded map, not a method call.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility,
            (Object? message) async {
      final map = message as Map;
      if (map['type'] == 'announce') {
        spoken.add((map['data'] as Map)['message'] as String);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, null);
  });

  Future<AppState> pump(WidgetTester tester, {String locale = 'en'}) async {
    final state = AppState()
      ..attachLibrary([
        _t('a', 'Living With Determination', 'ATLUS Sound Team'),
        _t('b', 'Mass Destruction', '川村ゆみ'),
      ])
      ..playTrackNow('a');
    await tester.pumpWidget(MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NowPlayingAnnouncer(
        state: state,
        child: const Scaffold(body: Text('shell')),
      ),
    ));
    await tester.pump();
    return state;
  }

  testWidgets('starting another track is said out loud', (tester) async {
    final state = await pump(tester);
    expect(spoken, isEmpty,
        reason: 'the track already playing when the app opens was not started '
            'by the user; announcing it talks over the first thing a screen '
            'reader says');

    state.playTrackNow('b');
    await tester.pump();

    expect(spoken, ['Now playing Mass Destruction by 川村ゆみ']);
  });

  testWidgets('the position ticking is not a track change', (tester) async {
    final state = await pump(tester);

    // The player notifies on every position update.
    state.playTrackNow('a');
    for (var i = 0; i < 5; i++) {
      state.notifyListeners();
    }
    await tester.pump();

    expect(spoken, isEmpty,
        reason: 'one announcement per track, not one per frame: a player that '
            'speaks on every tick is worse than one that never speaks');
  });

  testWidgets('announcements speak the locale in force', (tester) async {
    final state = await pump(tester, locale: 'fi');

    state.playTrackNow('b');
    await tester.pump();

    expect(spoken, ['Nyt soi Mass Destruction, 川村ゆみ'],
        reason: 'a Finnish user with TalkBack on must not be read English');
  });
}
