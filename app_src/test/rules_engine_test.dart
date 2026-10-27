library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/rules/rules_engine.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/skin_policy.dart';

Track _t(
  String id, {
  String title = '',
  String artist = 'ATLUS Sound Team',
  String album = 'Persona 3 Reload',
  int seconds = 180,
}) =>
    Track(
      id: id,
      title: title.isEmpty ? 'Track $id' : title,
      artist: artist,
      album: album,
      duration: Duration(seconds: seconds),
      file: '$id.opus',
      cover: '',
      gainDb: null);

PlaylistContext _ctx({
  ContextBand band = ContextBand.evening,
  bool atHome = true,
  bool raining = false,
  int hour = 18,
}) =>
    PlaylistContext(
      band: band, sky: raining ? Sky.rain : Sky.unknown, whereabouts: atHome ? Whereabouts.home : Whereabouts.unknown, localHour: hour);

void main() {
  const engine = RulesEngine();

  group('the shape classifier is GONE, so nothing classifies by duration', () {
    test('a sting and a closer are both admitted — length is not a criterion', () {
      final lib = [
        _t('a', seconds: 43),
        _t('b', seconds: 644),
      ];
      expect(engine.playlist(lib, _ctx()).length, 2);
    });
  });

  group('origin detection', () {
    test('a Persona 3 album is P3R', () {
      expect(engine.originOf(_t('a', album: 'Persona 3 Reload')), 'P3R');
    });

    test('a Megamix vinyl album is P3R', () {
      expect(
        engine.originOf(_t('a', album: 'Persona 3 Reload Megamix Vinyl Soundtrack')),
        'P3R');
    });

    test('an unrelated single is other', () {
      expect(
        engine.originOf(_t('a', artist: 'Dominic Fike', album: 'Apple Music Live')),
        'other');
    });

    test('a P5 album would be P5R', () {
      expect(engine.originOf(_t('a', album: 'Persona 5 Royal')), 'P5R');
    });

    test('a P4 album would be P4R', () {
      expect(engine.originOf(_t('a', album: 'Persona 4 Golden')), 'P4R');
    });
  });

  group('NOTHING is dropped for its length any more', () {
    test('a short track is admitted like any other', () {
      final lib = [_t('loop', seconds: 43), _t('song', seconds: 180)];
      final out = engine.select(lib, _ctx());
      expect(out.map((t) => t.id), ['loop', 'song'],
          reason: 'a 43-second track was dropped — the sting rule is back');
    });

    test('and the same in Dark Hour — there is no special case to have', () {
      final lib = [_t('loop', seconds: 43), _t('song', seconds: 180)];
      final out = engine.select(lib, _ctx(band: ContextBand.darkHour, hour: 0));
      expect(out.map((t) => t.id), ['loop', 'song']);
    });

    test('one short track among many keeps every track', () {
      final lib = [
        _t('s1', seconds: 43),
        for (var i = 0; i < 20; i++) _t('n$i', seconds: 180),
      ];
      final out = engine.select(lib, _ctx());
      expect(out.length, 21, reason: 'the library was filtered by duration');
    });
  });

  group('skip feedback is NOT learned from — reward only', () {
    test('NO amount of skipping suppresses a track', () {
      final mem = FeedbackMemory();
      for (var i = 0; i < 10; i++) {
        mem.record('t1', ContextBand.evening, SkipFeedback.rejected);
      }
      expect(mem.isSuppressed('t1', ContextBand.evening), isFalse,
          reason: 'skipping still buries a track');
      expect(mem.score('t1', ContextBand.evening), 0);
    });

    test('an acceptance IS recorded, and per band', () {
      final mem = FeedbackMemory();
      mem.record('t1', ContextBand.evening, SkipFeedback.accepted);
      mem.record('t1', ContextBand.morning, SkipFeedback.accepted);
      mem.record('t1', ContextBand.morning, SkipFeedback.accepted);
      expect(mem.score('t1', ContextBand.evening), 1);
      expect(mem.score('t1', ContextBand.morning), 2,
          reason: 'the bands are not separate beliefs');
    });

    test('a rewarded track is still selected', () {
      final mem = FeedbackMemory();
      mem.record('good', ContextBand.evening, SkipFeedback.accepted);
      final lib = [_t('good'), _t('other')];
      final out = engine.select(lib, _ctx());
      expect(out.map((t) => t.id), contains('good'));
    });

    test('a heavy-skipped track is STILL selected — nothing is filtered out', () {
      final mem = FeedbackMemory();
      for (var i = 0; i < 5; i++) {
        mem.record('skipped', ContextBand.evening, SkipFeedback.rejected);
      }
      final lib = [_t('skipped'), _t('good')];
      final out = engine.select(lib, _ctx());
      expect(out.map((t) => t.id), contains('skipped'));
    });

    test('none feedback is ignored entirely', () {
      final mem = FeedbackMemory();
      mem.record('t1', ContextBand.evening, SkipFeedback.none);
      expect(mem.size, 0);
    });

    test('clear wipes everything', () {
      final mem = FeedbackMemory();
      mem.record('t1', ContextBand.evening, SkipFeedback.accepted);
      mem.clear();
      expect(mem.size, 0);
    });
  });

  group('full pipeline', () {
    test('playlist applies NO length filter — it returns the list it was given', () {
      final lib = [
        _t('sting', seconds: 43),
        _t('fine1'),
        _t('fine2'),
      ];
      final out = engine.playlist(lib, _ctx());
      expect(out.length, 3, reason: 'a 43-second track was dropped for its length');
      expect(out.map((t) => t.id), contains('sting'));
    });

    test('an EMPTY EXCLUSION SET admits everything, and nothing else empties it', () {
      final lib = [_t('a', seconds: 30), _t('b', seconds: 40)];
      expect(engine.playlist(lib, _ctx()).length, 2,
          reason: 'the engine emptied a list of short tracks — the length filter is back');
    });
  });

  group('honest reporting of library fit', () {
    test('the real library cannot serve P5R and says so', () {
      final lib = [for (var i = 0; i < 10; i++) _t('t$i')];
      final fit = engine.fitFor(lib, SkinId.crimson);
      expect(fit.isThin, isTrue);
      expect(fit.summary, contains('No P5R music'));
    });

    test('a thin but non-zero match says "Only", not "No"', () {
      final lib = [
        _t('p5', album: 'Persona 5 Royal'),
        for (var i = 0; i < 99; i++) _t('t$i'),
      ];
      final fit = engine.fitFor(lib, SkinId.crimson);
      expect(fit.isThin, isTrue);
      expect(fit.matching, 1);
      expect(fit.summary, contains('Only 1 of 100'));
      expect(fit.summary, isNot(contains('No P5R music')));
    });

    test('P3R is well served', () {
      final lib = [for (var i = 0; i < 10; i++) _t('t$i')];
      final fit = engine.fitFor(lib, SkinId.abyss);
      expect(fit.isThin, isFalse);
      expect(fit.matching, 10);
    });

    test('an empty library is reported as thin, not divided by zero', () {
      final fit = engine.fitFor([], SkinId.abyss);
      expect(fit.isThin, isTrue);
    });
  });

  group('context energy', () {
    test('night and dark hour are low energy', () {
      expect(_ctx(band: ContextBand.night).energy, Energy.low);
      expect(_ctx(band: ContextBand.darkHour).energy, Energy.low);
    });

    test('afternoon is the high-energy band', () {
      expect(_ctx(band: ContextBand.afternoon).energy, Energy.high);
    });

    test('morning and evening sit in the middle', () {
      expect(_ctx(band: ContextBand.morning).energy, Energy.medium);
      expect(_ctx(band: ContextBand.evening).energy, Energy.medium);
    });

    test('NO band tolerates stings specially — the distinction was deleted with the rule', () {
      final lib = [_t('a', seconds: 43), _t('b', seconds: 180)];
      for (final b in ContextBand.values) {
        expect(engine.playlist(lib, _ctx(band: b, hour: 0)).length, 2,
            reason: '${b.name} dropped a track by length');
      }
    });

    test('copyWith replaces only what it is given', () {
      final base = _ctx(band: ContextBand.morning, hour: 8);
      final changed = base.copyWith(band: ContextBand.night);
      expect(changed.band, ContextBand.night);
      expect(changed.localHour, 8);
    });
  });
}
