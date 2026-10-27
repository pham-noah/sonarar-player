library;

import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/bonds.dart';
import 'package:sonarar/library/fusion.dart';
import 'package:sonarar/library/maintenance.dart';
import 'package:sonarar/library/play_log.dart';
import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/rediscovery.dart';
import 'package:sonarar/library/tag_overrides.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/rules/context_rules.dart';
import 'package:sonarar/rules/rules_engine.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/skin_policy.dart';

Track _t(String id, {String title = 'A Song', String artist = 'ATLUS Sound Team',
    String album = 'Persona 3 Reload', int seconds = 200, String file = '',
    String cover = 'covers/x.jpg'}) =>
    Track(
      id: id,
      title: title,
      artist: artist,
      album: album,
      duration: Duration(seconds: seconds),
      file: file.isEmpty ? '$id.opus' : file,
      cover: cover,
      gainDb: 0);

PlayEvent _e(String id, {
  required DateTime at,
  String band = 'evening',
  bool completed = true,
  int positionMs = 200000,
  int durationMs = 200000,
}) =>
    PlayEvent(
      trackId: id,
      at: at,
      band: band,
      positionMs: positionMs,
      durationMs: durationMs);

void main() {
  final now = DateTime(2026, 10, 2, 12);

  group('tag corrections', () {
    test('an override produces a NEW track and leaves the original alone', () {
      final t = _t('a', title: 'Wrong Title');
      final o = TagOverrides()..set('a', TagField.title, 'Right Title');

      final fixed = o.apply(t);

      expect(fixed.title, 'Right Title');
      expect(fixed.id, t.id, reason: 'the id is what everything else keys on');

      expect(t.title, 'Wrong Title');
    });

    test('nothing overridden is a provable no-op', () {
      final t = _t('a');
      expect(identical(TagOverrides().apply(t), t), isTrue);
    });

    test('a blank value removes the correction rather than storing ""', () {
      final o = TagOverrides()
        ..set('a', TagField.title, 'Fixed')
        ..set('a', TagField.title, '   ');
      expect(o.forTrack('a'), isEmpty);
      expect(o.isEmpty, isTrue);
    });

    test('a partly corrected track keeps its other fields', () {
      final o = TagOverrides()..set('a', TagField.artist, 'Someone Else');
      final fixed = o.apply(_t('a', title: 'T', album: 'Alb'));
      expect(fixed.artist, 'Someone Else');
      expect(fixed.title, 'T');
      expect(fixed.album, 'Alb');
    });

    test('decode ignores fields nothing reads, and a bad file yields nothing',
        () {
      final bad = TagOverrides.decode('{"overrides": {"a": {"bpm": "128"}}}');
      expect(bad.isEmpty, isTrue,
          reason: 'an override nothing reads must not be stored');

      final good = TagOverrides.decode(
          '{"overrides": {"a": {"title": " X ", "artist": ""}}}');
      expect(good.forTrack('a'), {'title': 'X'});

      expect(TagOverrides.decode('not json at all').isEmpty, isTrue);
    });

    test('prune drops corrections for tracks the library no longer has', () {
      final o = TagOverrides()
        ..set('a', TagField.title, 'x')
        ..set('gone', TagField.title, 'y');
      expect(o.prune({'a'}), 1);
      expect(o.length, 1);
    });
  });

  group('bonds', () {
    test('a completion earns points and an early skip takes them back', () {
      final board = buildBonds([
        _e('a', at: now.subtract(const Duration(days: 1))),
        _e('a', at: now, completed: false, positionMs: 3000),
      ]);
      final b = board.forTrack('a')!;
      expect(b.completions, 1);
      expect(b.earlySkips, 1);
      expect(b.points, lessThan(6),
          reason: '6 for the completion, 3 back for the skip');
    });

    test('gains DIMINISH within one context, which is the anti-repetition rule',
        () {
      final same = buildBonds([
        _e('a', at: now.subtract(const Duration(hours: 2))),
        _e('a', at: now.subtract(const Duration(hours: 1))),
      ]).forTrack('a')!;

      final spread = buildBonds([
        _e('a', at: now.subtract(const Duration(hours: 2)), band: 'morning'),
        _e('a', at: now, band: 'night'),
      ]).forTrack('a')!;

      expect(same.completions, 2);
      expect(spread.completions, 2);
      expect(same.points, lessThan(spread.points),
          reason: 'looping one track in one mood must not out-earn playing it '
              'across contexts — that is the whole reason the ladder is per band');
      expect(same.contexts, 1);
      expect(spread.contexts, 2);
    });

    test('a repeated early skip in one band never drives the score below the '
        'penalty for the first one', () {
      final b = buildBonds([
        for (var i = 0; i < 12; i++)
          _e('a', at: now.subtract(Duration(hours: i + 1)),
              completed: false, positionMs: 2000),
      ]).forTrack('a')!;

      expect(b.points, greaterThan(-10));
      expect(b.earlySkips, 12);
    });

    test('rank can go DOWN — the point of a bond over a play count', () {
      final high = buildBonds([
        _e('a', at: now.subtract(const Duration(days: 3)), band: 'morning'),
        _e('a', at: now.subtract(const Duration(days: 2)), band: 'evening'),
        _e('a', at: now.subtract(const Duration(days: 1)), band: 'night'),
      ]).forTrack('a')!;
      expect(high.rank, greaterThan(0));

      final after = buildBonds([
        _e('a', at: now.subtract(const Duration(days: 3)), band: 'morning'),
        _e('a', at: now.subtract(const Duration(days: 2)), band: 'evening'),
        _e('a', at: now, completed: false, positionMs: 1000),
      ]).forTrack('a')!;
      expect(after.points, lessThan(high.points));
    });

    test('a reset starts the counting again without touching the history', () {
      final events = [_e('a', at: DateTime(2026, 1, 1))];
      final before = buildBonds(events);
      expect(before.isEmpty, isFalse);

      final after = buildBonds(
        events,
        state: BondState().config
            .withResetAt(DateTime(2026, 6, 1))
            .let((c) => BondState(config: c)));
      expect(after.isEmpty, isTrue,
          reason: 'the play predates the reset, so the bond starts at nothing');

      expect(events.length, 1);
    });

    test('a skip inside the first ten seconds is not a counted play', () {
      final board = buildBonds([
        _e('a', at: now, completed: false, positionMs: 4000),
      ]);
      final b = board.forTrack('a')!;
      expect(b.completions, 0);
      expect(b.earlySkips, 1);
    });

    test('rank names line up with the ladder', () {
      for (var i = 0; i < kBondLadder.length; i++) {
        expect(kBondRanks[i].name.isNotEmpty, isTrue);
      }
      expect(kBondRanks[0].unlocks.contains('Nothing yet'), isTrue,
          reason: 'rank 0 must not promise an unlock it does not have');
      expect(kBondRanks[5].unlocks.contains('note'), isTrue);
    });

    test('a note is refused below the unlocking rank', () {
      final s = BondState();
      expect(s.setNote('a', 'hi', rank: BondState.kNoteRank - 1), isFalse);
      expect(s.noteFor('a'), isNull);
      expect(s.setNote('a', 'hi', rank: BondState.kNoteRank), isTrue);
      expect(s.noteFor('a'), 'hi');
    });
  });

  group('fusion', () {
    test('interleave alternates between the two sources', () {
      expect(fuseIds(['1', '2', '3'], ['a', 'b']),
          ['1', 'a', '2', 'b', '3']);
    });

    test('a track in both sources appears ONCE', () {
      expect(fuseIds(['1', '2'], ['2', '3']), ['1', '2', '3']);
    });

    test('append is all of the first then all of the second', () {
      expect(fuseIds(['1', '2'], ['a'], mode: FusionMode.append),
          ['1', '2', 'a']);
    });

    test('intersection keeps the order of the first list', () {
      expect(fuseIds(['1', '2', '3'], ['3', '1'], mode: FusionMode.intersection),
          ['1', '3']);
      expect(fuseIds(['1'], ['2'], mode: FusionMode.intersection), isEmpty);
    });

    test('a fusion that produces nothing creates NO playlist', () {
      final lists = PlaylistList();
      lists.create('A', id: 'a', trackIds: ['1']);
      lists.create('B', id: 'b', trackIds: ['2']);
      final created = fusePlaylists(lists, lists.byId('a')!, lists.byId('b')!,
          name: 'Mix', mode: FusionMode.intersection);
      expect(created, isNull);
      expect(lists.length, 2, reason: 'nothing was added');
    });

    test('fusing leaves both sources exactly as they were', () {
      final lists = PlaylistList();
      lists.create('A', id: 'a', trackIds: ['1', '2']);
      lists.create('B', id: 'b', trackIds: ['2', '3']);
      final created = fusePlaylists(lists, lists.byId('a')!, lists.byId('b')!,
          name: 'Mix', id: 'mix');
      expect(created!.trackIds, ['1', '2', '3']);
      expect(lists.byId('a')!.trackIds, ['1', '2']);
      expect(lists.byId('b')!.trackIds, ['2', '3']);
    });

    test('the size is knowable before committing', () {
      expect(fusionSize(['1', '2', '3'], ['3'], mode: FusionMode.intersection),
          1);
    });
  });

  group('rediscovery', () {
    final lib = [_t('a'), _t('b'), _t('c'), _t('d')];

    test('with no history at all, nothing is offered', () {
      final lists = buildRediscovery(library: lib, events: const [], now: now);
      expect(lists.first.usable, isFalse);
      expect(lists.first.playlist.isEmpty, isTrue,
          reason: 'a list of the whole library is not a rediscovery list');
    });

    test('a young log does NOT offer the entire library as rediscovery', () {
      final lists = buildRediscovery(
        library: lib,
        events: [_e('a', at: now)],
        now: now);
      expect(lists.first.playlist.length, 3);
      expect(lists.first.usable, isTrue);
    });

    test('a track played inside the window is not stale', () {
      final lists = buildRediscovery(
        library: lib,
        events: [
          _e('a', at: now),
          _e('b', at: now.subtract(const Duration(days: 400))),
          _e('c', at: now.subtract(const Duration(days: 1))),
          _e('d', at: now),
        ],
        now: now);
      expect(lists.first.playlist.trackIds, ['b']);
    });

    test('an early skip is not a play, so the track stays rediscoverable', () {
      final lists = buildRediscovery(
        library: lib,
        events: [
          _e('a', at: now, completed: false, positionMs: 2000),
          _e('b', at: now.subtract(const Duration(days: 400))),
          _e('c', at: now),
          _e('d', at: now),
        ],
        now: now);
      expect(lists.first.playlist.trackIds, contains('a'));
    });

    test('loved then forgotten needs BOTH a like and a quiet spell', () {
      final lists = buildRediscovery(
        library: lib,
        events: [
          _e('a', at: now.subtract(const Duration(days: 400))),
          _e('b', at: now),
          _e('c', at: now),
          _e('d', at: now),
        ],
        favorites: {'a', 'b'},
        now: now);
      final forgotten = lists[1];
      expect(forgotten.playlist.trackIds, ['a'],
          reason: 'b is liked but was played today, so it is not forgotten');
      expect(forgotten.usable, isTrue);
    });

    test('the derived ids are reserved so rename/delete can refuse them', () {
      expect(isDerivedPlaylistId(kRediscoverId), isTrue);
      expect(isDerivedPlaylistId(kForgottenId), isTrue);
      expect(isDerivedPlaylistId('pl_123'), isFalse);
    });
  });

  group('context rules', () {
    PlaylistContext ctx({
      ContextBand band = ContextBand.evening,
      bool raining = false,
      ManualMode? mode,
    }) =>
        PlaylistContext(
          band: band,
          sky: raining ? Sky.rain : Sky.unknown,
          whereabouts: Whereabouts.home,
          localHour: 19,
          mode: mode);

    test('the highest priority match wins', () {
      final rules = ContextRules([
        const ContextRule(id: 'low', priority: 10, band: ContextBand.evening),
        const ContextRule(id: 'high', priority: 90, band: ContextBand.evening),
      ]);
      expect(rules.firstMatch(ctx())!.id, 'high');
    });

    test('a rule about a different band does not match', () {
      final rules = ContextRules([
        const ContextRule(id: 'm', priority: 50, band: ContextBand.morning),
      ]);
      expect(rules.firstMatch(ctx()), isNull);
    });

    test('a rain rule fires only when it is actually raining', () {
      final rules = ContextRules([
        const ContextRule(id: 'rain', priority: 50, weather: WeatherWant.rain),
      ]);
      expect(rules.firstMatch(ctx(raining: true))!.id, 'rain');
      expect(rules.firstMatch(ctx()), isNull);
    });

    test('a mode rule matches only the mode he entered by hand', () {
      final rules = ContextRules([
        const ContextRule(id: 'b', priority: 80, mode: ManualMode.battle),
      ]);
      expect(rules.firstMatch(ctx(mode: ManualMode.battle))!.id, 'b');
      expect(rules.firstMatch(ctx()), isNull);
    });

    test('every condition present has to hold at once', () {
      final rules = ContextRules([
        const ContextRule(
          id: 'both',
          priority: 80,
          band: ContextBand.night,
          weather: WeatherWant.rain),
      ]);
      expect(rules.firstMatch(ctx(band: ContextBand.night, raining: true)),
          isNotNull);
      expect(rules.firstMatch(ctx(band: ContextBand.night)),
          isNull);
      expect(rules.firstMatch(ctx(band: ContextBand.evening, raining: true)),
          isNull);
    });

    test('the plan\'s snake_case spelling resolves to the enum value', () {
      final rules = ContextRules.decode(
          '{"rules": [{"id": "dh", "priority": 5, "when": {"time_band": "dark_hour"}}]}');
      expect(rules.length, 1, reason: 'the snake_case form must parse');
      expect(rules.rules.first.band, ContextBand.darkHour);

      final camel = ContextRules.decode(
          '{"rules": [{"id": "dh", "priority": 5, "when": {"time_band": "darkHour"}}]}');
      expect(camel.rules.first.band, ContextBand.darkHour);

      final seedFile = File('assets/config/rules.json');
      expect(seedFile.existsSync(), isTrue,
          reason: 'the seed is a shipped asset; if this fails the test is '
              'looking in the wrong place, not that the seed is missing');
      final seed = ContextRules.decode(seedFile.readAsStringSync());

      expect(seed.length, 3,
          reason: 'every rule in the bundled seed must survive decoding');
    });

    test('a mode named in snake_case also resolves', () {
      final rules = ContextRules.decode(
          '{"rules": [{"id": "x", "priority": 5, "when": {"mode": "dark_hour"}}]}');
      expect(rules.rules.first.mode, ManualMode.darkHour);
    });

    test('an unknown band name is an error, not "unconstrained"', () {
      final rules = ContextRules.decode(
          '{"rules": [{"id": "x", "priority": 5, "when": {"time_band": "twilight"}}]}');
      expect(rules.isEmpty, isTrue);
    });

    test('the unsupported "dry" condition is rejected outright', () {
      final rules = ContextRules.decode(
          '{"rules": [{"id": "x", "priority": 5, "when": {"weather": "dry"}}]}');
      expect(rules.isEmpty, isTrue);
    });

    test('a rule with no conditions is kept and matches everything', () {
      final rules = ContextRules.decode(
          '{"rules": [{"id": "always", "priority": 1, "playlist": "everything"}]}');
      expect(rules.firstMatch(ctx())!.playlist, 'everything');
    });

    test('round-trips through its own JSON', () {
      final rules = ContextRules([
        const ContextRule(
          id: 'dark-hour',
          priority: 78,
          band: ContextBand.darkHour,
          theme: SkinId.abyss),
      ]);
      final back = ContextRules.decode(rules.encode());
      expect(back.length, 1);
      expect(back.rules.first.id, 'dark-hour');
      expect(back.rules.first.band, ContextBand.darkHour);
      expect(back.rules.first.theme, SkinId.abyss);
    });

    test('describe() names what it does, for the explanation screen', () {
      const r = ContextRule(
          id: 'x', priority: 1, band: ContextBand.morning, playlist: 'morning-move');
      expect(r.describe(), contains('morning'));
      expect(r.describe(), contains('morning-move'));
    });
  });

  group('maintenance review', () {
    test('version suffixes are stripped, in both shapes a rip produces', () {
      final a = normaliseTitle('Living With Determination -Reload-');
      final b = normaliseTitle('Living With Determination');
      expect(a, b);

      expect(normaliseTitle('Burn My Dread (P3R ver.)'),
          normaliseTitle('Burn My Dread'));
      expect(normaliseTitle('Song [Remaster]'), 'song');
    });

    test('a real title is not mistaken for a suffix', () {
      expect(normaliseTitle('Living With Determination'),
          'living with determination');

      expect(normaliseTitle('Live and Learn'), 'live and learn');
    });

    test('the same piece under two spellings is reported as a duplicate', () {
      final dupes = findDuplicates([
        _t('a', title: 'Burn My Dread'),
        _t('b', title: 'Burn My Dread (P3R ver.)'),
        _t('c', title: 'Something Else'),
      ]);
      expect(dupes.length, 1);
      expect(dupes.first.tracks.map((t) => t.id), ['a', 'b']);
    });

    test('a different artist is not a duplicate', () {
      final dupes = findDuplicates([
        _t('a', title: 'Burn My Dread', artist: 'A'),
        _t('b', title: 'Burn My Dread', artist: 'B'),
      ]);
      expect(dupes, isEmpty,
          reason: 'the same title by a different artist is a cover, not a dup');
    });

    test('a clean library reports nothing', () {
      final findings = reviewLibrary([
        _t('a', title: 'Song', seconds: 200),
        _t('b', title: 'Another', seconds: 180),
      ]);
      expect(findings, isEmpty);
    });

    test('a jingle, a blank title and a doubled file are each reported', () {
      final findings = reviewLibrary([
        _t('a', title: 'Short', seconds: 12),
        _t('b', title: 'Untitled'),
        _t('c', title: 'Same', file: 'shared.opus'),
        _t('d', title: 'Same too', file: 'shared.opus'),
      ]);
      final kinds = findings.map((f) => f.kind).toSet();
      expect(kinds, contains(CleanupKind.veryShort));
      expect(kinds, contains(CleanupKind.missingMetadata));
      expect(kinds, contains(CleanupKind.sameFile));
    });

    test('the review never returns an action — only findings', () {
      for (final f in reviewLibrary([_t('a', title: 'Short', seconds: 5)])) {
        expect(f.detail, isNotEmpty);
        expect(f.trackIds, isNotEmpty);
      }
    });
  });

  group('theme vocabulary — Persona words are a theme, not a feature', () {
    test('the general build has a name for every themed word', () {
      const general = Skin(
        id: SkinId.abyss,
        displayName: 'General',
        background: Color(0xFF000000),
        accent: Color(0xFFFFFFFF),
        accentDeep: Color(0xFF888888),
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xFFCCCCCC),
        panel: Color(0xFF222222),
        onAccent: Color(0xFF000000),
        skewDegrees: 0,
        contextLabel: 'NOW',
        nowPlayingWordmark: 'PLAYING');
      expect(general.word(WordKey.libraryRoom, 'Library tools'), 'Library tools');
      expect(general.word(WordKey.modeBattle, 'Energy'), 'Energy');
    });

    test('every GAME skin names the rooms and modes it uses', () {
      for (final s in [kSkinAbyss, kSkinAmber, kSkinCrimson]) {
        expect(s.word(WordKey.libraryRoom, ''), isNotEmpty);
        expect(s.word(WordKey.affinityRoom, ''), isNotEmpty);
        expect(s.word(WordKey.modeBattle, ''), isNotEmpty);
        expect(s.word(WordKey.modeDeepNight, ''), isNotEmpty);
      }
    });

    test('a skin that names nothing falls back to neutral wording', () {
      for (final s in [kSkinMinimal, kSkinMono, kSkinBloom]) {
        expect(s.names, isEmpty, reason: '${s.displayName} should name nothing');
        expect(s.word(WordKey.libraryRoom, 'Library tools'), 'Library tools');
        expect(s.word(WordKey.modeBattle, 'Energy'), 'Energy');
      }
    });

    test('the plain mode names carry no Persona vocabulary', () {
      expect(ManualMode.battle.label, 'Energy');
      expect(ManualMode.darkHour.label, 'Night Hour');
      expect(ManualMode.battle.blurb.contains('All-Out'), isFalse);
    });

    test('the themed name is what the skin supplies', () {
      expect(manualModeName(kSkinAbyss, ManualMode.battle), 'NIGHTFALL');
      expect(manualModeName(kSkinCrimson, ManualMode.darkHour), 'BACKSTAGE');

      expect(manualModeBlurb(kSkinAbyss, ManualMode.battle), ManualMode.battle.blurb);
    });
  });

  group('manual contexts', () {
    test('battle borrows the high-energy band rather than inventing one', () {
      expect(ManualMode.battle.band, ContextBand.afternoon);
      final battle = PlaylistContext(
        band: ManualMode.battle.band,
        whereabouts: Whereabouts.home,
        sky: Sky.unknown,
        localHour: 15,
        mode: ManualMode.battle);
      expect(battle.effectiveEnergy, Energy.high);
    });

    test('Dark Hour entered by hand IS Dark Hour', () {
      final ctx = PlayContext(
        band: ManualMode.darkHour.band,
        whereabouts: Whereabouts.home,
        sky: Sky.unknown,
        localHour: 15,
        mode: ManualMode.darkHour);
      expect(ctx.isDarkHour, isTrue,
          reason: 'the testable path and the midnight path must be the same '
              'context, or the feature he can check is not the feature that '
              'fires at 00:00');
      expect(SkinPolicy().skinForContext(ctx), SkinId.abyss);
    });

    test('a manual context does not change the clock reading', () {
      final ctx = PlayContext(
        band: ManualMode.battle.band,
        whereabouts: Whereabouts.home,
        sky: Sky.unknown,
        localHour: 15,
        mode: ManualMode.battle);
      expect(ctx.localHour, 15,
          reason: 'time of day is an INPUT; a context is an override of how it '
              'is interpreted, never a change to the clock itself');
    });
  });
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
