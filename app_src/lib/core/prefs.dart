library;

import 'dart:convert';
import 'dart:io';

class AppPrefs {
  const AppPrefs({
    this.resumeOnLaunch = false,
    this.crossfadeSeconds = 0,
    this.sleepTimerMinutes = 30,
    this.skipThresholdSeconds = 10,
    this.officialOnly = false,
    this.tabAnimation = true,
    this.showFps = false,
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
    this.personaLayer = false,
    this.cycleCharacterArt = true,
    this.showVisualiser = true,
    this.showRomaji = true,
    this.dynamicByDefault = true,
    this.layoutId = 'persona',
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

  final bool personaLayer;

  final bool cycleCharacterArt;

  final bool showVisualiser;

  final bool showRomaji;

  final String? activePresetId;

  final bool dynamicByDefault;

  final bool refillWhenQueueEnds;

  final bool? libraryIsGrid;


  final String layoutId;


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

  AppPrefs copyWith({
    bool? resumeOnLaunch,

    bool clearPreset = false,
    int? crossfadeSeconds,
    int? sleepTimerMinutes,
    int? skipThresholdSeconds,
    bool? officialOnly,
    bool? tabAnimation,
    bool? showFps,
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
    bool? personaLayer,
    bool? cycleCharacterArt,
    bool? showVisualiser,
    bool? showRomaji,
    bool? dynamicByDefault,
    bool? refillWhenQueueEnds,

    bool? libraryIsGrid,
    bool clearLibraryGrid = false,
    String? layoutId,
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
  }) =>
      AppPrefs(
        resumeOnLaunch: resumeOnLaunch ?? this.resumeOnLaunch,
        crossfadeSeconds:
            (crossfadeSeconds ?? this.crossfadeSeconds).clamp(0, 12),
        sleepTimerMinutes:
            (sleepTimerMinutes ?? this.sleepTimerMinutes).clamp(5, 180),
        skipThresholdSeconds:
            (skipThresholdSeconds ?? this.skipThresholdSeconds).clamp(3, 60),
        officialOnly: officialOnly ?? this.officialOnly,
        tabAnimation: tabAnimation ?? this.tabAnimation,
        showFps: showFps ?? this.showFps,
        weatherRefreshMinutes:
            (weatherRefreshMinutes ?? this.weatherRefreshMinutes).clamp(5, 180),
        allowNetwork: allowNetwork ?? this.allowNetwork,
        contextWeather: contextWeather ?? this.contextWeather,
        contextClock: contextClock ?? this.contextClock,
        contextMix: contextMix ?? this.contextMix,
        placesEnabled: placesEnabled ?? this.placesEnabled,
        learnFromSkips: learnFromSkips ?? this.learnFromSkips,
        weatherVariants: weatherVariants ?? this.weatherVariants,
        autoSkin: autoSkin ?? this.autoSkin,
        recordHistory: recordHistory ?? this.recordHistory,
        personaLayer: personaLayer ?? this.personaLayer,
        cycleCharacterArt: cycleCharacterArt ?? this.cycleCharacterArt,
        showVisualiser: showVisualiser ?? this.showVisualiser,
        showRomaji: showRomaji ?? this.showRomaji,
        dynamicByDefault: dynamicByDefault ?? this.dynamicByDefault,
        refillWhenQueueEnds: refillWhenQueueEnds ?? this.refillWhenQueueEnds,
        libraryIsGrid:
            clearLibraryGrid ? null : (libraryIsGrid ?? this.libraryIsGrid),
        layoutId: layoutId ?? this.layoutId,
        activePresetId:
            clearPreset ? null : (activePresetId ?? initial.activePresetId),

        languageSkinId:
            clearLanguageSkin ? null : (languageSkinId ?? this.languageSkinId),
        skinId: skinId ?? this.skinId,
        spectrumSmoothness: spectrumSmoothness == null
            ? this.spectrumSmoothness
            : spectrumSmoothness.clamp(0, 100),
        spectrumScale: spectrumScale == null
            ? this.spectrumScale
            : spectrumScale.clamp(40, 220),
        spectrumShape: spectrumShape ?? this.spectrumShape,
        searchOnline: searchOnline ?? this.searchOnline,
        playlistSort: playlistSort ?? this.playlistSort,
        pinnedPlaylistIds: pinnedPlaylistIds ?? this.pinnedPlaylistIds,
        recentPlaylistIds: recentPlaylistIds ?? this.recentPlaylistIds,
      );

  Duration get crossfade => Duration(seconds: crossfadeSeconds);
  Duration get sleepTimer => Duration(minutes: sleepTimerMinutes);
  Duration get skipThreshold => Duration(seconds: skipThresholdSeconds);
  Duration get weatherRefresh => Duration(minutes: weatherRefreshMinutes);

  Map<String, Object?> toJson() => {
        'resume_on_launch': resumeOnLaunch,
        'crossfade_seconds': crossfadeSeconds,
        'sleep_timer_minutes': sleepTimerMinutes,
        'skip_threshold_seconds': skipThresholdSeconds,
        'official_only': officialOnly,
        'tab_animation': tabAnimation,
        'show_fps': showFps,
        'weather_refresh_minutes': weatherRefreshMinutes,
        'allow_network': allowNetwork,
        'context_weather': contextWeather,
        'context_clock': contextClock,
        'context_mix': contextMix,
        'places_enabled': placesEnabled,
        'learn_from_skips': learnFromSkips,
        'weather_variants': weatherVariants,
        'auto_skin': autoSkin,
        'record_history': recordHistory,
        'prefs_version': 2,
        'persona_layer': personaLayer,
        'cycle_character_art': cycleCharacterArt,
        'show_visualiser': showVisualiser,
        'show_romaji': showRomaji,
        'dynamic_by_default': dynamicByDefault,
        'refill_when_queue_ends': refillWhenQueueEnds,

        if (libraryIsGrid != null) 'library_is_grid': libraryIsGrid,
        'layout_id': layoutId,

        if (activePresetId != null) 'active_preset': activePresetId,

        if (languageSkinId != null) 'language_skin': languageSkinId,
        if (skinId != null) 'skin_id': skinId,

        if (spectrumSmoothness != null)
          'spectrum_smoothness': spectrumSmoothness,
        if (spectrumScale != null) 'spectrum_scale': spectrumScale,
        if (spectrumShape != null) 'spectrum_shape': spectrumShape,
        if (searchOnline != null) 'search_online': searchOnline,
        if (playlistSort != null) 'playlist_sort': playlistSort,
        if (pinnedPlaylistIds != null) 'pinned_playlists': pinnedPlaylistIds,
        if (recentPlaylistIds != null) 'recent_playlists': recentPlaylistIds,
      };

  static AppPrefs fromJson(Object? raw) {
    if (raw is! Map) return initial;
    return AppPrefs(
      resumeOnLaunch: _bool(raw['resume_on_launch']) ?? initial.resumeOnLaunch,
      crossfadeSeconds:
          _int(raw['crossfade_seconds']) ?? initial.crossfadeSeconds,
      sleepTimerMinutes:
          _int(raw['sleep_timer_minutes']) ?? initial.sleepTimerMinutes,
      skipThresholdSeconds:
          _int(raw['skip_threshold_seconds']) ?? initial.skipThresholdSeconds,
      officialOnly: raw['official_only'] == true || raw['prefer_music_videos'] == true,

      tabAnimation: raw['tab_animation'] != false,
      showFps: raw['show_fps'] == true,
      weatherRefreshMinutes:
          _int(raw['weather_refresh_minutes']) ?? initial.weatherRefreshMinutes,
      allowNetwork: _bool(raw['allow_network']) ?? initial.allowNetwork,
      contextWeather: _bool(raw['context_weather']) ?? initial.contextWeather,
      contextClock: _bool(raw['context_clock']) ?? initial.contextClock,
      contextMix: _bool(raw['context_mix']) ?? initial.contextMix,
      placesEnabled: _bool(raw['places_enabled']) ?? initial.placesEnabled,
      learnFromSkips: _bool(raw['learn_from_skips']) ?? initial.learnFromSkips,
      weatherVariants: _bool(raw['weather_variants']) ?? initial.weatherVariants,
      autoSkin: _bool(raw['auto_skin']) ?? initial.autoSkin,
      // Files written before prefs_version existed carry `record_history: false`
      // only because that was the default then — nobody chose it. Reading that
      // as a decision kept History empty on every install that predates this.
      recordHistory: raw['prefs_version'] == null
          ? true
          : (_bool(raw['record_history']) ?? initial.recordHistory),
      personaLayer: _bool(raw['persona_layer']) ?? initial.personaLayer,

      cycleCharacterArt:
          _bool(raw['cycle_character_art']) ?? initial.cycleCharacterArt,

      showVisualiser: _bool(raw['show_visualiser']) ?? initial.showVisualiser,
      showRomaji: _bool(raw['show_romaji']) ?? initial.showRomaji,

      dynamicByDefault:
          _bool(raw['dynamic_by_default']) ?? initial.dynamicByDefault,
      refillWhenQueueEnds:
          _bool(raw['refill_when_queue_ends']) ?? initial.refillWhenQueueEnds,

      libraryIsGrid:
          raw['library_is_grid'] is bool ? raw['library_is_grid'] as bool : null,

      layoutId: (raw['layout_id'] is String && (raw['layout_id'] as String).isNotEmpty)
          ? raw['layout_id'] as String
          : initial.layoutId,

      activePresetId: _str(raw['active_preset']),
      languageSkinId: _str(raw['language_skin']),
      skinId: _str(raw['skin_id']),

      spectrumSmoothness: raw['spectrum_smoothness'] is int
          ? (raw['spectrum_smoothness'] as int).clamp(0, 100)
          : null,
      spectrumScale: raw['spectrum_scale'] is int
          ? (raw['spectrum_scale'] as int).clamp(40, 220)
          : null,
      spectrumShape: _str(raw['spectrum_shape']),
      searchOnline: _bool(raw['search_online']),
      playlistSort: _str(raw['playlist_sort']),
      pinnedPlaylistIds: _strList(raw['pinned_playlists']),
      recentPlaylistIds: _strList(raw['recent_playlists']),
    );
  }

  static bool? _bool(Object? v) => v is bool ? v : null;

  static List<String>? _strList(Object? v) => v is List
      ? [for (final e in v) if (e is String && e.isNotEmpty) e]
      : null;
  static String? _str(Object? v) =>
      (v is String && v.trim().isNotEmpty) ? v.trim() : null;
  static int? _int(Object? v) => v is num ? v.toInt() : null;
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
