@Tags(['shots'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/main.dart';
import 'package:sonarar/player/queue.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/screens/mini_player.dart';
import 'package:sonarar/screens/player_screen.dart';
import 'package:sonarar/screens/settings_screen.dart';
import 'package:sonarar/screens/tab_bar_view.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/skin_policy.dart';

import 'shell_probe.dart';

/// Screenshots a review can actually read.
///
/// The committed goldens render in the test font, so every label is a row of
/// boxes: right for catching a moved layout, useless for judging type or
/// contrast. This suite registers the platform font first, then writes PNGs
/// instead of comparing them, so the tree the shell actually builds can be
/// looked at. Output goes to `docs/shots/review` (override with `SHOTS_OUT`).
///
/// The images are evidence, not assertions, so the `shots` tag stays out of the
/// default run: `flutter test --tags shots test/shots_test.dart`.
const Size kSmall = Size(360, 740);
const Size kPhone = Size(412, 900);
const Size kLarge = Size(480, 1000);

final String _outRoot = Platform.environment['SHOTS_OUT'] ?? 'docs/shots/review';

/// Latin fixtures on purpose: the host has no CJK font to register, so a
/// Japanese title would photograph as tofu and hide the type behind it.
Track _t(int i) => Track(
      id: 't$i',
      title: 'Living With Determination',
      artist: 'ATLUS Sound Team',
      album: 'Persona 3 Reload',
      duration: Duration(seconds: 180 + i * 7),
      file: 't$i.opus',
      cover: '',
      gainDb: -3.0,
    );

List<Track> _library() => [for (var i = 0; i < 24; i++) _t(i)];

AppState _state({bool playing = false}) {
  final s = AppState();
  s.attachLibrary(_library());
  for (var i = 0; i < 4; i++) {
    s.createPlaylist('Persona Mix $i');
  }
  s.updateContext(const PlayContext(
    band: ContextBand.evening,
    whereabouts: Whereabouts.home,
    sky: Sky.unknown,
    localHour: 19,
  ));
  if (playing) s.playTrackNow('b');
  return s;
}

/// Registers the fonts the app inherits from the platform.
///
/// Without this every string is drawn in the test font's boxes. Roboto is what
/// Android resolves a null `fontFamily` to, so the shots match the phone.
Future<void> _loadFonts() async {
  final dir = _materialFontsDir();
  if (dir == null) {
    // ignore: avoid_print
    print('shots: no platform font found — text renders as boxes');
    return;
  }
  const faces = [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ];
  for (final face in faces) {
    final file = File('${dir.path}/$face');
    if (!file.existsSync()) continue;
    final bytes = ByteData.sublistView(await file.readAsBytes());
    await (FontLoader('Roboto')..addFont(Future.value(bytes))).load();
  }

  // Every icon in the app is a glyph of this font; without it the shots are a
  // grid of hollow squares where the controls are.
  final icons = File('${dir.path}/materialicons-regular.otf');
  if (icons.existsSync()) {
    final bytes = ByteData.sublistView(await icons.readAsBytes());
    await (FontLoader('MaterialIcons')..addFont(Future.value(bytes))).load();
  }
}

/// A square cover for the player's art slot.
///
/// The art is a library asset, not a fixture, so the shot reads it the way the
/// app does and falls back to the bundled mark when the music folder is absent.
Uint8List _cover() {
  final dir = Directory(r'C:\Users\Noah\Music\Sonarar\covers');
  if (dir.existsSync()) {
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.jpg'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    if (files.isNotEmpty) return files.first.readAsBytesSync();
  }
  return File('assets/brand/logo_mark.png').readAsBytesSync();
}

Directory? _materialFontsDir() {
  final candidates = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final root?)
      '$root/bin/cache/artifacts/material_fonts',
  ];
  // flutter_tester lives at <flutter>/bin/cache/artifacts/engine/<host>/, so the
  // SDK is a few levels up from the running executable on any host.
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 6; i++) {
    candidates.add('${dir.path}/bin/cache/artifacts/material_fonts');
    dir = dir.parent;
  }
  for (final path in candidates) {
    final d = Directory(path);
    if (d.existsSync()) return d;
  }
  return null;
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

String _shot(String name, Size size) =>
    '$_outRoot/${name}_${size.width.round()}.png';

/// Shoots a screen inside a bare `Scaffold`.
///
/// These screens need a `Material` ancestor for their ink; the shell supplies
/// one in the app, so a host supplies it here.
Future<void> _shootWidget(
  WidgetTester tester,
  String name,
  Size size,
  Widget child,
) async {
  _size(tester, size);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: child),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();

  await expectLater(find.byType(Scaffold), matchesGoldenFile(_shot(name, size)));
}

Future<void> _shootShell(
  WidgetTester tester,
  String name,
  Size size,
  AppState state, {
  String? tab,
  bool openPlayer = false,
}) async {
  _size(tester, size);

  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HomeShell(state: state),
  ));
  await tester.pump(const Duration(milliseconds: 50));
  HomeShellStateProbe.shellCall(tester, 'debugFinishLoading');
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }

  if (tab != null) {
    await tester.tap(find.descendant(
      of: find.byType(TabBarView2),
      matching: find.text(tab == 'library' ? 'LIBRARY' : 'SETTINGS'),
    ));
    await tester.pumpAndSettle();
  }
  if (openPlayer) {
    HomeShellStateProbe.shellCall(tester, 'debugOpenPlayer');
    await tester.pumpAndSettle();
  }

  await expectLater(
    find.byType(HomeShell),
    matchesGoldenFile(_shot(name, size)),
  );
}

void main() {
  setUpAll(() async {
    goldenFileComparator = _WriteOnlyComparator();
    // A shot is of a widget tree, not of the platform: the audio engine asks for
    // a wakelock as soon as a track is current and this host has no plugin for
    // it, which would fail the test that merely looked at the screen.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      // A pigeon success reply is a one-element list: the error slot, null.
      (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
    );
    await _loadFonts();
  });

  for (final size in [kSmall, kPhone, kLarge]) {
    final w = size.width.round();

    testWidgets('shell home $w', (tester) async {
      await _shootShell(tester, 'shell_home', size, _state());
    });

    testWidgets('shell library $w', (tester) async {
      await _shootShell(tester, 'shell_library', size, _state(), tab: 'library');
    });

    testWidgets('shell settings $w', (tester) async {
      await _shootShell(tester, 'shell_settings', size, _state(),
          tab: 'settings');
    });

    testWidgets('library empty $w', (tester) async {
      final s = _state();
      await _shootWidget(
        tester,
        'library_empty',
        size,
        LibraryScreen(view: LibraryScreenView(
          tracks: const [],
          coverPathFor: (_) => null,
          skin: s.skin,
          libraryRoot: '/storage/emulated/0/Music/Sonarar',
          onChooseFolder: () {},
          onFindMusic: () {},
          playlists: PlaylistList(),
        )),
      );
    });

    testWidgets('library search $w', (tester) async {
      final s = _state();
      _size(tester, size);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: LibraryScreen(view: LibraryScreenView(
            tracks: _library(),
            coverPathFor: (_) => null,
            skin: s.skin,
            onFindMusic: () {},
            playlists: PlaylistList(),
          )),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(_shot('library_search', size)),
      );
    });

    testWidgets('mini player $w', (tester) async {
      final s = _state(playing: true);
      await _shootWidget(
        tester,
        'mini_player',
        size,
        MiniPlayer(
          skin: s.skin,
          track: s.currentTrack!,
          cover: null,
          playing: true,
          onPlayPause: () {},
          onCycleRepeat: () {},
          repeatMode: RepeatMode.one,
        ),
      );
    });

    testWidgets('player $w', (tester) async {
      final s = _state(playing: true);
      await _shootWidget(
        tester,
        'player',
        size,
        PlayerScreen(
          view: PlayerView(
            state: s,
            track: s.currentTrack,
            cover: MemoryImage(_cover()),
          ),
        ),
      );
    });

    testWidgets('settings light skin $w', (tester) async {
      final s = _state()..chooseSkinManually(SkinId.minimal);
      await _shootWidget(
          tester, 'settings_minimal', size, SettingsScreen(state: s));
    });
  }
}

/// Writes the PNG and calls it a pass: a shot is evidence, not a claim.
class _WriteOnlyComparator extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    await update(golden, imageBytes);
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    final file = File(golden.path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(imageBytes);
  }

  @override
  Uri getTestUri(Uri key, int? version) => key;
}
