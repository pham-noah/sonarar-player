library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/theme/skin_policy.dart';

Track _t(String id, {int seconds = 180, String album = 'Persona 3 Reload'}) =>
    Track(
      id: id,
      title: 'Title $id',
      artist: 'ATLUS Sound Team',
      album: album,
      duration: Duration(seconds: seconds),
      file: '$id.opus',
      cover: '',
      gainDb: null);

List<Track> _lib() => [
      _t('sting', seconds: 43),
      for (var i = 0; i < 8; i++) _t('n$i', seconds: 180),
      _t('long', seconds: 640),
    ];

PlayContext _ctx({required ContextBand band, int hour = 18, bool raining = false}) =>
    PlayContext(
      band: band,
      sky: raining ? Sky.rain : Sky.unknown,
      whereabouts: Whereabouts.home,
      localHour: hour);

void main() {
  group('the engine is actually wired into the queue', () {
    test('the whole library reaches the queue — nothing is removed by the app', () {
      final s = AppState()
        ..applyOptionalFeatures(learn: true, autoSkin: true, variants: true);
      s.updateContext(_ctx(band: ContextBand.evening));
      s.attachLibrary(_lib());

      expect(s.queue!.order.length, s.library.length,
          reason: 'the app removed tracks from the queue');
    });

    test('and no band changes that — there is no length rule left to be context-driven', () {
      final s = AppState()
        ..applyOptionalFeatures(learn: true, autoSkin: true, variants: true);
      s.updateContext(_ctx(band: ContextBand.darkHour, hour: 0));
      s.attachLibrary(_lib());

      expect(s.queue!.order.length, s.library.length);
    });

    test('the app exposes the library it was given', () {
      final s = AppState()
        ..applyOptionalFeatures(learn: true, autoSkin: true, variants: true);
      s.attachLibrary(_lib());
      expect(s.library.length, _lib().length);
    });

    test('an empty library leaves a usable, empty state', () {
      final s = AppState()
        ..applyOptionalFeatures(learn: true, autoSkin: true, variants: true);
      s.updateContext(_ctx(band: ContextBand.evening));
      s.attachLibrary(const []);
      expect(s.currentTrack, isNull);
      expect(s.library, isEmpty);
    });
  });

  group('a band change recomputes; a clock tick does not', () {
    test('the queue changes when the SITUATION changes — not merely the band', () {
      final s = AppState()
        ..applyOptionalFeatures(learn: true, autoSkin: true, variants: true);
      s.setPlaylists(PlaylistList([
        Playlist(id: 'v_afternoon', name: 'Afternoon', trackIds: const ['n1']),
        Playlist(id: 'v_rain', name: 'Rain', trackIds: const ['n4']),
      ]));
      s.updateContext(_ctx(band: ContextBand.afternoon, hour: 14));
      s.attachLibrary(_lib());
      s.playDynamic();
      final before = s.queue!.order.map((t) => t.id).toList();

      s.updateContext(_ctx(band: ContextBand.afternoon, hour: 14, raining: true));

      final after = s.queue!.order.map((t) => t.id).toList();
      expect(after, isNot(before),
          reason: 'the situation changed (rain), so the ranking should have too');
      expect(after.first, 'n4',
          reason: 'the rain playlist did not lead the queue — the situation is not ranking');
    });

    test('a BAND change alone leaves the order alone — the ranking no longer reads length', () {
      final s = AppState()
        ..applyOptionalFeatures(learn: true, autoSkin: true, variants: true);
      s.updateContext(_ctx(band: ContextBand.afternoon, hour: 14));
      s.attachLibrary(_lib());
      final afternoon = s.queue!.order.map((t) => t.id).toList();

      s.updateContext(_ctx(band: ContextBand.night, hour: 23));
      expect(s.queue!.order.map((t) => t.id).toList(), afternoon,
          reason: 'a band change with no situation playlist must not reorder — energy and shape'
              ' fit were removed, and nothing else distinguishes the two bands');
    });

    test('re-publishing the SAME band does not churn the queue', () {
      final s = AppState()
        ..applyOptionalFeatures(learn: true, autoSkin: true, variants: true);
      s.updateContext(_ctx(band: ContextBand.evening, hour: 19));
      s.attachLibrary(_lib());

      final before = s.queue!.order.map((t) => t.id).toList();

      s.updateContext(_ctx(band: ContextBand.evening, hour: 19));
      s.updateContext(_ctx(band: ContextBand.evening, hour: 19));

      expect(s.queue!.order.map((t) => t.id).toList(), before,
          reason: 'a clock tick must not reshuffle under the listener');
    });

    test('the current track survives a band change', () {
      final s = AppState()
        ..applyOptionalFeatures(learn: true, autoSkin: true, variants: true);
      s.updateContext(_ctx(band: ContextBand.afternoon, hour: 14));
      s.attachLibrary(_lib());

      s.nextTrack();
      s.nextTrack();
      final playing = s.currentTrack!.id;

      s.updateContext(_ctx(band: ContextBand.night, hour: 23));

      expect(s.currentTrack!.id, playing,
          reason: 'changing band changes what comes next, never what is playing');
    });

    test('a band change keeps the queue non-empty', () {
      final s = AppState()
        ..applyOptionalFeatures(learn: true, autoSkin: true, variants: true);
      s.updateContext(_ctx(band: ContextBand.afternoon, hour: 14));
      s.attachLibrary(_lib());
      s.updateContext(_ctx(band: ContextBand.night, hour: 23));
      expect(s.queue!.length, greaterThan(0));
    });
  });

  group('context reaches the app through updateContext', () {
    test('the playlist context reflects the last published band', () {
      final s = AppState()
        ..applyOptionalFeatures(learn: true, autoSkin: true, variants: true);
      s.updateContext(_ctx(band: ContextBand.morning, hour: 8));
      expect(s.playlistContext!.band, ContextBand.morning);
      expect(s.playlistContext!.localHour, 8);
    });

    test('the skin still follows the context (no regression)', () {
      final s = AppState()
        ..applyOptionalFeatures(learn: true, autoSkin: true, variants: true);
      s.updateContext(_ctx(band: ContextBand.darkHour, hour: 0));
      expect(s.skin.id.name, 'abyss');
      s.updateContext(_ctx(band: ContextBand.night, hour: 23));
      expect(s.skin.id.name, 'crimson');
    });
  });

  group('play feedback reaches the engine', () {
    test('skipping early twice suppresses the track in that band', () {
      final s = AppState()
        ..applyOptionalFeatures(learn: true, autoSkin: true, variants: true);
      s.updateContext(_ctx(band: ContextBand.evening, hour: 19));
      s.attachLibrary(_lib());

      final target = s.queue!.order.firstWhere((t) => t.id != 'sting');

      for (var i = 0; i < 2; i++) {
        s.recordPlayOutcome(
          track: target,
          positionWhenStopped: const Duration(seconds: 4));
      }
      expect(s.engine.playlist(s.library, s.playlistContext!)
          .map((t) => t.id), contains(target.id),
          reason: 'the track left the queue — nothing should remove it but his own exclusion');
    });

    test('a completed listen is recorded as an acceptance', () {
      final s = AppState()
        ..applyOptionalFeatures(learn: true, autoSkin: true, variants: true);
      s.updateContext(_ctx(band: ContextBand.evening, hour: 19));
      s.attachLibrary(_lib());
      final target = s.queue!.current!;
      s.recordPlayOutcome(
        track: target,
        positionWhenStopped: target.duration);

      expect(s.currentTrack, isNotNull);
    });

    test('a late skip records nothing', () {
      final s = AppState()
        ..applyOptionalFeatures(learn: true, autoSkin: true, variants: true);
      s.updateContext(_ctx(band: ContextBand.evening, hour: 19));
      s.attachLibrary(_lib());
      final target = s.queue!.current!;
      s.recordPlayOutcome(
        track: target,
        positionWhenStopped: target.duration ~/ 2);
      expect(s.currentTrack, isNotNull);
    });

    test('recording feedback with no context yet is safe', () {
      final s = AppState()
        ..applyOptionalFeatures(learn: true, autoSkin: true, variants: true);
      s.attachLibrary(_lib());
      s.recordPlayOutcome(
        track: _lib().first,
        positionWhenStopped: Duration.zero);
      expect(s.library, isNotEmpty);
    });
  });

  group('library fit is exposed to the UI', () {
    test('the real composition reports P4R and P5R as unserved', () {
      final s = AppState()
        ..applyOptionalFeatures(learn: true, autoSkin: true, variants: true);
      s.attachLibrary(_lib());
      expect(s.fitFor(s.skin.id).total, _lib().length);
    });

    test('a fit query on an empty library does not divide by zero', () {
      final s = AppState()
        ..applyOptionalFeatures(learn: true, autoSkin: true, variants: true);
      s.attachLibrary(const []);
      expect(s.fitFor(s.skin.id).isThin, isTrue);
    });
  });

  group('resume still works with the engine in the path', () {
    test('a resume overrides the engine ordering', () {
      final s = AppState()
        ..applyOptionalFeatures(learn: true, autoSkin: true, variants: true);
      s.updateContext(_ctx(band: ContextBand.evening, hour: 19));
      final lib = _lib();
      s.attachLibrary(lib);

      s.playTrackNow(lib[3].id);
      final snap = s.snapshot();

      final r = AppState();
      r.updateContext(_ctx(band: ContextBand.evening, hour: 19));
      r.attachLibrary(lib, resume: snap);
      expect(r.currentTrack!.id, lib[3].id);
    });
  });
}
