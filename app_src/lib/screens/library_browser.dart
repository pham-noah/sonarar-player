library;

import 'package:flutter/material.dart';

import '../library/playlists.dart';
import '../library/track.dart';
import '../theme/skin.dart';

enum LibraryView { playlists, artists, songs }

const double kBrowserChipFont = 12.0;

class LibraryBrowserBar extends StatelessWidget {
  const LibraryBrowserBar({
    super.key,
    required this.skin,
    required this.current,
    required this.onSelect,
    required this.playlistCount,
    required this.artistCount,
    this.songCount = 0,
    this.filterLabel,
    this.onClearFilter,
    this.besidePlaylists = const [],
    this.pickedView,
  });

  final String? filterLabel;

  final VoidCallback? onClearFilter;

  final LibraryView? pickedView;

  final List<Widget> besidePlaylists;

  final Skin skin;
  final LibraryView current;
  final void Function(LibraryView) onSelect;

  final int playlistCount;
  final int artistCount;

  final int songCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),

      child: SizedBox(
      height: 42,
      child: Row(
        children: [
          if (pickedView == LibraryView.playlists &&
              current == LibraryView.playlists) ...[
            GestureDetector(
              onTap: onClearFilter,
              child: Container(

                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: skin.accent.withValues(alpha: 0.92),
                  border: Border.all(color: skin.accent),
                ),
                child: Icon(Icons.close_rounded, color: skin.onAccent, size: 20),
              ),
            ),
            const SizedBox(width: 8),

            _segment(
              switch (current) {
                LibraryView.playlists => 'PLAYLISTS',
                LibraryView.artists => 'ARTISTS',
                LibraryView.songs => 'SONGS',
              },
              current,

              flexible: false,
            ),

            if (besidePlaylists.isNotEmpty) ...[
              const SizedBox(width: 6),
              ...besidePlaylists,
            ] else if (filterLabel != null) ...[
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: skin.accent.withValues(alpha: 0.14),
                    border: Border.all(color: skin.accent),
                  ),
                  child: Text(
                    filterLabel!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(

                      fontSize: kBrowserChipFont,
                      letterSpacing: 0.2,
                      fontWeight: FontWeight.w900,
                      color: skin.accent,
                    ),
                  ),
                ),
              ),
            ],
          ] else ...[

            _segment('PLAYLISTS', LibraryView.playlists),
            const SizedBox(width: 8),
            _segment('ARTISTS', LibraryView.artists),
            const SizedBox(width: 8),

            _segment('SONGS', LibraryView.songs),
          ],
        ],
      ),
      ),
    );
  }

  Widget _segment(String label, LibraryView view, {bool flexible = true}) {
    final active = view == current && view == pickedView;

    final body = GestureDetector(
        onTap: () => onSelect(view),
        child: Container(

          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: active
                ? skin.accent.withValues(alpha: 0.92)
                : skin.background.withValues(alpha: 0.45),
            border: Border.all(
              color: active
                  ? skin.accent
                  : skin.textSecondary.withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: kBrowserChipFont,
                    letterSpacing: 0.2,
                    fontWeight: FontWeight.w900,

                    color: active ? skin.onAccent : skin.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
    );

    return flexible ? Expanded(child: body) : body;
  }
}

class PlaylistRow extends StatelessWidget {
  const PlaylistRow({
    super.key,
    required this.skin,
    required this.playlist,
    required this.cover,
    this.onOpen,
    this.onPlay,
    this.onLongPress,
    this.blurb,
    this.isDynamic = false,
    this.pinned = false,
  });

  final Skin skin;
  final Playlist playlist;
  final ImageProvider? cover;
  final VoidCallback? onOpen;
  final VoidCallback? onPlay;
  final VoidCallback? onLongPress;

  final String? blurb;

  final bool isDynamic;

  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final empty = playlist.isEmpty;

    return GestureDetector(
      onTap: onOpen,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 14, 6),
        decoration: BoxDecoration(
          color: isDynamic
              ? skin.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: isDynamic
                ? skin.accent.withValues(alpha: 0.75)
                : skin.textSecondary.withValues(alpha: 0.28),
            width: isDynamic ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (isDynamic)
              Container(
                width: 4,
                height: 36,
                margin: const EdgeInsets.only(right: 8),
                color: skin.accent,
              ),
            Container(

              width: 40,
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(color: skin.accent.withValues(alpha: 0.5)),
              ),
              child: cover == null
                  ? ColoredBox(
                      color: skin.panel,
                      child: Icon(

                        isDynamic
                            ? Icons.auto_awesome_rounded
                            : Icons.queue_music_rounded,
                        color: skin.accentDeep,
                        size: 22,
                      ),
                    )
                  : Image(image: cover!, fit: BoxFit.cover),
            ),

            if (pinned) ...[
              const SizedBox(width: 8),
              Icon(Icons.push_pin_rounded, color: skin.accent, size: 16),
            ],
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: LayoutSpec.fontSmall,
                      fontWeight: FontWeight.w800,
                      color: skin.textPrimary,
                    ),
                  ),

                  if (blurb != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    blurb!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: LayoutSpec.fontLabel,
                      color: skin.accent,
                    ),
                  ),
                  ],
                ],
              ),
            ),
            if (onPlay != null && !empty)
              GestureDetector(
                onTap: onPlay,
                child: Icon(Icons.play_arrow_rounded,
                    color: skin.accent, size: 26),
              ),

          ],
        ),
      ),
    );
  }
}

Playlist likedAsPlaylist({
  required List<String> orderedIds,
  String name = 'Liked Songs',
}) =>
    Playlist(

      id: kLikedPlaylistId,
      name: name,
      trackIds: orderedIds,
    );

const String kLikedPlaylistId = '__liked__';

class ArtistRow extends StatelessWidget {
  const ArtistRow({
    super.key,
    required this.skin,
    required this.artist,
    required this.count,
    required this.cover,
    this.onOpen,
  });

  final Skin skin;
  final String artist;
  final int count;
  final ImageProvider? cover;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: skin.textSecondary.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          children: [

            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: skin.accent.withValues(alpha: 0.5)),
                image: cover == null
                    ? null
                    : DecorationImage(image: cover!, fit: BoxFit.cover),
              ),
              child: cover == null
                  ? Icon(Icons.person_rounded, color: skin.accentDeep, size: 24)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: LayoutSpec.fontSmall,
                  fontWeight: FontWeight.w700,
                  color: skin.textPrimary,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: LayoutSpec.fontLabel,
                color: skin.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
                color: skin.textSecondary.withValues(alpha: 0.6), size: 22),
          ],
        ),
      ),
    );
  }
}

Map<String, List<Track>> groupByArtist(List<Track> tracks) {
  final out = <String, List<Track>>{};
  for (final t in tracks) {
    final a = t.artist.trim();
    if (a.isEmpty) continue;
    out.putIfAbsent(a, () => <Track>[]).add(t);
  }
  return out;
}
