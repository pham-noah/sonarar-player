library;

import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';

import '../core/time_format.dart';
import '../core/track_labels.dart';
import '../l10n/l10n.dart';
import '../core/constants.dart';
import '../library/track.dart';

import '../player/queue.dart';
import '../theme/skin.dart';
import '../theme/layout.dart';
import '../theme/surface.dart';
import '../theme/tokens.dart';
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

    final content = Stack(
        children: [
          Padding(
            // 8dp around the art: the cover used to sit flush against the
            // screen edge, which read as a cropped picture rather than a plate
            // with a picture in it.
            padding: const EdgeInsets.all(Space.sm),
            child: Row(
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

                          if (v < -220 || dy < -48) {
                            unawaited(HapticFeedback.lightImpact());
                            widget.onSwipeUp!();
                          }
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
                                unawaited(HapticFeedback.selectionClick());
                                widget.onSwipePrevious?.call();
                              } else if (v < -220 || dx < -40) {
                                unawaited(HapticFeedback.selectionClick());
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
                              padding: const EdgeInsets.all(4),                              child: Icon(
                                Icons.lyrics_outlined,
                                size: 15,
                                color: widget.skin.accentInk,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: Space.sm),
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
                              style: Type.bodyBase(
                                context,
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
                semantic: l10nOf(context).playerRepeatAction,
              ),
              _btn(
                widget.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                widget.onPlayPause,
                big: true,
                semantic: widget.playing
                    ? l10nOf(context).playerPauseAction
                    : l10nOf(context).playerPlayAction,
              ),
              _btn(Icons.close_rounded, widget.onDisband,
                  active: false,
                  small: true,
                  semantic: l10nOf(context).playerClose),
            ],
            ),
          ),
          // The scrub is a rule across the top of the plate, not a band above
          // it: a band cost 8dp of the bar's 64, and the art has to stay inside
          // the height the bottom clearance reserves.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _scrub(widget.skin),
          ),
        ],
    );

    final bar = floating
        ? Padding(
            padding: p.arrangement.tabBarInsets,
            child: Surface(
              presentation: p,
              role: SurfaceRole.bar,
              radius: Corners.md,
              child: content,
            ),
          )
        : Padding(
            // A plate, not a strip glued to both edges: 8dp of page either
            // side, so the art has a frame and the bar reads as something
            // floating over the list.
            padding: const EdgeInsets.symmetric(horizontal: Space.sm),
            child: Container(
              decoration: BoxDecoration(
                // The plate is opaque: several skins draw `panel` as a tint
                // (Abyss at 15%), and a translucent plate lets its own `e2`
                // shadow show through the fill, which greys the bar instead of
                // lifting it.
                color: Color.alphaBlend(widget.skin.panel, widget.skin.background),
                borderRadius: BorderRadius.circular(Corners.md),
                // e2: the one elevation that means "floating over content".
                boxShadow: Elevation.e2(light: widget.skin.isLight),
              ),
              // The 1px edge is painted *over* the plate rather than as a
              // `border`: a BoxDecoration border insets its child by its own
              // width, which made the bar 66 tall against the 64 the bottom
              // clearance reserves.
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Corners.md),
                border: Border.all(color: widget.skin.edge(Tone.edge)),
              ),
              clipBehavior: Clip.antiAlias,
              child: content,
            ),
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

    // A strip you can drag is a slider, and a slider is the one control a
    // screen reader can actually work: it needs the role, the position and the
    // two actions. Without them TalkBack announces a 404×8 "button" nothing can
    // drag — which is exactly what this bar used to be.
    const step = Duration(seconds: 5);
    final here = Duration(milliseconds: at);
    Duration clamped(Duration d) => d < Duration.zero
        ? Duration.zero
        : (widget.duration != null && d > widget.duration! ? widget.duration! : d);
    final canSeek = widget.onSeek != null && total > 0;

    return Semantics(
      slider: true,
      label: l10nOf(context).miniPlayerSeek,
      value: '${mmss(here)} / ${mmss(widget.duration ?? Duration.zero)}',
      increasedValue: canSeek
          ? mmss(clamped(here + step))
          : null,
      decreasedValue: canSeek
          ? mmss(clamped(here - step))
          : null,
      onIncrease: !canSeek ? null : () => widget.onSeek!(clamped(here + step)),
      onDecrease: !canSeek ? null : () => widget.onSeek!(clamped(here - step)),
      child: LayoutBuilder(
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
          height: Space.sm,
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
    const size = 40.0;
    return Hero(
      tag: kCoverHeroTag(widget.track.id),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Corners.sm),
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
    String? semantic,
  }) {
    // 48 for every key in the bar: the neighbours were 44 wide, and the height
    // (48) came free because the bar is 64 high. The width was the only thing
    // hiding under a thumb.
    const w = 48.0;
    final tap = onTap;
    // The transport key is the one control in the bar that is a *surface*: the
    // accent fill with `onAccent` on it, so the bar has a single focal point
    // instead of four glyphs at the same weight.
    final filled = big;
    return Semantics(
      button: true,
      enabled: tap != null,
      label: semantic,
      excludeSemantics: true,
      child: Pressable(
        child: InkWell(
          onTap: tap == null
              ? null
              : () {
                  unawaited(HapticFeedback.selectionClick());
                  tap();
                },
          child: Container(
            width: w,
            height: 48,
            alignment: Alignment.center,
            decoration: filled
                ? BoxDecoration(
                    color: widget.skin.accent,
                    borderRadius: BorderRadius.circular(Corners.sm),
                  )
                : null,
            child: Icon(
              icon,
              size: big ? 28 : (small ? 18 : 22),
              color: filled
                  ? widget.skin.onAccent
                  : (active ? widget.skin.accentInk : widget.skin.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
