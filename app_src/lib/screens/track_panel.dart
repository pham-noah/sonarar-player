library;

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../library/track.dart';
import '../theme/skin.dart';
import '../widgets/pressable.dart';

class TrackPanel extends StatelessWidget {
  const TrackPanel({
    super.key,
    required this.state,
    required this.track,
    required this.position,
    this.onToggleBookmark,
    this.onFixTags,
    this.onLoopPoints,
    this.onAddToPlaylist,
    this.onNeverInShuffle,
    this.playCount,
    this.completionCount,
  });

  final AppState state;
  final Track track;

  final Duration position;

  final VoidCallback? onToggleBookmark;
  final VoidCallback? onFixTags;
  final VoidCallback? onLoopPoints;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onNeverInShuffle;

  final int? playCount;
  final int? completionCount;

  @override
  Widget build(BuildContext context) {
    final skin = state.uiSkin;
    final bookmarked = state.bookmarks.has(track.id);
    final excluded = state.exclusions.contains(track.id);
    final fixCount = state.tagOverrides.forTrack(track.id).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(
            track.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: LayoutSpec.fontBase,
              fontWeight: FontWeight.w800,
              color: skin.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: LayoutSpec.fontLabel,
              color: skin.textSecondary,
            ),
          ),
          const SizedBox(height: 18),

          _row(
            skin,
            bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,

            bookmarked
                ? 'Bookmarked at ${_mmss(state.bookmarks.at(track.id) ?? Duration.zero)}'
                : 'Bookmark this spot',
            onToggleBookmark,
            active: bookmarked,
            trailing: bookmarked ? _mmss(position) : null,
          ),

          _row(
            skin,
            Icons.edit_note_rounded,
            fixCount == 0
                ? 'Fix the tags'
                : 'Tags corrected · $fixCount field${fixCount == 1 ? '' : 's'}',
            onFixTags,
            active: fixCount > 0,
          ),

          _row(
            skin,
            Icons.repeat_rounded,
            'Loop points',
            onLoopPoints,
          ),

          _row(
            skin,
            Icons.playlist_add_rounded,
            'Add to a playlist',
            onAddToPlaylist,
          ),

          _row(
            skin,
            excluded ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            excluded ? 'Allowed in shuffle' : 'Never in shuffle',
            onNeverInShuffle,
            active: excluded,
          ),

          if (playCount != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: skin.textSecondary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.insights_rounded, size: 18, color: skin.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      playCount == 0
                          ? 'Never played'
                          : 'Played $playCount time${playCount == 1 ? '' : 's'}'
                              '${completionCount == null ? '' : ' · '
                                  '$completionCount through'}',
                      style: TextStyle(
                        fontSize: LayoutSpec.fontLabel,
                        fontWeight: FontWeight.w700,
                        color: skin.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(
    Skin skin,
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool active = false,
    String? trailing,
  }) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: active ? skin.accent.withValues(alpha: 0.12) : Colors.transparent,
              border: Border.all(
                color: active
                    ? skin.accent
                    : skin.textSecondary
                        .withValues(alpha: enabled ? 0.35 : 0.15),
                width: active ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: active
                      ? skin.accent
                      : enabled
                          ? skin.textSecondary
                          : skin.textSecondary.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: LayoutSpec.fontSmall,
                      fontWeight: FontWeight.w700,
                      color: enabled
                          ? skin.textPrimary
                          : skin.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing,
                    style: TextStyle(
                      fontSize: LayoutSpec.fontLabel,
                      fontWeight: FontWeight.w900,
                      color: skin.accent,
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

String _mmss(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
