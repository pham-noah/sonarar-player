library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;

import '../download/download_manager.dart';
import '../library/downloaded_tracks.dart';
import '../library/playlists.dart';
import '../theme/layout.dart';
import '../library/track.dart';
import '../library/library_repository.dart';
import '../theme/personalization.dart';
import '../theme/skin.dart';
import 'app_header.dart';
import '../widgets/screen_backdrop.dart';
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
      looksLikeOfficialRelease || vouchedChannels.contains(channel.toLowerCase());

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
  });

  final dynamic state;

  final LibraryRepository repo;

  final PlaylistSources playlistStore;

  final File? manifest;

  final bool allowNetwork;

  final bool searchOnline;

  final Widget? headerMark;

  final ValueChanged<bool>? onSearchOnline;

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
  bool _searching = false;
  String? _error;



  List<SearchHit> _local = const [];

  static String _fold(String s) => _foldForSearch(s);

  Timer? _typing;
  static const Duration _typingPause = Duration(milliseconds: 120);

  void _onQueryChanged(String raw) {
    _typing?.cancel();
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
      hits.add(SearchHit(
        id: t.id,
        title: t.title,
        channel: t.artist,
        duration: t.duration,
        thumbnailUrl: null,
        localCoverPath: widget.repo.coverPathFor(t),
      ));
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
      setState(() => _error =
          'Network is off in Settings, so nothing can be searched or downloaded.');
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
        _error = local.isEmpty
            ? 'Network is off in Settings, and nothing in your library matches.'
            : null;
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
      final results = await _yt.search.search(q);
      if (!mounted) return;

      final hits = [
        for (final v in results.take(30))
          SearchHit(
            id: v.id.value,
            title: v.title,
            channel: v.author,
            duration: v.duration ?? Duration.zero,
            thumbnailUrl: v.thumbnails.mediumResUrl,
          ),
      ];
      setState(() {
        _hits = hits;

        _libraryIds = _inLibrary();

        _vouched = _vouchChannels(hits);
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = '$e';
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
      setState(() => _error =
          'Network is off in Settings, so nothing can be searched or downloaded.');
      return;
    }
    if (widget.officialOnly && !hit.isOfficialGiven(_vouched)) {
      setState(() => _error =
          'Not an official release, so it was not downloaded. Turn off "Official only" '
          'in Settings to take any upload.');
      return;
    }
    widget.downloads.enqueue(DownloadJob(
      videoId: hit.id,
      title: hit.title,
      channel: hit.channel,
      thumbnailUrl: hit.thumbnailUrl,
      duration: hit.duration,
    ));
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
                  title: 'SEARCH',
                  mark: widget.headerMark,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                  child: Row(
                    children: [
                    Expanded(
                    child: TextField(
                    controller: _ctl,
                    onChanged: _onQueryChanged,
                    onSubmitted: (_) => _search(),
                    textInputAction: TextInputAction.search,
                    cursorColor: skin.accent,
                    style: TextStyle(fontSize: 18, color: skin.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search YouTube',
                      hintStyle: TextStyle(color: skin.textSecondary, fontSize: 18),
                      filled: true,
                      fillColor: skin.panel,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(
                          color: skin.textSecondary.withValues(alpha: 0.35),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: skin.accent, width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.search_rounded, color: skin.accent),
                        onPressed: _search,
                      ),
                    ),
                    ),
                    ),
                    if (!widget.allowNetwork && widget.onSearchOnline != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => widget.onSearchOnline!(!widget.searchOnline),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: widget.searchOnline
                                  ? skin.accent
                                  : skin.textSecondary.withValues(alpha: 0.5),
                              width: widget.searchOnline ? 2 : 1,
                            ),
                            color: widget.searchOnline
                                ? skin.accent.withValues(alpha: 0.14)
                                : null,
                          ),
                          child: Tooltip(
                            message: widget.searchOnline
                                ? 'Searching online — tap to turn off'
                                : 'Turn the network on for SEARCH ONLY '
                                    '(place, time and weather stay off)',
                            child: Icon(
                              widget.searchOnline
                                  ? Icons.wifi_rounded
                                  : Icons.wifi_off_rounded,
                              color: widget.searchOnline
                                  ? skin.accent
                                  : skin.textSecondary,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _openImport,
                      icon: Icon(Icons.playlist_add_rounded, color: skin.accent),
                      label: Text('IMPORT A PLAYLIST',
                          style: TextStyle(
                              fontSize: 16,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w800,
                              color: skin.accent)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: skin.accent.withValues(alpha: 0.6)),
                      ),
                    ),
                  ),
                ),
                if (_searching)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(fontSize: 16, color: skin.accent),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.only(
                      bottom: PresentationScope.of(context, fallback: skin)
                          .arrangement
                          .bottomClearance,
                    ),
                    itemCount: _local.length + _hits.length + (_local.isEmpty ? 0 : 1),
                    itemBuilder: (context, i) {
                      if (_local.isNotEmpty) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                            child: Text('IN YOUR LIBRARY',
                                style: TextStyle(
                                  fontSize: 13,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w900,
                                  color: skin.textSecondary,
                                )),
                          );
                        }
                        final j = i - 1;
                        if (j < _local.length) return _row(skin, _local[j]);
                        final k = j - _local.length;

                        if (k == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                            child: Text('ON YOUTUBE',
                                style: TextStyle(
                                  fontSize: 13,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w900,
                                  color: skin.textSecondary,
                                )),
                          );
                        }
                        return _row(skin, _hits[k - 1]);
                      }
                      return _row(skin, _hits[i]);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(Skin skin, SearchHit hit) {
    if (hit.localCoverPath != null || _local.any((l) => l.id == hit.id && l.thumbnailUrl == null)) {
      return _localRow(skin, hit);
    }
    // Read the live job, never a snapshot of it.
    final job = widget.downloads.jobFor(hit.id);
    final p = job?.fraction;
    final downloading = job != null;
    final done = _libraryIds.contains(hit.id);
    // A download that died used to vanish without a word: the ring simply
    // stopped. The reason is kept per video so the row can say it.
    final failure = done || downloading ? null : widget.downloads.errorFor(hit.id);
    return Container(
      // The row IS the progress. A separate queue above the list made the same
      // download appear twice and never where the user was looking.
      color: downloading ? skin.accent.withValues(alpha: 0.12) : null,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Row(
        children: [

          GestureDetector(
            onTap: (done && widget.onPlay != null && _libraryIds.contains(hit.id))
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
                        errorBuilder: (_, __, ___) => Container(color: skin.panel),
                        loadingBuilder: (_, child, progress) =>
                            progress == null ? child : Container(color: skin.panel),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hit.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, color: skin.textPrimary)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (widget.officialOnly) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: hit.isOfficialGiven(_vouched)
                              ? skin.accent.withValues(alpha: 0.22)
                              : skin.panel,
                          border: Border.all(
                            color: hit.isOfficialGiven(_vouched)
                                ? skin.accent
                                : skin.textSecondary.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          hit.isOfficialGiven(_vouched) ? 'OFFICIAL' : 'NOT OFFICIAL',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: hit.isOfficialGiven(_vouched) ? skin.accent : skin.textSecondary,
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
                        style: TextStyle(fontSize: 16, color: skin.textSecondary),
                      ),
                    ),
                  ],
                ),
                if (downloading) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: p,
                    color: skin.accent,
                    backgroundColor: skin.panel,
                  ),
                ],
                if (failure != null) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(failure)),
                    ),
                    child: Text(
                      'FAILED — ${failure.replaceFirst('Download failed: ', '')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: skin.textPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (done)
            widget.onPlay != null && _libraryIds.contains(hit.id)
                ? IconButton(
                    key: const Key('search-play'),
                    onPressed: () => widget.onPlay!(hit.id),
                    icon: Icon(Icons.play_circle_fill_rounded, color: skin.accent),
                    tooltip: 'Play this',
                  )
                : Icon(Icons.check_circle_rounded, color: skin.accent)
          else if (downloading)
            SizedBox(
              key: const Key('row-downloading'),
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                value: p,
                strokeWidth: 2.5,
                color: skin.accent,
                backgroundColor: skin.panel,
              ),
            )
          else if (widget.officialOnly && !hit.isOfficialGiven(_vouched))
            Tooltip(
              message: 'Not an official release',
              child: Icon(Icons.block_rounded,
                  color: skin.textSecondary.withValues(alpha: 0.5)),
            )
          else
            IconButton(
              onPressed: () => _download(hit),
              icon: Icon(Icons.download_rounded, color: skin.accent),
              tooltip: 'Download to the library',
            ),
        ],
      ),
    );
  }

  Widget _localRow(Skin skin, SearchHit hit) {
    final cover = hit.localCoverPath;
    return GestureDetector(
      key: Key('local-row-${hit.id}'),
      onTap: widget.onPlay == null ? null : () => widget.onPlay!(hit.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 56,
                height: 42,
                child: cover == null
                    ? Container(color: skin.panel)
                    : Image.file(File(cover), fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: skin.panel)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 18, color: skin.textPrimary)),
                  const SizedBox(height: 2),
                  Text('${hit.channel} · ${_mmss(hit.duration)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, color: skin.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.play_circle_fill_rounded, color: skin.accent),
          ],
        ),
      ),
    );
  }

  static String _mmss(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
