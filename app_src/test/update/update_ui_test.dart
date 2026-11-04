library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/update/update_service.dart';
import 'package:sonarar/update/update_ui.dart';

const _update = AppUpdate(
  version: '9.9.9',
  build: 99,
  apkUrl: 'https://example.test/a.apk',
  notesUrl: 'https://example.test/n',
  sizeBytes: 65 * 1024 * 1024,
  sha256: 'abc',
  notes: 'Fixed the thing that was broken.',
);

class _Harness {
  _Harness(this.ui);

  final UpdateUi ui;

  int checks = 0;
  AppUpdate? answer;
  Object? checkError;

  AppUpdate? fetching;
  int downloads = 0;
  double? lastProgress;
  File? downloadAnswer;
  Object? downloadError;

  File? installed;
  bool installAnswer = true;

  List<AppUpdate?> offers = [];
}

Future<_Harness> _setup({File? apk}) async {
  late _Harness h;
  final ui = UpdateUi(
    check: () async {
      h.checks++;
      if (h.checkError != null) throw h.checkError!;
      return h.answer;
    },
    fetch: (update, onProgress) async {
      h.downloads++;
      h.fetching = update;
      for (final p in [0.5, 1.0]) {
        onProgress(p);
        h.lastProgress = p;
      }
      if (h.downloadError != null) throw h.downloadError!;
      return h.downloadAnswer;
    },
    install: (file) async {
      h.installed = file;
      return h.installAnswer;
    },
    onOffer: (update) => h.offers.add(update),
  );
  h = _Harness(ui);
  h.downloadAnswer = apk ?? File('${Directory.systemTemp.path}/sonarar-test.apk');
  return h;
}

void main() {
  group('the update flow', () {
    test('a check that finds something offers it', () async {
      final h = await _setup();
      h.answer = _update;

      await h.ui.checkNow();

      expect(h.ui.phase, UpdatePhase.available);
      expect(h.ui.release?.version, '9.9.9');
      expect(h.offers.last?.version, '9.9.9');
    });

    test('a check that finds nothing says so, and withdraws any offer', () async {
      final h = await _setup();
      h.answer = null;

      await h.ui.checkNow();

      expect(h.ui.phase, UpdatePhase.upToDate);
      expect(h.ui.release, isNull);
      expect(h.offers.last, isNull, reason: 'the bar must stop offering the old one');
    });

    test('a check that fails is a phase, not a crash', () async {
      final h = await _setup();
      h.checkError = const SocketException('offline');

      await h.ui.checkNow();

      expect(h.ui.phase, UpdatePhase.failed);
      expect(h.ui.failure, contains('offline'));
    });

    test('opening the sheet runs the check when nothing is known', () async {
      final h = await _setup();
      h.answer = _update;

      h.ui.open();
      await Future<void>.delayed(Duration.zero);

      expect(h.checks, 1);
      expect(h.ui.isOpen, isTrue);
    });

    test('opening with an update in hand does NOT ask again', () async {
      final h = await _setup();

      h.ui.open(known: _update);
      await Future<void>.delayed(Duration.zero);

      expect(h.checks, 0, reason: 'the bar already had the answer');
      expect(h.ui.phase, UpdatePhase.available);
    });

    test('downloading reports progress and leaves the APK waiting to install',
        () async {
      final h = await _setup();
      h.answer = _update;
      await h.ui.checkNow();

      await h.ui.downloadNow();

      expect(h.downloads, 1);
      expect(h.fetching?.version, '9.9.9');
      expect(h.lastProgress, 1.0);
      expect(h.ui.phase, UpdatePhase.ready);
      expect(h.ui.apk, isNotNull);
      expect(h.installed, isNull, reason: 'downloading does not install by itself');
    });

    test('a download that does not finish ends in a failure, not an install',
        () async {
      final h = await _setup();
      h.downloadAnswer = null;
      h.answer = _update;
      await h.ui.checkNow();

      await h.ui.downloadNow();

      expect(h.ui.phase, UpdatePhase.failed);
      expect(h.ui.failure, 'incomplete');
      expect(h.ui.apk, isNull);
    });

    test('a download that throws ends in a failure too', () async {
      final h = await _setup();
      h.downloadError = const SocketException('no route');
      h.answer = _update;
      await h.ui.checkNow();

      await h.ui.downloadNow();

      expect(h.ui.phase, UpdatePhase.failed);
      expect(h.ui.failure, contains('no route'));
    });

    test('installing hands the APK over, and a refusal stays on the button',
        () async {
      final h = await _setup();
      h.answer = _update;
      await h.ui.checkNow();
      await h.ui.downloadNow();

      await h.ui.installNow();
      expect(h.installed?.path, h.ui.apk!.path);

      h.installAnswer = false;
      await h.ui.installNow();
      expect(h.ui.phase, UpdatePhase.ready,
          reason: 'a refused install leaves the sheet where it was, with the hint');
      expect(h.ui.failure, 'refused');
    });

    test('there is nothing to install before a download', () async {
      final h = await _setup();

      await h.ui.installNow();
      await h.ui.downloadNow();

      expect(h.installed, isNull);
      expect(h.downloads, 0);
    });

    test('a check while one is already running is not started twice', () async {
      final h = await _setup();
      h.answer = _update;

      final first = h.ui.checkNow();
      final second = h.ui.checkNow();
      await Future.wait([first, second]);

      expect(h.checks, 1);
    });

    test('sizes are shown in whole megabytes', () {
      expect(megabytesOf(65 * 1024 * 1024), 65);
      expect(megabytesOf(0), 0);
      expect(megabytesOf(700), 0, reason: 'rounds down below half a MB');
    });
  });
}
