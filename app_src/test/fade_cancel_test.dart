library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The fade moved out of the engine, and so did what this file used to check.
///
/// It held a `_Fade` copy of the engine's timer/completer logic and tested *that* —
/// which meant it would pass while the real engine was broken — plus three guards
/// on `audio_engine.dart`'s internals (`_fadeDone`, `_fadingOut`, `from * (i / steps)`).
///
/// The fade is `FadeEnvelope` now and is tested behaviourally in
/// `test/player/fade_envelope_test.dart`. Each guarantee this file carried, and
/// where it lives now:
///
///   a fade that runs to the end completes      → "a fade walks from where the level is"
///   a cancelled fade completes, not hangs      → "cancelling lets whoever is waiting carry on"
///   a second fade releases the first           → "the newest fade wins"
///   cancelling twice is harmless               → "cancelling lets whoever is waiting carry on"
///   the fade-out steps DOWN from the level     → "a fade starts from the level actually playing"
///
/// One guarantee is still about the engine itself, and stays here.

String _engineSource() {
  final f = File('lib/player/audio_engine.dart');
  if (!f.existsSync()) {
    fail('could not read ${f.absolute.path} — run this from the app package root');
  }
  return f.readAsStringSync();
}

void main() {
  group('the engine itself', () {
    test('has exactly ONE fade, the shared envelope', () {
      final src = _engineSource();

      expect(src.contains('Timer.periodic'), isFalse,
          reason: 'the engine has grown its own fade timer again — two fades with '
              'different cancel rules is how "the sleep fade sometimes keeps going" happens');

      expect(src.contains('_fadingOut'), isFalse,
          reason: 'the engine has a second cancel flag again, instead of the fade '
              'object completing its own waiter');

      expect(src.contains('_fade.fadeTo('), isTrue,
          reason: 'the loop fade does not go through FadeEnvelope, so cancelling a '
              'fade-out and cancelling any other fade behave differently');
    });
  });
}
