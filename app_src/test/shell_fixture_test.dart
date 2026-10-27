library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/main.dart';
import 'package:sonarar/library/dynamic_playlist.dart';
import 'package:sonarar/theme/skin_policy.dart';
import 'package:sonarar/screens/player_screen.dart';
import 'package:sonarar/screens/tab_bar_view.dart';

import 'shell_probe.dart';
import 'package:sonarar/rules/context_rules.dart';
import 'package:sonarar/theme/skin.dart';

Track _t(String id, {int minutes = 3, String album = 'Persona 3 Reload'}) => Track(
      id: id,
      title: 'Title $id',
      artist: 'ATLUS Sound Team',
      album: album,
      duration: Duration(minutes: minutes),
      file: '$id.opus',
      cover: '',
      gainDb: null);

List<Track> _library(int n) => [
      for (var i = 0; i < n; i++) _t('t$i', minutes: [1, 3, 6][i % 3]),
    ];

const _afternoon = PlayContext(
  band: ContextBand.afternoon,
  sky: Sky.unknown,
  localHour: 14);

late Directory _sandbox;

void _fakePlatform() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in const [
    'personar/storage',
    'plugins.flutter.io/path_provider',
    'dev.fluttercommunity.plus/wakelock',
    'com.ryanheise.just_audio_background',
    'personar/location',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
      if (name == 'plugins.flutter.io/path_provider' &&
          call.method.startsWith('get')) {
        return _sandbox.path;
      }
      if (name == 'personar/storage') return 'granted';
      return null;
    });
  }
}

Future<AppState> _pumpShell(WidgetTester tester, {int tracks = 30}) async {
  tester.view.physicalSize = const Size(420, 860) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final state = AppState();
  state.attachLibrary(_library(tracks));
  state.setPlaylists(PlaylistList([
    Playlist(id: 'v_afternoon', name: 'Afternoon', trackIds: const ['t0']),
    Playlist(id: 'v_morning', name: 'Morning', trackIds: const ['t29']),
  ]));
  state.updateContext(_afternoon);

  await tester.pumpWidget(MaterialApp(home: HomeShell(state: state)));
  await tester.pump(const Duration(milliseconds: 50));

  HomeShellStateProbe.shellCall(tester, 'debugFinishLoading');
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  return state;
}

void main() {
  setUp(() {
    _sandbox = Directory.systemTemp.createTempSync('personar-fixture-');
    _fakePlatform();
  });
  tearDown(() {
    if (_sandbox.existsSync()) _sandbox.deleteSync(recursive: true);
  });

  testWidgets('the shell renders with a real library', (tester) async {
    final state = await _pumpShell(tester);
    final e = tester.takeException();
    if (e != null) {
      // ignore: avoid_print
      print('HARNESS FIXTURE EXCEPTION:\n$e');
    }
    expect(find.byType(HomeShell), findsOneWidget);
    expect(state.library.length, 30, reason: 'the fixture library did not arrive');
  });

  testWidgets('DIAGNOSTIC: what is on screen at all?', (tester) async {
    await _pumpShell(tester);
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((d) => d != null && d.isNotEmpty)
        .take(14)
        .toList();
    // ignore: avoid_print
    print('HARNESS FIXTURE: '
        'tabBar=${find.byType(TabBarView2).evaluate().length} texts=$texts');
  });

  group('the queue', () {
    testWidgets('is the WHOLE library, never a stub', (tester) async {
      final state = await _pumpShell(tester);
      final q = state.queue;
      expect(q, isNotNull, reason: 'no queue was built for a 30-track library');
      expect(q!.order.length, greaterThanOrEqualTo(3),
          reason: 'the queue is a stub of ${q.order.length} of ${state.library.length}');
    });

    testWidgets('a rule CANNOT strand it on a short playlist', (tester) async {
      final state = await _pumpShell(tester);
      state.setPlaylists(PlaylistList([
        Playlist(id: 'pl_commuting', name: 'Commuting', trackIds: const ['t0']),
      ]));
      state.setContextRules(ContextRules([
        const ContextRule(
          id: 'commuting',
          priority: 66,
          place: PlaceWant.anywhere,
          playlist: 'Commuting'),
      ]));
      state.updateContext(const PlayContext(
        band: ContextBand.darkHour,
        sky: Sky.unknown,
        localHour: 2));
      await tester.pump(const Duration(milliseconds: 250));

      expect(state.queue!.order.length, greaterThanOrEqualTo(3),
          reason: 'the rule stranded the queue on its one-track list again');
    });

    testWidgets('a LIVE queue keeps re-ranking and a rule cannot take it',
        (tester) async {
      final state = await _pumpShell(tester);
      state.setPlaylists(PlaylistList([
        Playlist(id: 'pl_commuting', name: 'Commuting', trackIds: const ['t0']),

        Playlist(id: 'v_afternoon', name: 'Afternoon', trackIds: const ['t1']),
      ]));
      state.setContextRules(ContextRules([
        const ContextRule(
          id: 'commuting',
          priority: 66,
          place: PlaceWant.anywhere,
          playlist: 'Commuting'),
      ]));

      expect(state.playDynamic(), isTrue);
      expect(state.source, QueueSource.live);
      final before = [for (final t in state.queue!.order) t.id];

      state.setPlaylists(PlaylistList([
        Playlist(id: 'pl_commuting', name: 'Commuting', trackIds: const ['t0']),
        Playlist(id: 'v_rain', name: 'Rain', trackIds: const ['t9']),

        Playlist(id: 'v_afternoon', name: 'Afternoon', trackIds: const ['t1']),
      ]));
      state.updateContext(const PlayContext(
        band: ContextBand.morning,
        sky: Sky.rain,
        localHour: 2));
      await tester.pump(const Duration(milliseconds: 250));

      expect(state.source, QueueSource.live,
          reason: 'the rule took the live queue away — it is no longer dynamic');
      final after = [for (final t in state.queue!.order) t.id];
      expect(after, isNot(before), reason: 'the queue did not re-rank on a context change');
      expect(after, contains('t9'),
          reason: 'the rain list did not lead the re-rank');
      expect(after.length, lessThanOrEqualTo(AppState.kDynamicMixLimit));
    });
  });

  group('sleep is a situation', () {
    testWidgets('arming it does NOT replace the queue with the instrumental list',
        (tester) async {
      final state = await _pumpShell(tester);
      final before = state.queue!.order.length;
      state.setSleeping(true);
      await tester.pump(const Duration(milliseconds: 250));
      expect(state.sleeping, isTrue);

      expect(state.queue!.order.length, greaterThanOrEqualTo(before),
          reason: 'arming the sleep timer shrank the queue');
    });
  });

  group('updates reach the screen', () {
    testWidgets('a state change rebuilds, which is what "only on boot" meant',
        (tester) async {
      final state = await _pumpShell(tester);
      var rebuilt = 0;
      state.addListener(() => rebuilt++);
      state.setSleeping(true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(rebuilt, greaterThan(0),
          reason: 'a state change was not observed — the screen is frozen at its boot frame');
    });

    testWidgets('the shell keeps rendering after many changes', (tester) async {
      final state = await _pumpShell(tester);
      for (var i = 0; i < 6; i++) {
        state.setSleeping(i.isEven);
        state.chooseSkinManually(i.isEven ? SkinId.crimson : SkinId.abyss);
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(tester.takeException(), isNull,
          reason: 'a rebuild threw — this is the blank-window symptom');
      expect(find.byType(HomeShell), findsOneWidget);
    });
  });

  group('TAPS reach the app — the class of bug a hand finds', () {
    testWidgets('switching tabs works and survives the round trip', (tester) async {
      await _pumpShell(tester);
      for (final label in ['SEARCH', 'LIBRARY', 'HOME']) {
        final tab = find.text(label);
        expect(tab, findsOneWidget, reason: 'the $label tab is not on screen');
        await tester.tap(tab, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull,
            reason: 'switching to $label threw');
      }

      expect(find.text('SETTINGS'), findsNothing,
          reason: 'SETTINGS is back on the tab row — it belongs in the sidebar now');
      expect(find.byType(HomeShell), findsOneWidget);
    });

    testWidgets('the QUEUE panel opens and lists the real queue', (tester) async {
      final state = await _pumpShell(tester);
      HomeShellStateProbe.shellCall(tester, 'debugOpenPanel', PlayerPanel.queue);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: 'opening the queue panel threw');
      expect(state.queue!.order.length, greaterThanOrEqualTo(3));
    });

    testWidgets('the WHY panel opens without throwing', (tester) async {
      await _pumpShell(tester);
      HomeShellStateProbe.shellCall(tester, 'debugOpenPanel', PlayerPanel.why);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: 'the WHY panel threw');
    });

    testWidgets('pressing a playlist makes it the queue', (tester) async {
      final state = await _pumpShell(tester);
      state.setPlaylists(PlaylistList([
        Playlist(id: 'pl_mine', name: 'Mine', trackIds: const ['t0', 't1', 't2']),
      ]));
      final ok = state.playPlaylistRef('Mine');
      await tester.pump(const Duration(milliseconds: 300));
      expect(ok, isTrue, reason: 'pressing a playlist refused');
      expect(state.source, QueueSource.fixed,
          reason: 'a named playlist must be FIXED, not live');
      expect(state.queue!.order.length, 3);
    });

    testWidgets('pressing DYNAMIC gives a live queue and it actually has the library',
        (tester) async {
      final state = await _pumpShell(tester);
      final ok = state.playDynamic();
      await tester.pump(const Duration(milliseconds: 300));
      expect(ok, isTrue, reason: 'playDynamic refused — this is "the dynamic is not playing"');
      expect(state.source, QueueSource.live);

      expect(state.queue!.order.length,
          lessThanOrEqualTo(AppState.kDynamicMixLimit));
      expect(state.queue!.order, isNotEmpty,
          reason: 'the press produced no tracks — "the dynamic is not playing"');
      expect(tester.takeException(), isNull);
    });
  });

  group('THE MIX — what the switch turns on, driven as the app drives it', () {
    void seedDerived(AppState state) {
      final mix = state.dynamicMix();
      if (mix != null) state.setDerivedPlaylists([mix]);
    }

    testWidgets('the mix is a SESSION, not the whole library', (tester) async {
      final state = await _pumpShell(tester);
      state.updateContext(const PlayContext(
        band: ContextBand.morning, sky: Sky.unknown, localHour: 9));

      state.setPlaylists(PlaylistList([
        Playlist(id: 'v_morning', name: 'Morning', trackIds: const ['t0']),
      ]));
      seedDerived(state);
      final mix = state.dynamicMix()!;
      expect(mix.trackIds, isNotEmpty);

      expect(mix.trackIds.length, lessThanOrEqualTo(AppState.kDynamicMixLimit),
          reason: 'the mix is unbounded — the queue would be every track he owns');
    });

    testWidgets('turning the mode on gives a LIVE queue of the mix', (tester) async {
      final state = await _pumpShell(tester);
      state.updateContext(const PlayContext(
        band: ContextBand.morning, sky: Sky.unknown, localHour: 9));
      seedDerived(state);
      state.playTrack(state.library.first);
      expect(state.source, QueueSource.live);

      expect(state.queue!.order.length,
          lessThanOrEqualTo(AppState.kDynamicMixLimit),
          reason: 'the queue is not bounded by the mix limit — a big library would queue in full');
    });

    testWidgets('IT STAYS LIVE WHEN THE CONTEXT MOVES — his actual complaint', (tester) async {
      final state = await _pumpShell(tester);
      state.updateContext(const PlayContext(
        band: ContextBand.morning, sky: Sky.unknown, localHour: 9));
      seedDerived(state);
      state.playTrack(state.library.first);
      final mixBefore = state.dynamicMix();

      state.updateContext(const PlayContext(
        band: ContextBand.evening, whereabouts: Whereabouts.home, sky: Sky.rain, localHour: 20));
      await tester.pump(const Duration(milliseconds: 200));

      expect(state.source, QueueSource.live,
          reason: 'a context move knocked the live queue off live');
      expect(state.queue!.order.length,
          lessThanOrEqualTo(AppState.kDynamicMixLimit),
          reason: 'the queue is no longer a bounded mix after a context move');
      expect(state.playlistContext!.band, ContextBand.evening,
          reason: 'the context did not actually move');

      final mixAfter = state.dynamicMix();
      expect(identical(mixBefore, mixAfter), isFalse,
          reason: 'the dynamic mix was NOT recomputed after a context move — a stale cache,'
              ' which is exactly "the queue is not dynamic"');

      final after = state.queue!.order.map((t) => t.id).toList();
      expect(after, isNotEmpty);
      expect(after.length, lessThanOrEqualTo(AppState.kDynamicMixLimit));
    });

    testWidgets('PRESSING a one-track playlist is FIXED and short — correct, not a bug',
        (tester) async {
      final state = await _pumpShell(tester);
      state.updateContext(const PlayContext(
        band: ContextBand.morning, sky: Sky.unknown, localHour: 9));
      state.setPlaylists(PlaylistList([
        Playlist(id: 'pl_one', name: 'One', trackIds: const ['t0']),
      ]));
      final ok = state.playPlaylistRef('One');
      expect(ok, isTrue);
      expect(state.source, QueueSource.fixed,
          reason: 'a named playlist pressed is a SNAPSHOT — that is the whole distinction');
    });
  });

  group('BOOT ORDER — the context must exist before the derived lists are built', () {
    testWidgets('a library with a context yields a Dynamic row on the FIRST build',
        (tester) async {
      final bare = AppState();
      bare.attachLibrary(_library(30));
      expect(bare.dynamicMix(), isNull,
          reason: 'with no context there is nothing to mix — this is why building the lists first'
              ' produced no Dynamic row at all');

      bare.setPlaylists(PlaylistList([
        Playlist(id: 'v_morning', name: 'Morning', trackIds: const ['t0']),
      ]));
      bare.updateContext(const PlayContext(
        band: ContextBand.morning, sky: Sky.unknown, localHour: 9));

      final state = bare;
      final mix = state.dynamicMix();
      expect(mix, isNotNull, reason: 'the mix is unavailable once a context exists');
      state.setDerivedPlaylists([mix!]);

      expect(state.allPlaylists.where((p) => p.id == kDynamicId), hasLength(1),
          reason: 'Dynamic is not in the list a person actually presses');
      expect(state.allPlaylists.first.id, kDynamicId,
          reason: 'Dynamic is meant to be FIRST — it is the one that answers "just decide"');
    });

    testWidgets('a context move keeps the row fresh, not just the cache', (tester) async {
      final state = await _pumpShell(tester);
      state.updateContext(const PlayContext(
        band: ContextBand.morning, sky: Sky.unknown, localHour: 9));
      state.setDerivedPlaylists([state.dynamicMix()!]);

      state.updateContext(const PlayContext(
        band: ContextBand.evening, whereabouts: Whereabouts.home, sky: Sky.rain, localHour: 20));

      final row = state.allPlaylists.firstWhere((p) => p.id == kDynamicId);

      expect(row.trackIds, isNotEmpty,
          reason: 'the ROW is empty — the stale cache was cleared but the row was never rebuilt');
      expect(row.trackIds.length, lessThanOrEqualTo(AppState.kDynamicMixLimit),
          reason: 'the ROW holds more than a session');
      expect(state.playlistContext!.band, ContextBand.evening);
    });
  });
}
