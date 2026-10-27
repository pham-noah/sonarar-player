library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/track.dart';
import 'package:sonarar/player/queue_mode.dart';

Track _t(String id) => Track(
      id: id,
      title: id,
      artist: 'a',
      album: 'b',
      duration: const Duration(minutes: 3),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

void main() {
  final one = _t('one');
  final mix = [_t('a'), _t('b'), one, _t('c')];

  group('what the queue holds after a track is played', () {
    test('FIXED: the track ALONE — the playlist does not queue itself', () {
      final q = queueForPlayedTrack(track: one, mode: QueueMode.fixed, contextMix: mix);
      expect(q, hasLength(1));
      expect(q.single.id, 'one');
    });

    test('DYNAMIC: the context mix, unchanged when it already contains the track', () {
      final q = queueForPlayedTrack(track: one, mode: QueueMode.dynamic, contextMix: mix);
      expect(q.map((t) => t.id), mix.map((t) => t.id));
    });

    test('DYNAMIC: the played track still goes FIRST if the mix lacks it', () {
      final other = _t('zzz');
      final q = queueForPlayedTrack(track: other, mode: QueueMode.dynamic, contextMix: mix);
      expect(q.first.id, 'zzz');
      expect(q.length, mix.length + 1);
    });

    test('FIXED with an EMPTY context mix is still just the track', () {
      final q = queueForPlayedTrack(track: one, mode: QueueMode.fixed, contextMix: const []);
      expect(q, hasLength(1));
    });
  });

  group('what happens when the song ends', () {
    test('FIXED with nothing queued: STOP', () {
      expect(
        advanceFor(mode: QueueMode.fixed, repeatOne: false, repeatAll: false, hasNext: false),
        AutoAdvanceMode.stop,
      );
    });

    test('FIXED with a track he queued next: PLAY IT', () {
      expect(
        advanceFor(mode: QueueMode.fixed, repeatOne: false, repeatAll: false, hasNext: true),
        AutoAdvanceMode.next,
      );
    });

    test('DYNAMIC keeps going', () {
      expect(
        advanceFor(mode: QueueMode.dynamic, repeatOne: false, repeatAll: false, hasNext: true),
        AutoAdvanceMode.next,
      );
    });

    test('repeat-one replays in EITHER mode — it is an explicit instruction', () {
      for (final mode in QueueMode.values) {
        expect(
          advanceFor(mode: mode, repeatOne: true, repeatAll: false, hasNext: false),
          AutoAdvanceMode.replay,
          reason: 'repeat-one was ignored in $mode',
        );
      }
    });

    test('DYNAMIC with nothing left and no repeat: STOP', () {
      expect(
        advanceFor(mode: QueueMode.dynamic, repeatOne: false, repeatAll: false, hasNext: false),
        AutoAdvanceMode.stop,
      );
    });
  });
}
