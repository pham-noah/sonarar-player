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
import 'package:sonarar/theme/surface.dart';

import 'shell_probe.dart';

const _storage = MethodChannel('personar/storage');
late Directory _sandbox;

void _fakePlatform() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => call.method.startsWith('get') ? _sandbox.path : null,
  );
  messenger.setMockMethodCallHandler(_storage, (call) async {
    switch (call.method) {
      case 'status':
      case 'request':
      case 'requestNotification':
        return 'granted';
      default:
        return null;
    }
  });
  for (final name in const [
    'dev.fluttercommunity.plus/wakelock',
    'com.lykone.location',
    'com.ryanheise.just_audio_background',
    'personar/geofence',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(name),
        (call) async => null);
  }
}

Track _t(String id) => Track(
      id: id,
      title: 'Title $id',
      artist: 'a',
      album: 'b',
      duration: const Duration(minutes: 3),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

int _filters(WidgetTester tester) =>
    tester.widgetList(find.byType(BackdropFilter)).length;

void main() {
  setUp(() {
    _sandbox = Directory.systemTemp.createTempSync('personar-glass-hold-');
    _fakePlatform();
  });
  tearDown(() {
    if (_sandbox.existsSync()) _sandbox.deleteSync(recursive: true);
  });

  Future<void> pumpGlassShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 860) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final state = AppState();
    state.attachLibrary([for (var i = 0; i < 30; i++) _t('t$i')]);
    state.updateContext(const PlayContext(
        band: ContextBand.evening,
        whereabouts: Whereabouts.home,
        sky: Sky.unknown,
        localHour: 19));
    state.setLayout(LayoutKind.glass);

    await tester.pumpWidget(MaterialApp(home: HomeShell(state: state)));
    await tester.pump(const Duration(milliseconds: 50));
    HomeShellStateProbe.shellCall(tester, 'debugFinishLoading');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('the bar filters at rest, mid-switch, and after it lands',
      (tester) async {
    await pumpGlassShell(tester);

    final atRest = _filters(tester);
    expect(atRest, greaterThan(0),
        reason: 'the glass bar has no filter at rest — the material is gone, not steady');

    await tester.tap(find.text('LIBRARY'));
    await tester.pump();

    expect(_filters(tester), atRest,
        reason: 'the bar lost its filter the moment the tab started moving — that is the material '
            'turning off and on again, which is the report');

    await tester.pump(const Duration(milliseconds: 40));
    expect(_filters(tester), atRest,
        reason: 'the filter came back partway through the arrival — it must never have left');

    await tester.pumpAndSettle();
    expect(_filters(tester), atRest,
        reason: 'the bar did not return to the glass it was — the switch changed the material');
  });

  testWidgets('opening the player does not flip it either', (tester) async {
    await pumpGlassShell(tester);
    final atRest = _filters(tester);
    expect(atRest, greaterThan(0), reason: 'no glass at rest — nothing to hold');

    HomeShellStateProbe.shellCall(tester, 'debugOpenPlayer');
    await tester.pump();

    expect(_filters(tester), atRest,
        reason: 'the filter was dropped on the player route — the bars flicker on the way in');

    await tester.pumpAndSettle();

    expect(_filters(tester), 0,
        reason: 'the shell is still painting behind an opaque page');

    HomeShellStateProbe.shellCall(tester, 'debugClosePlayer');
    await tester.pumpAndSettle();
    expect(_filters(tester), atRest,
        reason: 'the bar did not come back to the glass it was after the player closed');
  });

  testWidgets('Solid never filters, whatever is moving', (tester) async {
    final skin = skinFor(SkinId.values.first);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Surface(
          presentation: presentationFor(LayoutKind.solid, skin),
          role: SurfaceRole.bar,
          child: const SizedBox(width: 200, height: 60),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(_filters(tester), 0, reason: 'Solid grew a backdrop filter');
  });
}
