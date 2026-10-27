library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/player/snapshot.dart';

PlaybackSnapshot _snap({String repeat = 'off'}) => PlaybackSnapshot(
      trackId: 't1',
      positionMs: 42000,
      queueIds: const ['t1', 't2'],
      queueIndex: 0,
      shuffle: true,
      artKey: 'makoto',
      repeat: repeat,
      savedAt: DateTime(2026, 10, 3),
    );

void main() {
  group('repeat survives the round trip', () {
    for (final mode in ['off', 'all', 'one']) {
      test('$mode comes back as $mode', () {
        final back = PlaybackSnapshot.fromJson(_snap(repeat: mode).toJson())!;
        expect(back.repeat, mode);
      });
    }

    test('it travels beside the flags that already worked', () {
      final s = _snap(repeat: 'one');
      final back = PlaybackSnapshot.fromJson(s.toJson())!;
      expect(back.shuffle, isTrue);
      expect(back.trackId, 't1');
      expect(back.positionMs, 42000);
      expect(back.artKey, 'makoto');
      expect(back.repeat, 'one', reason: 'the new field must not disturb them');
    });
  });

  group('an old file is survivable', () {
    test('a snapshot with no repeat key reads as off', () {
      final old = _snap().toJson()..remove('repeat');
      expect(PlaybackSnapshot.fromJson(old)!.repeat, 'off');
    });

    test('a corrupt value falls back to off rather than throwing', () {
      final bad = _snap().toJson()..['repeat'] = 'sometimes';
      expect(PlaybackSnapshot.fromJson(bad)!.repeat, 'off');
    });
  });
}
