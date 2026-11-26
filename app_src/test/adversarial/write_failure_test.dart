library;

// A music player's state lives in files next to the library: settings, playlists,
// loop points, bookmarks, favourites. Every one of those writes went through
// `StateStores._guard`, whose doc comment promised to "report the failure instead
// of hiding it" while the body did `debugPrint` and nothing else — a call that
// reaches nobody in a release build.
//
// So a full disk, a read-only volume or a locked file ate a whole session's work
// in silence, and no test could even ask about it: there was no way to make a
// write fail. This file adds that way — `debugFailNextWrite`, one shot, armed by
// the test and never by the app — and pins the two promises that follow from it:
//
//   1. the failure is published, once, naming the write;
//   2. the app says so, in the user's language, instead of swallowing it.
//
// The idea is taken from NeoTube's `failNextPush`, which arms a failed upload and
// asserts the app retries or says so. The defect it exposes here was live in the
// tree: nothing in `lib/` reported a failed state write.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/state_stores.dart';
import 'package:sonarar/main.dart';

import '../shell_probe.dart';

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
      case 'requestNotification':
        return 'granted';
      default:
        return null;
    }
  });
}

Future<void> _boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 860) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const SonararApp());
  final shell = find.byType(HomeShell, skipOffstage: false);
  final deadline = DateTime.now().add(const Duration(seconds: 25));
  while (DateTime.now().isBefore(deadline)) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));
    if (shell.evaluate().isNotEmpty &&
        HomeShellStateProbe.shellCall(tester, 'loading') == false) {
      return;
    }
  }
}

void main() {
  setUp(() {
    _sandbox = Directory.systemTemp.createTempSync('sonarar-write-fault-');
    rootBundle.clear();
    StateStores.writeFailure.value = null;
    StateStores.debugFailNextWrite = null;
    _fakePlatform();
  });

  tearDown(() {
    StateStores.debugFailNextWrite = null;
    StateStores.writeFailure.value = null;
    if (_sandbox.existsSync()) _sandbox.deleteSync(recursive: true);
  });

  group('a state write that cannot land', () {
    test('is published, naming the write', () async {
      final stores = await StateStores.open(libraryRoot: _sandbox.path);
      final prefs = await stores.prefs.load();

      StateStores.debugFailNextWrite =
          () async => throw const FileSystemException('no space left');
      await stores.savePrefs(prefs);

      expect(StateStores.writeFailure.value, 'save prefs',
          reason: 'A failed write to the user\'s own state was swallowed: '
              'debugPrint reaches nobody in a release build, so a full disk '
              'lost every setting changed in that session without a word.');
    });

    test('is armed for one write only, so the next one still lands', () async {
      final stores = await StateStores.open(libraryRoot: _sandbox.path);
      final prefs = await stores.prefs.load();

      StateStores.debugFailNextWrite =
          () async => throw const FileSystemException('no space left');
      await stores.savePrefs(prefs);
      expect(StateStores.writeFailure.value, 'save prefs');

      // The same write again with no fault armed: it must reach the disk.
      await stores.savePrefs(prefs);
      expect(File('${_sandbox.path}/.state/prefs.json').existsSync(), isTrue,
          reason: 'The armed fault was not one-shot: after one deliberate '
              'failure every later write was skipped too, so the fault itself '
              'would be the bug.');
    });

    test('every store goes through the same guard', () async {
      final stores = await StateStores.open(libraryRoot: _sandbox.path);
      final bonds = await stores.bonds.load();

      StateStores.debugFailNextWrite =
          () async => throw const FileSystemException('read-only volume');
      await stores.saveBonds(bonds);

      expect(StateStores.writeFailure.value, 'save bonds',
          reason: 'A store that writes around the guard fails invisibly, which '
              'is the defect the guard exists to prevent.');
    });
  });

  testWidgets('the app says so, above the tab bar, rather than losing it quietly',
      (tester) async {
    await _boot(tester);

    StateStores.debugFailNextWrite =
        () async => throw const FileSystemException('no space left');
    HomeShellStateProbe.shellCall(tester, 'debugSavePrefsNow');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text("Couldn't save your changes — the disk may be full."),
      findsOneWidget,
      reason: 'A save that fails must speak. Before this, the only trace was a '
          'debugPrint the user never sees, on the one class of failure that '
          'costs them work they just did.',
    );

    // It must land above the controls, not on them — the same rule the toasts
    // follow everywhere else.
    final rect = tester.getRect(
        find.text("Couldn't save your changes — the disk may be full."));
    expect(rect.bottom, lessThanOrEqualTo(860 - 70),
        reason: 'The message sat on the tab row (which starts at 790 on a '
            '420x860 phone), where it cannot be read and the controls behind it '
            'cannot be reached.');
  });
}
