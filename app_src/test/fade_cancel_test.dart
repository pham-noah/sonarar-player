library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

class _Fade {
  Timer? _timer;
  Completer<void>? _done;

  Future<void> fade({
    int steps = 3,
    Duration tick = const Duration(milliseconds: 1),
  }) {
    cancel();
    final done = Completer<void>();
    _done = done;
    var i = 0;
    _timer = Timer.periodic(tick, (t) {
      i++;
      if (i >= steps) {
        t.cancel();
        _timer = null;
        _done = null;
        if (!done.isCompleted) done.complete();
      }
    });
    return done.future;
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    final done = _done;
    _done = null;

    if (done != null && !done.isCompleted) done.complete();
  }
}

String _engineSource() {
  final f = File('lib/player/audio_engine.dart');
  if (!f.existsSync()) {
    fail('could not read ${f.absolute.path} — run this from the app package root');
  }
  return f.readAsStringSync();
}

void main() {
  test('a fade that runs to the end completes', () async {
    final f = _Fade();
    await f.fade(steps: 3).timeout(const Duration(seconds: 2));
  });

  test('a CANCELLED fade completes rather than hanging', () async {
    final f = _Fade();
    final pending = f.fade(steps: 1000, tick: const Duration(milliseconds: 50));
    f.cancel();
    await pending.timeout(
      const Duration(seconds: 2),
      onTimeout: () => fail('the cancelled fade stranded its caller'),
    );
  });

  test('starting a SECOND fade releases the first', () async {
    final f = _Fade();
    final first = f.fade(steps: 1000, tick: const Duration(milliseconds: 50));
    final second = f.fade(steps: 3);
    await first.timeout(
      const Duration(seconds: 2),
      onTimeout: () => fail('the superseded fade stranded its caller'),
    );
    await second.timeout(const Duration(seconds: 2));
  });

  test('cancelling twice is harmless', () {
    final f = _Fade();
    f.cancel();
    f.cancel();
  });

  group('the engine itself', () {
    test('_cancelFade completes the in-flight fade', () {
      final src = _engineSource();
      expect(src.contains('Completer<void>? _fadeDone'), isTrue,
          reason: 'the fade completion is not tracked, so it cannot be released');
      final cancel = src.substring(
        src.indexOf('void _cancelFade()'),
        src.indexOf('void _cancelFade()') + 700,
      );
      expect(cancel.contains('done.complete()'), isTrue,
          reason: 'cancelling a fade does not complete it — awaiting callers hang');
    });

    test('the fade-out has its own guard, not _wantPlay', () {
      final src = _engineSource();
      expect(src.contains('_fadingOut = true'), isTrue,
          reason: 'the fade-out has no dedicated flag, so it is guarding itself again');
      expect(src.contains('if (!_wantPlay && i != steps) break;'), isFalse,
          reason: 'the fade-out is using _wantPlay as its own re-entry guard');
    });

    test('the fade-out steps DOWN from the playing level', () {
      final src = _engineSource();
      expect(src.contains('from * (i / steps)'), isTrue,
          reason: 'the fade-out jumps to full volume instead of stepping down from the current level');
    });
  });
}
