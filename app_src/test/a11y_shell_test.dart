library;

// The same rule as `a11y_probe_test.dart`, applied to the app as it actually
// boots: the home page, the tab bar, the mini player host and the player, with
// the real library and the real queue behind them. The per-screen probes build
// their screens by hand, so they cannot see what the shell adds around them —
// and the shell is where the tab bar and the bar over every page live.

import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/clock.dart';
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

  messenger.setMockMethodCallHandler(_storage, (call) async {
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

  // The pigeon-generated wakelock API speaks BasicMessageChannel, and a
  // MethodChannel mock corrupts its reply.
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
    messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
      return null;
    });
  }
}

Future<void> _boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 860) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const SonararApp());
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

/// Tappable nodes that announce as a bare "button".
///
/// A node is labelled when the announcement would carry a word: its own label,
/// its value, or — via merging — a child that has one. Each failure names its
/// size, its actions and the nearest labelled ancestor.
List<String> _unlabelled(WidgetTester tester) {
  final owner = tester.binding.renderViews.first.owner!.semanticsOwner;
  if (owner == null) throw StateError('ensureSemantics() was not called');
  final out = <String>[];

  String? labelOf(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (data.label.trim().isNotEmpty) return data.label;
    if (data.value.trim().isNotEmpty) return data.value;
    String? child;
    node.visitChildren((c) {
      child ??= labelOf(c);
      return child == null;
    });
    return child;
  }

  String where(SemanticsNode node) {
    SemanticsNode? cursor = node.parent;
    while (cursor != null) {
      final l = cursor.getSemanticsData().label.trim();
      if (l.isNotEmpty) {
        return ' inside "${l.length > 24 ? l.substring(0, 24) : l}"';
      }
      cursor = cursor.parent;
    }
    return '';
  }

  void walk(SemanticsNode node) {
    final data = node.getSemanticsData();
    final tap = data.hasAction(SemanticsAction.tap);
    final long = data.hasAction(SemanticsAction.longPress);
    if ((tap || long) && (labelOf(node) ?? '').trim().isEmpty) {
      out.add('${node.rect.width.round()}×${node.rect.height.round()}'
          '${tap ? ' tap' : ''}${long ? ' long-press' : ''}${where(node)}');
    }
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  walk(owner.rootSemanticsNode!);
  return out;
}

void main() {
  setUp(() {
    // Pin the hour: the greeting and the skin band come from the wall clock, so
    // an unpinned run rendered differently at 06:00 than at 02:00 and the shell
    // golden failed for a reason that was not a regression. 02:00 is the band
    // the committed screenshots were taken in, so pinning it to 02:00 changes no
    // pixel and the image can no longer drift with the hour the suite runs at.
    Clock.now = () => DateTime(2026, 11, 14, 2, 0);

    _sandbox = Directory.systemTemp.createTempSync('sonarar-a11y-');
    rootBundle.clear();
    _fakePlatform();
  });
  tearDown(() {
    Clock.now = DateTime.now;
    if (_sandbox.existsSync()) _sandbox.deleteSync(recursive: true);
  });

  testWidgets('whatever the shell lands on announces every control',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _boot(tester);


    final landed = _unlabelled(tester);
    handle.dispose();

    expect(landed, isEmpty, reason: 'the screen a boot lands on');
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('the player announces every control on a booted app',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _boot(tester);

    HomeShellStateProbe.shellCall(tester, 'debugOpenPlayer');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    debugDumpSemanticsTree(DebugSemanticsDumpOrder.traversalOrder);
    final player = _unlabelled(tester);
    handle.dispose();

    expect(player, isEmpty, reason: 'the player, opened by the shell');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
