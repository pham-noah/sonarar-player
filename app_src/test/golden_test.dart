@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/screens/mini_player.dart';
import 'package:sonarar/screens/player_screen.dart';
import 'package:sonarar/screens/settings_screen.dart';
import 'package:sonarar/player/queue.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/skin_policy.dart';

import 'tolerant_golden.dart';

Track _t(String id, String title, String artist, {int seconds = 180}) => Track(
      id: id,
      title: title,
      artist: artist,
      album: 'Persona 3 Reload',
      duration: Duration(seconds: seconds),
      file: '$id.opus',
      cover: '',
      gainDb: -3.0);

final _lib = [
  _t('a', '全ての人の魂の戦い', 'ATLUS Sound Team', seconds: 349),
  _t('b', 'Living With Determination', 'ATLUS Sound Team', seconds: 174),
  _t('c', 'Burn My Dread', 'Lotus Juice', seconds: 208),
  _t('d', 'Brand New Days', 'ATLUS Sound Team', seconds: 352),
  _t('e', 'キミの記憶', 'ATLUS Sound Team', seconds: 399),
  _t('f', 'Memories of you', 'ATLUS Sound Team', seconds: 512),
];

AppState _stateFor({required ContextBand band, required int hour}) {
  final s = AppState();
  s.updateContext(PlayContext(
      band: band, whereabouts: Whereabouts.home, sky: Sky.unknown, localHour: hour));
  s.attachLibrary(_lib);

  s.playTrackNow(band == ContextBand.night ? 'a' : 'b');
  return s;
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: child)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      // ignore: avoid_print
      await precacheImage(image.image, element);
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  const size = Size(420, 860);

  setUpAll(() {
    goldenFileComparator = TolerantGoldenFileComparator(
      basePath: 'test',
      channelTolerance: 4);
  });

  testWidgets('player — Abyss evening', (tester) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final s = _stateFor(band: ContextBand.evening, hour: 19);
    expect(s.skin.id, SkinId.abyss, reason: 'evening must select Abyss');

    await _pump(
      tester,
      PlayerScreen(
        state: s,
        track: s.currentTrack,
        cover: MemoryImage(_coverBytes())));
    await expectLater(
      find.byType(PlayerScreen),
      matchesGoldenFile('goldens/player_abyss_evening.png'));
  });

  testWidgets('player — Amber morning', (tester) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final s = _stateFor(band: ContextBand.morning, hour: 8);
    expect(s.skin.id, SkinId.amber);

    await _pump(
      tester,
      PlayerScreen(
        state: s,
        track: s.currentTrack,
        cover: MemoryImage(_coverBytes())));
    await expectLater(
      find.byType(PlayerScreen),
      matchesGoldenFile('goldens/player_amber_morning.png'));
  });

  testWidgets('player — Crimson night', (tester) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final s = _stateFor(band: ContextBand.night, hour: 23);
    expect(s.skin.id, SkinId.crimson);

    await _pump(
      tester,
      PlayerScreen(
        state: s,
        track: s.currentTrack,
        cover: MemoryImage(_coverBytes())));
    await expectLater(
      find.byType(PlayerScreen),
      matchesGoldenFile('goldens/player_crimson_night.png'));
  });

  testWidgets('settings — Abyss', (tester) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final s = _stateFor(band: ContextBand.evening, hour: 19);
    await _pump(tester, SettingsScreen(state: s));
    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings_abyss.png'));
  });

  for (final id in [SkinId.minimal, SkinId.bloom]) {
    testWidgets('settings — ${id.name} (render for review)', (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final s = _stateFor(band: ContextBand.evening, hour: 19);

      s.chooseSkinManually(id);
      expect(s.skin.id, id, reason: 'the manual pick did not take effect');

      await _pump(tester, SettingsScreen(state: s));
      await tester.pump(const Duration(milliseconds: 200));
    });
  }

  testWidgets('library — Crimson', (tester) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final s = _stateFor(band: ContextBand.night, hour: 23);
    await _pump(
      tester,
      LibraryScreen(
        tracks: _lib,
        coverPathFor: (_) => null,
        skin: s.skin,

        playlists: PlaylistList(),
        libraryRoot: null));
    await expectLater(
      find.byType(LibraryScreen),
      matchesGoldenFile('goldens/library_crimson.png'));
  });

  testWidgets('player — with the cover slot filled', (tester) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final s = _stateFor(band: ContextBand.evening, hour: 19);
    await _pump(
      tester,
      PlayerScreen(
        state: s,
        track: s.currentTrack,
        cover: MemoryImage(_coverBytes())));
    await expectLater(
      find.byType(PlayerScreen),
      matchesGoldenFile('goldens/player_abyss_with_cover.png'));
  });

  testWidgets('player — at the wide-window size',
      (tester) async {
    const windowSize = Size(430, 900);
    tester.view.physicalSize = windowSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final s = _stateFor(band: ContextBand.evening, hour: 19);
    await _pump(
      tester,
      PlayerScreen(
        state: s,
        track: s.currentTrack,
        cover: MemoryImage(_coverBytes())));
    await expectLater(
      find.byType(PlayerScreen),
      matchesGoldenFile('goldens/player_window_size.png'));
  });

  testWidgets('mini player — over the library', (tester) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final s = _stateFor(band: ContextBand.evening, hour: 19);
    await _pump(
      tester,
      MiniPlayer(
        skin: s.skin,
        track: s.currentTrack!,
        cover: MemoryImage(_coverBytes()),
        playing: true,
        onPlayPause: () {},
        onCycleRepeat: () {},
        repeatMode: RepeatMode.one));
    await expectLater(
      find.byType(MiniPlayer),
      matchesGoldenFile('goldens/mini_player.png'));
  });
}

Uint8List _coverBytes() {
  const root = r'C:\Users\Noah\Music\Sonarar\covers';
  final dir = Directory(root);
  if (dir.existsSync()) {
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.jpg'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    if (files.isNotEmpty) return files.first.readAsBytesSync();
  }

  return base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAoAAAAKACAIAAACDr150AAAXiElEQVR42u3VQQ0AIRRDQWRwQMCKwH+QhYGem5CdBAXzad6Y63v6nb2ffvz58+fP/5/+wwEMgD9//vz5C7AB8OfPnz9/AXYAA+DPnz9//gJsAPz58+fPX4AdwAD48+fPn78AGwB//vz58xdgBzAA/vz58+cvwAbAnz9//vwF2AEMgD9//vz5C7AB8OfPnz9/ATYA/vz58+cvwA5gAPz58+fPX4ANgD9//vz5C7ADGAB//vz58xdgA+DPnz9//gLsAAbAnz9//vwF2AD48+fPn78AO4AB8OfPnz9/ATYA/vz58+cvwAbAnz9//vwF2AEMgD9//vz5C7AB8OfPnz9/AXYAA+DPnz9//gJsAPz58+fPX4AdwAD48+fPn78AGwB//vz58xdgBzAA/vz58+cvwAbAnz9//vwF2AD48+fPn78AO4AB8OfPnz9/ATYA/vz58+cvwA5gAPz58+fPX4ANgD9//vz5C7ADGAB//vz58xdgA+DPnz9//gLsAAbAnz9//vwF2AD48+fPn78AGwB//vz58xdgBzAA/vz58+cvwAbAnz9//vwF2AEMgD9//vz5C7AB8OfPnz9/AXYAA+DPnz9//gJsAPz58+fPX4AdwAD48+fPn78AGwB//vz58xdgA+DPnz9//gLsAAbAnz9//vwF2AD48+fPn78AO4AB8OfPnz9/ATYA/vz58+cvwA5gAPz58+fPX4ANgD9//vz5C7ADGAB//vz58xdgA+DPnz9//gLsAAbAnz9//gLsAAbAnz9//vwF2AD48+fPn78AO4AB8OfPnz9/ATYA/vz58+cvwA5gAPz58+fPX4ANgD9//vz5C7ADGAB//vz5848B9oF8IP78+fPn338CbAD8+fPnz1+ADYA/f/78+QuwAxgAf/78+fMXYAPgz58/f/4C7AAGwJ8/f/78BdgA+PPnz5+/ADuAAfDnz58/fwE2AP78+fPnL8AOYAD8+fPnz1+ADYA/f/78+QuwAfDnz58/fwF2AAPgz58/f/4CbAD8+fPnz1+AHcAA+PPnz5+/ABsAf/78+fMXYAcwAP78+fPnL8AGwJ8/f/78BdgBDIA/f/78+QuwAfDnz58/fwE2AP78+fPnL8AOYAD8+fPnz1+ADYA/f/78+QuwAxgAf/78+fMXYAPgz58/f/4C7AAGwJ8/f/78BdgA+PPnz5+/ADuAAfDnz58/fwE2AP78+fPnL8AGwJ8/f/78BdgBDIA/f/78+QuwAfDnz58/fwF2AAPgz58/f/4CbAD8+fPnz1+AHcAA+PPnz5+/ABsAf/78+fMXYAcwAP78+fPnL8AGwJ8/f/78BdgA+PPnz5+/ADuAAfDnz58/fwE2AP78+fPnL8AOYAD8+fPnz1+ADYA/f/78+QuwAxgAf/78+fMXYAPgz58/f/4C7AAGwJ8/f/78BdgA+PPnz5+/ABsAf/78+fMXYAcwAP78+fPnL8AGwJ8/f/78BdgBDIA/f/78+QuwAfDnz58/fwF2AAPgz58/f/4CbAD8+fPnz1+AHcAA+PPnz5+/ABsAf/78+fMXYAcwAP78+fMXYAcwAP78+fPnL8AGwJ8/f/78BdgBDIA/f/78+QuwAfDnz58/fwF2AAPgz58/f/4CbAD8+fPnz1+AHcAA+PPnz59/DrAP5APx58+fP//+E2AD4M+fP3/+AmwA/Pnz589fgB3AAPjz58+fvwAbAH/+/PnzF2AHMAD+/Pnz5y/ABsCfP3/+/AXYAQyAP3/+/PkLsAHw58+fP38BdgAD4M+fP3/+AmwA/Pnz589fgA2AP3/+/PkLsAMYAH/+/PnzF2AD4M+fP3/+AuwABsCfP3/+/AXYAPjz58+fvwA7gAHw58+fP38BNgD+/Pnz5y/ADmAA/Pnz589fgA2AP3/+/PkLsAHw58+fP38BdgAD4M+fP3/+AmwA/Pnz589fgB3AAPjz58+fvwAbAH/+/PnzF2AHMAD+/Pnz5y/ABsCfP3/+/AXYAQyAP3/+/PkLsAHw58+fP38BNgD+/Pnz5y/ADmAA/Pnz589fgA2AP3/+/PkLsAMYAH/+/PnzF2AD4M+fP3/+AuwABsCfP3/+/AXYAPjz58+fvwA7gAHw58+fP38BNgD+/Pnz5y/ABsCfP3/+/AXYAQyAP3/+/PkLsAHw58+fP38BdgAD4M+fP3/+AmwA/Pnz589fgB3AAPjz58+fvwAbAH/+/PnzF2AHMAD+/Pnz5y/ABsCfP3/+/AXYAPjz58+fvwA7gAHw58+fP38BNgD+/Pnz5y/ADmAA/Pnz589fgA2AP3/+/PkLsAMYAH/+/PnzF2AD4M+fP3/+AuwABsCfP3/+/AXYAPjz58+fvwA7gAHw58+fvwA7gAHw58+fP38BNgD+/Pnz5y/ADmAA/Pnz589fgA2AP3/+/PkLsAMYAH/+/PnzF2AD4M+fP3/+AuwABsCfP3/+/HOAfSAfiD9//vz5958AGwB//vz58xdgA+DPnz9//gLsAAbAnz9//vwF2AD48+fPn78AO4AB8OfPnz9/ATYA/vz58+cvwA5gAPz58+fPX4ANgD9//vz5C7ADGAB//vz58xdgA+DPnz9//gJsAPz58+fPX4AdwAD48+fPn78AGwB//vz58xdgBzAA/vz58+cvwAbAnz9//vwF2AEMgD9//vz5C7AB8OfPnz9/AXYAA+DPnz9//gJsAPz58+fPX4ANgD9//vz5C7ADGAB//vz58xdgA+DPnz9//gLsAAbAnz9//vwF2AD48+fPn78AO4AB8OfPnz9/ATYA/vz58+cvwA5gAPz58+fPX4ANgD9//vz5C7AB8OfPnz9/AXYAA+DPnz9//gJsAPz58+fPX4AdwAD48+fPn78AGwB//vz58xdgBzAA/vz58+cvwAbAnz9//vwF2AEMgD9//vz5C7AB8OfPnz9/ATYA/vz58+cvwA5gAPz58+fPX4ANgD9//vz5C7ADGAB//vz58xdgA+DPnz9//gLsAAbAnz9//vwF2AD48+fPn78AO4AB8OfPnz9/ATYA/vz58+cvwAbAnz9//vwF2AEMgD9//vz5C7AB8OfPnz9/AXYAA+DPnz9//gJsAPz58+fPX4AdwAD48+fPn78AGwB//vz58xdgBzAA/vz58+cvwAbAnz9//vwF2AEMgD9//vwF2AEMgD9//vz5C7AB8OfPnz9/AXYAA+DPnz9//gJsAPz58+fPX4AdwAD48+fPn78AGwB//vz58xdgBzAA/vz58+efA+wD+UD8+fPnz7//BNgA+PPnz5+/ABsAf/78+fMXYAcwAP78+fPnL8AGwJ8/f/78BdgBDIA/f/78+QuwAfDnz58/fwF2AAPgz58/f/4CbAD8+fPnz1+AHcAA+PPnz5+/ABsAf/78+fMXYAPgz58/f/4C7AAGwJ8/f/78BdgA+PPnz5+/ADuAAfDnz58/fwE2AP78+fPnL8AOYAD8+fPnz1+ADYA/f/78+QuwAxgAf/78+fMXYAPgz58/f/4CbAD8+fPnz1+AHcAA+PPnz5+/ABsAf/78+fMXYAcwAP78+fPnL8AGwJ8/f/78BdgBDIA/f/78+QuwAfDnz58/fwF2AAPgz58/f/4CbAD8+fPnz1+ADYA/f/78+QuwAxgAf/78+fMXYAPgz58/f/4C7AAGwJ8/f/78BdgA+PPnz5+/ADuAAfDnz58/fwE2AP78+fPnL8AOYAD8+fPnz1+ADYA/f/78+QuwAfDnz58/fwF2AAPgz58/f/4CbAD8+fPnz1+AHcAA+PPnz5+/ABsAf/78+fMXYAcwAP78+fPnL8AGwJ8/f/78BdgBDIA/f/78+QuwAfDnz58/fwE2AP78+fPnL8AOYAD8+fPnz1+ADYA/f/78+QuwAxgAf/78+fMXYAPgz58/f/4C7AAGwJ8/f/78BdgA+PPnz5+/ADuAAfDnz58/fwE2AP78+fPnL8AOYAD8+fPnL8AOYAD8+fPnz1+ADYA/f/78+QuwAxgAf/78+fMXYAPgz58/f/4C7AAGwJ8/f/78BdgA+PPnz5+/ADuAAfDnz58//xxgH8gH4s+fP3/+/SfABsCfP3/+/AXYAPjz58+fvwA7gAHw58+fP38BNgD+/Pnz5y/ADmAA/Pnz589fgA2AP3/+/PkLsAMYAH/+/PnzF2AD4M+fP3/+AuwABsCfP3/+/AXYAPjz58+fvwAbAH/+/PnzF2AHMAD+/Pnz5y/ABsCfP3/+/AXYAQyAP3/+/PkLsAHw58+fP38BdgAD4M+fP3/+AmwA/Pnz589fgB3AAPjz58+fvwAbAH/+/PnzF2AD4M+fP3/+AuwABsCfP3/+/AXYAPjz58+fvwA7gAHw58+fP38BNgD+/Pnz5y/ADmAA/Pnz589fgA2AP3/+/PkLsAMYAH/+/PnzF2AD4M+fP3/+AmwA/Pnz589fgB3AAPjz58+fvwAbAH/+/PnzF2AHMAD+/Pnz5y/ABsCfP3/+/AXYAQyAP3/+/PkLsAHw58+fP38BdgAD4M+fP3/+AmwA/Pnz589fgA2AP3/+/PkLsAMYAH/+/PnzF2AD4M+fP3/+AuwABsCfP3/+/AXYAPjz58+fvwA7gAHw58+fP38BNgD+/Pnz5y/ADmAA/Pnz589fgA2AP3/+/PkLsAHw58+fP38BdgAD4M+fP3/+AmwA/Pnz589fgB3AAPjz58+fvwAbAH/+/PnzF2AHMAD+/Pnz5y/ABsCfP3/+/AXYAQyAP3/+/PkLsAHw58+fP38BdgAD4M+fP38BdgAD4M+fP3/+AmwA/Pnz589fgB3AAPjz58+fvwAbAH/+/PnzF2AHMAD+/Pnz5y/ABsCfP3/+/AXYAQyAP3/+/PnnAPtAPhB//vz58+8/ATYA/vz58+cvwAbAnz9//vwF2AEMgD9//vz5C7AB8OfPnz9/AXYAA+DPnz9//gJsAPz58+fPX4AdwAD48+fPn78AGwB//vz58xdgBzAA/vz58+cvwAbAnz9//vwF2AD48+fPn78AO4AB8OfPnz9/ATYA/vz58+cvwA5gAPz58+fPX4ANgD9//vz5C7ADGAB//vz58xdgA+DPnz9//gLsAAbAnz9//vwF2AD48+fPn78AGwB//vz58xdgBzAA/vz58+cvwAbAnz9//vwF2AEMgD9//vz5C7AB8OfPnz9/AXYAA+DPnz9//gJsAPz58+fPX4AdwAD48+fPn78AGwB//vz58xdgA+DPnz9//gLsAAbAnz9//vwF2AD48+fPn78AO4AB8OfPnz9/ATYA/vz58+cvwA5gAPz58+fPX4ANgD9//vz5C7ADGAB//vz58xdgA+DPnz9//gJsAPz58+fPX4AdwAD48+fPn78AGwB//vz58xdgBzAA/vz58+cvwAbAnz9//vwF2AEMgD9//vz5C7AB8OfPnz9/AXYAA+DPnz9//gJsAPz58+fPX4ANgD9//vz5C7ADGAB//vz58xdgA+DPnz9//gLsAAbAnz9//vwF2AD48+fPn78AO4AB8OfPnz9/ATYA/vz58+cvwA5gAPz58+fPX4ANgD9//vz5C7ADGAB//vz5C7ADGAB//vz58xdgA+DPnz9//gLsAAbAnz9//vwF2AD48+fPn78AO4AB8OfPnz9/ATYA/vz58+cvwA5gAPz58+fPPwfYB/KB+PPnz59//wmwAfDnz58/fwE2AP78+fPnL8AOYAD8+fPnz1+ADYA/f/78+QuwAxgAf/78+fMXYAPgz58/f/4C7AAGwJ8/f/78BdgA+PPnz5+/ADuAAfDnz58/fwE2AP78+fPnL8AGwJ8/f/78BdgBDIA/f/78+QuwAfDnz58/fwF2AAPgz58/f/4CbAD8+fPnz1+AHcAA+PPnz5+/ABsAf/78+fMXYAcwAP78+fPnL8AGwJ8/f/78BdgA+PPnz5+/ADuAAfDnz58/fwE2AP78+fPnL8AOYAD8+fPnz1+ADYA/f/78+QuwAxgAf/78+fMXYAPgz58/f/4C7AAGwJ8/f/78BdgA+PPnz5+/ABsAf/78+fMXYAcwAP78+fPnL8AGwJ8/f/78BdgBDIA/f/78+QuwAfDnz58/fwF2AAPgz58/f/4CbAD8+fPnz1+AHcAA+PPnz5+/ABsAf/78+fMXYAPgz58/f/4C7AAGwJ8/f/78BdgA+PPnz5+/ADuAAfDnz58/fwE2AP78+fPnL8AOYAD8+fPnz1+ADYA/f/78+QuwAxgAf/78+fMXYAPgz58/f/4CbAD8+fPnz1+AHcAA+PPnz5+/ABsAf/78+fMXYAcwAP78+fPnL8AGwJ8/f/78BdgBDIA/f/78+QuwAfDnz58/fwF2AAPgz58/f/4CbAD8+fPnz1+AHcAA+PPnz1+AHcAA+PPnz5+/ABsAf/78+fMXYAcwAP78+fPnL8AGwJ8/f/78BdgBDIA/f/78+QuwAfDnz58/fwF2AAPgz58/f/45wD6QD8SfP3/+/PtPgA2AP3/+/PkLsAHw58+fP38BdgAD4M+fP3/+AmwA/Pnz589fgB3AAPjz58+fvwAbAH/+/PnzF2AHMAD+/Pnz5y/ABsCfP3/+/AXYAQyAP3/+/PkLsAHw58+fP38BNgD+/Pnz5y/ADmAA/Pnz589fgA2AP3/+/PkLsAMYAH/+/PnzF2AD4M+fP3/+AuwABsCfP3/+/AXYAPjz58+fvwA7gAHw58+fP38BNgD+/Pnz5y/ABsCfP3/+/AXYAQyAP3/+/PkLsAHw58+fP38BdgAD4M+fP3/+AmwA/Pnz589fgB3AAPjz58+fvwAbAH/+/PnzF2AHMAD+/Pnz5y/ABsCfP3/+/AXYAPjz58+fvwA7gAHw58+fP38BNgD+/Pnz5y/ADmAA/Pnz589fgA2AP3/+/PkLsAMYAH/+/PnzF2AD4M+fP3/+AuwABsCfP3/+/AXYAPjz58+fvwAbAH/+/PnzF2AHMAD+/Pnz5y/ABsCfP3/+/AXYAQyAP3/+/PkLsAHw58+fP38BdgAD4M+fP3/+AmwA/Pnz589fgB3AAPjz58+fvwAbAH/+/PnzF2AD4M+fP3/+AuwABsCfP3/+/AXYAPjz58+fvwA7gAHw58+fP38BNgD+/Pnz5y/ADmAA/Pnz589fgA2AP3/+/PkLsAMYAH/+/PnzF2AD4M+fP3/+AuwABsCfP3/+AuwABsCfP3/+/AXYAPjz58+fvwA7gAHw58+fP38BNgD+/Pnz5y/ADmAA/Pnz589fgA2AP3/+/PkLsAMYAH/+/PnzzwH2gXwg/vz58+fffwJsAPz58+fPX4ANgD9//vz5C7ADGAB//vz58xdgA+DPnz9//gLsAAbAnz9//vwF2AD48+fPn78AO4AB8OfPnz9/ATYA/vz58+cvwA5gAPz58+fPX4ANgD9//vz5C7AB8OfPnz9/AXYAA+DPnz9//gJsAPz58+fPX4AdwAD48+fPn78AGwB//vz58xdgBzAA/vz58+cvwAbAnz9//vwF2AEMgD9//vz5C7AB8OfPnz9/ATYA/vz58+cvwA5gAPz58+fPX4ANgD9//vz5C7ADGAB//vz58xdgA+DPnz9//gLsAAbAnz9//vwF2AD48+fPn78AO4AB8OfPnz9/ATYA/vz58+cvwAbAnz9//vwF2AEMgD9//vz5C7AB8OfPnz9/AXYAA+DPnz9//gJsAPz58+fPX4AdwAD48+fPn78AGwB//vz58xdgBzAA/vz58+cvwAbAnz9//vwF2AD48+fPn78AO4AB8OfPnz9/ATYA/vz58+cvwA5gAPz58+fPX4ANgD9//vz5C7ADGAB//vz58xdgA+DPnz9//gLsAAbAnz9//vwF2AD48+fPn78AGwB//vz58xdgBzAA/vz58+cvwAbAnz9//vwF2AEMgD9//vz5C7AB8OfPnz9/AXYAA+DPnz9//gJsAPz58+fPX4AdwAD48+fPn78AGwB//vz58xdgBzAA/vz58xdgBzAA/vz58+cvwAbAnz9//vwF2AEMgD9//vz5C7AB8OfPnz9/AXYAA+DPnz9//gJsAPz58+fPX4AdwAD48+fPn398F8+Ey2qf8/qtAAAAAElFTkSuQmCC');
}
