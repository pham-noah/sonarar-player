library;

import 'package:flutter/material.dart' hide RepeatMode;

import '../core/track_labels.dart';
import '../core/constants.dart';
import '../library/track.dart';

import '../player/queue.dart';
import '../theme/skin.dart';
import '../theme/layout.dart';
import '../theme/surface.dart';
import '../widgets/cross_fade_slot.dart';
import '../widgets/pressable.dart';

class MiniPlayer extends StatefulWidget {
  static const Key lyricsMarkKey = Key('miniplayer-lyrics-mark');

  const MiniPlayer({
    super.key,
    required this.skin,
    this.presentation,
    required this.track,
    required this.cover,
    required this.playing,
    required this.onPlayPause,

    required this.onCycleRepeat,

    required this.repeatMode,
    this.onOpen,
    this.onSwipeUp,
    this.onSwipeNext,
    this.onSwipePrevious,
    this.onDisband,
    this.position,
    this.duration,
    this.onSeek,
    this.lyricsActive = false,
    this.onAcceptTrack,
  });

  final Skin skin;

  final Presentation? presentation;
  final Track track;
  final ImageProvider? cover;
  final bool playing;

  final VoidCallback? onPlayPause;

  final VoidCallback? onCycleRepeat;

  final RepeatMode repeatMode;

  final VoidCallback? onOpen;

  final VoidCallback? onSwipeUp;

  final VoidCallback? onSwipeNext;
  final VoidCallback? onSwipePrevious;

  final VoidCallback? onDisband;

  final Duration? position;
  final Duration? duration;

  final ValueChanged<Duration>? onSeek;

  final bool lyricsActive;

  final void Function(Track)? onAcceptTrack;

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  double _dragDy = 0;

  double? _dragFrac;

  double _dragDx = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.presentation ?? Presentation.forSkin(widget.skin);
    final floating = p.arrangement.miniPlayerIsFloating;

    final content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _scrub(widget.skin),
          Row(
            children: [

              Expanded(
                child: GestureDetector(
                  onVerticalDragUpdate: widget.onSwipeUp == null
                      ? null
                      : (d) => _dragDy += d.primaryDelta ?? 0,
                  onVerticalDragEnd: widget.onSwipeUp == null
                      ? null
                      : (d) {
                          final v = d.primaryVelocity ?? 0;
                          final dy = _dragDy;
                          _dragDy = 0;

                          if (v < -220 || dy < -48) widget.onSwipeUp!();
                        },

                  onHorizontalDragUpdate:
                      (widget.onSwipeNext == null && widget.onSwipePrevious == null)
                          ? null
                          : (d) => _dragDx += d.primaryDelta ?? 0,
                  onHorizontalDragEnd:
                      (widget.onSwipeNext == null && widget.onSwipePrevious == null)
                          ? null
                          : (d) {
                              final v = d.primaryVelocity ?? 0;
                              final dx = _dragDx;
                              _dragDx = 0;

                              if (v > 220 || dx > 40) {
                                widget.onSwipePrevious?.call();
                              } else if (v < -220 || dx < -40) {
                                widget.onSwipeNext?.call();
                              }
                            },
                  child: InkWell(
                  onTap: widget.onOpen,
                  child: Row(
                    children: [

                      Stack(
                        alignment: Alignment.center,
                        children: [
                          _cover(),
                          if (widget.lyricsActive)

                            Container(
                              key: MiniPlayer.lyricsMarkKey,
                              decoration: BoxDecoration(
                                color: widget.skin.background.withValues(alpha: 0.72),
                                border: Border.all(color: widget.skin.accent, width: 2),
                              ),
                              padding: const EdgeInsets.all(5),
                              child: Icon(
                                Icons.lyrics_outlined,
                                size: 15,
                                color: widget.skin.accent,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titleWithoutArtist(widget.track.title, widget.track.artist),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: LayoutSpec.fontSmall,
                                fontWeight: FontWeight.w700,
                                color: widget.skin.textPrimary,
                              ),
                            ),
                            Text(
                              widget.track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: LayoutSpec.fontLabel,
                                color: widget.skin.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              ),
              _btn(
                widget.repeatMode == RepeatMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                widget.onCycleRepeat,
                active: widget.repeatMode != RepeatMode.off,
                small: true,
              ),
              _btn(
                widget.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                widget.onPlayPause,
                big: true,
              ),
              _btn(Icons.close_rounded, widget.onDisband, active: false, small: true),
            ],
          ),
        ],
    );

    final bar = floating
        ? Padding(
            padding: p.arrangement.tabBarInsets,
            child: Surface(
              presentation: p,
              role: SurfaceRole.bar,
              radius: 18,
              child: content,
            ),
          )
        : Container(
            decoration: BoxDecoration(
              color: widget.skin.panel,
              border: Border(
                top: BorderSide(color: widget.skin.accentAt(0.4)),
              ),
            ),
            child: content,
          );

    final swipeable = (widget.onSwipeNext == null && widget.onSwipePrevious == null)
        ? bar
        : GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (d) => _dragDx += d.primaryDelta ?? 0,
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              final dx = _dragDx;
              _dragDx = 0;

              if (v > 220 || dx > 40) {
                widget.onSwipePrevious?.call();
              } else if (v < -220 || dx < -40) {
                widget.onSwipeNext?.call();
              }
            },
            child: bar,
          );

    if (widget.onAcceptTrack == null) return swipeable;
    return DragTarget<Track>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => widget.onAcceptTrack!(details.data),
      builder: (context, candidate, _) {
        final armed = candidate.isNotEmpty;
        return Container(
          decoration: armed
              ? BoxDecoration(
                  border: Border.all(color: widget.skin.accent, width: 2),
                  color: widget.skin.accentAt(0.16),
                )
              : null,
          child: swipeable,
        );
      },
    );
  }

  Widget _scrub(Skin sk) {
    final total = widget.duration?.inMilliseconds ?? 0;
    final at = widget.position?.inMilliseconds ?? 0;

    final frac = _dragFrac ?? (total <= 0 ? 0.0 : (at / total).clamp(0.0, 1.0));
    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) =>
            _seekTo(d.localPosition.dx, box.maxWidth, widget.duration,
                remember: false),
        onHorizontalDragStart: (d) => _seekTo(d.localPosition.dx, box.maxWidth, widget.duration),
        onHorizontalDragUpdate: (d) => _seekTo(d.localPosition.dx, box.maxWidth, widget.duration),
        onHorizontalDragEnd: (_) => setState(() => _dragFrac = null),
        onHorizontalDragCancel: () => setState(() => _dragFrac = null),
        child: SizedBox(
          height: 14,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Stack(

              clipBehavior: Clip.none,
              children: [
                Container(height: 3, color: sk.panel),
                FractionallySizedBox(

                  widthFactor: total <= 0 ? 1.0 : frac,
                  child: Container(height: 3, color: sk.accent),
                ),

                if (_dragFrac != null)
                  Positioned(
                    left: (box.maxWidth * _dragFrac!) - 7,
                    top: -4,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: sk.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: sk.panel, width: 2),
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

  void _seekTo(double dx, double width, Duration? dur, {bool remember = true}) {
    if (dur == null || dur.inMilliseconds <= 0 || width <= 0) return;
    final f = (dx / width).clamp(0.0, 1.0);
    // A tap must not pin the bar; only a drag holds it under the finger.
    if (remember) setState(() => _dragFrac = f);
    widget.onSeek?.call(Duration(milliseconds: (dur.inMilliseconds * f).round()));
  }

  Widget _cover() {
    const size = 44.0;
    return Hero(
      tag: kCoverHeroTag(widget.track.id),
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          border: Border.all(color: widget.skin.accentAt(0.7)),
        ),

        child: CrossFadeSlot(
          keyValue: widget.track.id,
          child: widget.cover == null
              ? ColoredBox(color: widget.skin.background)
              : Image(
                  image: ResizeImage(widget.cover!, width: 132),
                  fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(color: widget.skin.background),
              ),
        ),
      ),
    );
  }

  Widget _btn(
    IconData icon,
    VoidCallback? onTap, {
    bool active = false,
    bool small = false,
    bool big = false,
  }) {
    final w = big ? 46.0 : (small ? 36.0 : 40.0);
    return Pressable(
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: w,
          height: 46,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: big ? 28 : (small ? 18 : 22),
            color: active ? widget.skin.accent : widget.skin.textPrimary,
          ),
        ),
      ),
    );
  }
}
