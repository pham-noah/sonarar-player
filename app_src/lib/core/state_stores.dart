library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../context/places.dart';
import '../core/prefs.dart';
import '../library/bonds.dart';
import '../library/exclusions.dart' show JsonMapStore;
import '../library/play_log.dart';
import '../library/playlist_loader.dart';
import '../library/playlists.dart';
import '../theme/personalization_store.dart';
import '../theme/theme_preset.dart';
import '../library/tag_overrides.dart';
import '../playback/loop_points.dart';
import '../player/snapshot.dart';
import '../rules/context_rules.dart' show ContextRules;
import '../rules/rules_loader.dart';

class StateStores {
  StateStores._(this.directory)
      : snapshot = SnapshotStore(directory: directory),
        loopPoints = LoopPointStore(File('$directory/loop_points.json')),
        exclusions = JsonMapStore<bool>(
          File('$directory/excluded.json'),
          encode: (v) => v,
          decode: (v) => v is bool ? v : null,
        ),
        bookmarks = JsonMapStore<Duration>(
          File('$directory/bookmarks.json'),
          encode: (v) => v.inMilliseconds,
          decode: (v) => v is num ? Duration(milliseconds: v.toInt()) : null,
        ),
        favorites = JsonMapStore<bool>(
          File('$directory/favorites.json'),
          encode: (v) => v,
          decode: (v) => v is bool ? v : null,
        ),
        prefs = PrefsStore(File('$directory/prefs.json')),
        personalization = PersonalizationStore(File('$directory/personalize.json')),
        places = PlaceStore(File('$directory/places.json')),
        tags = TagOverrideStore(File('$directory/tag_overrides.json')),
        bonds = BondStore(File('$directory/bonds.json')),

        themePresets = ThemePresetStore(File('$directory/theme_presets.json')),
        rules = ContextRulesLoader(file: File('$directory/rules.json')),
        playlists = PlaylistLoader(
          store: PlaylistStore(File('$directory/playlists.json')),
        ),
        playLog = PlayLog(File('$directory/plays.jsonl'));

  static Future<StateStores> open({String? libraryRoot}) async {
    final dir = await _resolveDirectory(libraryRoot);
    return StateStores._(dir);
  }

  final String directory;

  final SnapshotStore snapshot;
  final LoopPointStore loopPoints;
  final JsonMapStore<bool> exclusions;
  final JsonMapStore<Duration> bookmarks;
  final JsonMapStore<bool> favorites;
  final PrefsStore prefs;
  final PersonalizationStore personalization;
  final PlaceStore places;
  final TagOverrideStore tags;
  final BondStore bonds;
  final ThemePresetStore themePresets;
  final ContextRulesLoader rules;
  final PlaylistLoader playlists;
  final PlayLog playLog;

  static Future<String> _resolveDirectory(String? libraryRoot) async {
    final base = libraryRoot;
    if (base != null && base.isNotEmpty) {
      final dir = Directory('$base/.state');
      try {
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir.path;
      } catch (_) {
      }
    }
    if (Platform.isAndroid) {
      final dir = await getApplicationSupportDirectory();
      return dir.path;
    }
    return '.';
  }

  Future<void> saveLists({
    required Set<String> excludedIds,
    required Map<String, Duration> bookmarks,
    required Set<String> favoriteIds,
  }) async {
    await _guard(() => exclusions.save({for (final id in excludedIds) id: true}));
    await _guard(
      () => this.bookmarks.save({for (final e in bookmarks.entries) e.key: e.value}),
    );
    await _guard(() => favorites.save({for (final id in favoriteIds) id: true}));
  }

  Future<void> saveListsNow(PlaylistsView lists) =>
      _guard(() => playlists.save(lists));

  Future<void> savePrefs(AppPrefs next) => _guard(() => prefs.save(next));

  Future<void> savePlaces(PlaceBook book) => _guard(() => places.save(book));

  Future<void> savePlaylists(PlaylistsView lists) =>
      _guard(() => playlists.save(lists));

  Future<void> saveTags(TagOverrides overrides) =>
      _guard(() => tags.save(overrides));

  Future<void> saveBonds(BondState state) => _guard(() => bonds.save(state));

  Future<void> saveRules(ContextRules rules) =>
      _guard(() => this.rules.save(rules));

  Future<void> saveLoopPoints(Map<String, LoopPoints> points) =>
      _guard(() => loopPoints.save(points));

  Future<void> saveSnapshot(PlaybackSnapshot snap) =>
      _guard(() => snapshot.save(snap));

  static Future<void> _guard(Future<void> Function() write) async {
    try {
      await write();
    } catch (_) {
    }
  }
}
