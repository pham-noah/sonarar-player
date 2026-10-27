library;

import 'package:flutter/foundation.dart';

import '../art/art_focus.dart';
import '../art/skin_art.dart';
import '../library/bonds.dart';
import '../library/exclusions.dart';
import '../library/playlists.dart';
import '../library/play_log.dart';
import '../library/tag_overrides.dart';
import '../library/track.dart';
import '../library/weather_variants.dart';
import '../player/queue.dart';
import '../player/snapshot.dart';
import '../context/places.dart';
import '../library/dynamic_playlist.dart';
import '../library/dynamic_mix_resolver.dart';
import '../rules/context_change.dart';
import '../rules/context_rules.dart';
import '../rules/place_rules.dart';
import '../player/queue_mode.dart';
import '../rules/rules_engine.dart';
import '../theme/layout.dart';
import '../theme/skin.dart';
import '../theme/theme_preset.dart';
import '../theme/skin_policy.dart';

class AppState extends ChangeNotifier {
  AppState();

  final SkinPolicy _policy = const SkinPolicy();

  final RulesEngine _engine = const RulesEngine();
  final FeedbackMemory _memory = FeedbackMemory();

  RulesEngine get engine => _engine;

  FeedbackMemory get memory => _memory;

  void forgetLearned(String trackId, ContextBand band) {
    _memory.forget(trackId, band);
    notifyListeners();
  }

  int forgetAllLearned() {
    final n = _memory.learned.length;
    _memory.clear();
    notifyListeners();
    return n;
  }

  final ExclusionList _excluded = ExclusionList();

  final BookmarkList _bookmarks = BookmarkList();

  final FavoritesList _favorites = FavoritesList();

  PlaylistList _playlists = PlaylistList();

  List<Playlist> _derived = const [];
  List<Playlist> get derivedPlaylists => _derived;

  void setDerivedPlaylists(List<Playlist> lists) {
    _derived = List.unmodifiable(lists);
    notifyListeners();
  }

  List<Playlist> get allPlaylists => [..._derived, ..._playlists.all];

  void setPlaylists(PlaylistList lists) {
    _playlists = lists;
    notifyListeners();
  }

  static const int kDynamicMixLimit = 60;

  Playlist? dynamicMix() => _dynamicCache ??= _computeDynamicMix();

  Playlist? _computeDynamicMix() {
    final ctx = _playlistCtx;
    if (ctx == null || _library.isEmpty) return null;
    return _mixResolver.resolve((
      context: ctx,
      library: _library,
      playlists: allPlaylists,
      situationIds: _situationIds,
      bandListName: _currentSituation,
      rules: _contextRules,
      contextEnabled: _contextEnabled,
      honourClock: _clockOn,
      sleeping: _sleeping,
    ));
  }

  static const _mixResolver = DynamicMixResolver();

  List<Track> _contextMixTracks() {
    final mix = dynamicMix();
    if (mix == null) return const [];
    final byId = {for (final t in _library) t.id: t};
    return [
      for (final id in mix.trackIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  QueueSource get source => _source;

  QueueSource _source = QueueSource.automatic;

  String? get playingFrom => _playingFrom;
  String? _playingFrom;

  void setPlayingFrom(String? name) => _playingFrom = name;

  QueueMode _mode = QueueMode.dynamic;
  QueueMode get mode => _mode;

  void setMode(QueueMode value) {
    _modeChosen = true;
    if (_mode == value) return;
    _mode = value;
    final q = _queue;
    if (q != null) {
      var live = false;
      switch (value) {
        case QueueMode.fixed:
          final playing = currentTrack;
          if (playing != null) {
            q.replaceSource([playing], keepPlaying: true);
          }
        case QueueMode.dynamic:

          final resolved = _contextMixTracks();
          final keep = currentTrack;
          if (keep == null) break;
          if (resolved.isNotEmpty) {
            live = true;
            q.replaceSource(
              queueForPlayedTrack(track: keep, mode: QueueMode.dynamic, contextMix: resolved),
              keepPlaying: true,
            );
          } else {
            q.replaceSource([keep], keepPlaying: true);
          }
      }
      _source = live ? QueueSource.live : QueueSource.fixed;
    }
    notifyListeners();
  }

  void toggleMode() =>
      setMode(_mode == QueueMode.dynamic ? QueueMode.fixed : QueueMode.dynamic);

  bool _refillWhenQueueEnds = false;
  bool get refillWhenQueueEnds => _refillWhenQueueEnds;

  bool _contextEnabled = true;
  bool get contextEnabled => _contextEnabled;

  bool _clockOn = true;
  bool get clockOn => _clockOn;

  bool _learnFromSkips = false;
  bool _autoSkin = false;
  bool _weatherVariants = false;
  bool get learnFromSkips => _learnFromSkips;
  bool get autoSkin => _autoSkin;
  bool get weatherVariantsOn => _weatherVariants;

  void applyOptionalFeatures({
    required bool learn,
    required bool autoSkin,
    required bool variants,
  }) {
    final skinMoved = _autoSkin != autoSkin;
    _learnFromSkips = learn;
    _autoSkin = autoSkin;
    _weatherVariants = variants;
    if (skinMoved) notifyListeners();
  }

  void setClockEnabled(bool value) {
    if (_clockOn == value) return;
    _clockOn = value;
    _invalidateDynamic();
    notifyListeners();
  }

  List<Playlist> get visiblePlaylists => _contextEnabled
      ? allPlaylists
      : [
          for (final p in allPlaylists)
            if (!kContextDrivenListIds.contains(p.id)) p,
        ];

  void applyQueuePrefs({
    required bool defaultMode,
    required bool refill,
    bool contextEnabled = true,
  }) {
    _refillWhenQueueEnds = refill;

    if (_contextEnabled != contextEnabled) {
      _contextEnabled = contextEnabled;
      _invalidateDynamic();
    }
    if (!_modeChosen) {
      _mode = defaultMode ? QueueMode.dynamic : QueueMode.fixed;

      return;
    }
    notifyListeners();
  }

  bool _modeChosen = false;

  void restoreMode(QueueMode mode) {
    _mode = mode;
    _modeChosen = true;
  }

  Track? get variantSwappedFrom => _variantSwappedFrom;
  Track? _variantSwappedFrom;

  String? get _currentSituation => situationVariantTag(

        sky: _playlistCtx?.sky ?? Sky.unknown,
        whereabouts: _playlistCtx?.whereabouts ?? Whereabouts.unknown,
        sleeping: _sleeping,
        band: _playlistCtx?.band,
      );

  List<String> get _situationIds {
    final tag = _currentSituation;
    if (tag == null) return const [];
    return _playlists.byId('v_$tag')?.trackIds ?? const [];
  }

  Playlist? _dynamicCache;

  void _invalidateDynamic() {
    _dynamicCache = null;
    _refreshDynamicInDerived();
  }

  void _refreshDynamicInDerived() {
    if (_derived.isEmpty) return;
    final mix = dynamicMix();
    if (mix == null) return;
    _derived = List.unmodifiable([
      mix,
      ..._derived.where((p) => p.id != kDynamicId),
    ]);
  }

  bool switchToContextQueue() {
    final ctx = _playlistCtx;
    if (ctx == null) return false;

    final base = _engine.playlist(
      _library,
      ctx,
      excluded: _excluded.ids,
    );
    if (base.isEmpty) return false;

    // ignore: avoid_print
    print('[Sonarar][QUEUE] context switch admitted ${base.length} '
        'of ${_library.length} (excluded=${_excluded.ids.length})');

    _probeQueue('contextSwitch', base.length);
    _queue = PlayQueue(source: base, shuffle: _queue?.isShuffled ?? false);

    _source = QueueSource.live;
    _ended = false;
    notifyListeners();
    return true;
  }

  bool playPlaylistRef(String ref) {
    final want = ref.trim().toLowerCase();
    for (final p in allPlaylists) {
      if (p.id == ref || p.name.toLowerCase() == want) return playPlaylist(p);
    }
    return false;
  }

  TagOverrides _tags = TagOverrides();
  TagOverrides get tagOverrides => _tags;

  List<Track> _rawLibrary = const [];
  List<Track> get rawLibrary => _rawLibrary;

  void setTagOverrides(TagOverrides overrides) {
    _tags = overrides;
    _reapplyOverrides();
    notifyListeners();
  }

  void setTagOverride(String trackId, TagField field, String value) {
    _tags.set(trackId, field, value);
    _reapplyOverrides();
    notifyListeners();
  }

  void clearTagOverride(String trackId, TagField field) {
    _tags.clearField(trackId, field);
    _reapplyOverrides();
    notifyListeners();
  }

  void clearAllTagOverrides() {
    _tags.clearAll();
    _reapplyOverrides();
    notifyListeners();
  }

  void _reapplyOverrides() {
    if (_rawLibrary.isEmpty) return;
    _library = List<Track>.unmodifiable(_tags.applyAll(_rawLibrary));
  }

  BondState _bondState = BondState();
  BondState get bondState => _bondState;

  void setBondState(BondState state) {
    _bondState = state;
    notifyListeners();
  }

  void resetBonds({DateTime? at}) {
    _bondState.config = _bondState.config.withResetAt(at ?? DateTime.now());
    notifyListeners();
  }

  bool setBondNote(String trackId, String text, {required int rank}) {
    final ok = _bondState.setNote(trackId, text, rank: rank);
    if (ok) notifyListeners();
    return ok;
  }

  ContextRules _contextRules = ContextRules.empty;
  ContextRules get contextRules => _contextRules;

  ManualMode? _manualMode;

  ManualMode? get manualMode => _manualMode;

  ContextBand? _manualBandAtEntry;

  void setContextRules(ContextRules rules) {
    _writtenRules = rules;
    _rebuildRules();
  }

  ContextRules _writtenRules = ContextRules.empty;
  ContextRules get writtenRules => _writtenRules;

  PlaceBook _places = PlaceBook.empty;
  PlaceBook get places => _places;

  void setPlaces(PlaceBook book) {
    _places = book;
    _rebuildRules();
  }

  void _rebuildRules() {
    _contextRules = withPlaceRules(_writtenRules, _places);
    _invalidateDynamic();

    _derivedFrom = null;
    final ctx = _playlistCtx;
    if (ctx != null) {
      _applyPlaylistContext(ctx, rule: _contextRules.firstMatch(ctx));
    }
    notifyListeners();
  }

  ContextRule? get activeRule {
    final ctx = _playlistCtx;
    if (ctx == null) return null;
    return _contextRules.firstMatch(ctx);
  }

  int? get activeRulePlaylistSize {
    final ref = activeRule?.playlist;
    if (ref == null) return null;
    final want = ref.trim().toLowerCase();
    for (final p in allPlaylists) {
      if (p.id == ref || p.name.toLowerCase() == want) return p.length;
    }
    return null;
  }

  void enterMode(ManualMode mode) {
    final base = _lastContext;
    if (base == null) return;
    _manualMode = mode;
    _manualBandAtEntry = base.band;
    notifyListeners();
    updateContext(base);
  }

  void exitMode() {
    if (_manualMode == null) return;
    _manualMode = null;
    _manualBandAtEntry = null;
    _derivedFrom = null;
    notifyListeners();
    final base = _lastContext;
    if (base != null) updateContext(base);
  }

  bool playPlaylist(Playlist playlist) {
    final ids = playlist.trackIds.toSet();
    final tracks = _library.where((t) => ids.contains(t.id)).toList();
    if (tracks.isEmpty) {
      // ignore: avoid_print
      print('[Sonarar][PLAYPRESS] "${playlist.name}" has ${ids.length} ids, '
          'NONE of them in the ${_library.length}-track library');
      return false;
    }

    final byId = {for (final t in tracks) t.id: t};
    final ordered = [
      for (final id in playlist.trackIds)
        if (byId[id] != null) byId[id]!,
    ];
    if (ordered.isEmpty) return false;

    _probeQueue('playPlaylist', ordered.length);
    _queue = PlayQueue(source: ordered, shuffle: _queue?.isShuffled ?? false);

    _source = playlist.id == kDynamicId ? QueueSource.live : QueueSource.fixed;

    _playingFrom = playlist.id == kDynamicId ? null : playlist.name;
    _ended = false;
    notifyListeners();
    return true;
  }

  bool playDynamic() {
    final mix = dynamicMix();
    if (mix == null) return false;
    final ok = playPlaylist(mix);
    if (ok) _source = QueueSource.live;
    return ok;
  }

  bool swapToVariant(Track target) {
    final q = _queue;
    if (q == null) return false;
    final from = currentTrack;
    if (from == null || from.id == target.id) return false;
    final moved = q.replaceCurrent(target);
    if (!moved) return false;
    _variantSwappedFrom = from;
    notifyListeners();
    return true;
  }

  bool swapBack() {
    final from = _variantSwappedFrom;
    if (from == null) return false;
    final q = _queue;
    if (q == null) return false;
    if (!q.replaceCurrent(from)) return false;
    _variantSwappedFrom = null;
    notifyListeners();
    return true;
  }

  ExclusionIds get exclusions => _excluded;
  BookmarkMarks get bookmarks => _bookmarks;
  FavoritesView get favorites => _favorites;
  PlaylistsView get playlists => _playlists;

  bool toggleFavorite(String trackId) {
    final liked = _favorites.toggle(trackId);
    notifyListeners();
    return liked;
  }

  bool addFavorite(String trackId) {
    final added = _favorites.add(trackId);
    if (added) notifyListeners();
    return added;
  }

  void setBookmark(String trackId, Duration position) {
    _bookmarks.set(trackId, position);
    notifyListeners();
  }

  int pruneToLibrary(Set<String> liveLibraryIds) {
    final gone = _excluded.prune(liveLibraryIds) +
        _bookmarks.prune(liveLibraryIds) +
        _favorites.prune(liveLibraryIds);
    if (gone > 0) notifyListeners();
    return gone;
  }

  void restoreTrackSets({
    required Iterable<String> excludedIds,
    required Map<String, Duration> bookmarks,
    required Iterable<String> favoriteIds,
  }) {
    for (final id in excludedIds) {
      _excluded.exclude(id);
    }
    for (final e in bookmarks.entries) {
      _bookmarks.set(e.key, e.value);
    }
    for (final id in favoriteIds) {
      _favorites.add(id);
    }
    notifyListeners();
  }

  Playlist createPlaylist(String name, {String? id, List<String>? trackIds}) {
    final made = _playlists.create(name, id: id, trackIds: trackIds);
    notifyListeners();
    return made;
  }

  Playlist ensurePlaylist(String name) {
    final made = _playlists.ensure(name);
    notifyListeners();
    return made;
  }

  void deletePlaylist(String playlistId) {
    _playlists.delete(playlistId);
    notifyListeners();
  }

  bool addTrackToPlaylist(Playlist playlist, String trackId) {
    final added = _playlists.addTrack(playlist, trackId);
    notifyListeners();
    return added;
  }

  bool removeTrackFromPlaylist(Playlist playlist, String trackId) {
    final removed = playlist.remove(trackId);
    notifyListeners();
    return removed;
  }

  void toggleExclusion(String trackId) {
    final was = _excluded.contains(trackId);
    _excluded.toggle(trackId);
    if (was == _excluded.contains(trackId)) return;
    _rebuildQueueKeepingCurrent();
    notifyListeners();
  }

  void toggleBookmark(Track track, Duration position) {
    if (_bookmarks.has(track.id)) {
      _bookmarks.remove(track.id);
    } else {
      _bookmarks.set(track.id, position);
    }
    notifyListeners();
  }

  void _rebuildQueueKeepingCurrent() {
    final ctx = _playlistCtx;
    final q = _queue;
    if (q == null || ctx == null) return;

    final base = _engine.playlist(
      _library,
      ctx,
      excluded: _excluded.ids,
    );

    if (base.isEmpty) return;

    q.replaceSource(base, keepPlaying: true);
  }

  bool playNow(Track track) {
    final q = _queue;
    if (q == null) return false;

    final at = q.order.indexWhere((t) => t.id == track.id);
    if (at < 0) return false;

    q.jumpTo(track.id);
    notifyListeners();
    return true;
  }

  bool playTrack(Track track) {
    final q = _queue;

    final resolved = mode == QueueMode.dynamic
        ? _contextMixTracks()
        : const <Track>[];

    final live = mode == QueueMode.dynamic && resolved.isNotEmpty;
    final next = queueForPlayedTrack(
      track: track,
      mode: live ? QueueMode.dynamic : QueueMode.fixed,
      contextMix: resolved,
    );
    _queue = PlayQueue(source: next, shuffle: q?.isShuffled ?? false);
    if (next.isNotEmpty) _queue!.jumpTo(track.id);
    _source = live ? QueueSource.live : QueueSource.fixed;

    _playingFrom = null;
    _ended = false;
    notifyListeners();
    return true;
  }

  List<Track> _library = const [];
  List<Track> get library => _library;

  PlaylistContext? _playlistCtx;

  PlaylistContext? _derivedFrom;

  bool _sleeping = false;

  final Set<String> _sleepAdded = {};

  bool get sleeping => _sleeping;

  void setSleeping(bool value) {
    if (_sleeping == value) return;
    _sleeping = value;

    _lastSituationTag = null;
    _applySituationVariants();
    notifyListeners();
  }

  String? _lastSituationTag;

  String? get situationTag => _lastSituationTag;
  PlaylistContext? get playlistContext => _playlistCtx;

  SkinPreference _pref = const SkinPreference();
  PlayContext? _lastContext;

  Skin _skin = kSkinAbyss;

  Skin get skin => _skin;

  Skin get uiSkin => presentation.asSkin(_skin);

  final ValueNotifier<Skin> skinListenable = ValueNotifier<Skin>(kSkinAbyss);

  set _skinValue(Skin next) {
    _skin = next;
    skinListenable.value = next;
    _presentationCache = null;
  }

  LayoutKind _layoutId = LayoutKind.persona;
  LayoutKind get layoutId => _layoutId;

  int _paletteIndex = 0;
  int get paletteIndex => _paletteIndex;

  void setLayout(LayoutKind id, {int paletteIndex = 0}) {
    if (_layoutId == id && _paletteIndex == paletteIndex) return;
    _layoutId = id;
    _paletteIndex = paletteIndex;
    _presentationCache = null;
    notifyListeners();
  }

  Presentation? _presentationCache;

  Presentation get presentation =>
      _presentationCache ??= presentationFor(_layoutId, _skin,
          paletteIndex: _paletteIndex);

  LayoutPalette get palette => presentation.palette;

  MotionSpec get motion => presentation.motion;

  ScreenLayout get arrangement => presentation.arrangement;

  Skin get languageSkin => _languageSkin ?? _skin;

  Skin? _languageSkin;

  ThemePreset? _preset;
  ThemePreset? get preset => _preset;

  List<ThemePreset> _userPresets = const [];
  List<ThemePreset> get userPresets => _userPresets;

  List<ThemePreset> get allPresets => [...kBuiltInPresets, ..._userPresets];

  void setUserPresets(List<ThemePreset> presets) {
    _userPresets = List.unmodifiable(presets);
    notifyListeners();
  }

  void applyPreset(ThemePreset preset) {
    _preset = preset;
    _skinValue = skinFor(preset.skinId);
    _languageSkin = preset.languageSkinId == null
        ? null
        : skinFor(preset.effectiveLanguageSkin);

    _artSkinOverride = preset.artSkinId;
    _artIndex = 0;
    final layout = _layoutByName(preset.layoutId);
    if (layout != null && layout != _layoutId) {
      _layoutId = layout;
      _presentationCache = null;

      _paletteIndex = 0;
    }
    notifyListeners();
  }

  static LayoutKind? _layoutByName(String? raw) {
    if (raw == null) return null;
    for (final k in LayoutKind.values) {
      if (k.name == raw) return k;
    }
    return null;
  }

  void clearPreset() {
    _preset = null;
    _languageSkin = null;
    _artSkinOverride = null;
    followContextAgain();
  }

  SkinId? _artSkinOverride;
  SkinId? get artSkinOverride => _artSkinOverride;

  void setArtSkin(SkinId? id) {
    _artSkinOverride = id;
    _artIndex = 0;
    notifyListeners();
  }

  void setLanguageSkin(SkinId? id) {
    _languageSkin = id == null ? null : skinFor(id);
    notifyListeners();
  }

  SkinPreference get preference => _pref;

  void updateContext(PlayContext incoming) {
    final clockBand = incoming.band;
    if (_manualMode != null &&
        _manualBandAtEntry != null &&
        clockBand != _manualBandAtEntry) {
      _manualMode = null;
      _manualBandAtEntry = null;
    }

    final ctx = _manualMode == null
        ? incoming
        : PlayContext(
            band: _manualMode!.band,
            localHour: incoming.localHour,
            mode: _manualMode,
            placeId: incoming.placeId,

            sky: incoming.sky,
            whereabouts: incoming.whereabouts,
          );

    final resolved =
        _policy.resolve(ctx: ctx, pref: _pref, previousCtx: _lastContext);

    final bandChanged = _lastContext != null && _lastContext!.band != ctx.band;
    if (bandChanged && _preset == null) _pref = const SkinPreference();

    _lastContext = ctx;

    final playlistCtx = PlaylistContext(
      band: ctx.band,

      sky: ctx.sky,
      whereabouts: ctx.whereabouts,
      localHour: ctx.localHour,
      mode: ctx.mode,

      placeId: ctx.placeId,
    );
    _playlistCtx = playlistCtx;
    final rule = _contextRules.firstMatch(playlistCtx, honourClock: _clockOn);

    final nextId = _preset != null
        ? _preset!.skinId
        : ((!_clockOn || !_autoSkin)
            ? _skin.id
            : ((!_pref.isManual && rule?.theme != null)
                ? rule!.theme!
                : resolved));
    final next = skinFor(nextId);
    if (next.id != _skin.id) {
      _skinValue = next;
      _artIndex = 0;
      notifyListeners();
    }

    _applyPlaylistContext(playlistCtx, rule: rule);
  }

  void _applyPlaylistContext(PlaylistContext ctx, {ContextRule? rule}) {
    _playlistCtx = ctx;

    _invalidateDynamic();

    if (_library.isEmpty) return;

    if (_queueRestored && _source != QueueSource.live) {
      _queueRestored = false;
      _derivedFrom = ctx;
      notifyListeners();
      return;
    }
    _queueRestored = false;

    if (!contextChanged(_derivedFrom, ctx)) {
      return;
    }
    _derivedFrom = ctx;

    final ref = rule?.playlist;
    if (ref != null && _source != QueueSource.live) {
      final want = ref.trim().toLowerCase();
      for (final p in allPlaylists) {
        if (p.id == ref || p.name.toLowerCase() == want) {
          if (_makeQueue(p)) return;
          break;
        }
      }
    }

    final keep = currentTrack?.id;
    final ordered = _source == QueueSource.live
        ? _contextMixTracks()
        : _engine.playlist(_library, ctx,
            excluded: _excluded.ids);
    if (ordered.isEmpty) {
      if (_source == QueueSource.live) {
        final keep = currentTrack;
        _queue = PlayQueue(
          source: keep == null ? const [] : [keep],
          shuffle: _queue?.isShuffled ?? false,
        );
        notifyListeners();
      }
      return;
    }

    _probeQueue('situationReplan', ordered.length);
    final q = PlayQueue(source: ordered, shuffle: _queue?.isShuffled ?? false);
    if (keep != null) q.jumpTo(keep);
    _queue = q;
    _applySituationVariants();
    notifyListeners();
  }

  void _applySituationVariants() {
    final q = _queue;
    if (q == null) return;

    if (_sleeping) _applySleepOverride(q);
    if (!_sleeping) _removeSleepOverride(q);

    if (_source != QueueSource.live) return;
    if (!_weatherVariants) return;
    final situationNow = situationVariantTag(

      sky: _playlistCtx?.sky ?? Sky.unknown,
      whereabouts: _playlistCtx?.whereabouts ?? Whereabouts.unknown,
      sleeping: _sleeping,

      band: _playlistCtx?.band,
    );
    if (situationNow == _lastSituationTag) return;
    _lastSituationTag = situationNow;
    if (situationNow == null) return;

    final plan = planWeatherVariants(
      queue: q.order,
      currentIndex: q.index,
      library: _library,
      sky: _playlistCtx?.sky ?? Sky.unknown,
      whereabouts: _playlistCtx?.whereabouts ?? Whereabouts.unknown,
    );

    final additions = <Track>[
      ...plan.add,
      ..._seededVariantAdditions(queue: q, tag: situationNow),
    ];

    if (plan.replaceCurrent == null && additions.isEmpty) return;

    final from = plan.replacedFrom;

    final replacement = _sleeping ? null : plan.replaceCurrent;
    if (replacement != null) {
      q.replaceCurrent(replacement);
      _variantSwappedFrom = from;
    }

    for (final t in additions) {
      q.append(t);
    }
  }

  void _applySleepOverride(PlayQueue q) {
    final list = _playlists.byId('v_instrumental');
    if (list == null) return;
    final byId = {for (final t in _library) t.id: t};
    final want = [
      for (final id in list.trackIds)
        if (byId[id] != null) byId[id]!,
    ];
    if (want.isEmpty) return;

    final already = {for (final t in q.order) t.id};
    _sleepAdded
      ..clear()
      ..addAll([for (final t in want) if (!already.contains(t.id)) t.id]);

    q.promoteToNext(want);
  }

  void _removeSleepOverride(PlayQueue q) {
    final list = _playlists.byId('v_instrumental');
    if (list == null) return;

    final ids = _sleepAdded.toSet();
    final playing = currentTrack?.id;
    for (final id in ids) {
      if (id == playing) continue;
      q.remove(id);
    }
  }

  List<Track> _seededVariantAdditions({
    required PlayQueue queue,
    required String tag,
  }) {
    final list = _playlists.byId('v_$tag');
    if (list == null) return const [];
    final byId = {for (final t in _library) t.id: t};
    final queued = {for (final t in queue.order) t.id};
    return [
      for (final id in list.trackIds)
        if (!queued.contains(id) && byId[id] != null) byId[id]!,
    ];
  }

  bool _makeQueue(Playlist playlist) {
    final byId = {for (final t in _library) t.id: t};
    final ordered = [
      for (final id in playlist.trackIds)
        if (byId[id] != null) byId[id]!,
    ];
    if (ordered.isEmpty) return false;

    final keep = currentTrack?.id;

    final lead = ordered.length < 3
        ? [...ordered, ..._contextMixTracks()]
        : ordered;

    final q = PlayQueue(source: lead, shuffle: _queue?.isShuffled ?? false);
    if (keep != null) q.jumpTo(keep);
    if (lead.length != ordered.length) {
      // ignore: avoid_print
      print('[Sonarar][QUEUEPROBE] makeQueue: rule list had ${ordered.length}, '
          'built ${lead.length} (library=${_library.length})');
    } else {
      _probeQueue('makeQueue', lead.length);
    }
    _queue = q;
    _ended = false;

    _applySituationVariants();
    notifyListeners();
    return true;
  }

  void recordPlayOutcome({
    required Track track,
    required Duration positionWhenStopped,
    Duration skipThreshold = kSkipThreshold,
  }) {
    final ctx = _playlistCtx;
    if (ctx == null) return;
    final outcome = classifyOutcome(
      positionWhenStopped: positionWhenStopped,
      trackDuration: track.duration,
      skipThreshold: skipThreshold,
    );
    final feedback = switch (outcome) {
      PlayOutcome.completed => SkipFeedback.accepted,
      PlayOutcome.skippedEarly => SkipFeedback.rejected,

      PlayOutcome.skippedLate => SkipFeedback.none,
    };
    if (feedback == SkipFeedback.none) return;

    if (_learnFromSkips) _memory.record(track.id, ctx.band, feedback);
  }

  PlayEvent? playEventFor({
    required Track track,
    required Duration positionWhenStopped,
    DateTime? at,
  }) {
    final ctx = _playlistCtx;
    if (ctx == null) return null;
    return PlayEvent(
      trackId: track.id,
      at: at ?? DateTime.now(),
      band: ctx.band.name,
      positionMs: positionWhenStopped.inMilliseconds,
      durationMs: track.duration.inMilliseconds,

      raining: ctx.raining,
      mode: ctx.mode?.name,
    );
  }

  LibraryFit fitFor(SkinId id) => _engine.fitFor(_library, id);

  void chooseSkinManually(SkinId id) {
    _pref = SkinPreference(manualSkin: id, setAt: DateTime.now());
    final next = skinFor(id);
    if (next.id != _skin.id) {
      _skinValue = next;
      _artIndex = 0;
      notifyListeners();
    }
  }

  void followContextAgain() {
    _pref = const SkinPreference();
    final ctx = _lastContext;
    if (ctx != null) {
      final resolved = _policy.skinForContext(ctx);
      final next = skinFor(resolved);
      if (next.id != _skin.id) {
        _skinValue = next;
        _artIndex = 0;
        notifyListeners();
      }
    }
  }

  int _artIndex = 0;
  int get artIndex => _artIndex;

  SkinArtSet get artSet => artFor(_artSkinOverride ?? _skin.id);

  SkinArt? get art => artSet.atOrNull(_artIndex);

  bool get hasArt => artSet.hasArt;

  void nextArt() {
    _artIndex = artSet.nextIndex(_artIndex);
    notifyListeners();
  }

  void previousArt() {
    _artIndex = artSet.previousIndex(_artIndex);
    notifyListeners();
  }

  void selectArt(int index) {
    if (index < 0 || index >= artSet.length) return;
    _artIndex = index;
    notifyListeners();
  }

  final Map<String, ArtFocus> _artFocus = {};

  ArtFocus get artFocus {
    final piece = art;
    if (piece == null) return ArtFocus.centre;
    return _artFocus[piece.key] ?? piece.focus;
  }

  ArtFocus focusForPiece(SkinArt piece) =>
      _artFocus[piece.key] ?? piece.focus;

  bool hasCustomFocus(SkinArt piece) => _artFocus.containsKey(piece.key);

  void setArtFocus(ArtFocus focus) {
    final piece = art;
    if (piece == null) return;

    if (focus == piece.focus) {
      _artFocus.remove(piece.key);
    } else {
      _artFocus[piece.key] = focus.clamped();
    }
    notifyListeners();
  }

  void resetArtFocus() {
    final piece = art;
    if (piece == null) return;
    if (_artFocus.remove(piece.key) != null) notifyListeners();
  }

  Map<String, ArtFocus> get artFocusMap => Map.unmodifiable(_artFocus);

  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration?> duration = ValueNotifier(null);

  @override
  void dispose() {
    skinListenable.dispose();
    position.dispose();
    duration.dispose();
    super.dispose();
  }

  PlayQueue? _queue;
  PlayQueue? get queue => _queue;

  Track? get currentTrack => _queue?.current;

  void attachLibrary(List<Track> tracks, {PlaybackSnapshot? resume}) {
    _rawLibrary = List<Track>.unmodifiable(tracks);
    _library = List<Track>.unmodifiable(_tags.applyAll(_rawLibrary));

    final List<Track> base;
    if (resume != null && resume.disbanded) {
      base = const <Track>[];
    } else if (_playlistCtx == null && _mode == QueueMode.fixed) {
      final wanted = resume?.trackId;
      final one = wanted == null
          ? const <Track>[]
          : _library.where((t) => t.id == wanted).take(1).toList(growable: false);
      base = one;
    } else {
      final fromContext = _playlistCtx == null
          ? _library
          : _engine.playlist(_library, _playlistCtx!, excluded: _excluded.ids);
      base = fromContext.isEmpty ? _library : fromContext;
    }

    final q = PlayQueue(
      source: base,
      shuffle: resume?.shuffle ?? false,
    );
    _queue = q;

    if (resume != null && !resume.isStale) {
      q.restoreOrder(resume.queueIds);
      q.jumpTo(resume.trackId);
      _queueRestored = resume.queueIds.isNotEmpty;

      final key = resume.artKey;
      if (key.isNotEmpty) {
        final at = artSet.indexOfKey(key);
        if (at >= 0) _artIndex = at;
      }

      _repeat = switch (resume.repeat) {
        'all' => RepeatMode.all,
        'one' => RepeatMode.one,
        _ => RepeatMode.off,
      };

      _artFocus
        ..clear()
        ..addAll(resume.artFocus);
    }

    notifyListeners();
  }

  bool _queueRestored = false;

  void _probeQueue(String site, int len) {
    if (len < 3) {
      // ignore: avoid_print
      print('[Sonarar][QUEUEPROBE] $site built a queue of $len '
          '(library=${_library.length})');
    }
  }

  Playlist? saveQueueAsPlaylist(String name) {
    final q = _queue;
    if (q == null || q.order.isEmpty) return null;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    final made = _playlists.create(
      trimmed,
      trackIds: [for (final t in q.order) t.id],
    );
    notifyListeners();
    return made;
  }

  bool refillFromContext({bool allowLibraryFallback = true}) {
    final ended = currentTrack;
    if (ended == null) return false;
    final inLibrary = {for (final t in _library) t.id: t};

    final mix = dynamicMix();
    var resolved = <Track>[
      if (mix != null)
        for (final id in mix.trackIds)
          if (inLibrary[id] != null && id != ended.id) inLibrary[id]!,
    ];

    if (resolved.isEmpty) {
      if (!allowLibraryFallback) return false;
      final pool = [
        for (final t in _library)
          if (t.id != ended.id) t,
      ]..shuffle();
      resolved = pool.take(kDynamicMixLimit).toList(growable: false);
    }
    if (resolved.isEmpty) return false;
    _queue = PlayQueue(source: [ended, ...resolved], shuffle: false);

    _queue!.jumpTo(resolved.first.id);
    _source = QueueSource.live;
    _ended = false;
    notifyListeners();
    return true;
  }

  PlaybackSnapshot snapshot({int positionMs = 0, double volume = 1.0}) =>
      PlaybackSnapshot(
        trackId: currentTrack?.id ?? '',
        positionMs: positionMs,
        queueIds: _queue?.order.map((t) => t.id).toList(growable: false) ?? const [],
        queueIndex: _queue?.index ?? 0,
        shuffle: _queue?.isShuffled ?? false,
        queueMode: _mode == QueueMode.fixed ? 'fixed' : 'dynamic',
        disbanded: _queue == null,
        artKey: art?.key ?? '',
        savedAt: DateTime.now(),
        volume: volume,
        artFocus: artFocusMap,
      );

  double? _restoredVolume;
  double? get restoredVolume => _restoredVolume;
  void setRestoredVolume(double v) => _restoredVolume = v.clamp(0.0, 1.0);

  RepeatMode _repeat = RepeatMode.off;
  RepeatMode get repeatMode => _repeat;
  bool get isShuffled => _queue?.isShuffled ?? false;

  void cycleRepeat() {
    _repeat = switch (_repeat) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    notifyListeners();
    _repeatChanged();
  }

  void setRepeat(RepeatMode mode) {
    if (_repeat == mode) return;
    _repeat = mode;
    notifyListeners();
    _repeatChanged();
  }

  VoidCallback? onRepeatChanged;

  void _repeatChanged() => onRepeatChanged?.call();

  bool advance({bool automatic = false}) {
    final q = _queue;
    if (q == null) return false;
    _ended = false;
    final moved = q.next(wrap: _repeat == RepeatMode.all);
    notifyListeners();
    return moved != null || !automatic;
  }

  void toggleShuffle() {
    final q = _queue;
    if (q == null) return;
    q.setShuffle(!q.isShuffled);
    notifyListeners();
  }

  bool _ended = false;
  bool get queueEnded => _ended;

  void stopAtEnd() {
    _ended = true;
    notifyListeners();
  }

  AutoAdvance autoAdvanceAction() {
    if (_repeat == RepeatMode.one) return AutoAdvance.replay;
    final decision = advanceFor(
      mode: _mode,
      repeatOne: false,
      repeatAll: _repeat == RepeatMode.all,
      hasNext: _queue != null && _queue!.index + 1 < _queue!.length,
    );
    if (decision == AutoAdvanceMode.stop) return AutoAdvance.stop;
    final q = _queue;
    if (q == null) return AutoAdvance.stop;
    if (_repeat == RepeatMode.all) return AutoAdvance.next;

    return q.index + 1 < q.length ? AutoAdvance.next : AutoAdvance.stop;
  }

  void nextTrack() {
    final q = _queue;
    if (q == null) return;

    q.next(wrap: _repeat == RepeatMode.all);
    notifyListeners();
  }

  void previousTrack() {
    final q = _queue;
    if (q == null) return;
    q.previous();
    notifyListeners();
  }

  bool playTrackElsewhere(Track track) {
    final q = _queue;
    if (q == null) return playTrack(track);
    final inQueue = q.order.any((t) => t.id == track.id);
    if (!inQueue) q.appendSource([track]);
    playTrackNow(track.id);
    return true;
  }

  bool disbandQueue() {
    if (_queue?.current == null) return false;

    _queue = null;
    _playingFrom = null;
    _source = QueueSource.fixed;
    _ended = true;
    _platformMoved = false;
    notifyListeners();
    return true;
  }

  void playTrackNow(String trackId, {bool reload = true}) {
    final q = _queue;
    if (q == null) return;
    final moved = q.jumpTo(trackId);
    if (!moved && reload) return;

    _ended = false;

    if (!reload) {
      _platformMoved = true;
    } else {
      _platformMoved = false;
    }
    notifyListeners();
  }

  bool get trackChangeCameFromPlatform => _platformMoved;
  bool _platformMoved = false;

  void clearPlatformTrackChange() => _platformMoved = false;

  bool moveInQueue(int from, int to) {
    final q = _queue;
    if (q == null) return false;
    if (!q.move(from, to)) return false;
    notifyListeners();
    return true;
  }

  bool moveInUpcoming(int from, int to) {
    final q = _queue;
    if (q == null) return false;

    final offset = q.index + 1;
    if (from < 0 || offset + from >= q.length) return false;
    if (to < 0 || offset + to >= q.length) return false;
    return moveInQueue(offset + from, offset + to);
  }

  bool removeFromQueue(String trackId) {
    final q = _queue;
    if (q == null) return false;
    final wasCurrent = q.current?.id == trackId;
    if (!q.remove(trackId)) return false;
    notifyListeners();

    return wasCurrent;
  }

  @visibleForTesting
  bool setQueueForTest(List<Track> tracks) {
    if (tracks.isEmpty) return false;
    _queue = PlayQueue(source: tracks, shuffle: false);
    _source = QueueSource.fixed;
    _ended = false;
    notifyListeners();
    return true;
  }

  bool addToQueue(Track track) {
    final q = _queue;
    if (q == null) return false;
    if (!q.append(track)) return false;
    notifyListeners();
    return true;
  }

  bool playNextInQueue(Track track) {
    final q = _queue;
    if (q == null) return false;
    q.playNext(track);
    notifyListeners();
    return true;
  }

  bool isCurrent(String trackId) => _queue?.current?.id == trackId;

  List<Track> get queueOrder => _queue?.order ?? const [];

  int get queueIndex {
    final q = _queue;
    if (q == null || q.isEmpty) return -1;
    return q.index;
  }

  List<Track> get upNext => _queue?.upcoming ?? const [];

  List<Track> get played => _queue?.played ?? const [];

  int get upNextCount {
    final q = _queue;
    if (q == null || q.isEmpty) return 0;
    final remaining = q.length - q.index - 1;
    return remaining < 0 ? 0 : remaining;
  }
}
