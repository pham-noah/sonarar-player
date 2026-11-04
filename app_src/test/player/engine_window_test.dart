library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/track.dart';
import 'package:sonarar/player/engine_window.dart';

Track _t(int n) => Track(
      id: 't$n',
      title: 'Track $n',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(seconds: 120),
      file: 'music/t$n.m4a',
      cover: 'covers/t$n.jpg',
      gainDb: 0,
    );

List<Track> _order(int n) => [for (var i = 0; i < n; i++) _t(i)];

void main() {
  group('the engine window', () {
    test('holds a chunk of the queue around the track being played', () {
      final order = _order(60);
      final w = engineWindowFor(
        order: order,
        track: order[30],
        pathFor: (t) => '/lib/${t.file}',
        coverFor: (t) => '/lib/${t.cover}',
        exists: (_) => true,
      );

      expect(w.windowLength, 24, reason: 'one chunk, not the whole queue');
      expect(w.windowStart, 24, reason: 'the chunk containing track 30');
      expect(w.entries, hasLength(24));
      expect(w.index, 6, reason: 'track 30 sits six into a window starting at 24');
      expect(w.entries[w.index].path, '/lib/music/t30.m4a');
      expect(w.hasTarget, isTrue);
    });

    test('a track in the last partial chunk still gets a window', () {
      final order = _order(30);
      final w = engineWindowFor(
        order: order,
        track: order[29],
        pathFor: (t) => '/lib/${t.file}',
        coverFor: (_) => null,
        exists: (_) => true,
      );

      expect(w.windowStart, 24);
      expect(w.windowLength, 6);
      expect(w.index, 5);
    });

    test('a short queue is one window', () {
      final order = _order(3);
      final w = engineWindowFor(
        order: order,
        track: order[1],
        pathFor: (t) => '/lib/${t.file}',
        coverFor: (_) => null,
        exists: (_) => true,
      );

      expect(w.windowStart, 0);
      expect(w.windowLength, 3);
      expect(w.index, 1);
    });

    test('a missing file is dropped and the index follows it', () {
      final order = _order(5);
      final w = engineWindowFor(
        order: order,
        track: order[3],
        pathFor: (t) => '/lib/${t.file}',
        coverFor: (_) => null,
        exists: (p) => !p.contains('t1.m4a') && !p.contains('t0.m4a'),
      );

      expect(w.entries, hasLength(3));
      expect(w.index, 1, reason: 't2 is first now, so t3 is second');
      expect(w.entries[w.index].path, '/lib/music/t3.m4a');
    });

    test('a track whose own file is missing has no index, but the window survives',
        () {
      final order = _order(5);
      final w = engineWindowFor(
        order: order,
        track: order[2],
        pathFor: (t) => '/lib/${t.file}',
        coverFor: (_) => null,
        exists: (p) => !p.contains('t2.m4a'),
      );

      expect(w.index, -1);
      expect(w.hasTarget, isFalse);
      expect(w.entries, hasLength(4), reason: 'the rest of the window is still playable');
    });

    test('no playable file leaves an empty window', () {
      final order = _order(4);
      final w = engineWindowFor(
        order: order,
        track: order[0],
        pathFor: (t) => '/lib/${t.file}',
        coverFor: (_) => null,
        exists: (_) => false,
      );

      expect(w.isEmpty, isTrue);
      expect(w.index, -1);
      expect(w.windowLength, 4);
    });

    test('an empty queue is empty, not a crash', () {
      final w = engineWindowFor(
        order: const [],
        track: _t(0),
        pathFor: (t) => '/lib/${t.file}',
        coverFor: (_) => null,
        exists: (_) => true,
      );

      expect(w.isEmpty, isTrue);
      expect(w.index, -1);
      expect(w.windowStart, 0);
      expect(w.windowLength, 0);
    });

    test('a track the queue does not contain windows from the top', () {
      final order = _order(30);
      final stranger = Track(
        id: 'elsewhere',
        title: 'Elsewhere',
        artist: 'A',
        album: 'B',
        duration: Duration.zero,
        file: 'music/elsewhere.m4a',
        cover: '',
        gainDb: 0,
      );
      final w = engineWindowFor(
        order: order,
        track: stranger,
        pathFor: (t) => '/lib/${t.file}',
        coverFor: (_) => null,
        exists: (_) => true,
      );

      expect(w.windowStart, 0);
      expect(w.index, -1, reason: 'the wanted track is not in the window it fell into');
      expect(w.entries, hasLength(24));
    });

    test('a cover is only claimed when the cover file exists', () {
      final order = _order(2);
      final w = engineWindowFor(
        order: order,
        track: order[0],
        pathFor: (t) => '/lib/${t.file}',
        coverFor: (t) => '/lib/${t.cover}',
        exists: (p) => !p.contains('covers/'),
      );

      expect(w.entries.every((e) => e.cover == null), isTrue);
    });

    test('the chunk size is configurable and refused when nonsense', () {
      final order = _order(10);
      final w = engineWindowFor(
        order: order,
        track: order[5],
        pathFor: (t) => '/lib/${t.file}',
        coverFor: (_) => null,
        exists: (_) => true,
        chunk: 4,
      );

      expect(w.windowStart, 4);
      expect(w.windowLength, 4);
      expect(w.index, 1);

      expect(
        () => engineWindowFor(
          order: order,
          track: order[0],
          pathFor: (t) => '/lib/${t.file}',
          coverFor: (_) => null,
          exists: (_) => true,
          chunk: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
