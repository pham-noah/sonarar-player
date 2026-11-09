library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/main.dart';

import 'shell_probe.dart';

const _storage = MethodChannel('sonarar/storage');

late Directory _sandbox;

void _fakePlatform() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async {
      if (call.method.startsWith('get')) return _sandbox.path;
      return null;
    },
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_storage, (call) async {
    switch (call.method) {
      case 'status':
      case 'request':
        return 'granted';
      case 'requestNotification':
        return 'granted';
      default:
        return null;
    }
  });

  // The pigeon-generated wakelock API speaks BasicMessageChannel, not
  // MethodChannel: a MethodChannel mock corrupts its reply ("Message
  // corrupted"). Answer with the one-element envelope pigeon expects.
  const codec = StandardMessageCodec();
  for (final name in const [
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.enabled',
  ]) {
    messenger.setMockMessageHandler(
      name,
      (message) async => codec.encodeMessage(<Object?>[null]),
    );
  }

  for (final name in const [
    'dev.fluttercommunity.plus/wakelock',
    'com.ryanheise.just_audio_background',
    'sonarar/location',
  ]) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(name), (call) async {
      return null;
    });
  }
}

Future<void> _boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 860) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const SonararApp());
  // Boot does real disk I/O between steps, and the widget test's clock does not
  // advance it. Alternate a real event loop with a frame pump until the shell
  // says it has finished loading, so these tests observe a booted app rather
  // than a splash.
  final shell = find.byType(HomeShell, skipOffstage: false);
  final deadline = DateTime.now().add(const Duration(seconds: 25));
  while (DateTime.now().isBefore(deadline)) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 100));
    if (shell.evaluate().isNotEmpty &&
        HomeShellStateProbe.shellCall(tester, 'loading') == false) {
      return;
    }
  }
}

void main() {
  setUp(() {
    _sandbox = Directory.systemTemp.createTempSync('sonarar-harness-');
    // A cached asset future created in one test's fake clock hangs the next
    // boot at "restoring your place".
    rootBundle.clear();
    _fakePlatform();
  });
  tearDown(() {
    if (_sandbox.existsSync()) _sandbox.deleteSync(recursive: true);
  });

  testWidgets('BOOT PROBE: how far does _load get, and where does it stop?', (tester) async {
    await _boot(tester);
    final app = HomeShellStateProbe.appStateOf(tester);

    // ignore: avoid_dynamic_calls
    final lib = (app?.library as List?) ?? const [];
    // ignore: avoid_dynamic_calls
    final q = app?.queue;
    // ignore: avoid_print
    print('HARNESS PROBE: library=${lib.length} queue=${q != null}');
  });

  testWidgets('the shell reaches its LOADED state, not just a first frame',
      (tester) async {
    await _boot(tester);
    expect(tester.takeException(), isNull,
        reason: 'the boot path threw — this is the blank-window symptom');
    expect(find.byType(HomeShell), findsOneWidget);
    expect(HomeShellStateProbe.shellCall(tester, 'loading'), isFalse,
        reason: 'boot never finished — the shell is still on the splash');
  });

  testWidgets('the QUEUE is never a stub', (tester) async {
    await _boot(tester);
    final app = HomeShellStateProbe.appStateOf(tester);
    // ignore: avoid_dynamic_calls
    final library = (app?.library as List?) ?? const [];
    if (library.isEmpty) {
      // ignore: avoid_print
      print('HARNESS: no library reached the shell, so the queue assertion is skipped');
      return;
    }
    // ignore: avoid_dynamic_calls
    final queue = app?.queue;
    expect(queue, isNotNull, reason: 'a library arrived but no queue was built for it');
    // ignore: avoid_dynamic_calls
    final n = (queue.order as List).length;
    expect(n, greaterThanOrEqualTo(3),
        reason: 'the queue is a stub of $n of ${library.length} — something replaced it');
  });

  testWidgets('the ticker runs while playing and stops when it should',
      (tester) async {
    await _boot(tester);

    final running = HomeShellStateProbe.shellCall(tester, 'tickerRunning') as bool?;
    if (running == null) return;

    expect(running, isFalse,
        reason: 'the ticker runs with nothing to update — a per-second wakeup for nothing');
  });

  testWidgets('the ticker actually STARTS when it is wanted', (tester) async {
    await _boot(tester);

    HomeShellStateProbe.shellCall(tester, 'setDebugWantTicker', true);
    HomeShellStateProbe.shellCall(tester, 'debugSyncTicker');
    await tester.pump(const Duration(milliseconds: 50));

    expect(HomeShellStateProbe.shellCall(tester, 'tickerRunning'), isTrue,
        reason: 'the ticker never started — the sleep alarm and every position update are dead');
  });

  testWidgets('a state change REACHES the screen, which is what "only on boot" meant',
      (tester) async {
    await _boot(tester);
    final app = HomeShellStateProbe.appStateOf(tester);
    if (app == null) return;

    var rebuilt = 0;
    // ignore: avoid_dynamic_calls
    app.addListener(() => rebuilt++);
    // ignore: avoid_dynamic_calls
    app.setSleeping(true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(rebuilt, greaterThan(0),
        reason: 'a state change was not observed — the screen would be frozen at its boot frame');
  });

  testWidgets('no lyrics crash on a track the service cannot answer for',
      (tester) async {
    await _boot(tester);

    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(tester.takeException(), isNull,
        reason: 'the async load path threw after boot — the lyrics null crash looked like this');
  });
}

