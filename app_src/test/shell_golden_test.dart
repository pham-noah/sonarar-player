@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/core/clock.dart';
import 'package:sonarar/main.dart';
import 'package:sonarar/screens/tab_bar_view.dart';
import 'package:sonarar/theme/skin_policy.dart';

import 'shell_probe.dart';
import 'tolerant_golden.dart';

/// The shell as it is actually composed — bar, mini player, backdrop — with no
/// device in the loop. A golden of the whole window is the closest thing to a
/// screenshot this host can produce while hardware virtualisation is off.
Track _t(int i) => Track(
      id: 't$i',
      title: 'Title $i',
      artist: 'ATLUS Sound Team',
      album: 'Persona 5',
      duration: const Duration(minutes: 4),
      file: 't$i.opus',
      cover: '',
      gainDb: null,
    );

Future<void> _pump(WidgetTester tester, AppTab tab) async {
  tester.view.physicalSize = const Size(412, 900) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final state = AppState();
  state.attachLibrary([for (var i = 0; i < 24; i++) _t(i)]);
  for (var i = 0; i < 4; i++) {
    state.createPlaylist('Playlist $i');
  }
  state.updateContext(const PlayContext(
      band: ContextBand.evening,
      whereabouts: Whereabouts.home,
      sky: Sky.unknown,
      localHour: 19));

  await tester.pumpWidget(MaterialApp(home: HomeShell(state: state)));
  await tester.pump(const Duration(milliseconds: 50));
  HomeShellStateProbe.shellCall(tester, 'debugFinishLoading');
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }

  if (tab != AppTab.home) {
    await tester.tap(find.descendant(
      of: find.byType(TabBarView2),
      matching: find.text(
        tab == AppTab.library ? 'LIBRARY' : 'SETTINGS',
      ),
    ));
    await tester.pumpAndSettle();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    goldenFileComparator = TolerantGoldenFileComparator(
      basePath: 'test',
      channelTolerance: 4,
    );
  });

  setUp(() {
    // Pin the hour: the greeting and the skin band come from the wall clock, so
    // an unpinned run rendered differently at 06:00 than at 02:00 and the shell
    // golden failed for a reason that was not a regression. 02:00 is the band
    // the committed screenshots were taken in, so pinning it to 02:00 changes no
    // pixel and the image can no longer drift with the hour the suite runs at.
    Clock.now = () => DateTime(2026, 11, 14, 2, 0);

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // A golden of the shell pulls the wakelock in through the player; without
    // these the pigeon channel throws and the test dies before the compare.
    // Pigeon channels speak StandardMessageCodec, so they answer with a raw
    // encoded reply.
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

  tearDown(() {
    Clock.now = DateTime.now;
  });

  testWidgets('the shell, home tab', (tester) async {
    await _pump(tester, AppTab.home);
    await expectLater(
      find.byType(HomeShell),
      matchesGoldenFile('goldens/shell_home.png'),
    );
  });

  testWidgets('the shell, library tab', (tester) async {
    await _pump(tester, AppTab.library);
    await expectLater(
      find.byType(HomeShell),
      matchesGoldenFile('goldens/shell_library.png'),
    );
  });

  testWidgets('the shell, settings tab', (tester) async {
    await _pump(tester, AppTab.settings);
    await expectLater(
      find.byType(HomeShell),
      matchesGoldenFile('goldens/shell_settings.png'),
    );
  });
}
