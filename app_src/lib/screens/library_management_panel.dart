library;

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../library/playlists.dart';
import '../library/track.dart';
import '../theme/skin.dart';
import '../widgets/pressable.dart';

class LibraryManagementPanel extends StatelessWidget {
  const LibraryManagementPanel({
    super.key,
    required this.state,
    required this.track,
    this.onPlayNext,
    this.onPlayNow,
    this.onClose,
    this.playlists = const [],
    this.onAddToPlaylist,
    this.onFixTags,
    this.onRemoveDownload,
  });

  final AppState state;
  final Track track;

  final VoidCallback? onPlayNext;
  final VoidCallback? onPlayNow;
  final VoidCallback? onClose;

  final VoidCallback? onFixTags;

  final List<Playlist> playlists;

  final VoidCallback? onAddToPlaylist;

  final VoidCallback? onRemoveDownload;

  @override
  Widget build(BuildContext context) {
    final skin = state.uiSkin;
    final excluded = state.exclusions.contains(track.id);
    final bookmarked = state.bookmarks.has(track.id);
    final fixCount = state.tagOverrides.forTrack(track.id).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            track.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: LayoutSpec.fontBase,
              fontWeight: FontWeight.w900,
              color: skin.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: LayoutSpec.fontSmall, color: skin.textSecondary),
          ),
          const SizedBox(height: 20),

          _row(skin, Icons.play_arrow_rounded, 'Play now', onPlayNow),
          _row(skin, Icons.queue_music_rounded, 'Play next', onPlayNext),

          _row(
            skin,
            Icons.playlist_add_rounded,
            playlists.isEmpty ? 'New playlist' : 'Add to playlist',
            onAddToPlaylist,
          ),
          _row(
            skin,
            excluded ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            excluded ? 'Allow in shuffle again' : 'Never in shuffle',
            () => state.toggleExclusion(track.id),
          ),

          _row(
            skin,
            Icons.edit_note_rounded,
            fixCount == 0 ? 'Fix the tags' : 'Fix the tags ($fixCount)',
            onFixTags,
          ),
          _row(
            skin,
            bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            bookmarked ? 'Clear this bookmark' : 'Bookmark this spot',
            () => state.toggleBookmark(track, Duration.zero),
          ),

          if (onRemoveDownload != null) ...[
            const SizedBox(height: 6),
            Divider(color: skin.secondary(0.25)),
            _row(skin, Icons.delete_forever_rounded, 'Remove download', onRemoveDownload),
            Text(
              'Deletes the file from this phone. It is a download, so nothing else has it — the next library '
              'push will not bring it back.',
              style: TextStyle(
                fontSize: LayoutSpec.fontLabel,
                color: skin.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(

            excluded
                ? 'It stays in the library — it just never comes up in a playlist.'
                : 'Excluded tracks stay in the library; they are only kept out of playlists.',
            style: TextStyle(
              fontSize: LayoutSpec.fontLabel,
              color: skin.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(Skin skin, IconData icon, String label, VoidCallback? onTap) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(
                color: enabled
                    ? skin.secondary(0.35)
                    : skin.secondary(0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 20,
                    color: enabled ? skin.accent : skin.secondary(0.4)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: LayoutSpec.fontSmall,
                      fontWeight: FontWeight.w700,
                      color: enabled
                          ? skin.textPrimary
                          : skin.secondary(0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
