library;

import 'package:flutter/material.dart';

import '../library/track.dart';
import '../theme/skin.dart';
import 'cover_play_button.dart';
import 'swipe_panel.dart';

const double kRemoveThreshold = 110;

const double kQueueRowHeight = 66;

class SwipeableQueueRow extends StatefulWidget {
  const SwipeableQueueRow({
    super.key,
    required this.skin,
    required this.track,
    required this.isCurrent,
    required this.index,
    required this.upNextLength,
    required this.onMove,
    required this.onRemove,
    this.cover,
    required this.onReloadAfterRemove,
    this.onTogglePlay,
    this.onTap,
    this.isPlaying = false,
    this.reordering = false,
  });

  final Skin skin;
  final Track track;

  final bool isCurrent;

  final int? index;
  final int? upNextLength;

  final void Function(int from, int to) onMove;

  final VoidCallback onRemove;

  final VoidCallback onReloadAfterRemove;

  final ImageProvider? cover;

  final bool reordering;

  final VoidCallback? onTap;

  final VoidCallback? onTogglePlay;
  final bool isPlaying;

  @override
  State<SwipeableQueueRow> createState() => _SwipeableQueueRowState();
}

class _SwipeableQueueRowState extends State<SwipeableQueueRow> {
  double _dx = 0;

  @visibleForTesting
  double get horizontalOffset => _dx;

  bool _hovered = false;

  bool get _locked => widget.isCurrent || widget.index == null;

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    final willRemove = -_dx >= kRemoveThreshold;

    return SizedBox(
      height: kQueueRowHeight,
      child: Stack(
          children: [

            if (!_locked)
              Positioned.fill(
                child: SwipePanel(
                  side: SwipeSide.right,
                  progress: -_dx / kRemoveThreshold,
                  icon: Icons.delete_outline_rounded,
                  label: willRemove ? 'REMOVE' : '',
                  skin: skin,
                ),
              ),

            Transform.translate(
              offset: Offset(_dx, 0),
              child: Transform.scale(

                scale: widget.reordering ? 1.03 : 1.0,
                child: Material(
                  color: Colors.transparent,
                  elevation: widget.reordering ? 8 : 0,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hovered = true),
                    onExit: (_) => setState(() => _hovered = false),
                    child: GestureDetector(
                    behavior: HitTestBehavior.opaque,

                    onHorizontalDragUpdate: _locked
                        ? null
                        : (d) {
                            setState(() {
                              _dx = (_dx + d.delta.dx).clamp(-400.0, 0.0);
                            });
                          },
                    onHorizontalDragEnd: _locked
                        ? null
                        : (_) {
                            if (-_dx >= kRemoveThreshold) {
                              widget.onRemove();
                            }

                            setState(() => _dx = 0);
                          },
                    onHorizontalDragCancel: _locked
                        ? null
                        : () => setState(() => _dx = 0),

                    child: _content(skin),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }

  Widget _content(Skin skin) {
    final row = Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: BoxDecoration(

        color: widget.reordering
            ? skin.panel
            : (_hovered && !widget.isCurrent ? skin.panel : skin.background),
        border: Border.all(
          color: widget.isCurrent
              ? skin.accent
              : (_hovered
                  ? skin.accentAt(0.7)
                  : skin.secondary(0.28)),
          width: widget.isCurrent ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          _coverWidget(skin),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.track.title,

                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: LayoutSpec.fontSmall,
                    fontWeight: FontWeight.w700,
                    color: skin.textPrimary,
                  ),
                ),
                Text(

                  widget.track.artist,
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
          if (widget.isCurrent)
            Icon(Icons.graphic_eq_rounded, color: skin.accent, size: 18)
          else
            Icon(Icons.drag_indicator_rounded,
                color: skin.secondary(0.55), size: 17),
        ],
      ),
    );

    if (widget.onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: row,
    );
  }

  Widget _coverWidget(Skin skin) {
    return CoverPlayButton(
      skin: skin,
      cover: widget.cover,
      size: 38,

      showBorder: true,
      isPlaying: widget.isPlaying,

      fadeKey: widget.track.id,

      onTogglePlay: widget.isCurrent ? widget.onTogglePlay : null,
    );
  }
}
