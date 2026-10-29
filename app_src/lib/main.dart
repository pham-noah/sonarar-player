library;

import 'dart:async';
import 'dart:io' show Directory, File, Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'context/context_coordinator.dart';
import 'context/place_icons.dart';
import 'context/places.dart';
import 'screens/places_screen.dart';
import 'context/weather_codes.dart';
import 'core/build_info.dart';
import 'core/app_state.dart';
import 'player/art_warmer.dart';
import 'core/constants.dart';
import 'core/music_root.dart';
import 'core/diag_log.dart';
import 'core/latest_load.dart';
import 'core/prefs_decode.dart' as decode;
import 'core/shortcuts.dart';
import 'core/prefs.dart';
import 'widgets/download_ring.dart';
import 'widgets/fps_overlay.dart';
import 'download/download_manager.dart';
import 'core/state_stores.dart';
import 'library/compendium.dart';
import 'library/home_rails.dart';
import 'library/downloaded_tracks.dart';
import 'library/dynamic_playlist.dart';
import 'library/rediscovery.dart';
import 'library/storage_permission.dart';
import 'library/library_repository.dart';
import 'library/play_log.dart';
import 'library/playlists.dart';
import 'library/track.dart';
import 'library/variant_playlist.dart';
import 'library/variants.dart';
import 'playback/loop_controller.dart';
import 'playback/loop_points.dart';
import 'playback/sleep_timer.dart';
import 'player/art_cycle.dart';
import 'player/audio_engine.dart';
import 'screens/app_page.dart';
import 'screens/app_sidebar.dart';
import 'screens/bonds_screen.dart';
import 'screens/first_run_screen.dart';
import 'screens/never_in_shuffle_screen.dart';
import 'screens/library_management_panel.dart';
import 'screens/library_browser.dart';
import 'screens/library_screen.dart';
import 'screens/music_folder_screen.dart';
import 'screens/personalize_screen.dart';
import 'screens/player_screen.dart';
import 'screens/playlist_import_sheet.dart';
import 'screens/youtube_search_screen.dart';
import 'screens/rules_editor_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/compendium_screen.dart';
import 'screens/history_screen.dart';
import 'screens/tab_bar_view.dart';
import 'screens/tag_editor_sheet.dart';
import 'screens/archive_screen.dart';
import 'widgets/inline_panel.dart';
import 'screens/diagnostics_screen.dart';
import 'theme/ambient_backdrop.dart';
import 'theme/backdrop_layer.dart';
import 'theme/layout.dart';
import 'theme/layout_kit.dart';

import 'art/art_bundle.dart';
import 'update/update_bar.dart';
import 'theme/personalization.dart';
import 'theme/skin.dart';
import 'theme/theme_preset.dart';
import 'theme/theme_session.dart';
import 'theme/tab_motif.dart';
import 'theme/skin_policy.dart';
import 'library/lyrics.dart';
import 'library/romaji.dart';
import 'widgets/audio_panel.dart';
import 'widgets/lyrics_view.dart';
import 'widgets/mini_player_host.dart';
import 'widgets/panel_bodies.dart';
import 'widgets/framed_art.dart';
import 'widgets/spectrum.dart';
import 'player/spectrum_builder.dart';
import 'player/audio_route.dart';
import 'player/queue_mode.dart';
import 'player/queue.dart' as playqueue show RepeatMode;
import 'screens/home_screen.dart';

Future<void>? _audioInit;

Future<void> get _audioReady async => _audioInit == null ? null : await _audioInit;

final diagLog = DiagLog();

Future<void> main() async {
  final tMain = DateTime.now();
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: avoid_print
  print('[Sonarar][MAIN] binding=${DateTime.now().difference(tMain).inMilliseconds}ms');

  diagLog.attach();

  var fullErrorsPrinted = 0;
  FlutterError.onError = (details) {
    // ignore: avoid_print
    print('[Sonarar][FLUTTER_ERROR] ${details.exceptionAsString()}');
    // ignore: avoid_print
    print('[Sonarar][FLUTTER_ERROR] context=${details.context}');
    if (fullErrorsPrinted < 3) {
      fullErrorsPrinted++;
      // ignore: avoid_print
      print('[Sonarar][FLUTTER_ERROR] full:\n${details.toString()}');
    }

    final stack = details.stack;
    if (stack != null) {
      // ignore: avoid_print
      print('[Sonarar][FLUTTER_ERROR] stack:\n$stack');
    }
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    // ignore: avoid_print
    print('[Sonarar][UNCAUGHT] $error');
    // ignore: avoid_print
    print('[Sonarar][UNCAUGHT] stack:\n$stack');
    return true;
  };

  // audio_service's init holds the platform thread for ~2s on this device,
  // and the first frame waits behind it. Nothing needs the service before
  // playback (see `_audioReady`), so it starts once the first frame is on
  // screen instead of standing in front of it.
  Future<void> startAudio() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    final tAudio = DateTime.now();
    _audioInit = () async {
      await JustAudioBackground.init(
      androidNotificationChannelId: 'com.noah.sonarar.audio',
      androidNotificationChannelName: 'Sonarar playback',

      androidNotificationOngoing: false,

      androidNotificationIcon: 'mipmap/ic_launcher',

      androidStopForegroundOnPause: false,
      );
      // ignore: avoid_print
      print('[Sonarar][MAIN] audio_service READY in ${DateTime.now().difference(tAudio).inMilliseconds}ms '
          '(started after the first frame)');
    }();
    await _audioInit;
  }

  unawaited(diagLog.restore());

  AppLifecycleListener(
    onPause: () => unawaited(diagLog.flush()),
    onDetach: () => unawaited(diagLog.flush()),
  );

  // ignore: avoid_print
  print('[Sonarar][MAIN] pre_runApp=${DateTime.now().difference(tMain).inMilliseconds}ms');

  var firstFrameLogged = false;
  WidgetsBinding.instance.addTimingsCallback((timings) {
    if (firstFrameLogged) return;
    firstFrameLogged = true;
    final t = timings.last;
    // ignore: avoid_print
    print('[Sonarar][FRAME] first frame build=${t.buildDuration.inMilliseconds}ms '
        'raster=${t.rasterDuration.inMilliseconds}ms '
        'at=${DateTime.now().difference(tMain).inMilliseconds}ms');
  });

  runApp(const SonararApp());
  WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(startAudio()));
}

class SonararApp extends StatefulWidget {
  const SonararApp({super.key});

  @override
  State<SonararApp> createState() => _SonararAppState();
}

class _SonararAppState extends State<SonararApp> {
  final AppState _state = AppState();

  ThemeData? _theme;
  int? _themeAccent;

  LayoutKind? _themeLayoutId;
  SkinId? _themeSkinId;

  @override
  void initState() {
    super.initState();
    _syncContext();
  }

  void _syncContext() {
    final hour = DateTime.now().hour;
    _state.updateContext(
      PlayContext(
        band: const SkinPolicy().bandFor(hour),

        localHour: hour,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state.skinListenable,
      builder: (context, _) {
        final skin = _state.skin;
        final layoutId = _state.layoutId;
        if (_themeSkinId != skin.id ||
            _themeLayoutId != layoutId ||
            _themeAccent != skin.accent.toARGB32() ||
            _theme == null) {
          _themeSkinId = skin.id;
          _themeLayoutId = layoutId;
          _themeAccent = skin.accent.toARGB32();
          _theme = themeFor(skin, layout: _state.presentation);
        }

        return MaterialApp(
        title: 'Sonarar',
        debugShowCheckedModeBanner: false,
        theme: _theme!,
        home: HomeShell(state: _state),
      );
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});

  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

enum BackAction { closeList, closePanel, closePlayer, previousTab, leaveApp }

@visibleForTesting
BackAction backActionFor({
  required bool libraryListOpen,
  required bool panelOpen,
  required bool playerOpen,
  required bool hasTabHistory,
}) {
  if (libraryListOpen) return BackAction.closeList;
  if (panelOpen) return BackAction.closePanel;
  if (playerOpen) return BackAction.closePlayer;
  if (hasTabHistory) return BackAction.previousTab;
  return BackAction.leaveApp;
}

enum _InlineDoor { history, velvetRoom, compendium, bonds, places, diagnostics }

const Set<_InlineDoor> _kDoorsNeedingEvents = {
  _InlineDoor.history,
  _InlineDoor.compendium,
  _InlineDoor.bonds,
  _InlineDoor.velvetRoom,
};

class _HomeShellState extends State<HomeShell>

    with WidgetsBindingObserver {
  final LibraryRepository _repo = LibraryRepository();
  String _musicRoot = kAndroidLibraryRoot;

  late final DownloadManager _downloads = DownloadManager(
    repo: _repo,
    downloadDirOf: () => _repo.libraryRoot == null
        ? null
        : Directory('${_repo.libraryRoot}${Platform.pathSeparator}Downloaded'),
    manifestOf: () => _repo.libraryRoot == null
        ? null
        : File('${_repo.libraryRoot}${Platform.pathSeparator}$kManifestFileName'),
    onFiled: _reloadLibraryAfterDownload,
    log: diagLog,
  );

  late final StateStores _stores;

  /// Downloads is where a user already knows to look for a file they own, and
  /// it is the one folder the file pickers of other apps open by default.
  String get _backupDirectory => Platform.isAndroid
      ? '/storage/emulated/0/Download'
      : '${Directory.systemTemp.path}/sonarar-backups';

  String _stateDir = '';

  late final ContextCoordinator _ctx = ContextCoordinator(
    onChanged: _onContextMoved,
    allowNetwork: () => _prefs.allowNetwork,
    weatherEnabled: () => _prefs.contextWeather,
    placesEnabled: () => _prefs.placesEnabled,
  );

  Map<String, LoopPoints> _loopPoints = {};

  AppPrefs _prefs = AppPrefs.initial;
  AppPrefs get prefs => _prefs;

  bool? _playlistGridOverride;

  List<String> get _effectivePins =>
      _prefs.pinnedPlaylistIds ?? const [kLikedPlaylistId, kDownloadedId];

  void _togglePin(String id) {
    final current = [..._effectivePins];
    if (!current.remove(id)) current.insert(0, id);
    _setPrefs(_prefs.copyWith(pinnedPlaylistIds: current));
  }

  List<Track> get _rediscoverTracks {
    final byId = _stateLibraryById;
    return [
      for (final id in _rediscoverIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  void _openRediscover() {
    // ignore: discarded_futures
    openAppPage(
      context,
      title: 'REDISCOVER',
      skin: widget.state.uiSkin,
      presentation: widget.state.presentation,
      rebuildOn: _routeListenable,

      builder: (_) => LibraryScreen(
        tracks: _rediscoverTracks,
        playlists: null,
        skin: widget.state.uiSkin,
        coverPathFor: _repo.coverPathFor,
        onPlay: _playFromHome,
        onPlayPlaylist: null,
        onCreatePlaylist: (_) {},
        onDeletePlaylist: (_) {},
        headerScrollsAway: true,
      ),
    );
  }

  void _openRecap() {
    _openPage('RECAP — $_recapLabel', (_) => LibraryScreen(
      tracks: _recapTracks,
      playlists: null,
      skin: widget.state.uiSkin,
      coverPathFor: _repo.coverPathFor,
      onPlay: _playFromHome,
      onPlayPlaylist: null,
      onCreatePlaylist: (_) {},
      onDeletePlaylist: (_) {},
      headerScrollsAway: true,
    ));
  }

  void _notePlaylistOpened(String id) {
    final next = [id, ...?_prefs.recentPlaylistIds?.where((e) => e != id)];
    _setPrefs(_prefs.copyWith(recentPlaylistIds: next.take(40).toList()));
  }

  Widget _brandMark() {
    return Image.asset(
      'assets/brand/logo_mark.png',
      fit: BoxFit.contain,
      cacheWidth: 96,
      filterQuality: FilterQuality.medium,
    );
  }

  void _setPrefs(AppPrefs next) {
    final visualiserWasOff = !_prefs.showVisualiser;
    final weatherWasOff = !_prefs.contextWeather;
    final placesWasOff = !_prefs.placesEnabled;
    _shellChanged(() => _prefs = next);
    // ignore: discarded_futures
    _stores.savePrefs(next);
    _applyPrefs();

    // Switching these on asks for the reading now, not at the next tick.
    if (weatherWasOff && next.contextWeather && next.allowNetwork) {
      unawaited(_ctx.refreshWeather());
    }
    if (placesWasOff && next.placesEnabled && next.allowNetwork) {
      unawaited(_ctx.resolvePlaceThenWeather());
    }

    if (visualiserWasOff && next.showVisualiser) {
      unawaited(_loadSpectrum(widget.state.currentTrack?.id));
    }
  }

  void _applyLayoutPref() =>
      widget.state.setLayout(decode.layoutFromPrefs(_prefs.layoutId));

  void _syncPresetToPrefs() {
    _setPrefs(_prefs.copyWith(
      activePresetId: widget.state.preset?.id,
      clearPreset: widget.state.preset == null,
    ));

    _shellChanged(() {});
  }

  void _applyPrefs() {
    _ctx.restartWeatherTimer(_prefs.weatherRefresh);

    _audio?.setCrossfade(_prefs.crossfade);

    widget.state.applyQueuePrefs(
      defaultMode: _prefs.dynamicByDefault,
      refill: _prefs.refillWhenQueueEnds,

      contextEnabled: _prefs.allowNetwork && _prefs.contextMix,
    );
    widget.state.setClockEnabled(_prefs.contextClock);
    widget.state.applyOptionalFeatures(
      learn: _prefs.learnFromSkips,
      autoSkin: _prefs.autoSkin,
      variants: _prefs.weatherVariants,
    );
    _applyLayoutPref();
  }

  StorageAccess _storageAccess = StorageAccess.unknown;

  StorageAccess _notificationAccess = StorageAccess.unknown;

  double _volume = 1.0;
  double _volumeBeforeMute = 1.0;
  bool get _muted => _volume <= 0.0;

  final SleepTimer _sleep = SleepTimer();

  /// Armed from the player, spent on completion, dropped by a manual skip.
  bool _stopAfterTrack = false;

  final ValueNotifier<Duration?> _sleepLeft = ValueNotifier(null);
  AppTab _tab = AppTab.home;

  bool _tabSettled = false;

  List<String> _rediscoverIds = const [];

  bool _libraryListOpen = false;

  int _closeListRequest = 0;

  final _showPlayer = ValueNotifier<bool>(false);

  final _shellTick = ValueNotifier<int>(0);

  bool _disposed = false;

  late final Listenable _routeListenable =
      Listenable.merge([widget.state, _shellTick]);

  void _shellChanged(VoidCallback fn) {
    if (_disposed) return;
    setState(fn);
    _shellTick.value++;
  }

  void _openQueueAsPage() {
    _openPlayerWithPanel(PlayerPanel.queue);
  }

  void _openPlayer() => _openPlayerWithPanel(PlayerPanel.none);

  void _openPlayerWithPanel(PlayerPanel panel) {
    setState(() => _panel = panel);
    final skin = widget.state.uiSkin;
    final presentation = PresentationScope.of(context, fallback: skin);

    final motion = widget.state.motion;
    final route = PageRouteBuilder<void>(
      pageBuilder: (ctx, _, __) => PresentationScope(
        presentation: presentation,
        child: Material(
          color: skin.background,

          child: ListenableBuilder(
            listenable: _routeListenable,
            builder: (_, __) => _playerBody(ctx, widget.state.uiSkin),
          ),
        ),
      ),
      transitionDuration: widget.state.motion.tabTransition,
      reverseTransitionDuration: widget.state.motion.tabTransition,
      transitionsBuilder: (_, animation, _, child) {
        final curve =
            CurvedAnimation(parent: animation, curve: motion.arrivalCurve);
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(

            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          ),
        );
      },
    );

    unawaited(Navigator.of(context, rootNavigator: true).push(route).then((_) {
      _routeAnimation?.removeStatusListener(_onPlayerRouteStatus);
      _routeAnimation = null;
      if (mounted) _showPlayer.value = false;
    }));

    _routeAnimation = route.animation;
    route.animation?.addStatusListener(_onPlayerRouteStatus);
  }

  Animation<double>? _routeAnimation;

  void _onPlayerRouteStatus(AnimationStatus status) {
    if (!mounted) return;
    switch (status) {
      case AnimationStatus.completed:

        if (!_showPlayer.value) _showPlayer.value = true;
      case AnimationStatus.reverse:

        if (_showPlayer.value) _showPlayer.value = false;
      default:
        break;
    }
  }

  void _closePlayer() {
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) {
      nav.pop();
    }

    if (mounted) _showPlayer.value = false;
  }

  PlayContext? get _ctxForHome => _ctx.contextNow();

  Track? _continueTrack;

  List<Track> _jumpBackIn = const [];

  List<Track> _heavyRotation = const [];

  String? get _homeGreeting => switch (_ctxForHome?.band) {
        ContextBand.morning => 'Good morning',
        ContextBand.afternoon => 'Good afternoon',
        ContextBand.evening => 'Good evening',
        ContextBand.night => 'Good night',
        ContextBand.darkHour => 'Late night',
        null => null,
      };

  bool _askedStorage = false;
  bool _askedNotifications = false;

  /// Storage is asked for when the Library opens; notifications wait for first play.
  Future<void> _ensurePlaybackPermissions() async {
    if (!_askedStorage && _storageAccess != StorageAccess.granted) {
      _askedStorage = true;
      _storageAccess = await StoragePermission.request();
      if (mounted) setState(() {});
      // ignore: avoid_print
      print('[Sonarar] storage after request=$_storageAccess');
      // The library was read before the grant, so re-read it now, not next launch.
      if (_storageAccess == StorageAccess.granted) await _rereadLibrary();
    }
  }

  Future<void> _ensureNotificationPermission() async {
    if (_askedNotifications) return;
    _askedNotifications = true;
    _notificationAccess = await StoragePermission.requestNotification();
    if (mounted) setState(() {});
  }

  void _playNowMix() {
    final mix = widget.state.dynamicMix();
    if (mix == null) {
      _toast('Nothing fits right now');
      return;
    }
    widget.state.playPlaylist(mix);
    // ignore: discarded_futures
    _loadCurrentTrack();
  }

  List<Track> _newFromLibrary = const [];

  void _playFromHome(Track t) {
    widget.state.playTrackElsewhere(t);
    // ignore: discarded_futures
    _loadCurrentTrack();
  }

  Future<void> _refreshHomeRails() async {
    final events = await _stores.playLog.read();
    final rails = deriveHomeRails(
      tracks: _repo.tracks,
      events: events,
      now: DateTime.now(),
    );
    if (!mounted) return;
    setState(() {
      _continueTrack = rails.continueListening;
      _jumpBackIn = rails.jumpBackIn;
      _heavyRotation = rails.heavyRotation;
      _recapTracks = rails.recap;
      _newFromLibrary = rails.newFromLibrary;

      _lastEvents = events;
    });
  }

  List<PlaylistPlays> get _libraryPlaylists =>
      rankPlaylistsByPlays(playlists: _genreLists, events: _lastEvents);

  Playlist? get _mostRecentPlaylist {
    final all = widget.state.playlists.all;
    if (all.isEmpty) return null;
    final sorted = [...all]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.first;
  }

  List<Track> _repoIndexSource = const [];
  Map<String, Track>? _repoIndex;
  List<Track> _stateIndexSource = const [];
  Map<String, Track>? _stateIndex;

  Map<String, Track> get _repoTracksById {
    final tracks = _repo.tracks;
    if (_repoIndex == null || !identical(_repoIndexSource, tracks)) {
      _repoIndexSource = tracks;
      _repoIndex = {for (final t in tracks) t.id: t};
    }
    return _repoIndex!;
  }

  Map<String, Track> get _stateLibraryById {
    final library = widget.state.library;
    if (_stateIndex == null || !identical(_stateIndexSource, library)) {
      _stateIndexSource = library;
      _stateIndex = {for (final t in library) t.id: t};
    }
    return _stateIndex!;
  }

  List<Track> get _likedTracks {
    final byId = _repoTracksById;
    return [
      for (final id in widget.state.favorites.orderedIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  void _playPlaylistFromHome(Playlist p) {
    if (!widget.state.playPlaylist(p)) return;
    // ignore: discarded_futures
    _loadCurrentTrack();
  }

  void _openPlaylistPage(Playlist p) {
    _openPage(p.name.toUpperCase(), (_) => _playlistPageBody(p));
  }

  Widget _playlistPageBody(Playlist p) {
    final byId = _repoTracksById;
    final tracks = [
      for (final id in p.trackIds)
        if (byId[id] != null) byId[id]!,
    ];
    // ignore: discarded_futures
    return LibraryScreen(
      tracks: tracks,
      playlists: null,
      skin: widget.state.uiSkin,
      coverPathFor: _repo.coverPathFor,
      onPlay: _playFromHome,
      onPlayPlaylist: null,
      onCreatePlaylist: (_) {},
      onDeletePlaylist: (_) {},

      onAddSongs: () => _addSongsToPlaylist(p),
      headerScrollsAway: true,
    );
  }

  void _addSongsToPlaylist(Playlist playlist) {
    _openPage('ADD TO ${playlist.name.toUpperCase()}', (_) => LibraryScreen(
          tracks: _repo.tracks,
          playlists: null,
          skin: widget.state.uiSkin,
          coverPathFor: _repo.coverPathFor,
          onPlay: (t) {
            final added = widget.state.addTrackToPlaylist(playlist, t.id);

            _toast(added
                ? 'Added to ${playlist.name}'
                : 'Already in ${playlist.name}');
          },
          onPlayPlaylist: null,
          onCreatePlaylist: (_) {},
          onDeletePlaylist: (_) {},
          headerScrollsAway: true,
        ));
  }

  List<Playlist> get _genreLists => [
        for (final p in widget.state.playlists.all)
          if (!isDerivedPlaylistId(p.id) && !p.isEmpty) p,
      ];

  List<Track> _recapTracks = const [];

  static const String _recapLabel = 'THIS MONTH';

  int _libraryEntry = 0;

  TabTravel _travel = TabTravel.none;

  TrackSpectrum? _spectrum;
  late final SpectrumLibrary _spectra =
      SpectrumLibrary(_repo.libraryRoot);

  late final SpectrumBuilder _spectrumBuilder =
      SpectrumBuilder(libraryRoot: _repo.libraryRoot);

  late final AudioRoute _audioRoute = AudioRoute()
    ..onChanged = (list) {
      if (!mounted) return;

      setState(() => _audioOutputs = list);
    };

  List<AudioOutput> _audioOutputs = const [];

  Future<void> _refreshAudioOutputs() async {
    final list = await _audioRoute.outputs();
    if (!mounted) return;
    setState(() => _audioOutputs = list);
  }

  Future<void> _pickAudioOutput() async {
    final ok = await _audioRoute.openSwitcher();
    if (!mounted) return;

    if (!ok) _toast('Could not open the output settings');
  }
  bool _loading = true;



  bool _needsSetup = false;

  bool _playing = false;
  AudioEngine? _audio;
  Timer? _progress;

  final _tickerWanted = ValueNotifier<bool>(false);

  bool get tickerRunning => _progress != null;

  @visibleForTesting
  bool debugWantTicker = false;

  @visibleForTesting
  void debugSyncTicker() => _syncProgressTicker();

  @visibleForTesting
  void debugOpenPanel(PlayerPanel p) => setState(() => _panel = p);

  @visibleForTesting
  void debugOpenPlayer() => _openPlayer();

  @visibleForTesting
  void debugClosePlayer() => _closePlayer();

  @visibleForTesting
  PlayerPanel get debugCurrentPanel => _panel;

  @visibleForTesting
  bool get debugLibraryListOpen => _libraryListOpen;

  @visibleForTesting
  void debugFinishLoading() {
    if (!_loading) return;
    setState(() => _loading = false);
  }

  bool _fileMissing = false;

  bool _skippingMissing = false;

  void _syncProgressTicker() {
    final wanted = _playing || _sleep.isRunning || debugWantTicker;
    _tickerWanted.value = wanted;
    if (wanted && _progress == null) {
      _startProgressTicker();
    } else if (!wanted && _progress != null) {
      _progress!.cancel();
      _progress = null;
    }
  }

  void _startProgressTicker() {
    _progress?.cancel();
    _progress = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final e = _audio;
      if (e == null) return;
      final st = widget.state;

      final now = DateTime.now();
      if (_playing) {
        _sleep.resume(now);
      } else {
        _sleep.pause(now);
      }
      _sleepLeft.value = _sleep.remaining(now);

      if (_playing) {
        st.position.value = e.position;
        _lastPlayedId = st.currentTrack?.id;
        _lastPlayedMs = e.position.inMilliseconds;

        final trackLength = st.currentTrack?.duration;
        st.duration.value = trackLength ?? e.duration;
        _durationOrZero.value = trackLength ?? e.duration ?? Duration.zero;

        unawaited(e.tickLoop());

        final sleep = _sleep.tick(now);
        switch (sleep.action) {
          case SleepAction.fadeTo:
            unawaited(e.setVolume(_volume * sleep.volume));
          case SleepAction.stop:
            unawaited(e.pause());

            unawaited(e.setVolume(_volume));
            widget.state.setSleeping(false);
            if (mounted) {
              setState(() => _playing = false);
              _syncProgressTicker();
            }
          case SleepAction.none:
            break;
        }
      }
    });
  }

  String? _loadedTrackId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    unawaited(_load());
  }

  bool _inFront = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final inFront = state == AppLifecycleState.resumed;
    if (inFront == _inFront) return;
    _inFront = inFront;
    _syncWakelock();

    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (!_loading) _flushState();
    }
  }

  void _syncWakelock() {
    final wanted = _playing && _inFront;
    if (wanted == _wakelockOn) return;
    _wakelockOn = wanted;
    if (wanted) {
      // ignore: discarded_futures
      WakelockPlus.enable();
    } else {
      // ignore: discarded_futures
      WakelockPlus.disable();
    }
  }

  bool _wakelockOn = false;

  Future<void> _swapToVariant(Track target) async {
    final engine = _audio;
    if (engine == null) return;
    if (!widget.state.swapToVariant(target)) return;

    final at = await engine.beginVariantSwap();
    if (!mounted) return;
    final ok = await _loadCurrentTrack(startAt: at, autoPlay: false);
    if (!mounted) return;
    if (ok) {
      await engine.completeVariantSwap(fallbackAt: at);
    } else {
      await engine.abortVariantSwap();
    }
    if (mounted) setState(() {});
  }

  void _publishContext() => widget.state.updateContext(_ctx.contextNow());

  void _onContextMoved() {
    _publishContext();
    if (mounted) setState(() {});
  }

  Future<void> _maybeSwitchOnArrival() async {
    if (widget.state.switchToContextQueue()) {
      await _loadCurrentTrack(autoPlay: _playing);
    }
  }

  Future<void> _resolvePlaceThenWeather() =>
      _ctx.resolvePlaceThenWeather(onArrival: _maybeSwitchOnArrival);

  Future<bool> _loadCurrentTrack({Duration? startAt, bool autoPlay = true}) async {
    final engine = _audio;
    final track = widget.state.currentTrack;
    if (engine == null || track == null) return false;
    final path = _repo.absoluteFor(track);
    if (path == null) return false;

    engine.loop = LoopController(points: _loopPoints[track.id]);

    final effectiveStart = startAt ?? Duration.zero;

    unawaited(engine.setVolume(_volume));

    const chunk = 24;
    final order = widget.state.queue?.order ?? const <Track>[];

    if (order.length < 3) {
      // ignore: avoid_print
      print('[Sonarar][SHORTQUEUE] order=${order.length} track=${track.id} '
          'want=${widget.state.currentTrack?.id}');
      // ignore: avoid_print
      print('[Sonarar][SHORTQUEUE] stack:\n${StackTrace.current}');
    }
    final at = order.indexWhere((t) => t.id == track.id);
    final start = at < 0 ? 0 : (at ~/ chunk) * chunk;
    final window = order.sublist(
      start,
      (start + chunk).clamp(0, order.length),
    );

    ({String path, String title, String artist, String album, Uri? cover}) mk(
        Track t) {
      final p = _repo.absoluteFor(t);
      final c = _repo.coverPathFor(t);
      return (
        path: p ?? '',
        title: t.title,
        artist: t.artist,
        album: t.album,
        cover: (c != null && File(c).existsSync()) ? Uri.file(c) : null,
      );
    }

    final playable = <({String path, String title, String artist, String album, Uri? cover})>[];
    for (final t in window) {
      final e = mk(t);
      if (e.path.isNotEmpty && File(e.path).existsSync()) playable.add(e);
    }
    final idx = playable.indexWhere((e) => e.path == path);

    // ignore: avoid_print
    print('[Sonarar][WINDOW] ${playable.length} of ${window.length} files exist; '
        'want=$path '
        'sample=${window.isEmpty ? "none" : _repo.absoluteFor(window.first) ?? "null"}');

    bool ok;

    if (playable.isEmpty) {
      // ignore: avoid_print
      print('[Sonarar][LOAD] none of the ${window.length} window files exist; '
          'keeping the current queue. first=${window.isEmpty ? "none" : window.first.file}');
      _fileMissing = true;
      return false;
    }

    if (idx < 0) {
      // ignore: avoid_print
      print('[Sonarar][LOAD] not-in-window: window=${window.length} '
          'playable=${playable.length} want=$path '
          'first=${playable.isEmpty ? "none" : playable.first.path}');
      final coverPath = _repo.coverPathFor(track);
      ok = await engine.loadAndPlay(
        path,
        startAt: effectiveStart,
        autoPlay: autoPlay,
        title: track.title,
        artist: track.artist,
        album: track.album,
        coverUri: (coverPath != null && File(coverPath).existsSync())
            ? Uri.file(coverPath)
            : null,
      );
    } else {
      final paths = [for (final e in playable) e.path];
      if (engine.queueMatches(paths)) {
        await engine.seekToIndex(idx);
        if (effectiveStart > Duration.zero) await engine.seek(effectiveStart);
        if (autoPlay && !engine.isPlaying) await engine.play();
        ok = true;
      } else {
        ok = await engine.setQueue(playable, initialIndex: idx);

        if (ok && effectiveStart > Duration.zero) await engine.seek(effectiveStart);
      }

      if (ok) widget.state.queue?.markEngineSynced();
    }
    if (!mounted) return ok;

    _shellChanged(() {
      _fileMissing = !ok;
      if (!ok) {
        // ignore: avoid_print
        print('[Sonarar] could not load the current track — the player will '
            'report it as missing.');

        if (!_skippingMissing) {
          _skippingMissing = true;

          final steppedTo =
              widget.state.queue?.next(wrap: false);
          _skippingMissing = false;
          if (steppedTo != null) {
            // ignore: avoid_print
            print('[Sonarar] stepping over an unloadable track');
            // ignore: discarded_futures
            _loadCurrentTrack(autoPlay: _playing);
            return;
          }
        }
      }

      if (ok) _loadedTrackId = track.id;

      if (!ok) _playing = false;
      _syncProgressTicker();
    });
    return ok;
  }

  DateTime? _lastPhase;
  final Map<String, int> _phaseCosts = {};

  void _boot(double progress, String label) {
    final now = DateTime.now();
    final since = _lastPhase == null ? null : now.difference(_lastPhase!).inMilliseconds;
    _lastPhase = now;
    if (since != null) _phaseCosts[label] = since;
    if (mounted) setState(() {});
    // ignore: avoid_print
    print('[Sonarar] boot ${(progress * 100).round()}% $label'
        '${since == null ? '' : ' (+${since}ms)'}');
    if (progress >= 1.0) {
      final ranked = _phaseCosts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      // ignore: avoid_print
      print('[Sonarar] boot TOTAL '
          '${ranked.fold<int>(0, (sum, e) => sum + e.value)}ms — slowest: '
          '${ranked.take(3).map((e) => '${e.key}=${e.value}ms').join(', ')}');
    }
  }

  Future<void> _load() async {
    _boot(0.02, 'checking permissions');

    _storageAccess = await StoragePermission.status();
    _notificationAccess = await StoragePermission.notificationStatus();
    // ignore: avoid_print
    print('[Sonarar] storage status=$_storageAccess notifications=$_notificationAccess');
    if (mounted) setState(() {});
    // ignore: avoid_print
    print('[Sonarar] storage after request=$_storageAccess');

    _boot(0.18, 'reading your library');
    _musicRoot = await MusicRoot.read();
    _repo.root = _musicRoot;
    await _repo.load();
    _boot(0.52, 'found ${_repo.tracks.length} tracks');
    // ignore: avoid_print
    print('[Sonarar] library root=${_repo.libraryRoot} '
        'from=${_repo.loadedFrom ?? "none"} '
        'tracks=${_repo.tracks.length} '
        'accessDenied=${_repo.accessDenied}');

    _boot(0.60, 'opening your saved state');
    // Deliberately the default root, not the chosen one: plays, playlists and
    // themes are not music, and changing the music folder must not move them.
    _stores = await StateStores.open(libraryRoot: kAndroidLibraryRoot);
    widget.state.libraryRoot = _repo.libraryRoot;

    unawaited(_refreshHomeRails());
    _stateDir = _stores.directory;

    final (loopPoints, excludedIds, marks, favoriteIds, tags, bonds, rules) = await (
      _stores.loopPoints.load(),
      _stores.exclusions.load(),
      _stores.bookmarks.load(),
      _stores.favorites.load(),
      _stores.tags.load(),
      _stores.bonds.load(),
      _stores.rules.load(),
    ).wait;

    _loopPoints = loopPoints;

    _ctx.setPlaces(await _stores.places.load());

    _needsSetup = !File('${_stores.directory}/prefs.json').existsSync();

    _prefs = await _stores.prefs.load();

    widget.state.setPersonalization(await _stores.personalization.load());
    widget.state.onPersonalizationChanged = _stores.personalization.save;

    widget.state.applyQueuePrefs(
      defaultMode: _prefs.dynamicByDefault,
      refill: _prefs.refillWhenQueueEnds,

      contextEnabled: _prefs.allowNetwork && _prefs.contextMix,
    );
    widget.state.setClockEnabled(_prefs.contextClock);
    widget.state.applyOptionalFeatures(
      learn: _prefs.learnFromSkips,
      autoSkin: _prefs.autoSkin,
      variants: _prefs.weatherVariants,
    );
    _applyLayoutPref();
    widget.state.setPlaces(_ctx.placeBook);

    widget.state.setTagOverrides(tags);
    widget.state.setBondState(bonds);
    widget.state.setContextRules(rules);

    widget.state.restoreTrackSets(
      excludedIds: excludedIds.keys,
      bookmarks: marks,
      favoriteIds: favoriteIds.keys,
    );
    _boot(0.74, 'restoring your place');
    final resume = await _stores.snapshot.load();
    widget.state.attachLibrary(_repo.tracks, resume: resume);
    await _refreshArtBundles();
    if (resume != null) {
      widget.state.restoreMode(
        resume.queueMode == 'fixed' ? QueueMode.fixed : QueueMode.dynamic,
      );
    }

    final libraryIds = widget.state.library.map((t) => t.id).toSet();
    widget.state.pruneToLibrary(libraryIds);

    widget.state.setPlaylists(
      await _stores.playlists.load(libraryIds: libraryIds),
    );

    widget.state.onPresetsChanged = _themeSession.touched;
    final loadedPresets = await _stores.themePresets.load();
    final migratedPresets = [
      for (final p in loadedPresets)
        p.personalization == null
            ? p.copyWith(personalization: Personalization.defaults)
            : p,
    ];
    widget.state.setUserPresets(migratedPresets);
    if (migratedPresets.length != loadedPresets.length ||
        loadedPresets.any((p) => p.personalization == null)) {
      // A theme written before themes carried a whole look: give it one now.
      unawaited(_persistPresets());
    }
    final wantedPreset = _prefs.activePresetId;
    if (wantedPreset != null) {
      for (final p in widget.state.allPresets) {
        if (p.id == wantedPreset) {
          widget.state.applyPreset(p);
          break;
        }
      }
    }
    if (_prefs.activePresetId == null) {
      final savedSkin = decode.skinFromPrefs(_prefs.skinId);
      final savedWords = decode.skinFromPrefs(_prefs.languageSkinId);
      if (savedSkin != null || savedWords != null) {
        widget.state.applyPreset(ThemePreset(
          id: 'saved_look',
          name: 'Saved',

          skinId: savedSkin ?? widget.state.skin.id,

          languageSkinId: savedWords,
        ));
      }
    }
    _boot(0.88, 'building playlists');
    _publishContext();
    await _refreshDerivedPlaylists();

    widget.state.addListener(_onStateChanged);
    _downloads.addListener(_onDownloadProblem);

    final savedVolume = resume?.volume;
    if (savedVolume != null) {
      _volume = savedVolume;
      _volumeBeforeMute = savedVolume > 0 ? savedVolume : 1.0;
      widget.state.setRestoredVolume(savedVolume);
    }

    await _audioReady;
    _audio = AudioEngine()..listen();

    _audio!.onPlayingChanged = (playing) {
      if (playing) unawaited(_ensureNotificationPermission());
      if (mounted && _playing != playing) {
        setState(() => _playing = playing);

        _syncProgressTicker();

        _syncWakelock();
      }
    };

    _audio!.onSourceChanged = _onEngineSourceChanged;

    unawaited(_audio!.configureAudioSession());

    _audio!.onCompleted = () {
      final finished = widget.state.currentTrack;

      if (_stopAfterTrack) {
        _stopAfterTrack = false;
        if (finished != null) _closeOutPlay(finished);
        widget.state.stopAtEnd();
        if (mounted) setState(() => _playing = false);
        _syncProgressTicker();
        return;
      }

      switch (widget.state.autoAdvanceAction()) {
        case AutoAdvance.next:
          widget.state.advance(automatic: true);
          // ignore: discarded_futures
          _loadCurrentTrack();
        case AutoAdvance.replay:

          if (finished != null) _closeOutPlay(finished);
          // ignore: discarded_futures
          _loadCurrentTrack(autoPlay: true);
        case AutoAdvance.stop:

          if (widget.state.refillWhenQueueEnds && widget.state.refillFromContext()) {
            // ignore: discarded_futures
            _loadCurrentTrack(autoPlay: true);
            break;
          }

          widget.state.stopAtEnd();
          if (mounted) setState(() => _playing = false);
          _syncProgressTicker();
      }
    };

    widget.state.onRepeatChanged = () {
      // ignore: discarded_futures
      _audio?.setRepeatMode(widget.state.repeatMode);
    };

    final resumeAt = (resume != null && !resume.isStale && resume.positionMs > 0)
        ? Duration(milliseconds: resume.positionMs)
        : null;
    final autoStart = _prefs.resumeOnLaunch && resumeAt != null;

    _openTrack = widget.state.currentTrack;

    unawaited(_loadSpectrum(widget.state.currentTrack?.id));

    final loaded =
        await _loadCurrentTrack(startAt: resumeAt, autoPlay: autoStart);

    if (const bool.fromEnvironment('personar_audiotest')) {
      final engine = _audio;
      final t = widget.state.currentTrack;
      // ignore: avoid_print
      print('[Sonarar][AUDIO] loaded=$loaded track=${t?.title ?? "none"} '
          'path=${t == null ? "n/a" : _repo.absoluteFor(t)}');

      if (engine != null && loaded) {
        final t = widget.state.currentTrack;
        final path = _repo.absoluteFor(t!)!;
        // ignore: avoid_print
        print('[Sonarar][AUDIO] probe path=$path');
        unawaited(engine.play());
        for (var i = 1; i <= 8; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          // ignore: avoid_print
          print('[Sonarar][AUDIO] +${i}s playing=${engine.isPlaying} '
              'pos=${engine.position.inMilliseconds}ms '
              'dur=${engine.duration?.inMilliseconds ?? -1}ms');
        }
        await engine.pause();

        widget.state.nextTrack();
        await Future<void>.delayed(const Duration(milliseconds: 900));
        final t2 = widget.state.currentTrack;
        await engine.play();
        for (var i = 1; i <= 4; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          // ignore: avoid_print
          print('[Sonarar][AUDIO] NEXT +${i}s title=${t2?.title ?? "none"} '
              'playing=${engine.isPlaying} '
              'pos=${engine.position.inMilliseconds}ms');
        }
      }
    }

    _publishContext();
    unawaited(_resolvePlaceThenWeather());
    _applyPrefs();

    _ctx.startTimers(weatherRefresh: _prefs.weatherRefresh);

    // ignore: avoid_print
    print('[Sonarar] library=${_repo.tracks.length} '

        'from=${_repo.loadedFrom ?? "none"} '
        'resume=${resume == null ? "none" : (resume.isStale ? "stale" : resume.trackId)} '
        'track=${widget.state.currentTrack?.id ?? "none"} '
        'art=${widget.state.art?.key ?? "none"} '
        'band=${widget.state.playlistContext?.band.name ?? "none"} '
        'playlist=${widget.state.queue?.length ?? 0} '

        'storage=${_storageAccess.name} '
        'volume=${_volume.toStringAsFixed(2)} '
        'shuffle=${widget.state.queue?.isShuffled ?? false}');

    if (!mounted) return;

    _boot(1.0, 'ready');
    setState(() {
      _loading = false;
      if (!_tabSettled) {
        _tabSettled = true;
        if (_tab == AppTab.home && !_homeAvailable) _tab = AppTab.library;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ArtWarmer(
          context: context,
          state: widget.state,
          cover: _coverProvider,
        ).warm());
      }
    });

    if (_askedStorage && _storageAccess == StorageAccess.denied) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _toast('Sonarar cannot read your music folder — '
              'grant access in Settings → Apps → Sonarar → Permissions');
        }
      });
    }
  }

  Future<void> _togglePlay() async {
    final engine = _audio;
    if (engine == null) return;
    if (_playing) {
      await engine.pause();

      if (mounted) _shellChanged(() => _playing = false);
      return;
    }

    if (widget.state.queueEnded) {
      // Parked at the queue's end: play() alone reads as a dead button.
      final id = widget.state.currentTrack?.id;
      if (id != null) widget.state.playTrackNow(id);
      final started = await _loadCurrentTrack(startAt: Duration.zero);
      if (mounted) _shellChanged(() => _playing = started);
      _syncProgressTicker();
      return;
    }

    if (!engine.isPlaying && _loadedTrackId != widget.state.currentTrack?.id) {
      final started = await _loadCurrentTrack();
      if (mounted) _shellChanged(() => _playing = started);
      return;
    }
    await engine.play();
    if (mounted) _shellChanged(() => _playing = true);
    _syncProgressTicker();
  }

  bool _skipPending = false;

  Future<void> _skipNext() async {
    final engine = _audio;
    if (engine == null || _skipPending) return;
    // A skip is a request to move on, not to stop where we land.
    if (_stopAfterTrack) setState(() => _stopAfterTrack = false);

    if (!engine.hasNext) {
      if (canStepOutsideEngine(
        widget.state.queue,
        repeatAll: widget.state.repeatMode == playqueue.RepeatMode.all,
        forward: true,
      )) {
        _skipPending = true;

        try {
          widget.state.nextTrack();
          await _loadCurrentTrack();
        } finally {
          _skipPending = false;
        }
      }
      return;
    }
    _skipPending = true;
    try {
      await engine.skipNext();
    } finally {
      _skipPending = false;
    }
  }

  Future<void> _skipPrevious() async {
    final engine = _audio;
    if (engine == null || _skipPending) return;
    if (_stopAfterTrack) setState(() => _stopAfterTrack = false);
    if (!engine.hasPrevious) {
      if (canStepOutsideEngine(
        widget.state.queue,
        repeatAll: widget.state.repeatMode == playqueue.RepeatMode.all,
        forward: false,
      )) {
        _skipPending = true;

        try {
          widget.state.previousTrack();
          await _loadCurrentTrack();
        } finally {
          _skipPending = false;
        }
      }
      return;
    }
    _skipPending = true;
    try {
      await engine.skipPrevious();
    } finally {
      _skipPending = false;
    }
  }

  Future<void> _persistPlaces(PlaceBook book) async {
    await _stores.savePlaces(book);
  }

  @override
  void dispose() {
    _disposed = true;
    _downloads.removeListener(_onDownloadProblem);
    _themeSession.dispose();
    _tickerWanted.dispose();

    _shellTick.dispose();

    // ignore: discarded_futures
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);

    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
      _flushState();
    }

    _ctx.dispose();
    _durationOrZero.dispose();
    _progress?.cancel();

    _routeAnimation?.removeStatusListener(_onPlayerRouteStatus);
    _routeAnimation = null;

    unawaited(_audio?.dispose() ?? Future<void>.value());
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  final ValueNotifier<Duration> _durationOrZero = ValueNotifier(Duration.zero);

  String? _lastPlayedId;
  int _lastPlayedMs = 0;

  void _toggleSleep(Duration? for_) {
    if (_sleep.isRunning || for_ == null) {
      _sleep.cancel();

      _sleepLeft.value = null;
      widget.state.setSleeping(false);
      _syncProgressTicker();
      // Restore the slider level, not 1.0, or cancelling a fade jumps to max.
      unawaited(_audio?.setVolume(_volume) ?? Future<void>.value());

      if (mounted) _shellChanged(() {});
      return;
    }
    _sleep.start(DateTime.now(), for_);

    widget.state.setSleeping(true);

    _syncProgressTicker();

    if (mounted) _shellChanged(() {});
  }

  PlayerPanel _panel = PlayerPanel.none;

  final List<_InlineDoor> _inline = [];

  bool _panelMax = false;

  Track? _openTrack;

  List<Track>? _pathIndexFor;
  Map<String, String> _pathIndex = const {};

  String? _trackIdForPath(String path) {
    final library = widget.state.library;
    if (!identical(_pathIndexFor, library)) {
      _pathIndexFor = library;
      _pathIndex = {
        for (final t in library)
          if (_repo.absoluteFor(t) case final p?) p: t.id,
      };
    }
    return _pathIndex[path];
  }

  void _onEngineSourceChanged(String path) {
    final id = _trackIdForPath(path);
    if (id == null) return;

    final platformMoved = _audio?.sourceChangeWasPlatformInitiated ?? false;
    _audio?.clearPlatformSourceChange();

    if (id == widget.state.currentTrack?.id) return;

    widget.state.playTrackNow(id, reload: !platformMoved);
    _openTrack = widget.state.currentTrack;
    if (mounted) setState(() {});
  }

  void _onTrackChanged() {
    final next = widget.state.currentTrack;
    final prev = _openTrack;
    final changed = prev != null && prev.id != next?.id;

    _openTrack = next;

    if (!changed) return;

    _closeOutPlay(prev);

    if (shouldAdvanceArt(
      enabled: _prefs.cycleCharacterArt,
      trackChanged: changed,
      alreadyCycling: _cyclingArt,
    )) {
      _cyclingArt = true;
      try {
        widget.state.cycleArtForTrack();
      } finally {
        _cyclingArt = false;
      }
    }

    if (_prefs.showVisualiser) unawaited(_loadSpectrum(next?.id));

    // ignore: discarded_futures
    _refreshHomeRails();

    // ignore: discarded_futures
    _loadLyrics();
  }

  final _spectrumLoad = LatestLoad<String>();

  Future<void> _loadSpectrum(String? trackId) async {
    _spectrumLoad.start(trackId ?? '');
    if (trackId == null) {
      if (mounted) setState(() => _spectrum = null);
      return;
    }
    var loaded = await _spectra.load(trackId);

    if (loaded == null) {
      final track = _trackById(trackId);
      final audioPath = track == null ? null : _repo.absoluteFor(track);
      if (track != null && audioPath != null) {
        final built = await _spectrumBuilder.ensure(
          trackId: trackId,
          audioPath: audioPath,
        );

        if (built) {
          _spectra.forget(trackId);
          loaded = await _spectra.load(trackId);
        }
      }
    }

    if (!mounted || !_spectrumLoad.isLatest(trackId)) return;
    setState(() => _spectrum = loaded);
  }

  Track? _trackById(String id) {
    for (final t in widget.state.library) {
      if (t.id == id) return t;
    }
    final q = widget.state.queue;
    if (q == null) return null;
    if (q.current?.id == id) return q.current;
    for (final t in q.upcoming) {
      if (t.id == id) return t;
    }
    return null;
  }

  bool _cyclingArt = false;

  void _closeOutPlay(Track track) {
    final engine = _audio;
    if (engine == null) return;

    if (_closingOutPlay) return;
    _closingOutPlay = true;
    try {
      _closeOutPlayInner(track);
    } finally {
      _closingOutPlay = false;
    }
  }

  bool _closingOutPlay = false;

  void _closeOutPlayInner(Track track) {
    final engine = _audio;
    if (engine == null) return;

    final at = _lastPlayedId == track.id
        ? Duration(milliseconds: _lastPlayedMs)
        : engine.position;
    widget.state.recordPlayOutcome(
      track: track,
      positionWhenStopped: at,
      skipThreshold: _prefs.skipThreshold,
    );

    final event = widget.state.playEventFor(
      track: track,
      positionWhenStopped: at,
    );
    if (event != null && at > Duration.zero && _prefs.recordHistory) {
      unawaited(_appendThenRefresh(event));
    }
  }

  void _persistListsNow() => _stores.saveListsNow(widget.state.playlists);

  void _persistLists() {
    // ignore: discarded_futures
    _stores.saveLists(
      excludedIds: widget.state.exclusions.ids,
      bookmarks: widget.state.bookmarks.all,
      favoriteIds: widget.state.favorites.ids,
    );
  }

  void _playNext(Track track) {
    if (widget.state.playNextInQueue(track)) {
      // ignore: discarded_futures
      _loadCurrentTrack();
      if (mounted) setState(() {});
    }
  }

  void _onShortcut(ShortcutCommand command) {
    final state = widget.state;
    switch (command) {
      case ShortcutCommand.playPause:
        // ignore: discarded_futures
        _togglePlay();

      case ShortcutCommand.nextTrack:

        // ignore: discarded_futures
        _skipNext();

      case ShortcutCommand.previousTrack:
        // ignore: discarded_futures
        _skipPrevious();

      case ShortcutCommand.volumeUp:
        _setVolume(_volume + kVolumeStep);
      case ShortcutCommand.volumeDown:
        _setVolume(_volume - kVolumeStep);

      case ShortcutCommand.mute:
        if (_muted) {
          _setVolume(_volumeBeforeMute <= 0 ? 1.0 : _volumeBeforeMute);
        } else {
          _volumeBeforeMute = _volume;
          _setVolume(0);
        }

      case ShortcutCommand.seekForward:
        _seekBy(kSeekStep);
      case ShortcutCommand.seekBackward:
        _seekBy(-kSeekStep);

      case ShortcutCommand.shuffle:
        state.toggleShuffle();
        if (mounted) setState(() {});

      case ShortcutCommand.repeat:
        state.cycleRepeat();
        if (mounted) setState(() {});

      case ShortcutCommand.openSearch:
      case ShortcutCommand.filter:

        _searchRequest += 1;
        if (mounted) setState(() => _goToTab(AppTab.library));

      case ShortcutCommand.back:
      case ShortcutCommand.forward:

        _navigateHistory(command == ShortcutCommand.forward);

      case ShortcutCommand.openQueue:

        if (mounted) {
          setState(() {
            _showPlayer.value = true;
            _panel = PlayerPanel.queue;
            _panelMax = true;
          });
        }

      case ShortcutCommand.cycleTab:

        if (mounted) {
          setState(() {
            final visible = _visibleTabs;
            final next = (visible.indexOf(_tab) + 1) % visible.length;
            _goToTab(visible[next]);
          });
        }
    }
  }

  int _searchRequest = 0;

  bool _lyricsMode = false;

  Lyrics? _lyrics;

  final _lyricsLoad = LatestLoad<String>();

  Map<int, String> _romaji = const {};

  late final LyricsService _lyricsService = LyricsService(

    cacheDirectory: _stores.directory,
  );

  final ScrollController _lyricsScroll = ScrollController();

  Future<void> _loadLyrics() async {
    final track = widget.state.currentTrack;
    if (track == null) {
      if (mounted) {
        setState(() {
          _lyrics = null;
          _romaji = const {};
        });
      }
      return;
    }
    if (_lyricsLoad.isLatest(track.id)) return;
    _lyricsLoad.start(track.id);

    final result = await _lyricsService.forTrack(
      trackId: track.id,
      title: track.title,
      artist: track.artist,
      instrumental: _isInstrumental(track),
      // Length is the tie-breaker between the studio take and a live version.
      duration: track.duration,
    );

    if (!mounted || !_lyricsLoad.isLatest(track.id)) return;

    final found = result;
    if (found == null) {
      setState(() {
        _lyrics = null;
        _romaji = const {};
      });
      return;
    }

    final romaji = _prefs.showRomaji
        ? await Romaji.precompute([for (final l in found.lines) l.text])
        : const <int, String>{};
    if (!mounted || !_lyricsLoad.isLatest(track.id)) return;
    setState(() {
      _lyrics = found;
      _romaji = romaji;
    });
  }

  bool _isInstrumental(Track track) => track.variantTag == 'instrumental';

  String? _artistRequest;

  void _openArtist(String artist) {
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) nav.pop();
    setState(() {
      _showPlayer.value = false;
      _artistRequest = artist;
      _rememberTab(AppTab.library);
      _goToTab(AppTab.library);
    });
  }

  void _setVolume(double v) {
    final clamped = v.clamp(0.0, 1.0);
    if (clamped > 0) _volumeBeforeMute = clamped;

    _volume = clamped;
    _shellTick.value++;
    unawaited(_audio?.setVolume(clamped) ?? Future<void>.value());
  }

  void _seekBy(Duration delta) {
    final engine = _audio;
    if (engine == null) return;
    final total = widget.state.duration.value;
    final from = widget.state.position.value;
    var target = from + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (total != null && target > total) target = total;
    unawaited(engine.seek(target));
  }

  final List<AppTab> _history = [];
  int _historyAt = -1;

  void _rememberTab(AppTab tab) {
    if (_historyAt >= 0 && _history[_historyAt] == tab) return;

    if (_historyAt < _history.length - 1) {
      _history.removeRange(_historyAt + 1, _history.length);
    }
    _history.add(tab);
    _historyAt = _history.length - 1;
  }

  void _navigateHistory(bool forward) {
    final next = _historyAt + (forward ? 1 : -1);
    if (next < 0 || next >= _history.length) {
      _toast(forward ? 'No further forward' : 'No earlier tab');
      return;
    }
    _historyAt = next;
    setState(() => _goToTab(_history[next]));
  }

  Future<void> _pickPlaylistFor(Track track) async {
    final lists = widget.state.playlists.all;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: widget.state.uiSkin.background,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Text(
                  'Add to playlist',
                  style: TextStyle(
                    fontSize: LayoutSpec.fontSmall,
                    fontWeight: FontWeight.w900,
                    color: widget.state.skin.textPrimary,
                  ),
                ),
              ),
              for (final p in lists)
                ListTile(
                  title: Text(
                    p.name,
                    style: TextStyle(color: widget.state.skin.textPrimary),
                  ),

                  subtitle: Text(
                    p.contains(track.id) ? 'Already in this playlist'
                        : '${p.length} tracks',
                    style: TextStyle(color: widget.state.skin.textSecondary),
                  ),
                  onTap: () => Navigator.of(ctx).pop(p.id),
                ),
              ListTile(
                leading: Icon(Icons.add_rounded, color: widget.state.skin.accent),
                title: Text('New playlist',
                    style: TextStyle(color: widget.state.skin.accent)),
                onTap: () => Navigator.of(ctx).pop('__new__'),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == null) return;

    if (choice == '__new__') {
      final name = await _askPlaylistName();
      if (name == null) return;

      final created = widget.state.createPlaylist(name);
      widget.state.addTrackToPlaylist(created, track.id);
      await _persistPlaylists();
      _toast('Created "$name" with ${track.title}');
      return;
    }

    final playlist = widget.state.playlists.byId(choice);
    if (playlist == null) return;
    final added = playlist.add(track.id);
    await _persistPlaylists();
    if (mounted) setState(() {});
    _toast(added
        ? 'Added to ${playlist.name}'
        : 'Already in ${playlist.name}');
  }

  Future<String?> _askPlaylistName() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.state.uiSkin.background,
        title: Text('New playlist',
            style: TextStyle(color: widget.state.skin.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: widget.state.skin.textPrimary),
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = (name ?? '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  late final ThemeSession _themeSession =
      ThemeSession(save: (presets) => _stores.themePresets.save(presets));

  Future<void> _persistPresets() =>
      _stores.themePresets.save(widget.state.userPresets);

  Future<void> _persistPlaylists() =>
      _stores.savePlaylists(widget.state.playlists);

  void _queueFromDrag(Track track) {
    if (widget.state.queue == null) {
      // ignore: discarded_futures
      unawaited(_ensurePlaybackPermissions());
      widget.state.playTrack(track);
      _toast('Playing from — ${track.title}');
      setState(() {});
      return;
    }
    final ok = widget.state.addToQueue(track);
    _toast(ok ? 'Added to queue — ${track.title}' : 'Already in the queue');
  }

  void _toastUndo(String message, VoidCallback undo) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: widget.state.uiSkin.accent,
          onPressed: undo,
        ),
      ));
  }

  String? _shownDownloadError;

  /// A download that dies on a blocked folder otherwise only reaches the log,
  /// which is the one place nobody looks. Say it, and offer the fix.
  void _onDownloadProblem() {
    final error = _downloads.lastError;
    if (!mounted) return;
    if (error == null) {
      _shownDownloadError = null;
      return;
    }
    if (error == _shownDownloadError) return;
    _shownDownloadError = error;
    _toastAction(error, 'SETTINGS', () {
      unawaited(StoragePermission.request());
      _downloads.clearError();
      _shownDownloadError = null;
    });
  }

  void _toastAction(String message, String label, VoidCallback action) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: label,
          textColor: widget.state.uiSkin.accent,
          onPressed: action,
        ),
      ));
  }

  void _toast(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _openLibraryManagement(Track track) {
    unawaited(showModalBottomSheet<void>(
      context: context,
      backgroundColor: widget.state.uiSkin.background,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => LibraryManagementPanel(
        state: widget.state,
        track: track,
        onPlayNow: () {
          Navigator.of(ctx).pop();
          widget.state.playTrackNow(track.id);
          // ignore: discarded_futures
          _loadCurrentTrack();
        },
        onPlayNext: () {
          Navigator.of(ctx).pop();
          _playNext(track);
        },
        playlists: widget.state.playlists.all,
        onAddToPlaylist: () {
          Navigator.of(ctx).pop();
          // ignore: discarded_futures
          _pickPlaylistFor(track);
        },
        onFixTags: () {
          Navigator.of(ctx).pop();
          // ignore: discarded_futures
          _openTagEditor(track);
        },

        onRemoveDownload: isDownloaded(track)
            ? () async {
                final root = _repo.libraryRoot;
                if (root == null) {
                  _toast('The library is not resolved yet');
                  return;
                }
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    backgroundColor: widget.state.uiSkin.background,
                    title: Text('REMOVE "${track.title}"?',
                        style: TextStyle(fontSize: 18, color: widget.state.skin.textPrimary)),
                    content: Text(
                      'This deletes the file from the phone. It is a download, so nothing else has a copy.',
                      style: TextStyle(fontSize: 16, color: widget.state.skin.textSecondary),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(d).pop(false),
                          child: Text('KEEP',
                              style: TextStyle(color: widget.state.skin.accent))),
                      TextButton(
                          onPressed: () => Navigator.of(d).pop(true),
                          child: Text('REMOVE',
                              style: TextStyle(color: widget.state.skin.textSecondary))),
                    ],
                  ),
                );
                if (ok != true) return;
                final freed = await removeDownload(
                  track: track,
                  libraryRoot: root,
                  manifest: File('$root${Platform.pathSeparator}$kManifestFileName'),
                );

                if (widget.state.currentTrack?.id == track.id) {
                  await _audio?.pause();
                }

                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                _toast(freed == null
                    ? 'Could not remove it'
                    : 'Removed — ${(freed / 1048576).toStringAsFixed(1)} MB freed');
                unawaited(_reloadLibraryAfterDownload());
              }
            : null,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    ));
  }

  void _openNeverInShuffle() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NeverInShuffleScreen(
        state: widget.state,
        tracks: _repo.tracks,
      ),
    ));
  }

  String? _coverTrackId;
  ImageProvider? _coverCache;

  ImageProvider? _coverProvider() {
    final t = widget.state.currentTrack;
    if (t == null) {
      _coverTrackId = null;
      _coverCache = null;
      return null;
    }

    final path = _repo.coverPathFor(t);
    if (t.id == _coverTrackId && (_coverCache != null || path == null)) {
      return _coverCache;
    }

    _coverTrackId = t.id;

    _coverCache = (path == null || !File(path).existsSync())
        ? null
        : FileImage(File(path));
    return _coverCache;
  }



  /// The library is written in scan order, so what arrived last is at the end.
  /// Newest ten, newest first — enough for a rail, cheap enough to build on
  /// every frame without touching the disk.
  List<Track> get _recentTracks {
    final all = _repo.tracks;
    final out = <Track>[];
    for (var i = all.length - 1; i >= 0 && out.length < 10; i--) {
      out.add(all[i]);
    }
    return out;
  }

  List<PlayEvent> _lastEvents = const [];

  Future<void> _rebuildEngineQueueKeepingPosition() async {
    final engine = _audio;
    if (engine == null) return;

    final wasAt = engine.position;
    final wasPlaying = _playing;
    await _loadCurrentTrack(startAt: wasAt, autoPlay: wasPlaying);
  }

  Future<void> _refreshArtBundles() async {
    final found = scanArtBundles(_repo.libraryRoot);
    // One line, so "no art folders" can be told apart from "art folders the app
    // cannot see" without a debugger on the phone.
    debugPrint('[Sonarar][ART] bundles=${found.length} '
        '(${found.map((b) => b.name).join(",")}) root=${_repo.libraryRoot}');
    widget.state.setArtBundles(found);
  }

  Future<void> _rereadLibrary() async {
    await _repo.load();
    if (!mounted) return;
    widget.state.attachLibrary(_repo.tracks);
    await _refreshArtBundles();
    await _refreshDerivedPlaylists();
    if (mounted) setState(() {});
  }

  Future<void> _reloadLibraryAfterDownload() async {
    final before = widget.state.library.length;
    await _rereadLibrary();
    if (!mounted) return;
    final after = widget.state.library.length;
    _toast(after == before
        ? 'Downloaded — it is not in the library manifest yet'
        : 'Added to the library');
  }

  void _openHistory() {
    final log = _stores.playLog;
    // ignore: discarded_futures
    log.read().then((events) {
      if (!mounted) return;
      setState(() => _lastEvents = events);
      _openPage('HISTORY', (_) => _historyPage(widget.state.uiSkin));
    });
  }

  Widget _historyPage(Skin skin) => HistoryScreen(
        contextEnabled: _prefs.allowNetwork,
        skin: skin,
        events: _lastEvents,
        tracks: _repo.tracks,
        ranks: (_prefs.personaLayer ? BondsScreen(
          state: widget.state,
          events: _lastEvents,
          tracks: _repo.tracks,
          onNoteSaved: _bondsCallbacks().noteSaved,
          onReset: _bondsCallbacks().reset,
        ) : const SizedBox.shrink()),
      );

  String? _dynamicBlurb() {
    final ctx = widget.state.playlistContext;
    if (ctx == null) return null;

    final place = _ctx.currentPlaceId == null ? null : _ctx.placeBook.byId(_ctx.currentPlaceId!);
    return dynamicBlurb(
      band: ctx.band,
      raining: ctx.raining,
      snowing: _ctx.weatherReading?.condition == WeatherCondition.snow,
      placeName: place?.name,
      mode: ctx.mode,

      preciseFix: _ctx.hasFix &&
          fixCanTellPlacesApart(_ctx.place!.source, _ctx.place!.accuracyMetres),
    );
  }

  Future<void> _appendThenRefresh(PlayEvent event) async {
    await _stores.playLog.append(event);
    if (!mounted) return;
    await _refreshDerivedPlaylists();
  }

  Future<void> _refreshDerivedPlaylists() async {
    final log = _stores.playLog;
    final events = await log.read();
    if (!mounted) return;
    final lists = buildRediscovery(
      library: widget.state.library,
      events: events,
      favorites: widget.state.favorites.ids,
    );
    final dyn = widget.state.dynamicMix();

    final variants = variantsPlaylist(widget.state.library);
    final downloaded = downloadedPlaylist(widget.state.library);

    final rediscover = [
      for (final l in lists)
        if (l.playlist.id == kRediscoverId) ...l.playlist.trackIds,
    ];
    _rediscoverIds = rediscover;
    widget.state.setDerivedPlaylists([

      if (dyn != null) dyn,

      if (variants != null) variants,
      downloaded,
      for (final l in lists)
        if (l.usable) l.playlist,
    ]);

    final counts = <String, (int, int)>{};
    for (final e in events) {
      if (!isCountedPlay(e)) continue;
      final prev = counts[e.trackId] ?? (0, 0);
      counts[e.trackId] = (
        prev.$1 + 1,
        prev.$2 + (e.completed ? 1 : 0),
      );
    }
    if (mounted) setState(() => _playCounts = counts);
  }

  Future<void> _openTagEditor(Track track) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: widget.state.uiSkin.background,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TagEditorSheet(
        state: widget.state,
        track: track,
        onChanged: () {
          // ignore: discarded_futures
          _persistTags();
          if (mounted) setState(() {});
        },
      ),
    );
  }

  void _openSettingsPage() {
    _openPage(
      'SETTINGS',
      (_) => SettingsScreen(
        state: widget.state,
        section: SettingsSection.behaviour,
        musicRoot: _musicRoot,
        stateDirectory: _stores.directory,
        downloadDirectory: _backupDirectory,
        appVersion: '$appVersionName+$appVersionCode',
        onOpenMusicFolder: _openMusicFolder,
        prefs: _prefs,
        onPrefsChanged: _setPrefs,
        onContextsChanged: () {
          _syncPresetToPrefs();

          _shellChanged(() {});
        },
        weather: _ctx.weatherReading?.condition ?? WeatherCondition.unknown,

        showTitle: false,
        onOpenDiagnostics: _openDiagnosticsPage,
        onOpenPersonalize: _openPersonalizePage,
        onDeletePreset: (p) {
          widget.state.setUserPresets([
            for (final x in widget.state.userPresets)
              if (x.id != p.id) x,
          ]);
          if (widget.state.preset?.id == p.id) widget.state.clearPreset();
          // ignore: discarded_futures
          _persistPresets();

          _shellChanged(() {});
        },
      ),
    );
  }

  Future<void> _openMusicFolder() async {
    final chosen = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => MusicFolderScreen(
          skin: widget.state.uiSkin,
          current: _musicRoot,
        ),
      ),
    );
    if (chosen == null || chosen == _musicRoot) return;
    await MusicRoot.write(chosen);
    if (!mounted) return;
    final restart = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.state.uiSkin.panel,
        title: Text('Music folder saved',
            style: TextStyle(color: widget.state.uiSkin.textPrimary)),
        content: Text(
          'Sonarar reads the library once at launch, so it will load $chosen '
          'next time it opens.',
          style: TextStyle(color: widget.state.uiSkin.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('LATER'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('RESTART NOW'),
          ),
        ],
      ),
    );
    if (restart == true) await SystemNavigator.pop();
  }

  void _openPersonalizePage() {
    unawaited(Navigator.of(context)
        .push(MaterialPageRoute<void>(
      builder: (_) => PresentationScope(
        presentation: widget.state.presentation,
        child: PersonalizeScreen(
          state: widget.state,
          greeting: _homeGreeting,
          prefs: _prefs,
          onPrefsChanged: _setPrefs,
          onApplyTheme: (preset) {
            widget.state.applyPreset(preset);
            final layout = preset.layoutId;
            if (layout != null) {
              _setPrefs(_prefs.copyWith(layoutId: layout));
            }
          },
          onDeleteTheme: (preset) {
            widget.state.setUserPresets([
              for (final x in widget.state.userPresets)
                if (x.id != preset.id) x,
            ]);
            // ignore: discarded_futures
            _persistPresets();
          },
          onSaveTheme: (name) {
            Navigator.of(context).pop();
            _saveThemeByName(name);
          },
        ),
      ),
    ))
        .whenComplete(() => unawaited(_themeSession.flush())));
  }

  /// Same shape as the preset the Settings tile writes, so a look saved from
  /// PERSONALIZE and one saved from THEME are the same kind of object.
  void _saveThemeByName(String name) {
    final made = ThemePreset(
      id: freshPresetId({for (final p in widget.state.allPresets) p.id}),
      name: name,
      skinId: widget.state.skin.id,
      artSkinId: widget.state.artSkinOverride,
      languageSkinId: widget.state.languageSkin.id == widget.state.skin.id
          ? null
          : widget.state.languageSkin.id,
      layoutId: widget.state.layoutId.name,
      personalization: widget.state.personalization,
    );
    widget.state.setUserPresets([...widget.state.userPresets, made]);
    widget.state.applyPreset(made);
    // ignore: discarded_futures
    _persistPresets();
    _shellChanged(() {});
  }

  void _openDiagnosticsPage() {
    _openPage(
      'DIAGNOSTICS',

      (_) => _doors[_InlineDoor.diagnostics]!.build(widget.state.uiSkin),
    );
  }

  void _openArchivePage() {
    _openPage(
      widget.state.languageSkin.word(WordKey.libraryRoom, 'LIBRARY TOOLS'),
      (_) => ArchiveScreen(
        state: widget.state,
        onOpenTagEditor: _openTagEditor,
        compendiumEntries: buildCompendium(
          tracks: _repo.tracks,
          events: _lastEvents,
        ).entries,
        playingTrackId: widget.state.currentTrack?.id,
        onSummon: (t) {
          widget.state.playNextInQueue(t);
          _toast('${t.title} — next');
        },
        onOpenBonds: _openBonds,
        onOpenRules: _openRules,
      ),
    );
  }

  void _openArchive() => _openArchivePage();

  void _openPlacesPage() {
    _openPage('PLACES', (_) => _placesBody(widget.state.uiSkin));
  }

  Widget _placesBody(Skin skin, {bool inline = false}) => PlacesScreen(
        skin: skin,
        places: _ctx.placeBook,
        here: _ctx.place,
        poiService: _ctx.poi,
        kinds: _ctx.placeKinds,
        inline: inline,

        playlists: [for (final p in widget.state.playlists.all) p.name],
        onChanged: (book) {
          // ignore: discarded_futures
          _persistPlaces(book);

          widget.state.setPlaces(book);
          setState(() => _ctx.setPlaces(book));
        },
        onRefreshPosition: () {
          // ignore: discarded_futures
          _resolvePlaceThenWeather();
        },
      );

  void _openBonds() {
    _openDoor(_InlineDoor.bonds);
  }

  void _openRules() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RulesEditorScreen(
        state: widget.state,
        onChanged: () {
          // ignore: discarded_futures
          _persistRules();

          // ignore: discarded_futures
          _loadCurrentTrack();
          setState(() {});
        },
      ),
    ));
  }

  Future<void> _persistTags() => _stores.saveTags(widget.state.tagOverrides);

  Future<void> _persistBonds() => _stores.saveBonds(widget.state.bondState);

  ({void Function() noteSaved, void Function() reset}) _bondsCallbacks({
    String? resetToast,
  }) =>
      (
        noteSaved: () {
          // ignore: discarded_futures
          _persistBonds();
        },
        reset: () {
          widget.state.resetBonds();
          // ignore: discarded_futures
          _persistBonds();
          if (resetToast != null) _toast(resetToast);
        },
      );

  Future<void> _persistRules() => _stores.saveRules(widget.state.contextRules);

  Widget? _whyContent() => WhyBody(
        state: widget.state,
        placeName: _ctx.currentPlaceId == null
            ? null
            : _ctx.placeBook.byId(_ctx.currentPlaceId!)?.name,
        preciseFix: _ctx.hasFix &&
            fixCanTellPlacesApart(_ctx.place!.source, _ctx.place!.accuracyMetres),
        onPick: (t) {
          unawaited(_ensurePlaybackPermissions());
          widget.state.playTrack(t);
          setState(() => _panel = PlayerPanel.none);
          // ignore: discarded_futures
          _loadCurrentTrack();
        },
      );

  Future<void> _saveQueueAsPlaylist() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.state.uiSkin.background,
        title: Text('Save queue as playlist',
            style: TextStyle(color: widget.state.skin.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: widget.state.skin.textPrimary),
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    if (!mounted || name == null || name.trim().isEmpty) return;
    final made = widget.state.saveQueueAsPlaylist(name);
    if (made == null) {
      _toast('There is nothing in the queue to save.');
      return;
    }
    _persistListsNow();
    _toast('Saved "${made.name}" with ${made.length} tracks.');
  }

  Widget? _queueContent() => QueueBody(
        state: widget.state,
        playing: _playing,
        onSaveAsPlaylist: _saveQueueAsPlaylist,

        onClearUpcoming: () {
          final dropped = widget.state.clearUpcoming();
          if (dropped <= 0) return;
          unawaited(_rebuildEngineQueueKeepingPosition());
          _toast('Cleared $dropped from the queue');
        },

        onRemoved: (track, at) {
          _toastUndo('Removed ${track.title}', () {
            if (!widget.state.restoreToQueue(at, track)) return;
            unawaited(_rebuildEngineQueueKeepingPosition());
          });
        },

        coverFor: (t) => coverProviderFor(_repo.coverPathFor(t)),
        onPlay: (t) {
          widget.state.playTrackNow(t.id);
          // ignore: discarded_futures
          _loadCurrentTrack();
        },
        onTogglePlay: () {
          // ignore: discarded_futures
          _togglePlay();
        },

        onReorder: (from, to) {
          if (_audio?.moveWithinEngine(from, to) ?? false) return;
          // ignore: discarded_futures
          _loadCurrentTrack();
        },

        onReloadAfterRemove: () {
          // ignore: discarded_futures
          _loadCurrentTrack();
        },
      );

  Widget? _loopContent() {
    final t = widget.state.currentTrack;
    if (t == null) return null;
    return LoopBody(
      state: widget.state,
      track: t,
      points: _loopPoints[t.id],
      position: widget.state.position,
      duration: _durationOrZero,
      onPreview: (playing) async {
        if (playing) {
          await _audio?.play();
        } else {
          await _audio?.pause();
        }
      },

      onSave: (points) async {
        _loopPoints[t.id] = points;
        await _stores.saveLoopPoints(_loopPoints);
        if (widget.state.currentTrack?.id == t.id) {
          _audio?.loop = LoopController(points: points);
        }
      },
    );
  }

  Widget? _trackContent() {
    final t = widget.state.currentTrack;
    if (t == null) return null;
    return TrackBody(
      state: widget.state,
      track: t,
      position: widget.state.position.value,
      playCount: _playCounts[t.id]?.$1,
      completionCount: _playCounts[t.id]?.$2,
      onToggleBookmark: () {
        widget.state.toggleBookmark(t, widget.state.position.value);
        _persistLists();
      },
      onFixTags: () {
        // ignore: discarded_futures
        _openTagEditor(t);
        setState(() {});
      },
      onLoopPoints: () => setState(() => _panel = PlayerPanel.loop),
      onAddToPlaylist: () {
        setState(() => _panel = PlayerPanel.none);
        // ignore: discarded_futures
        _pickPlaylistFor(t);
      },
      onNeverInShuffle: () {
        widget.state.toggleExclusion(t.id);
        _toast(widget.state.exclusions.contains(t.id)
            ? 'Never in shuffle — the full list is in ${widget.state.languageSkin.word(WordKey.libraryRoom, 'library tools')}'
            : 'Allowed in shuffle again');
      },
    );
  }

  Map<String, (int, int)> _playCounts = const {};

  bool _reconciling = false;

  void _onStateChanged() {
    _onTrackChanged();
    _scheduleSave();

    if (_reconciling) return;
    _reconciling = true;
    try {
      _reconcileAudio();
    } finally {
      _reconciling = false;
    }
  }

  void _reconcileAudio() {
    if (!mounted) return;
    if (widget.state.trackChangeCameFromPlatform) {
      widget.state.clearPlatformTrackChange();
      return;
    }

    final queue = widget.state.queue;
    if (queue != null && queue.engineIsStale) {
      final engine = _audio;
      final want = widget.state.currentTrack;
      final wantPath = want == null ? null : _repo.absoluteFor(want);
      final sameTrack =
          engine != null && wantPath != null && engine.playingPath == wantPath;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (sameTrack) {
          unawaited(_rebuildEngineQueueKeepingPosition());
        } else {
          unawaited(_loadCurrentTrack());
        }
      });
      return;
    }

    final want = widget.state.currentTrack;
    if (want == null || want.id == _openTrack?.id) return;

    if (_audio?.playingPath == want.file) {
      _openTrack = want;
      return;
    }
    _openTrack = want;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadCurrentTrack());
    });
  }

  Timer? _saveDebounce;

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), _flushState);
  }

  void _flushState() {
    _saveDebounce = null;
    // ignore: discarded_futures
    _stores.saveSnapshot(widget.state.snapshot(volume: _volume));
    _persistLists();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) => _shell(context),
    );
  }

  Widget _tabContent(AppTab tab, Skin skin) => switch (tab) {
        AppTab.home => HomeScreen(
          skin: skin,
          headerArt: _headerArt(skin),
          recent: _recentTracks,
          home: widget.state.personalization.home,
          onOpenPersonalize: _openPersonalizePage,
          headerMark: _brandMark(),
          band: decode.bandNameOf(_ctxForHome?.band),
          continueTrack: _continueTrack,
          jumpBackIn: _jumpBackIn,
          heavyRotation: _heavyRotation,
          greeting: _homeGreeting,
          nowMixName: widget.state.dynamicMix()?.name,
          onPlayNowMix: _playNowMix,
          newFromLibrary: _newFromLibrary,
          rediscover: _rediscoverTracks,

          mostPlayed: _heavyRotation,
          likedSongs: _likedTracks,
          recentPlaylist: _mostRecentPlaylist,
          onPlayPlaylist: (p) => _playPlaylistFromHome(p),
          onOpenRecentPlaylist: () {
            final p = _mostRecentPlaylist;
            if (p != null) _openPlaylistPage(p);
          },
          onOpenRecap: _openRecap,
          genreLists: _genreLists,
          libraryPlaylists: _libraryPlaylists,
          recapTracks: _recapTracks,
          recapLabel: _recapLabel,

          allTracks: _repo.tracks,
          onOpenRediscover: _openRediscover,
          coverPathFor: _repo.coverPathFor,
          onPlay: _playFromHome,
          weather: _ctx.weatherReading?.condition ?? WeatherCondition.unknown,
          placeName: _ctx.currentPlaceId == null
              ? null
              : _ctx.placeBook.byId(_ctx.currentPlaceId!)?.name,
          placeIcon: _ctx.currentPlaceId == null
              ? null
              : placeIconFor(_ctx.placeBook.byId(_ctx.currentPlaceId!)?.icon),
          hasFix: _ctx.currentPlaceId != null,
          contextEnabled: widget.state.contextEnabled,
        ),
        AppTab.library => LibraryScreen(

          entryToken: _libraryEntry,
          grid: _prefs.libraryIsGrid ?? widget.state.arrangement.libraryIsGrid,
          headerScrollsAway: widget.state.arrangement.headerScrollsAway,
          contentMaxWidth: widget.state.arrangement.contentMaxWidth,
          tracks: _repo.tracks,
          coverPathFor: _repo.coverPathFor,
          skin: skin,
          headerArt: _headerArt(skin),
          libraryRoot: _repo.libraryRoot,

          onManage: _openLibraryManagement,

          onDragToQueue: widget.state.queue == null ? null : _queueFromDrag,
          likedIds: widget.state.favorites.ids,

          likedOrder: widget.state.favorites.orderedIds,

          headerMark: _brandMark(),
          playlistSort: _prefs.playlistSortName,
          pinnedPlaylistIds: _effectivePins,
          recentPlaylistIds: _prefs.recentPlaylistIds ?? const [],
          onPlaylistSort: (v) => _setPrefs(_prefs.copyWith(playlistSort: v)),
          onTogglePin: _togglePin,
          onPlaylistGrid: (v) => setState(() => _playlistGridOverride = v),
          playlistGrid: _playlistGridOverride,
          onPlaylistOpened: (p) => _notePlaylistOpened(p.id),

          onAddSongsTo: _addSongsToPlaylist,

          searchRequest: _searchRequest,
          closeListRequest: _closeListRequest,
          onListOpenChanged: (open) {
            if (open != _libraryListOpen) {
              setState(() => _libraryListOpen = open);
            }
          },
          artistRequest: _artistRequest,

          onPlay: (t) {
            widget.state.playTrackElsewhere(t);
            // ignore: discarded_futures
            _loadCurrentTrack();
          },
          playlists: widget.state.playlists,

          visiblePlaylists: widget.state.visiblePlaylists,
          derivedPlaylists: widget.state.derivedPlaylists,

          dynamicBlurb: _dynamicBlurb(),

          onPlayPlaylist: (p) {
            // ignore: avoid_print
            print('[Sonarar][PLAYPRESS] id=${p.id} name="${p.name}" '
                'tracks=${p.trackIds.length} library=${widget.state.library.length} '
                'dynamicMix=${widget.state.dynamicMix()?.length ?? -1}');
            if (widget.state.playPlaylist(p)) {
              // ignore: discarded_futures
              _loadCurrentTrack();
            } else {
              // ignore: avoid_print
              print('[Sonarar][PLAYPRESS] REFUSED — nothing playable');
              _toast('That playlist has nothing playable');
            }
          },

          onOpenPlaylist: (_) {},
          onOpenArtist: (_) {},
          onCreatePlaylist: (name) {
            widget.state.createPlaylist(name);
            // ignore: discarded_futures
            _persistPlaylists();
            _toast('Created "$name"');
          },

          onRemoveFromPlaylist: (p, t) {
            widget.state.removeTrackFromPlaylist(p, t.id);
            // ignore: discarded_futures
            _persistPlaylists();
            _toast('Removed from ${p.name}');
          },
          onDeletePlaylist: (p) {
            final slot = widget.state.playlistIndexOf(p.id);
            widget.state.deletePlaylist(p.id);
            // ignore: discarded_futures
            _persistPlaylists();
            _toastUndo('Deleted "${p.name}"', () {
              if (!widget.state.restorePlaylist(slot, p)) return;
              // ignore: discarded_futures
              _persistPlaylists();
            });
          },

          onQueue: (t) {
            final ok = widget.state.addToQueue(t);
            _toast(ok ? 'Added to queue — ${t.title}' : 'Already in the queue');
            return ok ? SwipeOutcome.queued : SwipeOutcome.alreadyQueued;
          },

          onLike: (t) {
            final liked = widget.state.toggleFavorite(t.id);
            _persistLists();
            _toast(liked ? 'Liked — ${t.title}' : 'Removed from Liked');
            return liked ? SwipeOutcome.liked : SwipeOutcome.unliked;
          },

          onTogglePlay: (_) {
            // ignore: discarded_futures
            _togglePlay();
          },

          playingTrackId: widget.state.currentTrack?.id,

          isPlaying: _playing,
        ),

        AppTab.search => YoutubeSearchScreen(
          state: widget.state,
          headerMark: _brandMark(),
          repo: _repo,
          downloads: _downloads,

          allowNetwork: _prefs.allowNetwork,
          searchOnline: _prefs.searchOnline ?? false,
          onSearchOnline: (v) => _setPrefs(_prefs.copyWith(searchOnline: v)),
          playlistStore: PlaylistSources(
            File('$_stateDir/imported_playlists.json'),
          ),

          onDownloaded: (_) {
            // ignore: discarded_futures
            _reloadLibraryAfterDownload();
          },

          onPlay: (trackId) {
            final t = widget.state.library.firstWhere(
              (x) => x.id == trackId,
              orElse: () => widget.state.currentTrack ?? _repo.tracks.first,
            );
            widget.state.playTrackElsewhere(t);
            // ignore: discarded_futures
            _loadCurrentTrack();
          },
          officialOnly: _prefs.officialOnly,
          onEnsurePlaylist: (name) => widget.state.ensurePlaylist(name),
          onAddToPlaylist: (pl, trackId) {
            widget.state.addTrackToPlaylist(pl, trackId);
            _persistListsNow();
          },

          manifest: _repo.libraryRoot == null
              ? null
              : File(
                  '${_repo.libraryRoot}${Platform.pathSeparator}$kManifestFileName'),
        ),

        AppTab.settings => SettingsScreen(
          state: widget.state,
          musicRoot: _musicRoot,
          stateDirectory: _stores.directory,
          downloadDirectory: _backupDirectory,
          appVersion: '$appVersionName+$appVersionCode',
          onOpenMusicFolder: _openMusicFolder,
          onOpenDiagnostics: () => _openDoor(_InlineDoor.diagnostics),
          onSavePreset: (name) {
            final made = ThemePreset(
              id: freshPresetId({
                for (final p in widget.state.allPresets) p.id,
              }),
              name: name,
              skinId: widget.state.skin.id,
              artSkinId: widget.state.artSkinOverride,
              languageSkinId:
                  widget.state.languageSkin.id == widget.state.skin.id
                      ? null
                      : widget.state.languageSkin.id,
              layoutId: widget.state.layoutId.name,
              personalization: widget.state.personalization,
            );
            widget.state.setUserPresets([
              ...widget.state.userPresets,
              made,
            ]);
            widget.state.applyPreset(made);
            // ignore: discarded_futures
            _persistPresets();
            setState(() {});
            _toast('Saved "$name"');
          },
          onDeletePreset: (p) {
            widget.state.setUserPresets([
              for (final x in widget.state.userPresets)
                if (x.id != p.id) x,
            ]);

            if (widget.state.preset?.id == p.id) {
              widget.state.clearPreset();
            }
            // ignore: discarded_futures
            _persistPresets();
            setState(() {});
            _toast('Deleted "${p.name}"');
          },

          weather: _ctx.weatherReading?.condition ?? WeatherCondition.unknown,

          onContextsChanged: () {
            _syncPresetToPrefs();
          },
          prefs: _prefs,
          onPrefsChanged: _setPrefs,
        ),
      };

  Widget _miniPlayer(Skin skin) {
    return ValueListenableBuilder<bool>(
      valueListenable: _showPlayer,
      builder: (_, showPlayer, __) {
        if (widget.state.currentTrack == null || showPlayer) {
          return const SizedBox.shrink();
        }
        return _miniPlayerBar(skin);
      },
    );
  }

  Widget _miniPlayerBar(Skin skin) => MiniPlayerHost(
      skin: skin,

      presentation: widget.state.presentation,
      state: widget.state,
      duration: _durationOrZero,
      playing: _playing,
      lyricsActive: _lyricsMode,

      downloadBadge: _downloads.isBusy
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: skin.accent,
                backgroundColor: skin.panel,
              ),
            )
          : null,
      cover: _coverProvider(),
      onSeek: (to) {
        // ignore: discarded_futures
        _audio?.seek(to);
        widget.state.position.value = to;
      },
      onPlayPause: _togglePlay,

      onSwipeNext: () {
        // ignore: discarded_futures
        _skipNext();
      },
      onSwipePrevious: () {
        // ignore: discarded_futures
        _skipPrevious();
      },

      onDisband: () {
        if (!widget.state.disbandQueue()) return;
        unawaited(_audio?.stop() ?? Future<void>.value());
        _saveDebounce?.cancel();
        _saveDebounce = null;
        unawaited(_stores.saveSnapshot(widget.state.snapshot(volume: _volume)));
        setState(() {
          _playing = false;
          _panel = PlayerPanel.none;
        });
      },
      onCycleRepeat: () {
        widget.state.cycleRepeat();
      },
      onToggleLyrics: _openPlayer,

      onOpenQueue: _openQueueAsPage,

      onDragToQueue: _queueFromDrag,
    );

  /// The place this tab is, for per-place pictures. Settings has none of its
  /// own and wears the default.
  SurfaceId get _surfaceForTab => switch (_tab) {
        AppTab.home => SurfaceId.home,
        AppTab.library => SurfaceId.library,
        AppTab.search => SurfaceId.search,
        AppTab.settings => SurfaceId.home,
      };

  Widget _tabBackdrop(Skin skin) {
    final personalization = widget.state.personalization;
    final photo = personalization.backdropFor(_surfaceForTab);
    final root = _repo.libraryRoot;
    return Stack(
        children: [
          // The photo sits under everything the skin paints, so the palette
          // still reads as the skin and the image is scenery, not wallpaper.
          if (photo.isSet)
            Positioned.fill(
              child: PersonalBackdrop(
                root: root == null ? null : Directory(root),
                spec: photo,
                skin: skin,
              ),
            ),
          if (!photo.isSet && personalization.fill.isSet)
            Positioned.fill(child: FillBackdrop(fill: personalization.fill)),
          Positioned.fill(
            child: AmbientBackdrop(
              presentation: widget.state.presentation,
              transparent: photo.isSet || personalization.fill.isSet,
            ),
          ),
          Positioned.fill(
            child: TabArrivalView(
              key: ValueKey('bg-${_tab.name}'),
              travel: _travel,
              arrival: TabArrival.forMotif(TabMotif.forTab(_tab.name)),
              duration: widget.state.motion.tabTransition * widget.state.motion.backdropFactor,

              motion: widget.state.motion,
              drift: 0.55,
              scaleOver: 1.14,
              animate: _prefs.tabAnimation,

              hardSnap: false,
              child: TabBackdrop(
                skin: skin,
                motif: TabMotif.forTab(_tab.name),
              ),
            ),
          ),
        ],
      );
  }

  final Map<AppTab, Widget> _builtTabs = {};

  int _arrivalEpoch = 0;

  List<AppTab> get _visibleTabs => [
        if (_homeAvailable) AppTab.home,
        AppTab.library,
        AppTab.search,
        AppTab.settings,
      ];

  bool get _homeAvailable =>
      _repo.tracks.isNotEmpty ||
      _libraryPlaylists.isNotEmpty ||
      _likedTracks.isNotEmpty ||
      widget.state.contextEnabled;

  void _goToTab(AppTab t) {
    final target = (t == AppTab.home && !_homeAvailable) ? AppTab.library : t;
    if (target != _tab) _arrivalEpoch++;
    _tab = target;
  }

  Widget _tabContentArrival(Skin skin) {
    _builtTabs[_tab] = _tabContent(_tab, skin);

    return Stack(
      children: [
        for (final t in AppTab.values)
          if (_builtTabs.containsKey(t))
            Offstage(

              offstage: t != _tab,
              child: TabArrivalView(

                key: ValueKey('arrival-$t'),
                travel: _travel,
                arrival: TabArrival.forMotif(TabMotif.forTab(t.name)),
                duration: widget.state.motion.tabTransition,
                motion: widget.state.motion,

                animate: _prefs.tabAnimation && widget.state.motion.enabled,

                replayToken: t == _tab ? _arrivalEpoch : null,

                child: _builtTabs[t]!,
              ),
            ),
      ],
    );
  }

  Widget _shellFrame(Skin skin) {
    final chrome = widget.state.presentation.kit.chrome;
    // Edge-to-edge is the default on modern Android: without this the tab row
    // sits under the gesture pill on phones that use gestures.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final bars = Column(
      mainAxisSize: MainAxisSize.min,
      children: [

        // A download in flight belongs with the bar you are already looking at,
        // not in a corner of the top bar you never watch.
        if (_downloads.isBusy && _tab != AppTab.search)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(
                right: widget.state.presentation.arrangement.tabBarInsets.right + 4,
                bottom: 6,
              ),
              child: DownloadRing(
                manager: _downloads,
                skin: skin,
                coverOf: (j) {
                  final path = _downloads.coverPathForJob(j);
                  return path == null ? null : FileImage(File(path));
                },
              ),
            ),
          ),
        _miniPlayer(skin),
        TabBarView2(
          skin: skin,
          presentation: widget.state.presentation,
          current: _tab,
          showHome: _homeAvailable,

          onSelect: _selectTab,
        ),
      ],
    );

    return switch (chrome.shellFrame) {
      ShellFrame.docked => Column(
          children: [

            UpdateBar(skin: skin),
            Expanded(
              child: Stack(
                children: [_tabBackdrop(skin), _tabContentArrival(skin)],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: bars,
            ),
          ],
        ),
      ShellFrame.floating => Stack(
          children: [
            Positioned.fill(
              child: Stack(
                children: [_tabBackdrop(skin), _tabContentArrival(skin)],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: bars,
              ),
            ),
          ],
        ),
    };
  }

  void _selectTab(AppTab t) {
    if (!_askedStorage && t == AppTab.library) {
      unawaited(_ensurePlaybackPermissions());
    }
    _rememberTab(t);

    final from = AppTab.values.indexOf(_tab);
    final to = AppTab.values.indexOf(t);
    setState(() {
      _travel = to == from
          ? TabTravel.none
          : (to > from ? TabTravel.forwards : TabTravel.backwards);

      if (t == AppTab.library) _libraryEntry++;
      _goToTab(t);
    });
  }

  /// Nothing to look at on purpose. The app opens on the skin's own colour and
  /// then the shell; a wordmark and a progress bar on every launch is an intro
  /// nobody asked for, and it only exists because art used to be decoded first.
  // A bare coloured box is indistinguishable from a stalled app: for the second
  // it takes to read the library, nothing says the app is alive. The mark and a
  // line of text cost nothing and make the first frame an answer.
  Widget _splash(Skin skin) => ColoredBox(
    color: skin.background,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 44, height: 44, child: _brandMark()),
          const SizedBox(height: 16),
          Text(
            'SONARAR',
            style: TextStyle(
              fontSize: LayoutSpec.fontFloor + 1,
              fontWeight: FontWeight.w900,
              letterSpacing: 4.5,
              color: skin.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'reading your library',
            style: TextStyle(
              fontSize: LayoutSpec.fontFloor,
              color: skin.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );

  /// Decoding art takes long enough to be seen. It happens once the shell is on
  /// screen, so opening the app is never gated on warm pictures.


  Widget _shell(BuildContext context) {
    final skin = widget.state.uiSkin;

    if (_loading) {
      return _splash(skin);
    }

    if (_needsSetup) {
      return FirstRunScreen(
        skin: skin,
        prefs: _prefs,
        layoutId: decode.layoutFromPrefs(_prefs.layoutId),
        onPrefs: _setPrefs,
        onDone: () => setState(() => _needsSetup = false),
      );
    }

    return ShortcutScope(
      onCommand: _onShortcut,
      child: PresentationScope(
        presentation: widget.state.presentation,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;

            final action = backActionFor(
              libraryListOpen: _libraryListOpen,
              panelOpen: _panel != PlayerPanel.none,
              playerOpen: _showPlayer.value,
              hasTabHistory: _historyAt > 0,
            );

            switch (action) {
              case BackAction.closeList:

                setState(() => _closeListRequest++);
              case BackAction.closePanel:
                setState(() => _panel = PlayerPanel.none);
              case BackAction.closePlayer:
                _showPlayer.value = false;
              case BackAction.previousTab:
                setState(() {
                  _historyAt--;
                  _goToTab(_history[_historyAt]);
                });
              case BackAction.leaveApp:
                // ignore: discarded_futures
                SystemNavigator.pop();
            }
          },
        child: Scaffold(
      backgroundColor: skin.background,

      drawer: AppSidebar(
        skin: skin,
        mark: _brandMark(),
        entries: [
          SidebarEntry(
            label: 'HISTORY',
            icon: Icons.insights_rounded,
            onTap: _openHistory,
          ),
          if (!_prefs.allowNetwork)
            SidebarEntry(
              label: 'PLACES',
              icon: Icons.location_on_rounded,
              onTap: _openPlacesPage,
            ),
          SidebarEntry(
            label: 'THE ARCHIVE',
            icon: Icons.meeting_room_rounded,
            onTap: _openArchive,
          ),
          SidebarEntry(
            label: 'PERSONALIZE',
            icon: Icons.tune_rounded,
            onTap: _openPersonalizePage,
          ),
          SidebarEntry(
            label: 'SETTINGS',
            icon: Icons.settings_rounded,

            onTap: _openSettingsPage,
          ),
        ],
        footer: Text(
          'Sonarar',
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 1.2,
            color: skin.textSecondary,
          ),
        ),
      ),
      body: Stack(
        children: [
            _shellFrame(skin),

            if (_prefs.showFps)
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, left: 8),
                    child: FpsOverlay(skin: skin),
                  ),
                ),
              ),

            if (_inline.isNotEmpty) _inlinePanel(context, skin),
          ],
        ),
      ),
      ),
    ),
    );
  }

  Widget? _headerArt(Skin skin, {double opacity = 0.9}) {
    final chrome = widget.state.presentation.kit.chrome;
    if (!widget.state.artChosen &&
        !chrome.artByDefault &&
        widget.state.artSkinOverride == null) {
      return null;
    }
    final art = widget.state.artForSurface(_surfaceForTab);
    if (art == null) return null;

    return FramedArt(
      assetPath: art.assetPath,
      aspect: art.aspect,
      spec: art.spec,
      focus: widget.state.artFocus.copyWith(dy: -0.25, zoom: 1.15),
      cacheWidth: 1080,
      opacity: opacity,
      burn: 1.0,
    );
  }

  Widget _playerBody(BuildContext context, Skin skin) {
    final current = _repo.tracks.isEmpty ? null : _repo.tracks.first;
    return Stack(
children: [
  PlayerScreen(
                    state: widget.state,
                    onMinimise: _closePlayer,
                    onArtist: _openArtist,
                    lyricsMode: _lyricsMode,
                    onLyrics: () => _shellChanged(() => _lyricsMode = !_lyricsMode),
                    lyrics: _lyrics,

                    romaji: _romaji,

                    lyricsContent: _lyricsMode
                        ? ValueListenableBuilder<Duration>(
                            valueListenable: widget.state.position,
                            builder: (_, at, __) => LyricsView(
                              skin: widget.state.uiSkin,
                              lyrics: _lyrics,
                              romaji: _romaji,
                              position: at,
                              onSeek: (to) {
                                // ignore: discarded_futures
                                _audio?.seek(to);

                                widget.state.position.value = to;

                                if (!_playing) {
                                  // ignore: discarded_futures
                                  _togglePlay();
                                }
                              },
                              controller: _lyricsScroll,
                              onExit: () => _shellChanged(() => _lyricsMode = false),
                            ),
                          )
                        : null,

                    spectrum: _prefs.showVisualiser ? _spectrum : null,
                    spectrumEase: _prefs.spectrumEase,
                    spectrumShape: SpectrumShape.byName(_prefs.spectrumShapeName),
                    spectrumHeight: LayoutSpec.spectrumHeight *
                        _prefs.spectrumScalePercent /
                        100.0,
                    track: widget.state.currentTrack ?? current,

                    onPlayPause: _togglePlay,
                    onSeek: (to) {
                      // ignore: discarded_futures
                      _audio?.seek(to);
                      widget.state.position.value = to;
                    },
                    playing: _playing,
                    fileMissing: _fileMissing,

                    panel: _panel,
                    audioContent: AudioPanel(
                      skin: skin,
                      volume: _volume,
                      onVolume: _setVolume,
                      muted: _volume <= 0.001,

                      outputs: _audioOutputs,

                      onPickOutput: _pickAudioOutput,
                    ),
                    onPanel: (p) {
                      _shellChanged(() {
                        _panel = p;
                        if (p == PlayerPanel.none) _panelMax = false;
                      });

                      if (p == PlayerPanel.track) {
                        // ignore: discarded_futures
                        _refreshDerivedPlaylists();
                      }

                      if (p == PlayerPanel.audio) {
                        // ignore: discarded_futures
                        _refreshAudioOutputs();
                      }
                    },
                    panelMaximised: _panelMax,
                    onPanelMaximised: (v) => _shellChanged(() => _panelMax = v),

                    hasWhy:
                        widget.state.contextEnabled &&
                            widget.state.playlistContext != null,
                    hasQueue: widget.state.queue != null,
                    hasTrackPanel: widget.state.currentTrack != null,
                    whyContent: _panel == PlayerPanel.why ? _whyContent() : null,
                    queueContent: _panel == PlayerPanel.queue ? _queueContent() : null,
                    trackContent: _panel == PlayerPanel.track ? _trackContent() : null,
                    loopContent: _panel == PlayerPanel.loop ? _loopContent() : null,

                    upNextCount: widget.state.upNextCount,

                    cover: _coverProvider(),
                    shuffled: widget.state.isShuffled,
                    onShuffle: () {
                      widget.state.toggleShuffle();
                      if (mounted) _shellChanged(() {});

                      // ignore: discarded_futures
                      _rebuildEngineQueueKeepingPosition();
                    },
                    repeatMode: widget.state.repeatMode,
                    onCycleRepeat: () {
                      widget.state.cycleRepeat();
                      if (mounted) _shellChanged(() {});
                    },

                    onNext: () {
                      // ignore: discarded_futures
                      _skipNext();
                    },
                    onPrevious: () {
                      // ignore: discarded_futures
                      _skipPrevious();
                    },
                    onSwipeNext: () {
                      // ignore: discarded_futures
                      _skipNext();
                    },
                    onSwipePrevious: () {
                      // ignore: discarded_futures
                      _skipPrevious();
                    },

                    variants: () {
                      final t = widget.state.currentTrack;
                      if (t == null) return const <Track>[];
                      return variantsOf(t, widget.state.library);
                    }(),
                    onSwapVariant: _swapToVariant,

                    placeName: _ctx.currentPlaceId == null
                        ? null
                        : _ctx.placeBook.byId(_ctx.currentPlaceId!)?.name,
                    placeIcon: _ctx.currentPlaceId == null
                        ? null
                        : placeIconFor(_ctx.placeBook.byId(_ctx.currentPlaceId!)?.icon),

                    weather: _ctx.weatherReading?.condition ?? WeatherCondition.unknown,

                    volume: _volume,
                    onVolume: _setVolume,
                    onSleep: _toggleSleep,
                    stopAfterTrack: _stopAfterTrack,
                    onStopAfterTrack: (v) {
                      setState(() => _stopAfterTrack = v);
                      _toast(v
                          ? 'Stopping after this track'
                          : 'Stop after this track — off');
                    },
                    sleepRunning: _sleep.isRunning,
                    sleepTimer: _prefs.sleepTimer,

                    sleepLeft: _sleepLeft,
                  ),
  Positioned(
    left: 8,
    top: MediaQuery.of(context).padding.top + 4,
    child: IconButton(
      onPressed: _closePlayer,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      color: skin.textPrimary,
      iconSize: 32,
      tooltip: 'Back',
    ),
  ),

  Positioned(
    left: 0,
    right: 0,
    top: 0,
    height: 72,
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v > 240) _closePlayer();
      },
    ),
  ),
        ],
      );
  }

  Widget _inlinePanel(BuildContext context, Skin skin) {
    final top = _inline.last;
    return InlinePanelSheet(
      skin: skin,
      title: _doors[top]!.title(widget.state.languageSkin),
      onClose: () => setState(() => _inline.clear()),
      onBack: _inline.length > 1
          ? () => setState(() => _inline.removeLast())
          : null,
      child: _doors[top]!.build(skin),
    );
  }

  void _openPage(String title, Widget Function(BuildContext) builder) {
    // The presentation belongs ABOVE the page: AppPage reads it for its own
    // header, and a scope inside the child left the arrow on the fallback skin.
    // ignore: discarded_futures
    openAppPage(
      context,
      title: title,
      skin: widget.state.uiSkin,
      presentation: widget.state.presentation,
      rebuildOn: _routeListenable,
      builder: builder,
    );
  }

  void _openDoor(_InlineDoor door) {
    if (_kDoorsNeedingEvents.contains(door)) {
      final log = _stores.playLog;
      // ignore: discarded_futures
      log.read().then((events) {
        if (!mounted) return;
        setState(() {
          _lastEvents = events;
          _inline.add(door);
        });
      });
      return;
    }
    setState(() => _inline.add(door));
  }

  late final Map<_InlineDoor, ({String Function(Skin) title, Widget Function(Skin) build})>
      _doors = {
    _InlineDoor.history: (
      title: (_) => 'HISTORY',
      build: (skin) => HistoryScreen(
        contextEnabled: _prefs.allowNetwork,
        skin: skin,
        events: _lastEvents,
        tracks: _repo.tracks,
        inline: true,

        ranks: (_prefs.personaLayer ? BondsScreen(
          state: widget.state,
          events: _lastEvents,
          tracks: _repo.tracks,
          inline: true,
          onNoteSaved: _bondsCallbacks().noteSaved,
          onReset: _bondsCallbacks().reset,
        ) : const SizedBox.shrink()),
      ),
    ),
    _InlineDoor.velvetRoom: (
      title: (skin) => skin.word(WordKey.libraryRoom, 'LIBRARY TOOLS'),
      build: (skin) => ArchiveScreen(
        state: widget.state,
        inline: true,
        onOpenTagEditor: (t) {
          // ignore: discarded_futures
          _openTagEditor(t);
        },
        compendiumEntries: buildCompendium(
          tracks: _repo.tracks,
          events: _lastEvents,
        ).entries,
        playingTrackId: widget.state.currentTrack?.id,
        onSummon: (t) {
          widget.state.playNextInQueue(t);
          _toast('${t.title} — next');
        },
        onOpenBonds: _openBonds,
        onOpenRules: _openRules,
        onOpenExclusions: _openNeverInShuffle,
        onRevertAllTags: () {
          widget.state.clearAllTagOverrides();
          // ignore: discarded_futures
          _persistTags();
        },
      ),
    ),
    _InlineDoor.compendium: (
      title: (_) => 'CATALOGUE',
      build: (skin) => CompendiumScreen(
        skin: skin,
        entries: buildCompendium(
          tracks: _repo.tracks,
          events: _lastEvents,
        ).entries,
        playingTrackId: widget.state.currentTrack?.id,
        inline: true,
        onSummon: (t) {
          widget.state.playNextInQueue(t);
          _toast('${t.title} — next');
        },
      ),
    ),
    _InlineDoor.bonds: (
      title: (skin) => skin.word(WordKey.affinityRoom, 'RANKS'),
      build: (skin) => BondsScreen(
        state: widget.state,
        events: _lastEvents,
        tracks: _repo.tracks,
        inline: true,
        onNoteSaved: _bondsCallbacks(resetToast: "Ranks restart from now - the history is untouched").noteSaved,
        onReset: _bondsCallbacks(resetToast: "Ranks restart from now - the history is untouched").reset,
      ),
    ),

    _InlineDoor.diagnostics: (
      title: (_) => 'DIAGNOSTICS',
      build: (skin) => DiagnosticsPanel(skin: skin, log: diagLog),
    ),
    _InlineDoor.places: (
      title: (_) => 'PLACES',

      build: (skin) => _placesBody(skin, inline: true),
    ),
  };
}
