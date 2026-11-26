library;

// Nothing in `lib/` reads the orientation, and the app is a portrait thing —
// but a phone in a car mount, a foldable half-open and a tablet all hand it a
// wider-than-tall viewport, and a fixed column that assumed height would paint
// the yellow overflow marker over the transport instead of scrolling.
//
// So: the same five screens on an 800x360 viewport, which is the short side of
// a small phone turned on its side. This is the cheap half of the question —
// that nothing overflows. Whether the landscape layout is *good* is a design
// call this cannot make.

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/player/queue.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/screens/mini_player.dart';
import 'package:sonarar/screens/player_screen.dart';
import 'package:sonarar/screens/queue_screen.dart';
import 'package:sonarar/screens/settings_screen.dart';

Track _t(String id, String title, String artist) => Track(
    id: id,
    title: title,
    artist: artist,
    album: 'Persona 3 Reload',
    duration: const Duration(seconds: 208),
    file: '$id.opus',
    cover: '',
    gainDb: -3.0);

final _lib = <Track>[
  _t('a', '全ての人の魂の戦い', 'ATLUS Sound Team'),
  _t('b', 'Living With Determination', 'ATLUS Sound Team'),
];

AppState _state() {
  final s = AppState()..attachLibrary(_lib);
  s.playTrackNow('a');
  return s;
}

Future<List<String>> _overflows(WidgetTester tester, String name, double scale,
    Widget child) async {
  tester.view.physicalSize = const Size(800, 360) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final caught = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => caught.add(details.toString());

  await tester.pumpWidget(MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: child),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  FlutterError.onError = previous;

  final found = <String>[];
  for (final text in caught) {
    if (!text.contains('overflowed')) continue;
    final lines = text.split('\n');
    final headline = lines.firstWhere((l) => l.contains('overflowed'), orElse: () => '');
    final where = lines.firstWhere(
        (l) => l.contains('file:///') && l.contains('app_src/lib'),
        orElse: () => '');
    found.add('$name @ ${scale}x: $headline\n    $where');
  }
  return found;
}

void main() {
  testWidgets('the five screens hold their shape in landscape', (tester) async {
    final s = _state();
    final complaints = <String>[];

    for (final scale in const [1.0]) {
      final t = s.currentTrack!;
      complaints.addAll(await _overflows(
          tester,
          'mini player',
          scale,
          MiniPlayer(
            skin: s.skin,
            track: t,
            cover: null,
            playing: true,
            position: const Duration(seconds: 42),
            duration: const Duration(seconds: 208),
            onSeek: (_) {},
            onPlayPause: () {},
            onCycleRepeat: () {},
            repeatMode: RepeatMode.off,
            onOpen: () {},
            onDisband: () {},
          )));
      complaints.addAll(await _overflows(
          tester,
          'library',
          scale,
          LibraryScreen(
              view: LibraryScreenView(
            tracks: _lib,
            coverPathFor: (_) => null,
            skin: s.skin,
            libraryRoot: '/music',
            likedIds: {'a'},
            onPlaylistSort: (_) {},
          ))));
      complaints.addAll(await _overflows(
          tester, 'settings', scale, SettingsScreen(state: s)));
      complaints.addAll(await _overflows(
          tester,
          'player',
          scale,
          PlayerScreen(
              view: PlayerView(
                  state: s, track: s.currentTrack, cover: null))));
      complaints.addAll(await _overflows(
          tester, 'queue', scale, QueuePanel(state: s)));
    }

    expect(complaints, isEmpty, reason: complaints.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
