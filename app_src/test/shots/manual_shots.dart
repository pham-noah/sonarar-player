/// Renders the app's screens to PNG for the README. Not part of the suite:
///
///     flutter test test/shots/manual_shots.dart --update-goldens
///
/// The library is invented and the artwork is generated; the UI is the real one.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/context/weather_codes.dart';
import 'package:sonarar/library/home_rails.dart';
import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/home_screen.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/screens/player_screen.dart';
import 'package:sonarar/screens/settings_screen.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/widgets/panel_bodies.dart';

const Size _phone = Size(390, 844);

const String _coverDir = 'test/shots/covers';

Uint8List _cover(String name) =>
    File('$_coverDir/$name.png').readAsBytesSync();

String _coverPath(Track t) => '$_coverDir/${t.id}.png';

Track _t(String id, String title, String artist, String album, int seconds) =>
    Track(
      id: id,
      title: title,
      artist: artist,
      album: album,
      duration: Duration(seconds: seconds),
      file: '$id.opus',
      cover: '',
      gainDb: -3.0,
    );

final _library = <Track>[
  _t('night-drive', 'Night Drive', 'Hana Ito', 'After Hours', 274),
  _t('paper-lantern', 'Paper Lantern', 'Hana Ito', 'After Hours', 231),
  _t('salt-air', 'Salt Air', 'Rowan Marsh', 'Coastal', 198),
  _t('quiet-hours', 'Quiet Hours', 'Rowan Marsh', 'Coastal', 245),
  _t('low-sun', 'Low Sun', 'Kite Ensemble', 'Long Way Round', 312),
  _t('blue-hour', 'Blue Hour', 'Kite Ensemble', 'Long Way Round', 268),
];

/// The harness replaces fonts with one that draws every glyph as a block.
Future<void> _loadFonts() async {
  const fonts = 'C:/src/flutter/bin/cache/artifacts/material_fonts';
  final families = <String, List<String>>{
    'Roboto': ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-black.ttf'],
    'MaterialIcons': ['materialicons-regular.otf'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      final path = '$fonts/$file';
      if (!File(path).existsSync()) continue;
      loader.addFont(
        Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
      );
    }
    await loader.load();
  }
}

/// Precache against the drawing element: an `Image` decodes asynchronously.
final _coverImages = <String, MemoryImage>{};

ImageProvider _memoryCovers(String path) => _coverImages.putIfAbsent(
      path,
      () => MemoryImage(File(path).readAsBytesSync()),
    );

Future<void> _pump(WidgetTester tester, Widget screen, Skin skin) async {
  debugCoverProvider = _memoryCovers;
  tester.view.physicalSize = _phone * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeFor(skin),
      home: Scaffold(body: screen),
    ),
  );
  await tester.pump();

  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();

  // ignore: avoid_print
  print('[shots] ${screen.runtimeType}: images='
      '${find.byType(Image).evaluate().length} '
      'cached=${PaintingBinding.instance.imageCache.currentSize}');
}

AppState _state(SkinId id) {
  final s = AppState();
  s.chooseSkinManually(id);
  return s;
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('home', (tester) async {
    final s = _state(SkinId.abyss);
    final plays = PlaylistList([
      Playlist(
        id: 'pl_night',
        name: 'Night Bus',
        trackIds: const ['night-drive', 'blue-hour', 'paper-lantern'],
      ),
      Playlist(
        id: 'pl_slow',
        name: 'Slow Sunday',
        trackIds: const ['quiet-hours', 'salt-air'],
      ),
    ]);

    final screen = HomeScreen(
      skin: s.skin,
      band: 'EVENING',
      greeting: 'Good evening',
      continueTrack: _library[1],
      jumpBackIn: _library.sublist(2, 5),
      heavyRotation: _library,
      rediscover: _library.reversed.take(4).toList(),
      mostPlayed: _library,
      likedSongs: _library.take(3).toList(),
      libraryPlaylists: rankPlaylistsByPlays(
        playlists: plays.all,
        events: const [],
      ),
      recapTracks: const [],
      allTracks: _library,
      nowMixName: 'Rain, at home',
      onPlayNowMix: () {},
      weather: WeatherCondition.rain,
      placeName: 'Home',
      hasFix: true,
      contextEnabled: true,
      coverPathFor: _coverPath,
      onPlay: (_) {},
    );

    await _pump(tester, screen, s.skin);
    await expectLater(
        find.byType(HomeScreen), matchesGoldenFile('../../../docs/shots/home.png'));
  });

  testWidgets('library', (tester) async {
    final s = _state(SkinId.crimson);
    final screen = LibraryScreen(
      tracks: _library,
      coverPathFor: _coverPath,
      skin: s.skin,
      playlists: PlaylistList([
        Playlist(id: 'pl_a', name: 'Night Bus', trackIds: const ['night-drive']),
      ]),
      libraryRoot: '/storage/emulated/0/Music/Sonarar',
    );

    await _pump(tester, screen, s.skin);
    await expectLater(find.byType(LibraryScreen),
        matchesGoldenFile('../../../docs/shots/library.png'));
  });

  testWidgets('player', (tester) async {
    final s = _state(SkinId.abyss);
    final screen = PlayerScreen(
      state: s,
      track: _library.first,
      cover: MemoryImage(_cover('night-drive')),
    );

    await _pump(tester, screen, s.skin);
    await expectLater(find.byType(PlayerScreen),
        matchesGoldenFile('../../../docs/shots/player.png'));
  });

  testWidgets('settings', (tester) async {
    final s = _state(SkinId.mono);
    final screen = SettingsScreen(state: s);

    await _pump(tester, screen, s.skin);
    await expectLater(find.byType(SettingsScreen),
        matchesGoldenFile('../../../docs/shots/settings.png'));
  });
}
