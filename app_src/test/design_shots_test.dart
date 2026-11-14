library;

// Renders the UI-audit state matrix to build/design-shots/<phase>/.
//
// This is a design tool, not a gate: it writes PNGs and always passes. Run it
// with a phase in the name so before/after pairs cannot overwrite each other:
//
//   "C:/src/flutter/bin/flutter.bat" test test/design_shots_test.dart \
//       --dart-define=PHASE=before
//
// No device or emulator: every shot is a widget-tree render, so hover and
// pressed states are injected with real pointer events.

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/core/prefs.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/main.dart';
import 'package:sonarar/screens/first_run_screen.dart';
import 'package:sonarar/screens/player_screen.dart' show PlayerPanel;
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/skin_policy.dart';

import 'shell_probe.dart';
import 'tolerant_golden.dart';

const String _phase = String.fromEnvironment('PHASE', defaultValue: 'before');

int _boots = 0;

Track _t(String id, {String? title, String? artist, String? album}) => Track(
      id: id,
      title: title ?? 'Title $id',
      artist: artist ?? 'Artist $id',
      album: album ?? 'Persona 5',
      duration: const Duration(minutes: 3, seconds: 14),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

final List<Track> _library = <Track>[
  _t('1', title: 'Night Drive', artist: 'Kaori Ito', album: 'Evening'),  _t('2', title: 'Paper Lanterns', artist: 'Sable Court', album: 'Evening'),
  _t('3', title: 'Static Bloom', artist: 'The Quiet Hours'),
  _t('4', title: 'Second Crossing', artist: 'Iori Nakamura'),
  _t('5', title: 'Cold Coffee', artist: 'Marisa Vale'),
  _t('6', title: 'Harbour Lights', artist: 'North Pier'),
  _t('7', title: 'Half Awake', artist: 'June Field'),
  _t('8', title: 'Blue Hour', artist: 'Kaori Ito'),
  _t('9', title: 'Empty Platform', artist: 'The Quiet Hours'),
];

AppState _state({bool empty = false}) {
  final state = AppState();
  state.attachLibrary(empty ? <Track>[] : _library);
  if (!empty) {
    state.updateContext(const PlayContext(
      band: ContextBand.evening,
      whereabouts: Whereabouts.home,
      sky: Sky.unknown,
      localHour: 19,
    ));
  }
  return state;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  // The app's own boot paths reach for plugins that do not exist in the test
  // harness (path_provider, permissions). Those failures are the harness's, not
  // the UI's, so they are drained instead of failing the shot.
  while (tester.takeException() != null) {}
}

Future<void> _boot(
  WidgetTester tester, {
  Size size = const Size(412, 892),
  double dpr = 2.0,
  LayoutKind kind = LayoutKind.sonar,
  int paletteIndex = 0,
  SkinId skin = SkinId.abyss,
  bool empty = false,
}) async {
  tester.view.physicalSize = size * dpr;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);

  final state = _state(empty: empty);
  state.chooseSkinManually(skin);
  state.setLayout(kind, paletteIndex: paletteIndex);

  // A fresh key per boot: re-pumping the same widget type would reuse the old
  // State and keep the player route on its Navigator.
  await tester.pumpWidget(MaterialApp(
    key: ValueKey<int>(_boots++),
    debugShowCheckedModeBanner: false,
    home: HomeShell(state: state),
  ));
  // Let the real boot sequence run — it is what loads the bundled demo library,
  // and force-finishing too early leaves every list empty.
  for (var i = 0; i < 24; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    while (tester.takeException() != null) {}
  }
  HomeShellStateProbe.shellCall(tester, 'debugFinishLoading');
  await _settle(tester);
}

Future<void> _shot(WidgetTester tester, String name) => expectLater(
      find.byType(HomeShell),
      matchesGoldenFile('../build/design-shots/$_phase/$name.png'),
    );

Future<void> _shotWidget(WidgetTester tester, String name) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../build/design-shots/$_phase/$name.png'),
    );

Future<void> _toLibrary(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.library_music_rounded).first);
  await _settle(tester);
}

Future<void> _toSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_rounded).first);
  await _settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // Pigeon channels speak StandardMessageCodec, so they answer with a raw
    // encoded reply; wrapping them in a MethodCallHandler corrupts the message.
    for (final name in const [
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.isEnabled',
    ]) {
      messenger.setMockMessageHandler(
        name,
        (message) async =>
            const StandardMessageCodec().encodeMessage(<Object?>[null]),
      );
    }
    for (final name in const [
      'dev.fluttercommunity.plus/wakelock',
      'com.ryanheise.just_audio_background',
      'sonarar/location',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async => null);
    }
  });

  setUpAll(() {
    goldenFileComparator = TolerantGoldenFileComparator(
      basePath: 'test',
      channelTolerance: 4,
      writeOnly: true,
    );
  });

  // `flutter test` draws every glyph as a box because the engine's default
  // family is Ahem. Registering Roboto under that same family name (and under
  // the null-family fallback the widgets actually ask for) makes the shots
  // legible without touching app code.
  setUpAll(() async {
    const dir = 'C:/src/flutter/bin/cache/artifacts/material_fonts';
    const files = <String>[
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
      'roboto-black.ttf',
      'roboto-italic.ttf',
    ];
    for (final family in const ['Ahem', 'Roboto', 'sans-serif']) {
      final loader = FontLoader(family);
      for (final f in files) {
        final file = File('$dir/$f');
        if (file.existsSync()) {
          loader.addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer)));
        }
      }
      await loader.load();
    }

    // Without the icon font every glyph button renders as an empty square.
    final icons = File('$dir/materialicons-regular.otf');
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)));
      await loader.load();
    }
  });

  const phone = Size(412, 892);
  const small = Size(320, 620);

  final variants = <(String, LayoutKind, int, SkinId)>[
    ('sonar-abyss', LayoutKind.sonar, 0, SkinId.abyss),
    ('solid-midnight', LayoutKind.solid, 0, SkinId.crimson),
    ('glass-aurora', LayoutKind.glass, 0, SkinId.crimson),
    ('light-minimal', LayoutKind.solid, 0, SkinId.minimal),
    ('sonar-minimal', LayoutKind.sonar, 0, SkinId.minimal),
  ];

  for (final (label, kind, paletteIndex, skin) in variants) {
    testWidgets('matrix — $label', (tester) async {
      Future<void> boot({Size size = phone}) => _boot(
            tester,
            size: size,
            kind: kind,
            paletteIndex: paletteIndex,
            skin: skin,
          );

      // --- default screens, phone ---
      await boot();
      await _shot(tester, '$label-home');

      await _toLibrary(tester);
      await _shot(tester, '$label-library');

      await _toSettings(tester);
      await _shot(tester, '$label-settings');

      await _boot(tester, kind: kind, paletteIndex: paletteIndex, skin: skin);
      HomeShellStateProbe.shellCall(tester, 'debugOpenPlayer');
      await _settle(tester);
      await _shotWidget(tester, '$label-player');

      // The queue panel is the only screen with real list rows in this harness
      // (the song list needs a folder on disk), so it carries the row evidence.
      await _boot(tester, kind: kind, paletteIndex: paletteIndex, skin: skin);
      HomeShellStateProbe.shellCall(tester, 'debugOpenPanel', PlayerPanel.queue);
      await _settle(tester);
      await _shot(tester, '$label-panel-queue');

      // --- pressed + hover, captured mid-gesture ---
      await boot();
      final play = tester.getCenter(find.byIcon(Icons.play_arrow_rounded).first);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: play);
      await tester.pump(const Duration(milliseconds: 200));
      await _shot(tester, '$label-hover');
      await mouse.down(play);
      await tester.pump(const Duration(milliseconds: 40));
      await _shot(tester, '$label-pressed');
      await mouse.up();
      await mouse.removePointer();
      await _settle(tester);

      // --- small window ---
      await boot(size: small);
      await _shot(tester, '$label-home-small');

      await _toLibrary(tester);
      await _shot(tester, '$label-library-small');

      await _toSettings(tester);
      await _shot(tester, '$label-settings-small');

      // --- empty library ---
      await _boot(tester, kind: kind, paletteIndex: paletteIndex, skin: skin, empty: true);
      await _shot(tester, '$label-home-empty');

      await _toLibrary(tester);
      await _shot(tester, '$label-library-empty');
    });
  }

  testWidgets('first run', (tester) async {
    for (final (label, kind, skin) in <(String, LayoutKind, SkinId)>[
      ('sonar-abyss', LayoutKind.sonar, SkinId.abyss),
      ('light-minimal', LayoutKind.solid, SkinId.minimal),
    ]) {
      tester.view.physicalSize = phone * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final state = _state();
      state.chooseSkinManually(skin);
      state.setLayout(kind);

      await tester.pumpWidget(MaterialApp(
        home: PresentationScope(
          presentation: state.presentation,
          child: FirstRunScreen(
            skin: state.uiSkin,
            prefs: AppPrefs.initial,
            layoutId: kind,
            onPrefs: (_) {},
            onDone: () {},
          ),
        ),
      ));
      await _settle(tester);
      await _shotWidget(tester, '$label-firstrun');
    }
  });
}
