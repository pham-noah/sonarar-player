library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../library/dynamic_playlist.dart';
import '../library/playlists.dart';
import '../library/rediscovery.dart';
import '../library/downloaded_tracks.dart';
import '../library/track.dart';
import '../theme/layout.dart';
import '../theme/skin.dart';
import '../theme/layout_kit.dart';
import '../widgets/panel_bodies.dart';
import '../widgets/cover_play_button.dart';
import '../widgets/devices.dart';
import '../widgets/swipe_panel.dart';
import 'app_header.dart';
import 'app_sidebar.dart';
import 'library_browser.dart';
import '../widgets/stagger_in.dart';

const double kLibraryRowHeight = 64;

const Key kLibraryRowSlideKey = Key('library-row-slide');

const double kQueueThreshold = 110;
const double kLikeThreshold = 110;

const double kSwipeTravelCap = 140;

enum _SwipeAction { queue, like }

enum SwipeOutcome { queued, alreadyQueued, liked, unliked, nothing }

enum _PlaylistKind { seeded, custom }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.tracks,
    required this.coverPathFor,
    required this.skin,
    this.libraryRoot,
    this.onManage,
    this.onTogglePlay,
    this.playingTrackId,
    this.isPlaying = false,
    this.onQueue,
    this.onLike,
    this.likedIds = const {},
    this.likedOrder = const [],
    this.searchRequest = 0,
    this.closeListRequest = 0,
    this.onListOpenChanged,
    this.artistRequest,
    this.onPlay,
    this.onAddSongs,
    this.onAddSongsTo,
    this.playlists,
    this.visiblePlaylists,
    this.headerScrollsAway = false,
    this.contentMaxWidth,
    this.derivedPlaylists = const [],
    this.dynamicBlurb,
    this.entryToken = 0,
    this.searchOnly = false,
    this.rankedList = false,
    this.grid = false,
    this.playlistSort = 'recents',
    this.pinnedPlaylistIds = const [],
    this.recentPlaylistIds = const [],
    this.onPlaylistSort,
    this.onTogglePin,
    this.onPlaylistGrid,
    this.headerMark,
    this.playlistGrid,
    this.onPlaylistOpened,
    this.onDragToQueue,
    this.headerArt,
    this.onOpenPlaylist,
    this.onPlayPlaylist,
    this.onOpenArtist,
    this.onCreatePlaylist,
    this.onDeletePlaylist,
    this.onRemoveFromPlaylist,
  });

  final void Function(Track)? onDragToQueue;

  final int entryToken;

  final List<Track> tracks;
  final String? Function(Track) coverPathFor;
  final Skin skin;
  final String? libraryRoot;

  final void Function(Track)? onManage;

  final void Function(Track)? onTogglePlay;

  final String? playingTrackId;

  final bool isPlaying;

  final SwipeOutcome Function(Track)? onQueue;

  final SwipeOutcome Function(Track)? onLike;

  final Set<String> likedIds;

  final List<String> likedOrder;

  final int searchRequest;

  final int closeListRequest;

  final ValueChanged<bool>? onListOpenChanged;

  final String? artistRequest;

  final void Function(Track)? onPlay;

  final PlaylistsView? playlists;

  final bool headerScrollsAway;

  final double? contentMaxWidth;

  final List<Playlist>? visiblePlaylists;

  final List<Playlist> derivedPlaylists;

  final String? dynamicBlurb;

  final bool searchOnly;

  final Widget? headerArt;

  final bool rankedList;

  final bool grid;

  final String playlistSort;

  final List<String> pinnedPlaylistIds;

  final List<String> recentPlaylistIds;

  final ValueChanged<String>? onPlaylistSort;

  final ValueChanged<String>? onTogglePin;

  final ValueChanged<bool>? onPlaylistGrid;

  final Widget? headerMark;

  final bool? playlistGrid;

  final ValueChanged<Playlist>? onPlaylistOpened;

  final void Function(Playlist)? onOpenPlaylist;
  final void Function(Playlist)? onPlayPlaylist;
  final void Function(String artist)? onOpenArtist;

  final void Function(String name)? onCreatePlaylist;

  final VoidCallback? onAddSongs;

  final void Function(Playlist playlist)? onAddSongsTo;
  final void Function(Playlist)? onDeletePlaylist;

  final void Function(Playlist, Track)? onRemoveFromPlaylist;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _listController = ScrollController();

  static const double _kLibraryBottomAir = 16;

  double get _clearance =>
      PresentationScope.of(context, fallback: widget.skin).arrangement.bottomClearance +
      _kLibraryBottomAir;

  int? _cursor;
  String _filter = '';

  LibraryView _view = LibraryView.playlists;

  List<String>? _sortedArtistsCache;

  List<String> get _sortedArtists {
    final cached = _sortedArtistsCache;
    if (cached != null) return cached;
    return _sortedArtistsCache = _byArtist.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  _PlaylistKind? _playlistFilter;

  bool? _playlistGrid;

  bool _kindChoicesOpen = false;

  LibraryView? _pickedView;

  bool get _playlistsAreGrid => _playlistGrid ?? widget.playlistGrid ?? widget.grid;

  bool get _searchOnly => widget.searchOnly;

  Playlist? _openPlaylist;

  String? _openArtist;
  late List<Track> _visible = widget.tracks;

  late Map<String, List<Track>> _byArtist = groupByArtist(widget.tracks);

  int get _artistCount => _byArtist.length;

  @override
  void didUpdateWidget(LibraryScreen old) {
    super.didUpdateWidget(old);
    if (old.entryToken != widget.entryToken) {
      _view = LibraryView.playlists;
      _playlistFilter = null;
      _openPlaylist = null;
      _openArtist = null;
      _cursor = null;
    }

    if (old.tracks != widget.tracks || !setEquals(old.likedIds, widget.likedIds)) {
      _byArtist = groupByArtist(widget.tracks);

      _sortedArtistsCache = null;
      _applyFilter();
    }

    if (old.searchRequest != widget.searchRequest) {
      _searchFocus.requestFocus();
      _searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchController.text.length,
      );
    }

    if (widget.closeListRequest != old.closeListRequest) {
      _closeOpenList();
    }

    if (widget.artistRequest != null &&
        widget.artistRequest != old.artistRequest) {
      setState(() => _applyArtistRequest(widget.artistRequest));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final terms = Track.searchTerms(_filter);
    setState(() {
      _visible = terms.isEmpty
          ? widget.tracks
          : widget.tracks.where((t) => t.matchesTerms(terms)).toList(growable: false);

      if (_cursor != null) {
        _cursor = _visible.isEmpty
            ? null
            : _cursor!.clamp(0, _visible.length - 1);
      }
    });
  }

  void _moveCursor(int delta) {
    if (_visible.isEmpty) return;

    final from = _cursor ?? (delta > 0 ? -1 : 0);
    final next = (from + delta).clamp(0, _visible.length - 1);
    setState(() => _cursor = next);
    _revealCursor();
  }

  void _revealCursor() {
    final i = _cursor;
    if (i == null || !_listController.hasClients) return;
    const rowHeight = kLibraryRowHeight;
    final position = _listController.position;
    final rowTop = i * rowHeight;
    final rowBottom = rowTop + rowHeight;

    final margin = rowHeight;
    if (rowTop - margin < position.pixels) {
      _listController.jumpTo((rowTop - margin).clamp(0.0, position.maxScrollExtent));
    } else if (rowBottom + margin > position.pixels + position.viewportDimension) {
      _listController.jumpTo((rowBottom + margin - position.viewportDimension)
          .clamp(0.0, position.maxScrollExtent));
    }
  }

  void _playCursor() {
    final i = _cursor;
    if (i == null || i >= _visible.length) return;
    widget.onPlay?.call(_visible[i]);
  }

  @override
  void initState() {
    super.initState();
    _applyFilter();

    _applyArtistRequest(widget.artistRequest);
  }

  void _applyArtistRequest(String? artist) {
    if (artist == null || artist.isEmpty) return;
    _view = LibraryView.artists;
    _openArtist = artist;
    _openPlaylist = null;
    _cursor = null;
  }

  void _selectView(LibraryView v) {
    setState(() {
      _view = v;

      _openPlaylist = null;
      _openArtist = null;
      _cursor = null;
    });
  }

  Widget _capped(Widget child) => widget.contentMaxWidth == null
      ? child
      : Center(
          child: ConstrainedBox(

            constraints: BoxConstraints(maxWidth: widget.contentMaxWidth!),
            child: child,
          ),
        );

  bool get debugListOpen => _openPlaylist != null || _openArtist != null;

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;

    if (_searchOnly) {
      final fullArt = widget.headerArt;
      return ColoredBox(
        color: PresentationScope.of(context, fallback: skin).palette.pageFill ??
              PresentationScope.of(context, fallback: skin).palette.background,
        child: Stack(
          children: [
            if (fullArt != null)
              Positioned.fill(

                child: IgnorePointer(
                  child: Opacity(opacity: 0.20, child: fullArt),
                ),
              ),
            SafeArea(
              child: _capped(Column(
                children: [

                  _header(
                    skin,
                    title: 'SEARCH',
                    countLabel: '${_visible.length} found',
                  ),
                  _searchField(skin),
                  const SizedBox(height: 4),
                  Expanded(child: _body(skin)),
                ],
              )),
            ),
          ],
        ),
      );
    }

    final page = Column(
          children: [
            if (!widget.headerScrollsAway) ...[
              _head(skin),
              const SizedBox(height: 4),
            ],
            Expanded(child: _body(skin)),
          ],
    );

    return ColoredBox(
      color: PresentationScope.of(context, fallback: skin).palette.pageFill ??
              PresentationScope.of(context, fallback: skin).palette.background,
      child: SafeArea(
        child: _capped(page),
      ),
    );
  }

  Widget _sortSegment(Skin skin, String label, String value) {
    final on = widget.playlistSort == value;
    return GestureDetector(
      onTap: widget.onPlaylistSort == null
          ? null
          : () => widget.onPlaylistSort!(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          color: on
              ? skin.accent.withValues(alpha: 0.92)
              : skin.background.withValues(alpha: 0.45),
          border: Border.all(
            color: on ? skin.accent : skin.textSecondary.withValues(alpha: 0.55),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: kBrowserChipFont,
            letterSpacing: 0.3,
            fontWeight: FontWeight.w900,
            color: on ? skin.onAccent : skin.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _playlistCell(Skin skin, Playlist p) {
    final pinned = widget.pinnedPlaylistIds.contains(p.id);
    return GestureDetector(
      onTap: () => _openList(p),

      onLongPress: () => _playlistActions(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: pinned
                      ? skin.accent
                      : skin.textSecondary.withValues(alpha: 0.28),
                  width: pinned ? 2 : 1,
                ),
              ),
              child: _coverOfFirst(p) == null
                  ? Center(
                      child: Icon(Icons.queue_music_rounded,
                          color: skin.textSecondary, size: 30))
                  : Image(image: _coverOfFirst(p)!, fit: BoxFit.cover),
            ),
          ),

          if (pinned) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.push_pin_rounded, color: skin.accent, size: 14),
                const SizedBox(width: 5),

                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'PINNED',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: LayoutSpec.fontLabel,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w900,
                        color: skin.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: LayoutSpec.fontSmall,
                    fontWeight: FontWeight.w800,
                    color: skin.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openList(Playlist p) {
    setState(() {
      _openPlaylist = p;
      _cursor = null;
    });
    widget.onPlaylistOpened?.call(p);

    widget.onListOpenChanged?.call(true);
  }

  void _closeOpenList() {
    if (_openPlaylist == null && _openArtist == null) return;
    setState(() {
      _openPlaylist = null;
      _openArtist = null;
      _cursor = null;
    });
    widget.onListOpenChanged?.call(false);
  }

  Widget _kindChip(Skin skin, String label, _PlaylistKind kind) {
    final on = _playlistFilter == kind;
    return GestureDetector(

      onTap: () => setState(() {
        _playlistFilter = on ? null : kind;
        _kindChoicesOpen = false;

        _pickedView = on ? null : LibraryView.playlists;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          color: on
              ? skin.accent.withValues(alpha: 0.92)
              : skin.background.withValues(alpha: 0.45),
          border: Border.all(
            color: on ? skin.accent : skin.textSecondary.withValues(alpha: 0.55),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(

            fontSize: kBrowserChipFont,
            letterSpacing: 0.3,
            fontWeight: FontWeight.w900,
            color: on ? skin.onAccent : skin.textPrimary,
          ),
        ),
      ),
    );
  }

  bool get _showBrowserBar =>
      _openPlaylist == null && _openArtist == null && widget.playlists != null;

  Playlist? get _openListForAdd {
    final opened = _openPlaylist;
    if (opened != null && widget.onAddSongsTo != null) return opened;
    return null;
  }

  bool get _plusAddsSongs => _openListForAdd != null || widget.onAddSongs != null;

  VoidCallback? get _plusAction {
    final target = _openListForAdd;
    if (target != null) return () => widget.onAddSongsTo!(target);
    if (widget.onAddSongs != null) return widget.onAddSongs;
    return widget.onCreatePlaylist == null ? null : _newPlaylistDialog;
  }

  Widget _head(Skin skin) => _headStrip(
        skin,
        Column(

          mainAxisSize: MainAxisSize.min,
          children: [
            _header(
              skin,
              onNewPlaylist: _plusAction,
              newPlaylistIcon:
                  _plusAddsSongs ? Icons.playlist_add_rounded : Icons.add_rounded,
            ),

            if (_showBrowserBar)
            LibraryBrowserBar(
              skin: skin,
              current: _view,

              onSelect: (v) {
                if (v == _view) {
                  setState(() {
                    if (v == LibraryView.playlists) {
                      _pickedView = _pickedView == v ? null : v;
                      _kindChoicesOpen = _pickedView == LibraryView.playlists;
                      _playlistFilter = null;
                    } else {
                      _pickedView = _pickedView == v ? null : v;
                    }
                  });
                  return;
                }
                setState(() {
                  _kindChoicesOpen = false;
                  _pickedView = v;

                  _playlistFilter = null;
                });
                _selectView(v);
              },
              playlistCount: widget.playlists?.length ?? 0,
              artistCount: _artistCount,
              songCount: widget.tracks.length,
              besidePlaylists: !_kindChoicesOpen
                  ? const []
                  : [
                      _kindChip(skin, 'SEEDED', _PlaylistKind.seeded),
                      const SizedBox(width: 5),
                      _kindChip(skin, 'CUSTOM', _PlaylistKind.custom),
                    ],
              pickedView: _pickedView,
              filterLabel: _playlistFilter?.name,

              onClearFilter: () => setState(() {
                _playlistFilter = null;
                _kindChoicesOpen = false;
                _pickedView = null;
              }),
            ),
          ],
        ),
      );

  Widget _headStrip(
    Skin skin,
    Widget head, {
    bool scrim = true,
  }) {
    final art = widget.headerArt;
    if (art == null) return head;
    final artLayer = Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,

      child: IgnorePointer(child: art),
    );

    final stack = Stack(
      clipBehavior: Clip.hardEdge,
      children: [
          artLayer,
          if (scrim)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    skin.background.withValues(alpha: 0.42),
                    skin.background.withValues(alpha: 0.80),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: skin.accent.withValues(alpha: 0.45),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          head,
        ],
    );
    return stack;
  }

  Widget _header(
    Skin skin, {
    String title = 'LIBRARY',
    String? countLabel,

    VoidCallback? onNewPlaylist,

    IconData newPlaylistIcon = Icons.add_rounded,
  }) {
    final presentation = PresentationScope.of(context, fallback: skin);

    Widget? plus(Color color) => onNewPlaylist == null
        ? null
        : GestureDetector(
            onTap: onNewPlaylist,

            child: SizedBox(
              width: 44,
              height: 34,
              child: Center(
                child: Icon(
                  newPlaylistIcon,
                  size: 28,
                  color: color,
                ),
              ),
            ),
          );

    if (presentation.kit.chrome.libraryHeader == HeaderForm.appHeader) {
      return AppScreenHeader(
        skin: skin,
        title: title,
        mark: widget.headerMark,
        trailing: plus(presentation.palette.textPrimary),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 20, 8),
      child: Row(
        children: [
          if (widget.headerMark != null)
            SidebarMarkButton(mark: widget.headerMark!, size: AppScreenHeader.markSize),
          Expanded(
            child: SectionBand(
              skin: skin,
              label: title,

              trailing: plus(presentation.palette.pageFill ?? presentation.palette.background),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField(Skin skin) {
    final slant = skin.skewDegrees * (3.14159265 / 180);
    final square = slant.abs() < 0.001;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Transform(
        transform: Matrix4.skewX(-slant * 0.5),
        alignment: Alignment.centerLeft,
        child: Container(

          decoration: BoxDecoration(
            color: skin.accent,
            borderRadius: square ? BorderRadius.circular(12) : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Transform(
            transform: Matrix4.skewX(slant * 0.5),
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              style: TextStyle(
                fontSize: LayoutSpec.fontBase,
                fontWeight: FontWeight.w700,
                color: skin.textPrimary,
              ),
              cursorColor: skin.textPrimary,
              onChanged: (v) {
                _filter = v;
                _applyFilter();
              },
              decoration: InputDecoration(
                hintText: 'Title, artist, album, folder',
                hintStyle: TextStyle(
                  fontSize: LayoutSpec.fontBase,
                  color: skin.textPrimary.withValues(alpha: 0.66),
                ),
                border: InputBorder.none,
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded,
                    color: skin.textPrimary, size: 26),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(Skin skin) {
    if (_searchOnly) return _list(skin);
    if (_openPlaylist != null || _openArtist != null) return _filteredList(skin);
    switch (_view) {
      case LibraryView.playlists:
        return _playlistsView(skin);
      case LibraryView.artists:
        return _artistsView(skin);
      case LibraryView.songs:

        return _list(skin);
    }
  }

  Widget _filteredList(Skin skin) {
    final name = _openPlaylist?.name ?? _openArtist ?? '';
    final tracks = _tracksForOpen();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

        GestureDetector(
          onTap: _closeOpenList,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Row(
              children: [
                Icon(Icons.arrow_back_rounded, color: skin.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                    fontSize: LayoutSpec.fontLabel,
                      fontWeight: FontWeight.w800,
                      color: skin.accent,
                    ),
                  ),
                ),
                Text(
                  '${tracks.length}',
                  style: TextStyle(
                    fontSize: LayoutSpec.fontLabel,
                    color: skin.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: tracks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _openPlaylist != null
                          ? 'This playlist is empty.\nLong-press a track to add it.'
                          : 'No tracks by this artist.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: LayoutSpec.fontBase,
                        color: skin.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                )
              : _list(skin, tracks, _openPlaylist),
        ),
      ],
    );
  }

  List<Track> _tracksForOpen() {
    final pl = _openPlaylist;
    if (pl != null) {
      final byId = {for (final t in widget.tracks) t.id: t};
      return [
        for (final id in pl.trackIds)
          if (byId[id] != null) byId[id]!,
      ];
    }
    final artist = _openArtist;
    if (artist == null) return const [];
    return widget.tracks.where((t) => t.artist.trim() == artist).toList();
  }

  Widget _playlistsView(Skin skin) {
    final all = widget.visiblePlaylists ?? widget.playlists?.all ?? const <Playlist>[];
    var derived = [for (final p in all) if (isDerivedPlaylistId(p.id)) p];
    var seeded = [
      for (final p in all)
        if (!isDerivedPlaylistId(p.id) && isSeededPlaylistId(p.id)) p
    ];
    var custom = [
      for (final p in all)
        if (!isDerivedPlaylistId(p.id) && !isSeededPlaylistId(p.id)) p
    ];

    List<Playlist> arrange(List<Playlist> input) {
      final pinned = widget.pinnedPlaylistIds.toSet();
      final all = widget.playlists?.all ?? const <Playlist>[];
      final fileOrder = {for (var i = 0; i < all.length; i++) all[i].id: i};
      int byFileOrder(Playlist a, Playlist b) {
        final ia = fileOrder[a.id];
        final ib = fileOrder[b.id];

        if (ia == null && ib == null) {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
        if (ia == null) return 1;
        if (ib == null) return -1;
        return ib.compareTo(ia);
      }

      int bySort(Playlist a, Playlist b) {
        switch (widget.playlistSort) {
          case 'alpha':
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          case 'updated':

            if (a.updatedAt == 0 && b.updatedAt == 0) return byFileOrder(a, b);
            if (a.updatedAt == 0) return 1;
            if (b.updatedAt == 0) return -1;
            return b.updatedAt.compareTo(a.updatedAt);
          default:
            if (a.createdAt == 0 && b.createdAt == 0) return byFileOrder(a, b);
            if (a.createdAt == 0) return 1;
            if (b.createdAt == 0) return -1;
            return b.createdAt.compareTo(a.createdAt);
        }
      }

      final isPinned = [for (final p in input) if (pinned.contains(p.id)) p]..sort(bySort);
      final rest = [for (final p in input) if (!pinned.contains(p.id)) p]..sort(bySort);
      return [...isPinned, ...rest];
    }

    final liked = likedAsPlaylist(orderedIds: widget.likedOrder);

    final lists = arrange(switch (_playlistFilter) {
      _PlaylistKind.seeded => seeded,
      _PlaylistKind.custom => custom,
      null => [...seeded, ...custom],
    });

    return ListView(
      padding: EdgeInsets.only(bottom: _clearance),
      children: [

        if (widget.headerScrollsAway) _head(skin),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Row(
            children: [
              _sortSegment(skin, 'RECENTS', 'recents'),
              const SizedBox(width: 6),
              _sortSegment(skin, 'UPDATED', 'updated'),
              const SizedBox(width: 6),
              _sortSegment(skin, 'A–Z', 'alpha'),
              const Spacer(),

              GestureDetector(
                onTap: widget.onPlaylistGrid == null
                    ? null
                    : () => widget.onPlaylistGrid!(!_playlistsAreGrid),
                child: Icon(
                  _playlistsAreGrid
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  color: widget.onPlaylistGrid == null
                      ? skin.textSecondary.withValues(alpha: 0.4)
                      : skin.accent,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
        if (!_playlistsAreGrid)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: PlaylistRow(
              skin: skin,
              playlist: liked,
              cover: _coverOfFirst(liked),

              pinned: widget.pinnedPlaylistIds.contains(kLikedPlaylistId),
              onOpen: () => _openList(liked),
              onLongPress: () => _playlistActions(liked),
              onPlay: widget.onPlayPlaylist == null
                  ? null
                  : () => widget.onPlayPlaylist!(liked),
            ),
          ),
        if (!_playlistsAreGrid && _playlistFilter != _PlaylistKind.custom)
          for (final p in derived)
            if (p.id != kRediscoverId &&
                (p.id == kDownloadedId || (p.id != kDynamicId && !p.isEmpty)))
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: PlaylistRow(
                  skin: skin,
                  playlist: p,
                  cover: _coverOfFirst(p),
                  pinned: widget.pinnedPlaylistIds.contains(p.id),
                  onOpen: () => _openList(p),

                  onLongPress: () => _playlistActions(p),
                  onPlay: widget.onPlayPlaylist == null
                      ? null
                      : () => widget.onPlayPlaylist!(p),
                ),
              ),

        if (lists.isEmpty &&
            !derived.any((p) => p.id != kRediscoverId))
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(
              'No playlists yet.',
              style: TextStyle(
                fontSize: LayoutSpec.fontBase,
                color: skin.textSecondary,
              ),
            ),
          )
        else if (_playlistsAreGrid)
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 12.0;

              final cell = (constraints.maxWidth - 40 - gap * 2) / 3;
              final cells = <Widget>[
                _playlistCell(skin, liked),
                if (_playlistFilter != _PlaylistKind.custom)
                  for (final p in derived)
            if (p.id != kRediscoverId &&
                (p.id == kDownloadedId || (p.id != kDynamicId && !p.isEmpty)))
                      _playlistCell(skin, p),
                for (final p in lists) _playlistCell(skin, p),
              ];
              return Wrap(
                spacing: gap,
                runSpacing: 14,
                children: [
                  for (final entry in cells.asMap().entries)
                    StaggerIn(
                      index: entry.key,
                      style: StaggerStyle.shelf,
                      child: SizedBox(
                        width: cell,
                        child: entry.value,
                      ),
                    ),
                ],
              );
            },
          )
        else
          for (final entry in lists.asMap().entries)

            StaggerIn(
              index: entry.key,
              style: StaggerStyle.shelf,
              child:
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: PlaylistRow(
                  skin: skin,
                  playlist: entry.value,

                  cover: _coverOfFirst(entry.value),
                  pinned: widget.pinnedPlaylistIds.contains(entry.value.id),

                  onOpen: () => _openList(entry.value),
                  onPlay: (widget.onPlayPlaylist == null || entry.value.isEmpty)
                      ? null
                      : () => widget.onPlayPlaylist!(entry.value),
                  onLongPress: () => _playlistActions(entry.value),
                ),
              ),
            ),
      ],
    );
  }

  Widget _artistsView(Skin skin) {
    final grouped = _byArtist;

    final names = _sortedArtists;

    if (names.isEmpty) {
      return Center(
        child: Text(
          'No artists.',
          style: TextStyle(fontSize: LayoutSpec.fontBase, color: skin.textSecondary),
        ),
      );
    }

    final withHeader = widget.headerScrollsAway;
    return ListView.builder(
      padding: EdgeInsets.only(bottom: _clearance),
      itemCount: names.length + (withHeader ? 1 : 0),
      itemBuilder: (context, i) {
        if (withHeader && i == 0) return _head(skin);
        final name = names[i - (withHeader ? 1 : 0)];
        final tracks = grouped[name]!;
        return StaggerIn(
          index: i,
          style: StaggerStyle.shelf,
          child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: ArtistRow(
            skin: skin,
            artist: name,
            count: tracks.length,
            cover: _coverOf(tracks.first),
            onOpen: () => setState(() {
              _openArtist = name;
              _cursor = null;
            }),
          ),
        ),
        );
      },
    );
  }

  ImageProvider? _coverOfFirst(Playlist p) {
    if (p.isEmpty) return null;
    final byId = {for (final t in widget.tracks) t.id: t};
    final t = byId[p.trackIds.first];
    return t == null ? null : _coverOf(t);
  }

  ImageProvider? _coverOf(Track t, {int decodeWidth = 120}) {
    final path = widget.coverPathFor(t);
    if (path == null || path.isEmpty) return null;
    final base = coverProviderFor(path);
    if (base == null) return null;
    return ResizeImage.resizeIfNeeded(decodeWidth, null, base);
  }

  Future<void> _newPlaylistDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PresentationScope.uiSkin(context, widget.skin).background,
        title: Text('New playlist',
            style: TextStyle(color: widget.skin.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: widget.skin.textPrimary),
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
    if (trimmed.isEmpty) return;
    widget.onCreatePlaylist?.call(trimmed);
  }

  Future<void> _playlistActions(Playlist p) async {
    final seeded = isSeededPlaylistId(p.id);
    final owned = !isDerivedPlaylistId(p.id) && !seeded;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: PresentationScope.uiSkin(context, widget.skin).background,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.onTogglePin != null)
              ListTile(
                leading: Icon(
                  widget.pinnedPlaylistIds.contains(p.id)
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  color: widget.skin.accent,
                ),
                title: Text(
                  widget.pinnedPlaylistIds.contains(p.id)
                      ? 'Unpin "${p.name}"'
                      : 'Pin "${p.name}"',
                  style: TextStyle(color: widget.skin.textPrimary),
                ),
                onTap: () => Navigator.of(ctx).pop('pin'),
              ),
            if (owned)
              ListTile(
                title: Text('Rename "${p.name}"',
                    style: TextStyle(color: widget.skin.textPrimary)),
                onTap: () => Navigator.of(ctx).pop('rename'),
              ),
            if (owned)
              ListTile(
                title: Text('Delete "${p.name}"',
                    style: TextStyle(color: widget.skin.accent)),
                onTap: () => Navigator.of(ctx).pop('delete'),
              ),
            if (seeded || isDerivedPlaylistId(p.id))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(

                  isDerivedPlaylistId(p.id)
                      ? 'Made by the app from what you listen to — pin it, but it cannot be renamed or deleted.'
                      : 'Shipped with the app — pin or rename it, but it cannot be deleted.',
                  style: TextStyle(
                    fontSize: LayoutSpec.fontLabel,
                    color: widget.skin.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (action == 'pin') {
      widget.onTogglePin?.call(p.id);
    }
    if (action == 'delete') {
      widget.onDeletePlaylist?.call(p);
    }
  }

  Widget _list(Skin skin, [List<Track>? source, Playlist? inPlaylist]) {
    final rows = source ?? _visible;
    if (widget.tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.library_music_outlined,
                  size: 64, color: skin.textSecondary),
              const SizedBox(height: 20),
              Text(
                'No library found on this device.',
                style: TextStyle(fontSize: LayoutSpec.fontTitle, color: skin.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Expected at:\n${widget.libraryRoot ?? ''}',
                style: TextStyle(fontSize: LayoutSpec.fontLabel, color: skin.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_visible.isEmpty) {
      return Center(
        child: Text(
          'Nothing matches "$_filter".',
          style: TextStyle(fontSize: LayoutSpec.fontBase, color: skin.textSecondary),
        ),
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _moveCursor(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _moveCursor(-1),
        const SingleActivator(LogicalKeyboardKey.enter): _playCursor,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _playCursor,
      },
      child: Focus(
        autofocus: true,

        child: (widget.grid || widget.headerScrollsAway)
            ? CustomScrollView(
                controller: _listController,
                slivers: [

                  if (widget.headerScrollsAway)
                    SliverToBoxAdapter(child: _head(skin)),
                  if (widget.grid)
                    SliverPadding(
                      padding: EdgeInsets.only(bottom: _clearance),
                      sliver: SliverGrid.builder(
                        itemCount: rows.length,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(

                          maxCrossAxisExtent: 150,
                          childAspectRatio: 0.78,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                        itemBuilder: (context, i) =>
                            _gridCard(context, i, rows, skin, inPlaylist),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.only(bottom: _clearance),
                      sliver: SliverList.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, i) => _rowAt(i, rows, skin),
                      ),
                    ),
                ],
              )
            : ListView.builder(
      controller: _listController,
      padding: EdgeInsets.only(bottom: _clearance),
      itemCount: rows.length,

      itemExtent: kLibraryRowHeight,
      itemBuilder: (context, i) => _rowAt(i, rows, skin, inPlaylist: inPlaylist, source: source),
    ),
        ),
      );
  }

  Widget _rowAt(int i, List<Track> rows, Skin skin, {Playlist? inPlaylist, List<Track>? source}) =>
      StaggerIn(
    index: i,

    style: StaggerStyle.shelf,
    child: _TrackRow(
    track: rows[i],
    coverPath: widget.coverPathFor(rows[i]),
    skin: skin,
    onManage: widget.onManage,

    onCoverTap: widget.onTogglePlay == null
        ? null
        : () {
            final t = rows[i];
            if (widget.playingTrackId == t.id) {
              widget.onTogglePlay!(t);
            } else {
              widget.onPlay?.call(t);
            }
          },

    isPlaying: widget.isPlaying,

    isLiked: widget.likedIds.contains(rows[i].id),
    onQueue: widget.onQueue == null
        ? null
        : (t) => widget.onQueue!(t),
    onDragToQueue: widget.onDragToQueue,

    dragLabel: rows[i].title,
    onLike: widget.onLike == null
        ? null
        : (t) {
            if (inPlaylist != null) {
              widget.onRemoveFromPlaylist?.call(inPlaylist, t);
            } else {
              widget.onLike!(t);
            }
          },
    inPlaylist: inPlaylist != null,

    onSelect: () => setState(() => _cursor = i),
    selected: _cursor == i && source == null,
    index: i,

    ranked: widget.rankedList,
  ),
  );

  Widget _gridCard(
    BuildContext context,
    int i,
    List<Track> rows,
    Skin skin,
    Playlist? inPlaylist,
  ) {
    final t = rows[i];
    final playing = widget.playingTrackId == t.id;
    final pal = PresentationScope.of(context, fallback: skin).palette;

    Widget coverBox = Container(
      decoration: BoxDecoration(
        color: pal.surface,
        border: Border.all(
          color: playing ? pal.accent : pal.border,
          width: playing ? 2 : 1,
        ),
      ),
      child: widget.coverPathFor(t) == null
          ? null
          : Image.file(File(widget.coverPathFor(t)!), fit: BoxFit.cover),
    );

    final drag = widget.onDragToQueue;
    if (drag != null) {
      coverBox = LongPressDraggable<Track>(
        data: t,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: _TrackRowState.dragFeedback(
          skin: skin,
          label: t.title,
          coverPath: widget.coverPathFor(t),

          size: 56,
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: coverBox),
        child: coverBox,
      );
    }

    return GestureDetector(
      onTap: widget.onPlay == null ? null : () => widget.onPlay!(t),

      onLongPress: widget.onManage == null ? null : () => widget.onManage!(t),
      behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: coverBox),
            const SizedBox(height: 6),
            Text(
              t.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: LayoutSpec.fontLabel,
                fontWeight: FontWeight.w600,
                color: playing ? pal.accent : pal.textPrimary,
              ),
            ),
            Text(
              t.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: LayoutSpec.fontLabel,
                color: pal.textSecondary,
              ),
            ),
          ],
        ),
    );
  }
}

class _TrackRow extends StatefulWidget {
  const _TrackRow({
    required this.track,
    required this.coverPath,
    required this.skin,
    this.index = 0,
    this.ranked = false,
    this.onManage,
    this.onQueue,
    this.onDragToQueue,
    this.dragLabel = '',
    this.onLike,
    this.isLiked = false,
    this.isPlaying = false,
    this.onSelect,
    this.selected = false,
    this.onCoverTap,
    this.inPlaylist = false,
  });

  final Track track;
  final String? coverPath;
  final Skin skin;

  final int index;

  final bool ranked;

  final void Function(Track)? onManage;

  final void Function(Track)? onQueue;

  final void Function(Track)? onDragToQueue;

  final String dragLabel;

  final void Function(Track)? onLike;

  final bool isLiked;

  final bool isPlaying;

  final VoidCallback? onSelect;

  final bool selected;

  final bool inPlaylist;

  final VoidCallback? onCoverTap;

  @override
  State<_TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<_TrackRow> {
  bool _hovered = false;

  double _dx = 0;

  @visibleForTesting
  double get horizontalOffset => _dx;

  _SwipeAction? get _pending {
    if (_dx >= kQueueThreshold) return _SwipeAction.queue;
    if (-_dx >= kLikeThreshold) return _SwipeAction.like;
    return null;
  }

  Track get track => widget.track;
  Skin get skin => widget.skin;
  String? get coverPath => widget.coverPath;
  void Function(Track)? get onManage => widget.onManage;
  bool get isLiked => widget.isLiked;
  bool get isPlaying => widget.isPlaying;
  bool get selected => widget.selected;
  VoidCallback? get onSelect => widget.onSelect;
  VoidCallback? get onCoverTap => widget.onCoverTap;
  void Function(Track)? get onQueue => widget.onQueue;
  void Function(Track)? get onDragToQueue => widget.onDragToQueue;
  String get dragLabel => widget.dragLabel;
  bool get inPlaylist => widget.inPlaylist;
  void Function(Track)? get onLike => widget.onLike;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: _build(),
    );
  }

  Widget _build() {
return Stack(
      fit: StackFit.passthrough,
      children: [
        if (_dx > 4)
          Positioned.fill(
            child: SwipePanel(
              side: SwipeSide.left,
              progress: _dx / kQueueThreshold,
              icon: Icons.playlist_add_rounded,
              label: 'QUEUE',
              skin: skin,
            ),
          ),
        if (_dx < -4)
          Positioned.fill(
            child: SwipePanel(
              side: SwipeSide.right,
              progress: -_dx / kLikeThreshold,
              icon: inPlaylist
                  ? Icons.remove_circle_outline_rounded
                  : (isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded),
              label: inPlaylist ? 'REMOVE' : (isLiked ? 'UNLIKE' : 'LIKE'),
              skin: skin,
            ),
          ),
        Transform.translate(

      key: kLibraryRowSlideKey,
      offset: Offset(_dx, 0),
      child: GestureDetector(
      onTap: onSelect,

      onLongPress: onManage == null ? null : () => onManage!(track),

      behavior: HitTestBehavior.opaque,

      onHorizontalDragUpdate: (widget.onQueue == null && widget.onLike == null)
          ? null
          : (d) => setState(() {
                _dx = (_dx + d.delta.dx)
                    .clamp(-kSwipeTravelCap, kSwipeTravelCap);
              }),
      onHorizontalDragCancel: () => setState(() => _dx = 0),
      onHorizontalDragEnd: (_) {
        final action = _pending;
        setState(() => _dx = 0);

        switch (action) {
          case _SwipeAction.queue:
            widget.onQueue?.call(track);
          case _SwipeAction.like:
            widget.onLike?.call(track);
          case null:
            break;
        }
      },
      child: Padding(

      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Stack(

      fit: StackFit.passthrough,
      children: [
        Column(
      mainAxisSize: MainAxisSize.min,

      mainAxisAlignment: MainAxisAlignment.center,
      children: [
      Row(
        children: [

          BigNumeral(
            skin: skin,
            value: widget.index + 1,
            dim: !widget.ranked,
            width: 28,
          ),
          const SizedBox(width: 6),
          _cover(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(

                    fontSize: LayoutSpec.fontLabel,
                    color: skin.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: LayoutSpec.fontLabel,
                    color: skin.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isLiked) ...[
            const SizedBox(width: 8),
            Icon(Icons.favorite_rounded, color: skin.accent, size: 15),
          ],
          const SizedBox(width: 12),
          Text(
            _fmt(track.duration),
            style: TextStyle(fontSize: LayoutSpec.fontLabel, color: skin.textSecondary),
          ),
        ],
      ),
      ],
      ),

      Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: 3,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          color: (selected || _hovered) ? skin.accent : Colors.transparent,
        ),
      ),

      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedContainer(

            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,

            color: (_hovered || selected) ? skin.panel : Colors.transparent,
          ),
        ),
      ),
      ],
      ),
      ),
      ),
        ),
      ],
    );
  }

  Widget _cover() {
    const size = 56.0;
    final path = coverPath;
    final button = CoverPlayButton(
      skin: skin,
      cover: (path != null && path.isNotEmpty)
          ? ResizeImage(FileImage(File(path)), width: (size * 3).round())
          : null,
      size: size,

      fallbackIcon: Icons.music_note,
      fallbackIconColor: skin.accentDeep,

      fallbackIconSize: 26,
      isPlaying: widget.isPlaying == true,

      fadeKey: track.id,

      onTogglePlay: onCoverTap,
    );

    final drag = onDragToQueue;
    if (drag == null) return button;
    return LongPressDraggable<Track>(
      data: track,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _dragFeedback(skin, size),
      childWhenDragging: Opacity(opacity: 0.3, child: button),
      child: button,
    );
  }

  static Widget dragFeedback({
    required Skin skin,
    required String label,
    required String? coverPath,
    required double size,
  }) {
    final path = coverPath;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: skin.panel,
          border: Border.all(color: skin.accent, width: 2),
          boxShadow: [
            BoxShadow(color: skin.slabShadow, blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: (path != null && path.isNotEmpty)
                  ? Image(
                      image: ResizeImage(FileImage(File(path)), width: (size * 2).round()),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.music_note, color: skin.accentDeep, size: 26),
                    )
                  : Icon(Icons.music_note, color: skin.accentDeep, size: 26),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: LayoutSpec.fontLabel,
                      fontWeight: FontWeight.w700,
                      color: skin.textPrimary,
                    ),
                  ),
                  Text(
                    'Add to queue',
                    style: TextStyle(
                      fontSize: LayoutSpec.fontLabel,
                      color: skin.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dragFeedback(Skin skin, double size) => dragFeedback(
        skin: skin,
        label: dragLabel,
        coverPath: coverPath,
        size: size,
      );

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
