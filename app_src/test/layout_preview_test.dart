library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/main.dart';
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/skin_policy.dart';

import 'shell_probe.dart';
import 'tolerant_golden.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Title $id',
      artist: 'Artist $id',
      album: 'Persona 5',
      duration: const Duration(minutes: 3),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

int _paletteCount(LayoutKind k) => switch (k) {
      LayoutKind.sonar => 1,
      LayoutKind.solid => kSolidPalettes.length,
      LayoutKind.glass => kGlassPalettes.length,
    };

String _paletteName(LayoutKind k, int i) => switch (k) {
      LayoutKind.sonar => 'default',
      LayoutKind.solid => kSolidPalettes[i].name.toLowerCase(),
      LayoutKind.glass => kGlassPalettes[i].name.toLowerCase(),
    };

void main() {
  const size = Size(420, 860);

  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
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
      'personar/location',
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

  final previews = <(LayoutKind, int, String)>[
    for (final k in LayoutKind.values)
      for (var i = 0; i < _paletteCount(k); i++) (k, i, _paletteName(k, i)),
  ];

  for (final (kind, paletteIndex, paletteName) in previews) {
    testWidgets('layout preview — ${kind.name} / $paletteName', (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final state = AppState();
      state.attachLibrary([for (var i = 0; i < 30; i++) _t('t$i')]);
      state.updateContext(const PlayContext(
        band: ContextBand.evening,
        whereabouts: Whereabouts.home,
        sky: Sky.unknown,
        localHour: 19,
      ));
      state.chooseSkinManually(SkinId.crimson);
      state.setLayout(kind, paletteIndex: paletteIndex);

      // ignore: avoid_print
      print('${kind.name}/$paletteName: layoutId BEFORE shell = ${state.layoutId}');
      await tester.pumpWidget(MaterialApp(home: HomeShell(state: state)));
      await tester.pump(const Duration(milliseconds: 50));
      HomeShellStateProbe.shellCall(tester, 'debugFinishLoading');
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }

      // ignore: avoid_print
      print('${kind.name}/$paletteName: AFTER shell = ${state.layoutId}  '
          'accent=${state.palette.accent} bg=${state.palette.background}');

      await expectLater(
        find.byType(HomeShell),
        matchesGoldenFile(
            '../build/layout-preview/${kind.name}-$paletteName-player.png'),
      );

      await tester.tap(find.text('LIBRARY').first);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await expectLater(
        find.byType(HomeShell),
        matchesGoldenFile(
            '../build/layout-preview/${kind.name}-$paletteName-library.png'),
      );

      for (final suffix in ['player', 'library']) {
        final f = File('build/layout-preview/${kind.name}-$paletteName-$suffix.png');
        // ignore: avoid_print
        print('preview ${kind.name}-$paletteName-$suffix exists=${f.existsSync()} '
            'bytes=${f.existsSync() ? f.lengthSync() : 0}');
      }
    });
  }
}
