library;

import '../l10n/script.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;

import '../download/download_manager.dart';
import '../library/downloaded_tracks.dart';
import '../library/playlists.dart';
import '../theme/layout.dart';
import '../core/time_format.dart';
import '../library/track.dart';
import '../library/library_repository.dart';
import '../theme/personalization.dart';
import '../theme/skin.dart';
import '../theme/tokens.dart' show Space;
import 'app_header.dart';
import '../widgets/screen_backdrop.dart';
import '../widgets/toasts.dart';
import 'playlist_import_sheet.dart';

String foldForSearch(String s) => _foldForSearch(s);

String _foldForSearch(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-z0-9\u00c0-\uffff ]+"), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class SearchHit {
  const SearchHit({
    required this.id,
    required this.title,
    required this.channel,
    required this.duration,
    this.thumbnailUrl,
    this.localCoverPath,
  });

  final String id;
  final String title;
  final String channel;
  final Duration duration;

  final String? thumbnailUrl;

  final String? localCoverPath;

  bool isOfficialGiven(Set<String> vouchedChannels) =>
      looksLikeOfficialRelease ||
      vouchedChannels.contains(channel.toLowerCase());

  bool get looksLikeOfficialRelease {
    final t = title.toLowerCase();
    final c = channel.toLowerCase();

    const videoMarkers = [
      'official music video',
      'official video',
      'music video',
      'official mv',
      'official 4k video',
      ' (mv)',
      '【mv】',
      '[mv]',
    ];
    if (videoMarkers.any(t.contains)) return true;

    const audioMarkers = [
      'official audio',
      '(audio)',
      '[audio]',
      'audio only',
      'official sound',
      'official ost',
      'official soundtrack',
    ];
    if (audioMarkers.any(t.contains)) return true;

    if (c.endsWith(' - topic')) return true;
    if (c.endsWith('- topic')) return true;
    if (c.contains('vevo')) return true;

    return false;
  }
}

class YoutubeSearchScreen extends StatefulWidget {
  const YoutubeSearchScreen({
    super.key,
    required this.state,
    required this.repo,
    required this.playlistStore,
    this.manifest,
    this.onDownloaded,
    this.onPlay,
    required this.downloads,
    this.onEnsurePlaylist,
    this.onAddToPlaylist,
    this.officialOnly = false,
    this.allowNetwork = true,
    this.searchOnline = false,
    this.headerMark,
    this.onSearchOnline,
    this.onBack,
    this.search,
  });

  final dynamic state;

  final LibraryRepository repo;

  final PlaylistSources playlistStore;

  final File? manifest;

  final bool allowNetwork;

  final bool searchOnline;

  final Widget? headerMark;

  final ValueChanged<bool>? onSearchOnline;

  /// Null when the screen is a tab; a page needs a way out that is not the
  /// system gesture.
  final VoidCallback? onBack;

  /// How this screen asks YouTube for results.
  ///
  /// Injected because a widget test - and the shot suite that photographs the
  /// page - cannot reach the network, and a page whose only state is "empty"
  /// is a page whose rows were never looked at.
  final Future<List<SearchHit>> Function(String query)? search;

  bool get online => allowNetwork || searchOnline;

  final DownloadManager downloads;

  final Playlist Function(String name)? onEnsurePlaylist;
  final void Function(Playlist playlist, String trackId)? onAddToPlaylist;

  final bool officialOnly;

  final void Function(String path)? onDownloaded;

  final void Function(String trackId)? onPlay;

  @override
  State<YoutubeSearchScreen> createState() => _YoutubeSearchScreenState();
}

class _YoutubeSearchScreenState extends State<YoutubeSearchScreen> {
  final _ctl = TextEditingController();
  final _yt = YoutubeExplode();

  List<SearchHit> _hits = const [];

  /// Set when the engine fetch failed. A failure has to be visible, or "it didn't
  /// work" is all a person can see.
  bool _setupFailed = false;

  static const Key downloadsSetupBannerKey = Key('downloads-setup-banner');

  Future<void> _installEngine() async {
    if (_setupFailed && mounted) setState(() => _setupFailed = false);
    final ok = await widget.downloads.installEngine();
    if (!mounted) return;
    setState(() => _setupFailed = !ok);
    if (!ok) {
      debugPrint('[Sonarar][DL] engine setup failed from the search banner');
      toast(context, l10nOf(context).downloadsSetupFailed);
    }
  }

  Widget _setupBanner(Skin skin) {
    final downloads = widget.downloads;
    final out = downloads.downloadsCompiledOut;
    final installing = downloads.installingEngine;
    final l10n = l10nOf(context);

    return GestureDetector(
      key: downloadsSetupBannerKey,
      onTap: out || installing ? null : _installEngine,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: skin.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _setupFailed ? skin.accent : skin.edge(0.28),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _setupFailed
                  ? Icons.error_outline_rounded
                  : Icons.cloud_download_outlined,
              size: 18,
              color: _setupFailed ? skin.accentInk : skin.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    out
                        ? l10n.downloadsNotInThisBuild
                        : (_setupFailed
                              ? l10n.downloadsSetupFailed
                              : l10n.downloadsSetup),
                    style: TextStyle(
                      color: _setupFailed ? skin.accentInk : skin.textPrimary,
                      fontSize: LayoutSpec.fontFloor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // The stage that failed, in whatever words it used. Without this
                  // the banner was a dead end: "it didn't work" was all anyone could
                  // tell me, because all the app said was that it hadn't.
                  if (_setupFailed && widget.downloads.engineFailure != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        widget.downloads.engineFailure!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: skin.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (installing)
              SizedBox(
                width: 40,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: skin.accent,
                  backgroundColor: skin.edge(0.2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _searching = false;
  String? _error;

  /// The query the rows on screen were asked for. A finished search that found
  /// nothing says so; a page nobody has searched yet does not.
  String? _searched;

  List<SearchHit> _local = const [];

  static String _fold(String s) => _foldForSearch(s);

  Timer? _typing;
  static const Duration _typingPause = Duration(milliseconds: 120);

  /// Empty the field and the rows that came from it.
  void _clearQuery() {
    _typing?.cancel();
    _ctl.clear();
    setState(() {
      _local = const [];
      _hits = const [];
      _error = null;
      _searched = null;
    });
  }

  /// Search for a suggestion: the field says it, the rows are for it.
  void _searchFor(String query) {
    _typing?.cancel();
    _ctl.text = query;
    _ctl.selection = TextSelection.collapsed(offset: query.length);
    setState(() {
      _local = _localMatches(query);
      _error = null;
    });
    FocusScope.of(context).unfocus();
    // ignore: discarded_futures
    _search();
  }

  /// The artists of the library, most tracks first: the page's own answer to
  /// "what should I look for", drawn rather than explained.
  List<String> _artistSuggestions() {
    final dynamic st = widget.state;
    final List<Track> lib = st.library;
    final counts = <String, int>{};
    for (final t in lib) {
      final artist = t.artist.trim();
      if (artist.isEmpty) continue;
      counts[artist] = (counts[artist] ?? 0) + 1;
    }
    final ranked = counts.entries.toList()
      ..sort(
        (a, b) => b.value != a.value
            ? b.value.compareTo(a.value)
            : a.key.toLowerCase().compareTo(b.key.toLowerCase()),
      );
    return [for (final e in ranked.take(6)) e.key];
  }

  void _onQueryChanged(String raw) {
    _typing?.cancel();
    // The rows above belong to the query they were asked for. Keeping them
    // while the field says something else put last search's YouTube results
    // under a word they were never about.
    if (_hits.isNotEmpty || _error != null || _searched != null) {
      setState(() {
        _hits = const [];
        _error = null;
        _searched = null;
      });
    }
    _typing = Timer(_typingPause, () {
      if (!mounted) return;
      setState(() => _local = _localMatches(raw));
    });
  }

  List<SearchHit> _localMatches(String q) {
    final needle = _fold(q);
    if (needle.isEmpty) return const [];
    final dynamic st = widget.state;
    final List<Track> lib = st.library;

    final words = needle.split(' ').where((w) => w.isNotEmpty).toList();
    final hits = <SearchHit>[];
    for (final t in lib) {
      final hay = _fold('${t.title} ${t.artist}');
      var all = true;
      for (final w in words) {
        if (!hay.contains(w)) {
          all = false;
          break;
        }
      }
      if (!all) continue;
      hits.add(
        SearchHit(
          id: t.id,
          title: t.title,
          channel: t.artist,
          duration: t.duration,
          thumbnailUrl: null,
          localCoverPath: widget.repo.coverPathFor(t),
        ),
      );
    }

    hits.sort((a, b) {
      final at = _fold(a.title).startsWith(needle) ? 0 : 1;
      final bt = _fold(b.title).startsWith(needle) ? 0 : 1;
      if (at != bt) return at - bt;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return hits;
  }

  Set<String> _libraryIds = {};

  Set<String> _vouched = {};

  static Set<String> _vouchChannels(List<SearchHit> hits) => {
    for (final h in hits)
      if (h.looksLikeOfficialRelease) h.channel.toLowerCase(),
  };

  Set<String> _inLibrary() {
    final dynamic st = widget.state;
    final List<Track> lib = st.library;

    final ids = <String>{};
    for (final dynamic t in lib) {
      if (!isDownloaded(t)) continue;
      ids.add(t.id);
      final m = RegExp(r'([A-Za-z0-9_-]{11})').allMatches(t.file);
      for (final g in m) {
        ids.add(g.group(1)!);
      }
    }
    return ids;
  }

  /// Every notification, not just the ones that shrink the queue: a finished
  /// download changes no count, it changes a *row* — and a row that only
  /// repaints when you switch tabs reads as a download that never landed.
  void _onDownloadsChanged() {
    if (!mounted) return;
    setState(() => _libraryIds = _inLibrary());
  }

  @override
  void initState() {
    super.initState();
    widget.downloads.addListener(_onDownloadsChanged);
    // The manifest write and the library reload land after the download
    // manager has already gone quiet, so the row also has to follow the
    // library itself — that is the state the row is drawn from.
    widget.state.addListener(_onDownloadsChanged);
    // An engine installed before the last update is still installed. Ask the
    // device rather than offering the same 14 MB download again.
    // ignore: discarded_futures
    widget.downloads.probeEngine();
  }

  @override
  void dispose() {
    _typing?.cancel();
    widget.downloads.removeListener(_onDownloadsChanged);
    widget.state.removeListener(_onDownloadsChanged);
    _ctl.dispose();
    _yt.close();
    super.dispose();
  }

  Future<void> _openImport() async {
    if (!widget.online) {
      setState(() => _error = l10nOf(context).ytNetworkOff);
      return;
    }
    final dir = await _downloadDir();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: skinOf().background,
      builder: (_) => PlaylistManagerSheet(
        skin: skinOf(),
        store: widget.playlistStore,
        downloadDir: dir,
        manifest: widget.manifest,
        onImported: (_) => widget.onDownloaded?.call(''),
        onEnsurePlaylist: widget.onEnsurePlaylist,
        onAddToPlaylist: widget.onAddToPlaylist,
        onPrepareEngine: () => widget.downloads.installEngine(),
      ),
    );
  }

  Skin skinOf() {
    final dynamic st = widget.state;
    final prefs = st.presentation as dynamic;
    return (prefs.asSkin(st.skin as Skin)) as Skin;
  }

  Future<void> _search() async {
    final q = _ctl.text.trim();
    if (q.isEmpty || _searching) return;

    final local = _localMatches(q);
    if (!widget.online) {
      setState(() {
        _local = local;
        _hits = const [];
        _searching = false;
        _error = local.isEmpty ? l10nOf(context).ytNetworkOffNoMatch : null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _local = local;
      _hits = const [];
    });
    try {
      final hits = widget.search != null
          ? await widget.search!(q)
          : [
              for (final v in (await _yt.search.search(q)).take(30))
                SearchHit(
                  id: v.id.value,
                  title: v.title,
                  channel: v.author,
                  duration: v.duration ?? Duration.zero,
                  thumbnailUrl: v.thumbnails.mediumResUrl,
                ),
            ];
      if (!mounted) return;

      setState(() {
        _hits = hits;
        _searched = q;

        _libraryIds = _inLibrary();

        _vouched = _vouchChannels(hits);
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      // The exception is for the diagnostics; a socket timeout spelled out over
      // the results is not something a person can act on.
      debugPrint('[Sonarar][YT] search "$q" failed: $e');
      setState(() {
        _error = l10nOf(context).ytSearchFailed;
        _searching = false;
      });
    }
  }

  Future<Directory> _downloadDir() async {
    final root = widget.repo.libraryRoot;
    if (root == null) throw StateError('the library root is not resolved yet');
    final dir = Directory('$root${Platform.pathSeparator}Downloaded');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  void _download(SearchHit hit) {
    if (!widget.online) {
      setState(() => _error = l10nOf(context).ytNetworkOff);
      return;
    }
    if (widget.officialOnly && !hit.isOfficialGiven(_vouched)) {
      setState(() => _error = l10nOf(context).ytNotOfficialSkipped);
      return;
    }
    widget.downloads.enqueue(
      DownloadJob(
        videoId: hit.id,
        title: hit.title,
        channel: hit.channel,
        thumbnailUrl: hit.thumbnailUrl,
        duration: hit.duration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = skinOf();

    final chrome = PresentationScope.of(context, fallback: skin).kit.chrome;

    final dynamic st = widget.state;
    final art = st.artForSurface(SurfaceId.search);
    return Stack(
      clipBehavior: chrome.backdropClip,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: chrome.backdropReach,
          child: ScreenBackdrop(
            skin: skin,
            art: art,
            focus: art == null ? null : st.focusForPiece(art),
          ),
        ),

        ColoredBox(
          color: skin.background.withValues(alpha: 0.72),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppScreenHeader(
                  skin: skin,
                  title: l10nOf(context).librarySearch,
                  mark: widget.headerMark,
                  leading: widget.onBack == null
                      ? null
                      : Semantics(
                          button: true,
                          label: MaterialLocalizations.of(context)
                              .backButtonTooltip,
                          excludeSemantics: true,
                          onTap: widget.onBack,
                          child: GestureDetector(
                            key: const Key('search-back'),
                            onTap: widget.onBack,
                            behavior: HitTestBehavior.opaque,
                            // The header centres its row: a 48 box is the whole
                            // of the touch target, the glyph need not fill it.
                            child: SizedBox(
                              width: Space.tap,
                              height: Space.tap,
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: skin.accentInk,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctl,
                          onChanged: _onQueryChanged,
                          onSubmitted: (_) => _search(),
                          textInputAction: TextInputAction.search,
                          cursorColor: skin.accent,
                          style: TextStyle(
                            fontSize: LayoutSpec.fontSmall,
                            color: skin.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: l10nOf(context).ytSearchHint,
                            hintStyle: TextStyle(
                              color: skin.textSecondary,
                              fontSize: LayoutSpec.fontSmall,
                            ),
                            filled: true,
                            fillColor: skin.panel,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(color: skin.edge(0.35)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: skin.accent,
                                width: 2,
                              ),
                            ),
                            suffixIcon:
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _ctl,
                                  builder: (context, value, _) => Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (value.text.isNotEmpty)
                                        _iconTarget(
                                          key: const Key('search-clear'),
                                          icon: Icons.close_rounded,
                                          label: l10nOf(context).ytClearSearch,
                                          color: skin.textSecondary,
                                          onTap: _clearQuery,
                                        ),
                                      if (_searching)
                                        const Padding(
                                          padding: EdgeInsets.all(14),
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                            ),
                                          ),
                                        )
                                      else
                                        _iconTarget(
                                          key: const Key('search-submit'),
                                          icon: Icons.search_rounded,
                                          label: l10nOf(context).ytSearchHint,
                                          color: skin.accentInk,
                                          onTap: _search,
                                        ),
                                    ],
                                  ),
                                ),
                          ),
                        ),
                      ),
                      if (!widget.allowNetwork &&
                          widget.onSearchOnline != null) ...[
                        const SizedBox(width: 8),
                        Semantics(
                          button: true,
                          toggled: widget.searchOnline,
                          label: widget.searchOnline
                              ? l10nOf(context).ytSearchingOnline
                              : l10nOf(context).ytNetworkOnSearchOnly,
                          excludeSemantics: true,
                          onTap: () =>
                              widget.onSearchOnline!(!widget.searchOnline),
                          child: GestureDetector(
                            onTap: () =>
                                widget.onSearchOnline!(!widget.searchOnline),
                            child: Container(
                              width: Space.tap,
                              height: Space.tap,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: widget.searchOnline
                                      ? skin.accent
                                      : skin.secondary(0.5),
                                  width: widget.searchOnline ? 2 : 1,
                                ),
                                color: widget.searchOnline
                                    ? skin.accentAt(0.14)
                                    : null,
                              ),
                              child: Tooltip(
                                message: widget.searchOnline
                                    ? l10nOf(context).ytSearchingOnline
                                    : l10nOf(context).ytNetworkOnSearchOnly,
                                child: Icon(
                                  widget.searchOnline
                                      ? Icons.wifi_rounded
                                      : Icons.wifi_off_rounded,
                                  color: widget.searchOnline
                                      ? skin.accentInk
                                      : skin.textSecondary,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: SizedBox(
                    height: Space.tap,
                    child: OutlinedButton.icon(
                      key: const Key('import-playlist'),
                      onPressed: _openImport,
                      icon: Icon(
                        Icons.playlist_add_rounded,
                        color: skin.accentInk,
                      ),
                      label: Text(
                        l10nOf(context).ytImportPlaylist,
                        style: TextStyle(
                          fontSize: LayoutSpec.fontFloor,
                          letterSpacing: trackingFor(context, 1.2),
                          fontWeight: FontWeight.w800,
                          color: skin.accentInk,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: skin.accentAt(0.6)),
                      ),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: skin.accentInk,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              fontSize: LayoutSpec.fontFloor,
                              color: skin.accentInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (widget.downloads.downloadsCompiledOut ||
                    (widget.downloads.needsEngine &&
                        !widget.downloads.checkingEngine))
                  _setupBanner(skin),
                Expanded(
                  // Nothing searched yet: the suggestions sit in the middle of
                  // the space they are about, not pinned under the button as if
                  // a list had failed to load.
                  child: _quiet
                      ? Center(child: _artistBand(skin))
                      : ListView(
                          // Scrolling the results is reading them: the keyboard
                          // that was covering half of them can go.
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.only(
                            bottom: PresentationScope.of(
                              context,
                              fallback: skin,
                            ).arrangement.bottomClearance,
                          ),
                          children: _body(skin),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// What the page shows under the field: the rows for the query, or the note
  /// that the query found nothing.
  List<Widget> _body(Skin skin) {
    final l10n = l10nOf(context);
    return [
      if (_local.isNotEmpty) _section(skin, l10n.ytInLibrary),
      for (final hit in _local) _row(skin, hit),
      if (_hits.isNotEmpty) _section(skin, l10n.ytOnYoutube),
      for (final hit in _hits) _row(skin, hit),
      if (_searched != null && _hits.isEmpty && _error == null)
        _note(skin, l10n.ytNoResults(_searched!)),
    ];
  }

  /// No query, no rows, no answer: the page has nothing to show yet, which is
  /// the one state allowed to look empty.
  bool get _quiet =>
      _local.isEmpty &&
      _hits.isEmpty &&
      _searched == null &&
      _error == null &&
      !_searching;

  Widget _section(Skin skin, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 14,
        letterSpacing: trackingFor(context, 1.4),
        fontWeight: FontWeight.w800,
        color: skin.textSecondary,
      ),
    ),
  );

  Widget _note(Skin skin, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: LayoutSpec.fontSmall,
        color: skin.textSecondary,
      ),
    ),
  );

  Widget _artistBand(Skin skin) {
    final artists = _artistSuggestions();
    if (artists.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      // A board of choices, wrapped, so a library with several artists reads as
      // "pick one" rather than as a single lonely chip.
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [for (final artist in artists) _artistChip(skin, artist)],
      ),
    );
  }

  Widget _artistChip(Skin skin, String artist) => Semantics(
    button: true,
    label: artist,
    excludeSemantics: true,
    onTap: () => _searchFor(artist),
    child: GestureDetector(
      key: Key('artist-suggestion-$artist'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _searchFor(artist),
      child: Container(
        height: Space.tap,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: skin.panel,
          border: Border.all(color: skin.accentAt(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 18, color: skin.accentInk),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: LayoutSpec.fontFloor,
                  fontWeight: FontWeight.w700,
                  color: skin.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// One control, one meaning, never smaller than the touch floor: play,
  /// stop, try again, or take the track.
  Widget _iconTarget({
    Key? key,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    onTap: onTap,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        key: key,
        width: Space.tap,
        height: Space.tap,
        child: Icon(icon, color: color, size: 22),
      ),
    ),
  );

  Widget _rowAction(
    Skin skin,
    SearchHit hit, {
    required bool done,
    required DownloadJob? job,
    required bool running,
    required DownloadIssue? issue,
  }) {
    final l10n = l10nOf(context);
    final action = rowActionFor(
      inLibrary: done,
      playable: widget.onPlay != null && _libraryIds.contains(hit.id),
      queued: job != null,
      failed: issue != null,
      officialOnly: widget.officialOnly,
      official: hit.isOfficialGiven(_vouched),
      engineMissing:
          widget.downloads.needsEngine || widget.downloads.downloadsCompiledOut,
    );
    return switch (action) {
      RowAction.play => _iconTarget(
        key: const Key('search-play'),
        icon: Icons.play_circle_fill_rounded,
        label: l10n.ytPlayThis,
        color: skin.accentInk,
        onTap: () => widget.onPlay!(hit.id),
      ),
      RowAction.done => Icon(Icons.check_circle_rounded, color: skin.accentInk),
      RowAction.cancel => _iconTarget(
        key: const Key('row-cancel'),
        icon: Icons.close_rounded,
        label: l10n.downloadCancel,
        color: skin.accentInk,
        // A download that has not started is not cancelled, it is taken out of
        // the queue: stopping "the download" while another one runs stops the
        // wrong one.
        onTap: () => running
            ? widget.downloads.cancelCurrent()
            : widget.downloads.remove(job!),
      ),
      RowAction.retry => _iconTarget(
        key: const Key('row-retry'),
        icon: Icons.refresh_rounded,
        label: l10n.downloadRetry,
        color: skin.accentInk,
        onTap: () {
          widget.downloads.clearErrorFor(hit.id);
          _download(hit);
        },
      ),
      RowAction.blocked => Tooltip(
        message: l10n.ytNotOfficialBadge,
        child: Icon(Icons.block_rounded, color: skin.secondary(0.5)),
      ),
      // The banner above the list is where this is dealt with. A live icon per
      // row was thirty buttons that all did nothing.
      RowAction.unavailable => Icon(
        Icons.download_rounded,
        color: skin.textMuted,
      ),
      RowAction.download => _iconTarget(
        key: Key('row-download-${hit.id}'),
        icon: Icons.download_rounded,
        label: l10n.ytDownload,
        color: skin.accentInk,
        onTap: () => _download(hit),
      ),
    };
  }

  Widget _row(Skin skin, SearchHit hit) {
    if (hit.localCoverPath != null ||
        _local.any((l) => l.id == hit.id && l.thumbnailUrl == null)) {
      return _localRow(skin, hit);
    }
    // Read the live job, never a snapshot of it.
    final job = widget.downloads.jobFor(hit.id);
    final p = job?.fraction;
    final downloading = job != null;
    final running = job != null && identical(widget.downloads.current, job);
    final done = _libraryIds.contains(hit.id);
    // The reason a download died is kept per video, so the row can say it
    // instead of the ring simply stopping.
    final issue = done || downloading
        ? null
        : widget.downloads.errorFor(hit.id);
    final l10n = l10nOf(context);
    final failure = issue == null
        ? null
        : switch (issue.kind) {
            DownloadBlockKind.needsAllFiles => l10n.downloadNeedsAllFiles,
            DownloadBlockKind.cannotWrite => l10n.downloadCannotWrite,
            null => l10n.downloadFailed(issue.detail ?? ''),
          };
    return Container(
      // The row IS the progress. A separate queue above the list made the same
      // download appear twice and never where the user was looking.
      color: downloading ? skin.accentAt(0.12) : null,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap:
                (done && widget.onPlay != null && _libraryIds.contains(hit.id))
                ? () => widget.onPlay!(hit.id)
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 56,
                height: 42,
                child: hit.thumbnailUrl == null
                    ? Container(color: skin.panel)
                    : Image.network(
                        hit.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: skin.panel),
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : Container(color: skin.panel),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hit.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: LayoutSpec.fontSmall,
                    color: skin.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (widget.officialOnly) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: hit.isOfficialGiven(_vouched)
                              ? skin.accentAt(0.22)
                              : skin.panel,
                          border: Border.all(
                            color: hit.isOfficialGiven(_vouched)
                                ? skin.accent
                                : skin.secondary(0.5),
                          ),
                        ),
                        child: Text(
                          hit.isOfficialGiven(_vouched)
                              ? l10nOf(context).ytOfficial
                              : l10nOf(context).ytNotOfficial,
                          style: TextStyle(
                            fontSize: LayoutSpec.fontMicro,
                            fontWeight: FontWeight.w800,
                            letterSpacing: trackingFor(context, 0.6),
                            color: hit.isOfficialGiven(_vouched)
                                ? skin.accentInk
                                : skin.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        '${hit.channel} · ${_mmss(hit.duration)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: LayoutSpec.fontFloor,
                          color: skin.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (downloading) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    // Waiting in the queue is not progress: a bar that moves
                    // for a download that has not started said work was
                    // happening.
                    value: running ? p : 0,
                    color: running ? skin.accent : skin.textMuted,
                    backgroundColor: skin.panel,
                    minHeight: 3,
                  ),
                ],
                if (failure != null) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => toast(context, failure),
                    child: Text(
                      l10n.downloadFailedShort(failure),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: skin.textPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _rowAction(
            skin,
            hit,
            done: done,
            job: job,
            running: running,
            issue: issue,
          ),
        ],
      ),
    );
  }

  Widget _localRow(Skin skin, SearchHit hit) {
    final cover = hit.localCoverPath;
    return Semantics(
      button: widget.onPlay != null,
      label: l10nOf(context).ytPlayThis,
      child: GestureDetector(
        key: Key('local-row-${hit.id}'),
        onTap: widget.onPlay == null ? null : () => widget.onPlay!(hit.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 56,
                  height: 42,
                  child: cover == null
                      ? Container(color: skin.panel)
                      : Image.file(
                          File(cover),
                          fit: BoxFit.cover,
                          cacheWidth: 168,
                          errorBuilder: (_, __, ___) =>
                              Container(color: skin.panel),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: LayoutSpec.fontSmall,
                        color: skin.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${hit.channel} · ${_mmss(hit.duration)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: LayoutSpec.fontFloor,
                        color: skin.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.play_circle_fill_rounded, color: skin.accentInk),
            ],
          ),
        ),
      ),
    );
  }

  static String _mmss(Duration d) => mmss(d);
}

/// What the control at the end of a search row is for.
///
/// One slot, one meaning: whatever else is true about a track, the row offers
/// exactly one thing to do with it. Kept out of the widget so the order of
/// those claims - a running download outranks a stale failure, a finished one
/// outranks both - is testable without a phone or YouTube.
enum RowAction { play, done, cancel, retry, blocked, unavailable, download }

RowAction rowActionFor({
  required bool inLibrary,
  required bool playable,
  required bool queued,
  required bool failed,
  required bool officialOnly,
  required bool official,
  required bool engineMissing,
}) {
  if (inLibrary) return playable ? RowAction.play : RowAction.done;
  if (queued) return RowAction.cancel;
  if (failed) return RowAction.retry;
  if (officialOnly && !official) return RowAction.blocked;
  if (engineMissing) return RowAction.unavailable;
  return RowAction.download;
}
