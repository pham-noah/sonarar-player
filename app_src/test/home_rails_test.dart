library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/home_rails.dart';
import 'package:sonarar/library/play_log.dart';
import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';

Track _t(String id) => Track(
      id: id,
      title: id,
      artist: 'ATLUS Sound Team',
      album: 'Persona 5',
      duration: const Duration(minutes: 4),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

final _now = DateTime(2026, 6, 15, 12);

PlayEvent _play(String trackId, DateTime at) => PlayEvent(
      trackId: trackId,
      at: at,
      band: 'evening',
      positionMs: 240000,
      durationMs: 240000,
    );

void main() {
  group('continue listening and jump back in', () {
    test('the most recent distinct play leads, newest first', () {
      final rails = deriveHomeRails(
        tracks: [_t('a'), _t('b'), _t('c')],
        events: [
          _play('a', _now.subtract(const Duration(days: 3))),
          _play('b', _now.subtract(const Duration(days: 2))),
          _play('c', _now.subtract(const Duration(days: 1))),
        ],
        now: _now,
      );
      expect(rails.continueListening!.id, 'c');
      expect(rails.jumpBackIn.map((t) => t.id), ['b', 'a']);
    });

    test('a track heard four times does not fill the rail four times', () {
      final rails = deriveHomeRails(
        tracks: [_t('a'), _t('b')],
        events: [
          _play('a', _now.subtract(const Duration(days: 4))),
          _play('a', _now.subtract(const Duration(days: 3))),
          _play('a', _now.subtract(const Duration(days: 2))),
          _play('b', _now.subtract(const Duration(days: 1))),
        ],
        now: _now,
      );
      expect(rails.jumpBackIn.map((t) => t.id), ['a']);
    });

    test('a track removed from the library is skipped, not shown as a ghost', () {
      final rails = deriveHomeRails(
        tracks: [_t('b')],
        events: [
          _play('gone', _now.subtract(const Duration(days: 2))),
          _play('b', _now.subtract(const Duration(days: 1))),
        ],
        now: _now,
      );
      expect(rails.continueListening!.id, 'b');
      expect(rails.jumpBackIn, isEmpty);
    });

    test('an empty log leaves continue listening null rather than throwing', () {
      final rails = deriveHomeRails(tracks: [_t('a')], events: const [], now: _now);
      expect(rails.continueListening, isNull);
      expect(rails.jumpBackIn, isEmpty);
    });

    test('the rail is capped, so one session cannot fill the whole page', () {
      final rails = deriveHomeRails(
        tracks: [for (var i = 0; i < 40; i++) _t('t$i')],
        events: [
          for (var i = 0; i < 40; i++)
            _play('t$i', _now.subtract(Duration(hours: i + 1)))
        ],
        now: _now,
      );
      expect(rails.jumpBackIn, hasLength(kRailLength - 1));
    });
  });

  group('heavy rotation', () {
    test('a track played once is not rotation', () {
      final rails = deriveHomeRails(
        tracks: [_t('a'), _t('b')],
        events: [
          _play('a', _now.subtract(const Duration(days: 1))),
          _play('b', _now.subtract(const Duration(days: 2))),
          _play('b', _now.subtract(const Duration(days: 3))),
        ],
        now: _now,
      );
      expect(rails.heavyRotation.map((t) => t.id), ['b']);
    });

    test('the most-played comes first', () {
      final rails = deriveHomeRails(
        tracks: [_t('a'), _t('b')],
        events: [
          _play('a', _now.subtract(const Duration(days: 5))),
          _play('a', _now.subtract(const Duration(days: 6))),
          _play('b', _now.subtract(const Duration(days: 1))),
          _play('b', _now.subtract(const Duration(days: 2))),
          _play('b', _now.subtract(const Duration(days: 3))),
        ],
        now: _now,
      );
      expect(rails.heavyRotation.first.id, 'b');
    });
  });

  group('the recap', () {
    test('only plays inside the window are summarised', () {
      final rails = deriveHomeRails(
        tracks: [_t('old'), _t('new')],
        events: [
          _play('old', _now.subtract(const Duration(days: 45))),
          _play('new', _now.subtract(const Duration(days: 2))),
        ],
        now: _now,
      );
      expect(rails.recap.map((t) => t.id), ['new']);
    });

    test('a play exactly at the cutoff is still inside', () {
      final at = _now.subtract(const Duration(days: kRecapDays));
      final rails = deriveHomeRails(
        tracks: [_t('a')],

        events: [_play('a', at.add(const Duration(microseconds: 1)))],
        now: _now,
      );
      expect(rails.recap.map((t) => t.id), ['a']);
    });

    test('a track played twice in the window appears once', () {
      final rails = deriveHomeRails(
        tracks: [_t('a')],
        events: [
          _play('a', _now.subtract(const Duration(days: 1))),
          _play('a', _now.subtract(const Duration(days: 2))),
        ],
        now: _now,
      );
      expect(rails.recap.map((t) => t.id), ['a']);
    });

    test('the window follows the clock passed in, not today', () {
      final rails = deriveHomeRails(
        tracks: [_t('a')],
        events: [_play('a', DateTime(2026, 1, 5))],
        now: DateTime(2026, 1, 6),
      );
      expect(rails.recap.map((t) => t.id), ['a']);
    });
  });

  group('new from your library', () {
    test('the newest arrivals come first', () {
      final rails = deriveHomeRails(
        tracks: [for (var i = 0; i < 20; i++) _t('t$i')],
        events: const [],
        now: _now,
      );
      expect(rails.newFromLibrary.map((t) => t.id),
          ['t19', 't18', 't17', 't16', 't15', 't14', 't13', 't12', 't11', 't10', 't9', 't8']);
    });

    test('a small library yields nothing, because it is all already on screen', () {
      final rails = deriveHomeRails(
        tracks: [_t('a'), _t('b')],
        events: const [],
        now: _now,
      );
      expect(rails.newFromLibrary, isEmpty,
          reason: 'twelve tracks or fewer is the whole library, not new arrivals');
    });

    test('exactly the floor still yields nothing', () {
      final rails = deriveHomeRails(
        tracks: [for (var i = 0; i < kNewFromLibraryFloor; i++) _t('t$i')],
        events: const [],
        now: _now,
      );
      expect(rails.newFromLibrary, isEmpty);
    });

    test('one more than the floor yields the tail', () {
      final rails = deriveHomeRails(
        tracks: [for (var i = 0; i < kNewFromLibraryFloor + 1; i++) _t('t$i')],
        events: const [],
        now: _now,
      );
      expect(rails.newFromLibrary, hasLength(kRailLength));
      expect(rails.newFromLibrary.first.id, 't$kNewFromLibraryFloor');
    });
  });

  group('it is a function of its inputs', () {
    test('the same inputs give the same rails', () {
      final tracks = [for (var i = 0; i < 20; i++) _t('t$i')];
      final events = [
        _play('t3', _now.subtract(const Duration(days: 1))),
        _play('t3', _now.subtract(const Duration(days: 2))),
      ];

      final a = deriveHomeRails(tracks: tracks, events: events, now: _now);
      final b = deriveHomeRails(tracks: tracks, events: events, now: _now);

      expect(a.continueListening!.id, b.continueListening!.id);
      expect(a.heavyRotation.map((t) => t.id), b.heavyRotation.map((t) => t.id));
      expect(a.recap.map((t) => t.id), b.recap.map((t) => t.id));
    });
  });

  group('the playlists, ranked by how much they are played', () {
    Playlist list(String id, List<String> trackIds) =>
        Playlist(id: id, name: id, trackIds: trackIds);

    test('most plays first, and the count is the sum over the LIST OWN tracks', () {
      final ranked = rankPlaylistsByPlays(
        playlists: [
          list('quiet', ['a']),
          list('loud', ['b']),
        ],
        events: [
          _play('a', _now.subtract(const Duration(days: 2))),
          _play('b', _now.subtract(const Duration(days: 3))),
          _play('b', _now.subtract(const Duration(days: 2))),
          _play('b', _now.subtract(const Duration(days: 1))),
        ],
      );
      expect(ranked.map((e) => e.playlist.id), ['loud', 'quiet']);
      expect(ranked.first.plays, 3);
      expect(ranked.last.plays, 1);
    });

    test('a track in two lists counts for both — a list is played as much as its music is', () {
      final ranked = rankPlaylistsByPlays(
        playlists: [
          list('one', ['a']),
          list('both', ['a', 'b']),
        ],
        events: [
          _play('a', _now.subtract(const Duration(days: 2))),
          _play('b', _now.subtract(const Duration(days: 1))),
        ],
      );
      expect(ranked.first.playlist.id, 'both');
      expect(ranked.first.plays, 2);
      expect(ranked.last.plays, 1);
    });

    test('a skipped track is not a play here either', () {
      final ranked = rankPlaylistsByPlays(
        playlists: [list('skipped', ['a'])],
        events: [
          PlayEvent(
            trackId: 'a',
            at: _now.subtract(const Duration(days: 1)),
            band: 'evening',
            positionMs: 2000,
            durationMs: 240000,
          ),
        ],
      );
      expect(ranked.single.plays, 0);
    });

    test('a list with no plays is KEPT, and sorts last', () {
      final ranked = rankPlaylistsByPlays(
        playlists: [list('never', ['a']), list('played', ['b'])],
        events: [_play('b', _now.subtract(const Duration(days: 1)))],
      );
      expect(ranked.map((e) => e.playlist.id), ['played', 'never']);
      expect(ranked.last.plays, 0);
    });

    test('a tie breaks on the name, so the order does not reshuffle by itself', () {
      final ranked = rankPlaylistsByPlays(
        playlists: [
          Playlist(id: 'z', name: 'Zeta', trackIds: const ['a']),
          Playlist(id: 'a', name: 'Alpha', trackIds: const ['a']),
        ],
        events: [_play('a', _now.subtract(const Duration(days: 1)))],
      );
      expect(ranked.map((e) => e.playlist.name), ['Alpha', 'Zeta']);
    });
  });
}
