library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/rules/playlist_explanation.dart';
import 'package:sonarar/rules/context_rules.dart';
import 'package:sonarar/rules/rules_engine.dart';
import 'package:sonarar/theme/skin_policy.dart';

Track _t(
  String id, {
  int seconds = 180,
  String album = 'Persona 3 Reload',
  String artist = 'ATLUS Sound Team',
}) =>
    Track(
      id: id,
      title: 'Track $id',
      artist: artist,
      album: album,
      duration: Duration(seconds: seconds),
      file: '$id.opus',
      cover: '',
      gainDb: 0);

PlaylistContext _ctx({
  ContextBand band = ContextBand.evening,
  bool raining = false,
  int hour = 19,
}) =>
    PlaylistContext(band: band, sky: raining ? Sky.rain : Sky.unknown, whereabouts: Whereabouts.home, localHour: hour);

PlaylistExplanation _run({
  Track? current,
  List<Track>? library,
  PlaylistContext? ctx,
  FeedbackMemory? memory,
  String preferredOrigin = 'P3R',

  bool noContext = false,

  String? placeName,
  bool preciseFix = true,
  String? situationTag,
  bool sleeping = false,
  bool isLive = false,
  ContextRule? rule,
  int? ruleTrackCount,
}) =>
    explainPlaylist(
      current: current,
      library: library ?? [_t('a')],
      ctx: noContext ? null : (ctx ?? _ctx()),
      engine: const RulesEngine(),
      memory: memory ?? FeedbackMemory(),
      preferredOrigin: preferredOrigin,
      placeName: placeName,
      preciseFix: preciseFix,
      situationTag: situationTag,
      sleeping: sleeping,
      isLive: isLive,
      rule: rule,
      ruleTrackCount: ruleTrackCount);

void main() {
  group('it never claims a location reading', () {
    test('place is NOT claimed when no reading arrived', () {
      final e = _run();
      final joined = e.context.map((l) => l.text).join(' ').toLowerCase();
      expect(joined, isNot(contains('you are at')),
          reason: 'a place was claimed with no reading to support it');
      expect(joined, isNot(contains('at home')),
          reason: 'the app claimed home from a flag on a context with no reading');
    });

    test('a resolved place is named', () {
      final e = _run(placeName: 'Home');
      expect(e.context.any((l) => l.text.contains('Home')), isTrue,
          reason: 'a known place was not reported');
    });

    test('an approximate fix says so', () {
      final e = _run(placeName: 'Home', preciseFix: false);
      expect(e.context.any((l) => l.text.toLowerCase().contains('approximate')), isTrue);
    });
  });

  group('weather is reported honestly', () {
    test('rain says the rain rule is active', () {
      final e = _run(ctx: _ctx(raining: true), situationTag: 'rain');
      expect(
        e.context.any((l) => l.text.contains('Raining') && l.text.contains('active')),
        isTrue);
    });

    test('no weather is said NOTHING about', () {
      final e = _run(ctx: _ctx(), situationTag: null);
      expect(
        e.context.any((l) => l.text.toLowerCase().contains('rain')),
        isFalse,
        reason: 'the screen is talking about weather that is doing nothing');
    });
  });

  group('the explanation agrees with the selector', () {
    test('the selector admits everything the app does not exclude', () {
      final lib = [
        _t('long', seconds: 400),
        _t('normal', seconds: 200),
        _t('sting', seconds: 40),
      ];
      final ctx = _ctx();
      final engine = const RulesEngine();

      expect(engine.select(lib, ctx).length, lib.length,
          reason: 'the selector dropped a track — it is filtering by something other than exclusions');
      expect(engine.select(lib, ctx, excluded: const {'sting'}).length, lib.length - 1,
          reason: 'an explicit exclusion did not remove exactly that track');
    });

    test('NO sting line, in any band — the filter it described is gone', () {
      for (final band in [ContextBand.evening, ContextBand.darkHour]) {
        final lib = [_t('a'), _t('sting', seconds: 40)];
        final e = _run(ctx: _ctx(band: band, hour: 0), library: lib);
        expect(e.excluded.any((l) => l.text.contains('sting')), isFalse,
            reason: 'a sting line reappeared in ${band.name} — it describes a deleted filter');
      }
    });

    test('SKIPS ARE NEVER REPORTED AS SUPPRESSION, because they are not learned from', () {
      final memory = FeedbackMemory();
      final lib = [_t('skipme'), _t('b')];
      for (var i = 0; i < 5; i++) {
        memory.record('skipme', ContextBand.evening, SkipFeedback.rejected);
      }
      final e = _run(current: lib[1], library: lib, memory: memory);
      expect(e.excluded.any((l) => l.text.contains('suppressed')), isFalse);
      expect(memory.isSuppressed('skipme', ContextBand.evening), isFalse);
    });

    test('a reward IS reported', () {
      final memory = FeedbackMemory();
      memory.record('x', ContextBand.evening, SkipFeedback.accepted);
      final e = _run(current: _t('x'), memory: memory);
      expect(e.playing.any((l) => l.text.contains('kept it')), isTrue);
    });
  });

  group('the origin lecture is gone', () {
    test('a track is not explained by its game origin', () {
      final e = _run(current: _t('a'), preferredOrigin: 'P5R');
      expect(e.playing.any((l) => l.text.contains('game origin')), isFalse);
      expect(e.playing.any((l) => l.text.contains('preference rather than a filter')), isFalse);
    });

    test('and NOT a ranking either — there is no ranking to report', () {
      final e = _run(current: _t('a'), library: [_t('a'), _t('b')]);
      expect(
        e.playing.any((l) => l.text.contains('Best fit') || l.text.startsWith('#')),
        isFalse,
        reason: 'the panel still reports a ranking, but the ranking was deleted',
      );
    });
  });

  group('degenerate inputs do not produce a broken explanation', () {
    test('no context yet says so — the one case where an empty panel needs a reason', () {
      final e = _run(noContext: true);
      expect(e.context.first.text, contains('Waiting for a context reading'));
    });

    test('nothing playing says so', () {
      final e = _run(current: null);
      expect(e.playing.first.text, contains('Nothing is playing'));
    });

    test('an empty library does not crash or invent counts', () {
      final e = _run(library: const []);
      expect(e.excluded, isEmpty);
    });

    test('a clean library says NOTHING about exclusions, and that is the point', () {
      final e = _run(library: [_t('a'), _t('b')]);
      expect(e.excluded, isEmpty);
    });
  });
}
