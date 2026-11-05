library;

import 'dart:convert';
import 'dart:io';

/// One preference: its key in the file, what it reads as when the file is silent,
/// how a value in the file is understood, and where its range is enforced.
///
/// A key used to be written out in five places — the field, `copyWith`, `toJson`,
/// `fromJson`, and the screen that reads it — and the three that touch the file
/// disagreed: the decoder took a junk value as its default while `copyWith` clamped
/// it, so a number could be written at one range and read back at another. The
/// tolerance is stated once, here, and both `fromJson` and `copyWith` come through
/// it.
class PrefKey<T> implements PrefRow {
  PrefKey(
    this.name, {
    required this.initial,
    required this.read,
    required this.decode,
    this.legacy = const <String>[],
    T Function(T value)? normalise,
    Object? Function(T value)? encode,
  })  : normalise = normalise ?? _keep,
        encode = encode ?? _echo;

  /// The key in `prefs.json`.
  @override
  final String name;

  /// What the build does when the file says nothing — and what a value that cannot
  /// be understood falls back to.
  final T initial;

  final T Function(AppPrefs prefs) read;

  /// Reads a value from the file. Null means "not usable", which is treated exactly
  /// like absent: a hand-edited file must not stop a launch.
  final T? Function(Object? value) decode;

  /// The names this key used to be written under. An old file is read, not migrated.
  final List<String> legacy;

  /// The range, in the one place that both the decoder and `copyWith` pass through.
  final T Function(T value) normalise;

  /// How the value goes into the file; null leaves the key out entirely.
  final Object? Function(T value) encode;

  static T _keep<T>(T value) => value;

  static Object? _echo<T>(T value) => value;

  static const _Absent _absent = _Absent();

  T of(Map<Object?, Object?> raw) {
    Object? found = _absent;
    if (raw.containsKey(name)) {
      found = raw[name];
    } else {
      for (final alias in legacy) {
        if (raw.containsKey(alias)) {
          found = raw[alias];
          break;
        }
      }
    }
    if (found is _Absent) return normalise(initial);
    return normalise(decode(found) ?? initial);
  }

  @override
  Object? encoded(AppPrefs prefs) => encode(read(prefs));
}

/// What [AppPrefs.toJson] needs from a row: its name and its value, whatever the
/// type. The table is a list of these, so adding a key and forgetting to write it
/// out is not possible.
abstract interface class PrefRow {
  String get name;

  Object? encoded(AppPrefs prefs);
}

class _Absent {
  const _Absent();
}

class AppPrefs {
  const AppPrefs({
    this.resumeOnLaunch = false,
    this.crossfadeSeconds = 0,
    this.sleepTimerMinutes = 30,
    this.skipThresholdSeconds = 10,
    this.officialOnly = false,
    this.tabAnimation = true,
    this.showFps = false,
    this.checkForUpdates = true,
    this.locale,
    this.weatherRefreshMinutes = 30,
    this.allowNetwork = true,
    this.contextWeather = false,
    this.contextClock = false,
    this.contextMix = false,
    this.placesEnabled = false,
    this.learnFromSkips = false,
    this.weatherVariants = false,
    this.autoSkin = false,
    this.recordHistory = true,
    this.bondsLayer = false,
    this.cycleCharacterArt = true,
    this.showVisualiser = true,
    this.showRomaji = true,
    this.dynamicByDefault = true,
    this.layoutId = 'persona',
    this.paletteIndex = 0,
    this.refillWhenQueueEnds = false,
    this.libraryIsGrid,
    this.activePresetId,
    this.languageSkinId,
    this.skinId,
    this.spectrumSmoothness,
    this.spectrumScale,
    this.spectrumShape,
    this.searchOnline,
    this.playlistSort,
    this.pinnedPlaylistIds,
    this.recentPlaylistIds,
  });

  static const AppPrefs initial = AppPrefs();

  final bool resumeOnLaunch;

  final int crossfadeSeconds;

  final int sleepTimerMinutes;

  final int skipThresholdSeconds;

  final bool officialOnly;

  final bool tabAnimation;

  final bool showFps;

  /// Asking GitHub for a newer build. Off means the app never phones home about
  /// itself; the check is a courtesy, so it can be declined.
  final bool checkForUpdates;

  /// BCP-47 language tag the UI speaks, or null to follow the phone.
  ///
  /// Stored as the tag rather than as an index into a list: a list that gains a
  /// language must not silently change what an older build means by "3".
  final String? locale;

  final int weatherRefreshMinutes;

  final bool allowNetwork;

  final bool contextWeather;

  final bool contextClock;

  final bool contextMix;

  final bool placesEnabled;

  final bool learnFromSkips;

  final bool weatherVariants;

  final bool autoSkin;

  final bool recordHistory;

  final bool bondsLayer;

  final bool cycleCharacterArt;

  final bool showVisualiser;

  final bool showRomaji;

  final String? activePresetId;

  final bool dynamicByDefault;

  final bool refillWhenQueueEnds;

  final bool? libraryIsGrid;

  final String layoutId;

  /// Which palette of the chosen layout to wear. Solid and Glass each ship a list
  /// of their own; Persona's colours are skins, so this stays 0 there.
  ///
  /// It has to be a preference: the layout is applied again on every preference
  /// change, so a palette held only in AppState was reset to the first one the
  /// moment anything else was toggled.
  final int paletteIndex;

  final String? languageSkinId;

  final String? skinId;

  final int? spectrumSmoothness;

  static const int defaultSmoothnessPercent = 35;

  double get spectrumEase =>
      ((spectrumSmoothness ?? defaultSmoothnessPercent).clamp(0, 100)) / 100.0;

  static const int defaultScalePercent = 100;

  final int? spectrumScale;

  int get spectrumScalePercent =>
      (spectrumScale ?? defaultScalePercent).clamp(40, 220);

  final String? spectrumShape;

  String get spectrumShapeName => spectrumShape ?? 'rounded';

  String get playlistSortName => playlistSort ?? 'recents';

  bool get playlistsPinned => (pinnedPlaylistIds ?? const []).isNotEmpty;

  final bool? searchOnline;

  final String? playlistSort;

  final List<String>? pinnedPlaylistIds;

  final List<String>? recentPlaylistIds;

  // ---------------------------------------------------------------- the table --

  /// Every key the file can carry.
  ///
  /// `toJson` walks this list, so a key with no row is a key that is never saved;
  /// and `fromJson`/`copyWith` resolve through the same rows, so a key cannot be
  /// clamped on one path and not the other.
  static final List<PrefRow> rows = <PrefRow>[
    _kResumeOnLaunch,
    _kCrossfade,
    _kSleepTimer,
    _kSkipThreshold,
    _kOfficialOnly,
    _kTabAnimation,
    _kShowFps,
    _kCheckForUpdates,
    _kLocale,
    _kWeatherRefresh,
    _kAllowNetwork,
    _kContextWeather,
    _kContextClock,
    _kContextMix,
    _kPlacesEnabled,
    _kLearnFromSkips,
    _kWeatherVariants,
    _kAutoSkin,
    _kRecordHistory,
    _kBondsLayer,
    _kCycleCharacterArt,
    _kShowVisualiser,
    _kShowRomaji,
    _kDynamicByDefault,
    _kLayoutId,
    _kPaletteIndex,
    _kRefillWhenQueueEnds,
    _kLibraryIsGrid,
    _kActivePreset,
    _kLanguageSkin,
    _kSkinId,
    _kSpectrumSmoothness,
    _kSpectrumScale,
    _kSpectrumShape,
    _kSearchOnline,
    _kPlaylistSort,
    _kPinnedPlaylists,
    _kRecentPlaylists,
  ];

  static final _kResumeOnLaunch = PrefKey<bool>(
    'resume_on_launch',
    initial: false,
    read: (p) => p.resumeOnLaunch,
    decode: _asBool,
  );

  static final _kCrossfade = PrefKey<int>(
    'crossfade_seconds',
    initial: 0,
    read: (p) => p.crossfadeSeconds,
    decode: _asInt,
    normalise: (v) => v.clamp(0, 12),
  );

  static final _kSleepTimer = PrefKey<int>(
    'sleep_timer_minutes',
    initial: 30,
    read: (p) => p.sleepTimerMinutes,
    decode: _asInt,
    normalise: (v) => v.clamp(5, 180),
  );

  static final _kSkipThreshold = PrefKey<int>(
    'skip_threshold_seconds',
    initial: 10,
    read: (p) => p.skipThresholdSeconds,
    decode: _asInt,
    normalise: (v) => v.clamp(3, 60),
  );

  static final _kOfficialOnly = PrefKey<bool>(
    'official_only',
    initial: false,
    read: (p) => p.officialOnly,
    decode: _asBool,
    // The name this switch had before the rename.
    legacy: const ['prefer_music_videos'],
  );

  static final _kTabAnimation = PrefKey<bool>(
    'tab_animation',
    initial: true,
    read: (p) => p.tabAnimation,
    decode: _asBool,
  );

  static final _kShowFps = PrefKey<bool>(
    'show_fps',
    initial: false,
    read: (p) => p.showFps,
    decode: _asBool,
  );

  static final _kCheckForUpdates = PrefKey<bool>(
    'check_for_updates',
    initial: true,
    read: (p) => p.checkForUpdates,
    decode: _asBool,
  );

  static final _kLocale = PrefKey<String?>(
    'locale',
    initial: null,
    read: (p) => p.locale,
    decode: _languageTag,
  );

  static final _kWeatherRefresh = PrefKey<int>(
    'weather_refresh_minutes',
    initial: 30,
    read: (p) => p.weatherRefreshMinutes,
    decode: _asInt,
    normalise: (v) => v.clamp(5, 180),
  );

  static final _kAllowNetwork = PrefKey<bool>(
    'allow_network',
    initial: true,
    read: (p) => p.allowNetwork,
    decode: _asBool,
  );

  static final _kContextWeather = PrefKey<bool>(
    'context_weather',
    initial: false,
    read: (p) => p.contextWeather,
    decode: _asBool,
  );

  static final _kContextClock = PrefKey<bool>(
    'context_clock',
    initial: false,
    read: (p) => p.contextClock,
    decode: _asBool,
  );

  static final _kContextMix = PrefKey<bool>(
    'context_mix',
    initial: false,
    read: (p) => p.contextMix,
    decode: _asBool,
  );

  static final _kPlacesEnabled = PrefKey<bool>(
    'places_enabled',
    initial: false,
    read: (p) => p.placesEnabled,
    decode: _asBool,
  );

  static final _kLearnFromSkips = PrefKey<bool>(
    'learn_from_skips',
    initial: false,
    read: (p) => p.learnFromSkips,
    decode: _asBool,
  );

  static final _kWeatherVariants = PrefKey<bool>(
    'weather_variants',
    initial: false,
    read: (p) => p.weatherVariants,
    decode: _asBool,
  );

  static final _kAutoSkin = PrefKey<bool>(
    'auto_skin',
    initial: false,
    read: (p) => p.autoSkin,
    decode: _asBool,
  );

  static final _kRecordHistory = PrefKey<bool>(
    'record_history',
    initial: true,
    read: (p) => p.recordHistory,
    decode: _asBool,
  );

  static final _kBondsLayer = PrefKey<bool>(
    'bonds_layer',
    initial: false,
    read: (p) => p.bondsLayer,
    decode: _asBool,
    // Files written before the rename stored this as 'persona_layer'.
    legacy: const ['persona_layer'],
  );

  static final _kCycleCharacterArt = PrefKey<bool>(
    'cycle_character_art',
    initial: true,
    read: (p) => p.cycleCharacterArt,
    decode: _asBool,
  );

  static final _kShowVisualiser = PrefKey<bool>(
    'show_visualiser',
    initial: true,
    read: (p) => p.showVisualiser,
    decode: _asBool,
  );

  static final _kShowRomaji = PrefKey<bool>(
    'show_romaji',
    initial: true,
    read: (p) => p.showRomaji,
    decode: _asBool,
  );

  static final _kDynamicByDefault = PrefKey<bool>(
    'dynamic_by_default',
    initial: true,
    read: (p) => p.dynamicByDefault,
    decode: _asBool,
  );

  static final _kLayoutId = PrefKey<String>(
    'layout_id',
    initial: 'persona',
    read: (p) => p.layoutId,
    decode: (v) => (v is String && v.isNotEmpty) ? v : null,
  );

  static final _kPaletteIndex = PrefKey<int>(
    'palette',
    initial: 0,
    read: (p) => p.paletteIndex,
    decode: _asInt,
    normalise: (v) => v < 0 ? 0 : v,
    // The first palette is the default; storing it would be noise in a diff.
    encode: (v) => v == 0 ? null : v,
  );

  static final _kRefillWhenQueueEnds = PrefKey<bool>(
    'refill_when_queue_ends',
    initial: false,
    read: (p) => p.refillWhenQueueEnds,
    decode: _asBool,
  );

  static final _kLibraryIsGrid = PrefKey<bool?>(
    'library_is_grid',
    initial: null,
    read: (p) => p.libraryIsGrid,
    decode: _asBool,
  );

  static final _kActivePreset = PrefKey<String?>(
    'active_preset',
    initial: null,
    read: (p) => p.activePresetId,
    decode: _asStr,
  );

  static final _kLanguageSkin = PrefKey<String?>(
    'language_skin',
    initial: null,
    read: (p) => p.languageSkinId,
    decode: _asStr,
  );

  static final _kSkinId = PrefKey<String?>(
    'skin_id',
    initial: null,
    read: (p) => p.skinId,
    decode: _asStr,
  );

  static final _kSpectrumSmoothness = PrefKey<int?>(
    'spectrum_smoothness',
    initial: null,
    read: (p) => p.spectrumSmoothness,
    decode: _asInt,
    normalise: (v) => v?.clamp(0, 100),
  );

  static final _kSpectrumScale = PrefKey<int?>(
    'spectrum_scale',
    initial: null,
    read: (p) => p.spectrumScale,
    decode: _asInt,
    normalise: (v) => v?.clamp(40, 220),
  );

  static final _kSpectrumShape = PrefKey<String?>(
    'spectrum_shape',
    initial: null,
    read: (p) => p.spectrumShape,
    decode: _asStr,
  );

  static final _kSearchOnline = PrefKey<bool?>(
    'search_online',
    initial: null,
    read: (p) => p.searchOnline,
    decode: _asBool,
  );

  static final _kPlaylistSort = PrefKey<String?>(
    'playlist_sort',
    initial: null,
    read: (p) => p.playlistSort,
    decode: _asStr,
  );

  static final _kPinnedPlaylists = PrefKey<List<String>?>(
    'pinned_playlists',
    initial: null,
    read: (p) => p.pinnedPlaylistIds,
    decode: _asStrList,
  );

  static final _kRecentPlaylists = PrefKey<List<String>?>(
    'recent_playlists',
    initial: null,
    read: (p) => p.recentPlaylistIds,
    decode: _asStrList,
  );

  // ------------------------------------------------------------- the readers --

  static bool? _asBool(Object? v) => v is bool ? v : null;

  /// NaN and infinity are numbers a cast would take and `toInt` would throw on.
  static int? _asInt(Object? v) =>
      (v is num && v.isFinite) ? v.toInt() : null;

  static String? _asStr(Object? v) =>
      (v is String && v.trim().isNotEmpty) ? v.trim() : null;

  static List<String>? _asStrList(Object? v) => v is List
      ? [for (final e in v) if (e is String && e.isNotEmpty) e]
      : null;

  /// Only tags this build actually speaks. A tag from a newer build (or a
  /// hand-edited file) must fall back to the system rather than leave the UI
  /// hunting for a localization that does not exist.
  static const Set<String> supportedLanguages = {
    'en',
    'vi',
    'ja',
    'zh-Hans',
    'fi',
  };

  static String? _languageTag(Object? v) =>
      (v is String && supportedLanguages.contains(v)) ? v : null;

  static void _put<T>(Map<Object?, Object?> raw, PrefKey<T> key, T? value) {
    if (value != null) raw[key.name] = value;
  }

  // --------------------------------------------------------------- the file --

  Map<String, Object?> toJson() {
    final out = <String, Object?>{'prefs_version': 2};
    for (final row in rows) {
      final value = row.encoded(this);
      if (value != null) out[row.name] = value;
    }
    return out;
  }

  static AppPrefs fromJson(Object? raw) {
    if (raw is! Map) return initial;
    return _resolve(raw.cast<Object?, Object?>());
  }

  /// The single place a resolved map of keys becomes an [AppPrefs].
  ///
  /// Both `fromJson` and `copyWith` end here, so "what a file means" and "what a
  /// copy means" cannot drift apart.
  static AppPrefs _resolve(Map<Object?, Object?> raw) => AppPrefs(
        resumeOnLaunch: _kResumeOnLaunch.of(raw),
        crossfadeSeconds: _kCrossfade.of(raw),
        sleepTimerMinutes: _kSleepTimer.of(raw),
        skipThresholdSeconds: _kSkipThreshold.of(raw),
        officialOnly: _kOfficialOnly.of(raw),
        tabAnimation: _kTabAnimation.of(raw),
        showFps: _kShowFps.of(raw),
        checkForUpdates: _kCheckForUpdates.of(raw),
        locale: _kLocale.of(raw),
        weatherRefreshMinutes: _kWeatherRefresh.of(raw),
        allowNetwork: _kAllowNetwork.of(raw),
        contextWeather: _kContextWeather.of(raw),
        contextClock: _kContextClock.of(raw),
        contextMix: _kContextMix.of(raw),
        placesEnabled: _kPlacesEnabled.of(raw),
        learnFromSkips: _kLearnFromSkips.of(raw),
        weatherVariants: _kWeatherVariants.of(raw),
        autoSkin: _kAutoSkin.of(raw),
        recordHistory: _kRecordHistory.of(raw),
        bondsLayer: _kBondsLayer.of(raw),
        cycleCharacterArt: _kCycleCharacterArt.of(raw),
        showVisualiser: _kShowVisualiser.of(raw),
        showRomaji: _kShowRomaji.of(raw),
        dynamicByDefault: _kDynamicByDefault.of(raw),
        layoutId: _kLayoutId.of(raw),
        paletteIndex: _kPaletteIndex.of(raw),
        refillWhenQueueEnds: _kRefillWhenQueueEnds.of(raw),
        libraryIsGrid: _kLibraryIsGrid.of(raw),
        activePresetId: _kActivePreset.of(raw),
        languageSkinId: _kLanguageSkin.of(raw),
        skinId: _kSkinId.of(raw),
        spectrumSmoothness: _kSpectrumSmoothness.of(raw),
        spectrumScale: _kSpectrumScale.of(raw),
        spectrumShape: _kSpectrumShape.of(raw),
        searchOnline: _kSearchOnline.of(raw),
        playlistSort: _kPlaylistSort.of(raw),
        pinnedPlaylistIds: _kPinnedPlaylists.of(raw),
        recentPlaylistIds: _kRecentPlaylists.of(raw),
      );

  /// A copy with the named keys changed.
  ///
  /// null means "unchanged" for every field, so clearing a value that is
  /// legitimately null needs a word of its own. The edit is applied to the file
  /// representation and resolved again: a copy therefore clamps and validates
  /// exactly as a load does.
  AppPrefs copyWith({
    bool? resumeOnLaunch,
    bool clearPreset = false,
    int? crossfadeSeconds,
    int? sleepTimerMinutes,
    int? skipThresholdSeconds,
    bool? officialOnly,
    bool? tabAnimation,
    bool? showFps,
    String? locale,
    bool clearLocale = false,
    bool? checkForUpdates,
    int? weatherRefreshMinutes,
    bool? allowNetwork,
    bool? contextWeather,
    bool? contextClock,
    bool? contextMix,
    bool? placesEnabled,
    bool? learnFromSkips,
    bool? weatherVariants,
    bool? autoSkin,
    bool? recordHistory,
    bool? bondsLayer,
    bool? cycleCharacterArt,
    bool? showVisualiser,
    bool? showRomaji,
    bool? dynamicByDefault,
    bool? refillWhenQueueEnds,
    bool? libraryIsGrid,
    bool clearLibraryGrid = false,
    String? layoutId,
    int? paletteIndex,
    String? activePresetId,
    String? languageSkinId,
    bool clearLanguageSkin = false,
    String? skinId,
    int? spectrumSmoothness,
    int? spectrumScale,
    String? spectrumShape,
    bool? searchOnline,
    String? playlistSort,
    List<String>? pinnedPlaylistIds,
    List<String>? recentPlaylistIds,
  }) {
    final raw = <Object?, Object?>{...toJson()};

    _put(raw, _kResumeOnLaunch, resumeOnLaunch);
    _put(raw, _kCrossfade, crossfadeSeconds);
    _put(raw, _kSleepTimer, sleepTimerMinutes);
    _put(raw, _kSkipThreshold, skipThresholdSeconds);
    _put(raw, _kOfficialOnly, officialOnly);
    _put(raw, _kTabAnimation, tabAnimation);
    _put(raw, _kShowFps, showFps);
    _put(raw, _kCheckForUpdates, checkForUpdates);
    _put(raw, _kLocale, locale);
    _put(raw, _kWeatherRefresh, weatherRefreshMinutes);
    _put(raw, _kAllowNetwork, allowNetwork);
    _put(raw, _kContextWeather, contextWeather);
    _put(raw, _kContextClock, contextClock);
    _put(raw, _kContextMix, contextMix);
    _put(raw, _kPlacesEnabled, placesEnabled);
    _put(raw, _kLearnFromSkips, learnFromSkips);
    _put(raw, _kWeatherVariants, weatherVariants);
    _put(raw, _kAutoSkin, autoSkin);
    _put(raw, _kRecordHistory, recordHistory);
    _put(raw, _kBondsLayer, bondsLayer);
    _put(raw, _kCycleCharacterArt, cycleCharacterArt);
    _put(raw, _kShowVisualiser, showVisualiser);
    _put(raw, _kShowRomaji, showRomaji);
    _put(raw, _kDynamicByDefault, dynamicByDefault);
    _put(raw, _kLayoutId, layoutId);
    _put(raw, _kPaletteIndex, paletteIndex);
    _put(raw, _kRefillWhenQueueEnds, refillWhenQueueEnds);
    _put(raw, _kLibraryIsGrid, libraryIsGrid);
    _put(raw, _kActivePreset, activePresetId);
    _put(raw, _kLanguageSkin, languageSkinId);
    _put(raw, _kSkinId, skinId);
    _put(raw, _kSpectrumSmoothness, spectrumSmoothness);
    _put(raw, _kSpectrumScale, spectrumScale);
    _put(raw, _kSpectrumShape, spectrumShape);
    _put(raw, _kSearchOnline, searchOnline);
    _put(raw, _kPlaylistSort, playlistSort);
    _put(raw, _kPinnedPlaylists, pinnedPlaylistIds);
    _put(raw, _kRecentPlaylists, recentPlaylistIds);

    if (clearLocale) raw.remove(_kLocale.name);
    if (clearPreset) raw.remove(_kActivePreset.name);
    if (clearLanguageSkin) raw.remove(_kLanguageSkin.name);
    if (clearLibraryGrid) raw.remove(_kLibraryIsGrid.name);

    return _resolve(raw);
  }

  Duration get crossfade => Duration(seconds: crossfadeSeconds);
  Duration get sleepTimer => Duration(minutes: sleepTimerMinutes);
  Duration get skipThreshold => Duration(seconds: skipThresholdSeconds);
  Duration get weatherRefresh => Duration(minutes: weatherRefreshMinutes);
}

class PrefsStore {
  PrefsStore(this.file);

  final File file;

  Future<AppPrefs> load() async {
    if (!file.existsSync()) return AppPrefs.initial;
    try {
      return AppPrefs.fromJson(jsonDecode(await file.readAsString()));
    } on FormatException {
      return AppPrefs.initial;
    } on FileSystemException {
      return AppPrefs.initial;
    }
  }

  Future<void> save(AppPrefs prefs) async {
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(prefs.toJson()));
    } on FileSystemException {
      // ignore: empty_catches
    }
  }
}
