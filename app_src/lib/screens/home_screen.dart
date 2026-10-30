library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../core/track_labels.dart';
import '../context/context_icons.dart';
import 'app_header.dart';
import '../context/place_icons.dart';
import '../context/weather_codes.dart';
import '../library/home_rails.dart';
import '../library/playlists.dart';
import '../library/track.dart';
import '../theme/layout.dart';
import '../theme/personalization.dart';
import '../theme/skin.dart';
import '../widgets/art_scrim.dart';

enum HomeTab { home, quickPick, fromLibrary, genre, recap }

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.skin,
    required this.band,
    this.continueTrack,
    this.jumpBackIn = const [],
    this.heavyRotation = const [],
    this.greeting,
    this.headerMark,
    this.nowMixName,
    this.onPlayNowMix,
    this.newFromLibrary = const [],
    this.mostPlayed = const [],
    this.likedSongs = const [],
    this.recentPlaylist,
    this.onOpenRecentPlaylist,
    this.libraryPlaylists = const [],
    this.genreLists = const [],
    this.recapTracks = const [],
    this.home = HomeLayout.defaults,
    this.onOpenPersonalize,
    this.recapLabel = '',
    this.allTracks = const [],
    this.onOpenRecap,
    this.onPlayPlaylist,
    this.rediscover = const [],
    this.onOpenRediscover,
    this.coverPathFor,
    this.onPlay,
    this.weather = WeatherCondition.unknown,
    this.placeName,
    this.placeIcon,
    this.hasFix = false,
    this.contextEnabled = true,
    this.headerArt,
    this.recent = const [],
  });

  final Skin skin;

  /// The picture this place wears, if it wears one. Home was the one place with
  /// no art at all, so choosing a picture for HOME did nothing.
  final Widget? headerArt;

  /// What arrived in the library last, newest first. Without this, downloaded
  /// music only ever appeared in Library — Home had no rail that could show a
  /// track with no play history and no playlist.
  final List<Track> recent;

  final String? band;

  final Track? continueTrack;

  final List<Track> jumpBackIn;

  final List<Track> heavyRotation;

  final String? greeting;

  final Widget? headerMark;

  final String? nowMixName;

  final VoidCallback? onPlayNowMix;

  final List<Track> newFromLibrary;

  final List<Track> rediscover;

  final VoidCallback? onOpenRediscover;

  final String? Function(Track)? coverPathFor;

  final void Function(Track)? onPlay;

  final List<Track> mostPlayed;

  final List<Track> likedSongs;

  final Playlist? recentPlaylist;

  final VoidCallback? onOpenRecentPlaylist;

  final List<PlaylistPlays> libraryPlaylists;

  final List<Playlist> genreLists;

  final List<Track> recapTracks;

  /// Which sections this page draws, and in what order. NOW is pinned at the
  /// top — it is the header's own context row, not a section that can be moved
  /// under the lists.
  final HomeLayout home;

  /// A visible door. The drawer hides Settings well enough that a feature
  /// living only behind it is a feature nobody finds.
  final VoidCallback? onOpenPersonalize;

  final String recapLabel;

  final void Function(Playlist)? onPlayPlaylist;

  final VoidCallback? onOpenRecap;



  final List<Track> allTracks;

  final WeatherCondition weather;
  final String? placeName;
  final IconData? placeIcon;
  final bool hasFix;
  final bool contextEnabled;

  @override
  Widget build(BuildContext context) {
    final list = SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          PresentationScope.of(context, fallback: skin)
              .arrangement
              .bottomClearance,
        ),
        children: [
          if (greeting != null)
            AppScreenHeader(
              skin: skin,
              title: greeting!,
              mark: headerMark,
              trailing: onOpenPersonalize == null
                  ? null
                  : IconButton(
                      key: const Key('open-personalize'),
                      onPressed: onOpenPersonalize,
                      icon: Icon(Icons.tune_rounded, color: skin.accent),
                      tooltip: 'Personalize',
                    ),
            ),

        if (contextEnabled) ...[
          _bandText('NOW'),
          Row(
            children: [
              _stateTile(
                context,
                _bandIcon(band),
                band ?? 'NO BAND',
                dim: band == null,
              ),
              const SizedBox(width: 8),
              _stateTile(
                context,
                weatherIcon(weather) ?? Icons.help_outline_rounded,
                weatherName(weather),
                dim: weather == WeatherCondition.unknown,
              ),
              const SizedBox(width: 8),
              _stateTile(
                context,
                hasFix
                    ? (placeIcon ?? kDefaultPlaceIcon)
                    : Icons.location_searching_rounded,
                hasFix
                    ? ((placeName == null || placeName!.trim().isEmpty)
                        ? 'ELSEWHERE'
                        : placeName!.toUpperCase())
                    : 'NO FIX',
                dim: !hasFix || placeName == null || placeName!.trim().isEmpty,
              ),
            ],
          ),

          if (onPlayNowMix != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onPlayNowMix,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                decoration: BoxDecoration(
                  color: skin.accent,
                ),
                child: Row(
                  children: [
                    Icon(Icons.play_arrow_rounded,
                        color: skin.onAccent,
                        size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        nowMixName == null
                            ? 'PLAY WHAT FITS NOW'
                            : 'PLAY WHAT FITS NOW — $nowMixName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: LayoutSpec.fontFloor,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w900,
                          color: skin.onAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 26),
        ],

        for (final section in home.visible) ...switch (section) {
          HomeSection.now => const <Widget>[],
          HomeSection.continueListening => _continueSection(context),
          HomeSection.recentlyAdded => _recentSection(context),
          HomeSection.rediscover => _rediscoverSection(context),
          HomeSection.jumpBackIn => _jumpBackInSection(context),
          HomeSection.quickPick => _quickPickSection(context),
          HomeSection.fromLibrary => _fromLibrarySection(context),
          HomeSection.recap => _recapSection(context),
        },

        ],
      ),
    );

    final art = headerArt;
    if (art == null) return list;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 320,
          child: IgnorePointer(child: art),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 320,
          child: ArtScrim(color: skin.background),
        ),
        list,
      ],
    );
  }

  List<Widget> _continueSection(BuildContext context) {
    if (continueTrack == null) return const [];
    return [
      _bandText('CONTINUE LISTENING'),
      _continueRow(context, continueTrack!),
      const SizedBox(height: 22),
    ];
  }

  List<Widget> _rediscoverSection(BuildContext context) {
    if (rediscover.isEmpty) return const [];
    return [
      GestureDetector(
        onTap: onOpenRediscover,
        child: _bandText('REDISCOVER'),
      ),
      _coverRail(context, rediscover),
      const SizedBox(height: 22),
    ];
  }

  List<Widget> _jumpBackInSection(BuildContext context) {
    if (jumpBackIn.isEmpty) return const [];
    return [
      _bandText('JUMP BACK IN'),
      _coverRail(context, jumpBackIn),
      const SizedBox(height: 22),
    ];
  }

  List<Widget> _quickPickSection(BuildContext context) {
    final seen = <String>{};
    final pool = <Track>[
      for (final t in mostPlayed)
        if (seen.add(t.id)) t,
      for (final t in likedSongs)
        if (seen.add(t.id)) t,
    ];
    if (pool.isEmpty) return const [];
    return [
      _bandText('QUICK PICK'),
      _QuickPickPager(
        skin: skin,
        pool: pool,
        coverPathFor: coverPathFor,
        onPlay: onPlay,
      ),
      const SizedBox(height: 22),
    ];
  }

  List<Widget> _fromLibrarySection(BuildContext context) {
    if (libraryPlaylists.isEmpty) return const [];
    return [
      _bandText('FROM YOUR LIBRARY'),
      _playlistRail(context, libraryPlaylists),
      const SizedBox(height: 22),
    ];
  }

  Widget _playlistRail(BuildContext context, List<PlaylistPlays> lists) {
    final pal = PresentationScope.of(context, fallback: skin).palette;
    return SizedBox(
      height: 104 + 6 + 2 * 26 + 4,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: lists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final entry = lists[i];
          final p = entry.playlist;
          return GestureDetector(

            onTap: onPlayPlaylist == null ? null : () => onPlayPlaylist!(p),
            child: SizedBox(
              width: 104,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: _playlistCover(p),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: LayoutSpec.fontFloor,
                      fontWeight: FontWeight.w800,
                      color: pal.textPrimary,
                    ),
                  ),
                  Text(

                    entry.plays > 0
                        ? '${entry.plays} plays · ${p.length} songs'
                        : '${p.length} ${p.length == 1 ? "song" : "songs"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: LayoutSpec.fontFloor, color: pal.textSecondary),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _playlistCover(Playlist p) {
    final first = tracksOf(p);
    final cover = first.isEmpty ? null : coverPathFor?.call(first.first);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: skin.secondary(0.28)),
      ),
      child: (cover == null || !File(cover).existsSync())
          ? ColoredBox(
              color: skin.panel,
              child: Icon(Icons.queue_music_rounded, color: skin.accentDeep, size: 30),
            )
          // Full-size art in a small slot is a decode the UI never uses.
          : Image(
              image: ResizeImage(FileImage(File(cover)), width: 312),
              fit: BoxFit.cover,
            ),
    );
  }

  // ignore: unused_element
  List<Widget> _genreSection(BuildContext context) {
    final withTracks = [
      for (final p in genreLists)
        if (tracksOf(p).isNotEmpty) p,
    ];
    if (withTracks.isEmpty) return const [];
    return [
      _bandText('GENRE'),
      for (final p in withTracks) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            p.name,
            style: TextStyle(
              fontSize: LayoutSpec.fontFloor,
              fontWeight: FontWeight.w800,
              color: skin.textSecondary,
            ),
          ),
        ),
        _coverRail(context, tracksOf(p)),
        const SizedBox(height: 18),
      ],
      const SizedBox(height: 4),
    ];
  }

  List<Widget> _recentSection(BuildContext context) {
    if (recent.isEmpty) return const [];
    return [
      _bandText('RECENTLY ADDED'),
      SizedBox(
        height: 104 + 6 + 2 * 20 + 10,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: recent.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final t = recent[i];
            final cover = coverPathFor?.call(t);
            final play = onPlay;
            return GestureDetector(
              onTap: play == null ? null : () => play(t),
              child: SizedBox(
                width: 104,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        color: skin.panel,
                        child: cover == null
                            ? Icon(Icons.music_note_rounded,
                                size: 26,
                                color: skin.secondary(0.6))
                            : Image.file(
                                File(cover),
                                fit: BoxFit.cover,
                                cacheWidth: 320,
                                errorBuilder: (_, __, ___) => Icon(
                                    Icons.music_note_rounded,
                                    size: 26,
                                    color: skin.textSecondary),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      titleWithoutArtist(t.title, t.artist),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: LayoutSpec.fontFloor,
                        fontWeight: FontWeight.w700,
                        color: skin.textPrimary,
                      ),
                    ),
                    Text(
                      t.artist,
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
            );
          },
        ),
      ),
      const SizedBox(height: 22),
    ];
  }

  List<Widget> _recapSection(BuildContext context) {
    if (recapTracks.isEmpty) return const [];
    return [
      _bandText('RECAP — ${recapLabel.toUpperCase()}'),
      _recapCard(context),
      const SizedBox(height: 22),
    ];
  }

  Widget _recapCard(BuildContext context) {
    final pal = PresentationScope.of(context, fallback: skin).palette;
    final first = recapTracks.first;
    final cover = coverPathFor?.call(first);
    return GestureDetector(
      onTap: onOpenRecap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: pal.surface,
          border: Border.all(color: pal.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: (cover == null || !File(cover).existsSync())
                  ? ColoredBox(color: pal.surface)
                  : Image(
                      image: ResizeImage(FileImage(File(cover)), width: 216),
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'RECAP — ${recapLabel.toUpperCase()}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: pal.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${recapTracks.length} '
                    '${recapTracks.length == 1 ? "song" : "songs"} you played',
                    style: TextStyle(fontSize: LayoutSpec.fontFloor, color: pal.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: pal.textSecondary),
          ],
        ),
      ),
    );
  }

  List<Track> tracksOf(Playlist p) {
    final byId = {for (final t in allTracks) t.id: t};
    return [
      for (final id in p.trackIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Widget _bandText(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: LayoutSpec.fontFloor,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w900,
            color: skin.accent,
            // The band sits on artwork, so it needs a shadow of its own.
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.85),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      );

  Widget _continueRow(BuildContext context, Track t) {
    final pal = PresentationScope.of(context, fallback: skin).palette;
    return GestureDetector(
      onTap: onPlay == null ? null : () => onPlay!(t),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(

          color: pal.surface,
          border: Border.all(color: pal.border),
        ),
        child: Row(
          children: [
            _coverBox(context, t, 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titleWithoutArtist(t.title, t.artist),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: pal.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: LayoutSpec.fontFloor, color: pal.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.play_arrow_rounded, color: pal.accent, size: 26),
          ],
        ),
      ),
    );
  }

  // 104px cover + 6px gap + two 16px lines. The floor raised the lines and a
  // fixed 150 clipped them by 6px; the height now comes from what is in the tile.
  Widget _coverRail(BuildContext context, List<Track> tracks) => SizedBox(
        height: 104 + 6 + 2 * 26 + 4,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: tracks.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => _coverTile(context, tracks[i]),
        ),
      );

  Widget _coverTile(BuildContext context, Track t) {
    final pal = PresentationScope.of(context, fallback: skin).palette;
    return GestureDetector(

      onTap: onPlay == null ? null : () => onPlay!(t),
      child: SizedBox(
        width: 104,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _coverBox(context, t, 104),
            const SizedBox(height: 6),
            Text(
              t.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: LayoutSpec.fontFloor,
                fontWeight: FontWeight.w700,
                color: pal.textPrimary,
              ),
            ),
            Text(
              t.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: LayoutSpec.fontFloor, color: pal.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverBox(BuildContext context, Track t, double size) {
    final pal = PresentationScope.of(context, fallback: skin).palette;
    final path = coverPathFor?.call(t);
    return Container(
      width: size,
      height: size,
      color: pal.surface,
      child: (path == null || path.isEmpty)
          ? Icon(Icons.music_note, color: pal.accent, size: size * 0.34)
          : Image.file(
              File(path),
              width: size,
              height: size,
              fit: BoxFit.cover,

              cacheWidth: (size * 3).round(),
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.music_note, color: pal.accent, size: size * 0.34),
            ),
    );
  }

  Widget _stateTile(BuildContext context, IconData icon, String label, {bool dim = false}) {
    final pal = PresentationScope.of(context, fallback: skin).palette;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: pal.surface,
          border: Border.all(
            color: dim ? pal.border : pal.accent,
            width: dim ? 1 : 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: dim ? pal.textSecondary : pal.accent),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: LayoutSpec.fontFloor,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w900,
                  color: dim ? pal.textSecondary : pal.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _bandIcon(String? band) {
    switch (band) {
      case 'morning':
        return Icons.wb_sunny_rounded;
      case 'afternoon':
        return Icons.light_mode_rounded;
      case 'evening':
        return Icons.wb_twilight_rounded;
      case 'night':
        return Icons.nightlight_round;
      default:
        return Icons.schedule_rounded;
    }
  }
}

class _QuickPickPager extends StatelessWidget {
  const _QuickPickPager({
    required this.skin,
    required this.pool,
    required this.coverPathFor,
    required this.onPlay,
  });

  final Skin skin;
  final List<Track> pool;
  final String? Function(Track)? coverPathFor;
  final void Function(Track)? onPlay;

  static const int _perPage = 4;

  @override
  Widget build(BuildContext context) {
    final shuffled = [...pool]..shuffle();
    final pages = (shuffled.length / _perPage).ceil();
    if (pages == 0) return const SizedBox();
    return SizedBox(
      height: kQuickPickRowHeight * _perPage,
      child: PageView.builder(
        itemCount: pages,
        itemBuilder: (_, page) {
          final slice = shuffled.skip(page * _perPage).take(_perPage).toList();
          return Column(
            children: [
              for (final t in slice)
                SizedBox(
                  height: kQuickPickRowHeight,
                  child: _QuickPickRow(
                    skin: skin,
                    track: t,
                    coverPath: coverPathFor?.call(t),
                    onTap: onPlay == null ? null : () => onPlay!(t),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

const double kQuickPickRowHeight = 56;

class _QuickPickRow extends StatelessWidget {
  const _QuickPickRow({
    required this.skin,
    required this.track,
    required this.coverPath,
    required this.onTap,
  });

  final Skin skin;
  final Track track;
  final String? coverPath;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pal = PresentationScope.of(context, fallback: skin).palette;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: (coverPath == null || !File(coverPath!).existsSync())
                ? ColoredBox(color: skin.panel)
                : Image(
                    image: ResizeImage(FileImage(File(coverPath!)), width: 132),
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: LayoutSpec.fontFloor,
                    fontWeight: FontWeight.w700,
                    color: pal.textPrimary,
                  ),
                ),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: LayoutSpec.fontFloor, color: pal.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
