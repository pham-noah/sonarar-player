library;

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../library/track.dart';
import '../theme/layout.dart';
import '../theme/skin.dart';
import '../widgets/stagger_in.dart';
import '../widgets/pressable.dart';
import '../widgets/swipeable_queue_row.dart';

const Key queueSaveKey = Key('queue-save-as-playlist');

const Key queueClearUpcomingKey = Key('queue-clear-upcoming');

class QueuePanel extends StatelessWidget {
  const QueuePanel({
    super.key,
    required this.state,
    this.onReload,
    this.coverFor,
    this.onTogglePlay,
    this.onPlay,
    this.isPlaying = false,
    this.onSaveAsPlaylist,
    this.onClearUpcoming,
    this.onRemoved,
    this.onReorder,
    this.onReloadAfterRemove,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 24),
  });

  final AppState state;

  final ImageProvider? Function(Track)? coverFor;

  final VoidCallback? onReload;

  final VoidCallback? onTogglePlay;

  final void Function(Track)? onPlay;

  final bool isPlaying;

  final VoidCallback? onSaveAsPlaylist;

  final VoidCallback? onClearUpcoming;

  /// Fired AFTER a successful removal, with the slot it came from, so the shell
  /// can offer an undo.
  final void Function(Track track, int index)? onRemoved;

  final void Function(int from, int to)? onReorder;

  final VoidCallback? onReloadAfterRemove;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final skin = state.uiSkin;

    final order = state.queueOrder;
    final currentAt = state.queueIndex;
    final hasQueue = order.isNotEmpty && currentAt >= 0;

    return ColoredBox(
      color: skin.background,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: padding.resolve(TextDirection.ltr).top),
            ),

            if (onSaveAsPlaylist != null && hasQueue)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: 14,
                    left: padding.resolve(TextDirection.ltr).left,
                    right: padding.resolve(TextDirection.ltr).right,
                  ),
                  child: Row(
                    children: [
                      Pressable(
                        key: queueSaveKey,
                        onTap: onSaveAsPlaylist!,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.playlist_add_rounded, size: 18, color: skin.accent),
                            const SizedBox(width: 8),
                            Text(
                              'SAVE AS PLAYLIST',
                              style: TextStyle(
                                fontSize: LayoutSpec.fontLabel,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w800,
                                color: skin.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onClearUpcoming != null && order.length > currentAt + 1) ...[
                        const SizedBox(width: 22),
                        Pressable(
                          key: queueClearUpcomingKey,
                          onTap: onClearUpcoming!,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.playlist_remove_rounded,
                                  size: 18, color: skin.textSecondary),
                              const SizedBox(width: 8),
                              Text(
                                'CLEAR UPCOMING',
                                style: TextStyle(
                                  fontSize: LayoutSpec.fontLabel,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w800,
                                  color: skin.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            if (!hasQueue)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: padding.resolve(TextDirection.ltr).left,
                  ),
                  child: Text(
                    'Nothing queued yet.',
                    style: TextStyle(
                      fontSize: LayoutSpec.fontBase,
                      color: skin.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.only(
                  left: padding.resolve(TextDirection.ltr).left,
                  right: padding.resolve(TextDirection.ltr).right,

                  bottom: PresentationScope.of(context, fallback: skin)
                      .arrangement
                      .bottomClearance,
                ),
                sliver: SliverReorderableList(
                  itemCount: order.length,

                  // ignore: deprecated_member_use
                  onReorder: (from, to) {
                    if (to > from) to -= 1;
                    if (to != from) {
                      if (!state.moveInQueue(from, to)) return;

                      if (onReorder != null) {
                        onReorder!(from, to);
                      } else {
                        onReload?.call();
                      }
                    }
                  },
                  itemBuilder: (context, i) {
                    final t = order[i];
                    final isCurrent = i == currentAt;
                    final row = SwipeableQueueRow(
                      skin: skin,
                      track: t,
                      isCurrent: isCurrent,
                      index: i,
                      upNextLength: order.length,
                      cover: coverFor?.call(t),
                      isPlaying: isPlaying,
                      onTogglePlay: onTogglePlay,

                      onTap: onPlay == null ? null : () => onPlay!(t),

                      onMove: (from, to) {
                        if (!state.moveInQueue(from, to)) return;
                        if (onReorder != null) {
                          onReorder!(from, to);
                        } else {
                          onReload?.call();
                        }
                      },
                      onRemove: () {
                        final slot = state.queueOrder.indexWhere((x) => x.id == t.id);
                        if (slot < 0) return;
                        final currentChanged = state.removeFromQueue(t.id);
                        onRemoved?.call(t, slot);
                        if (currentChanged) {
                          (onReloadAfterRemove ?? onReload)?.call();
                        }
                      },
                      onReloadAfterRemove: () {},
                    );
                    return StaggerIn(
                      key: ValueKey(t.id),
                      index: i,
                      style: StaggerStyle.drop,
                      child: Padding(

                        padding: const EdgeInsets.only(bottom: 6),

                        child: isCurrent
                            ? row

                            : ReorderableDelayedDragStartListener(
                                index: i,
                                child: row,
                              ),
                      ),
                    );
                  },
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}
