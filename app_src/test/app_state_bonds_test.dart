library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/bonds.dart';
import 'package:sonarar/library/track.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Beneath the Mask',
      artist: 'ATLUS Sound Team',
      album: 'Persona 5',
      duration: const Duration(minutes: 4),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

AppState _state() => AppState()
  ..attachLibrary([for (var i = 0; i < 3; i++) _t('t$i')]);

/// The bonds cluster, measured before it was touched: a field, one setter, one
/// reset and one note forward. It did not need extracting into an object of its own —
/// what it needed was for the field to stop being poked from outside, so the state
/// it hands out is the only state there is.
void main() {
  group('a bond mutation tells the listener', () {
    test('loading a saved bond file notifies', () {
      final state = _state();
      var notified = 0;
      state.addListener(() => notified++);

      state.setBondState(BondState(notes: const {'t0': 'the rain one'}));

      expect(notified, 1);
      expect(state.bondState.noteFor('t0'), 'the rain one');
    });

    test('resetting the counters notifies and stamps the reset', () {
      final state = _state();
      var notified = 0;
      state.addListener(() => notified++);
      final at = DateTime(2026, 11, 5, 12);

      state.resetBonds(at: at);

      expect(notified, 1);
      expect(state.bondState.config.resetAt, at,
          reason: 'the screen shows when the ladder restarted');
    });

    test('writing a note notifies', () {
      final state = _state();
      var notified = 0;
      state.addListener(() => notified++);

      expect(state.setBondNote('t1', '  late night  ', rank: 3), isTrue);

      expect(notified, 1);
      expect(state.bondState.noteFor('t1'), 'late night',
          reason: 'a note is stored trimmed, not with the editor\'s padding');
    });

    test('clearing a note notifies too, because the screen shows it gone', () {
      final state = _state();
      state.setBondNote('t1', 'something', rank: 3);
      var notified = 0;
      state.addListener(() => notified++);

      expect(state.setBondNote('t1', '   ', rank: 3), isTrue);

      expect(notified, 1);
      expect(state.bondState.noteFor('t1'), isNull);
    });
  });

  group('a bond mutation that changed nothing stays quiet', () {
    test('a note refused for a low rank does not notify', () {
      final state = _state();
      var notified = 0;
      state.addListener(() => notified++);

      expect(state.setBondNote('t1', 'too soon', rank: 2), isFalse);

      expect(notified, 0,
          reason: 'the note was refused, so nothing on screen changed');
      expect(state.bondState.noteFor('t1'), isNull);
    });
  });

  group('the cluster is one object', () {
    test('what the app hands over is what every screen reads', () {
      final state = _state();
      final saved = BondState(config: const BondConfig(completionPoints: 9));

      state.setBondState(saved);

      expect(identical(state.bondState, saved), isTrue,
          reason: 'a copy here would silently disconnect the bonds screen');
      expect(state.bondState.config.completionPoints, 9);
    });

    test('resetting goes through the state, not through its config', () {
      final state = _state();
      final before = state.bondState;

      state.resetBonds();

      expect(identical(state.bondState, before), isTrue,
          reason: 'a reset changes the counters, not the object the app holds');
      expect(before.config.resetAt, isNotNull);
    });
  });
}
