library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/app_state.dart';
import '../library/track.dart';
import '../screens/mini_player.dart';
import '../theme/layout.dart';
import '../theme/skin.dart';

class MiniPlayerHost extends StatelessWidget {
  const MiniPlayerHost({
    super.key,
    required this.skin,

    this.presentation,
    required this.state,
    required this.duration,
    required this.playing,
    required this.cover,
    required this.onSeek,
    required this.onPlayPause,
    required this.onCycleRepeat,
    required this.onToggleLyrics,
    required this.onOpenQueue,
    this.onDisband,
    this.onSwipeNext,
    this.onSwipePrevious,
    this.onDragToQueue,
    this.lyricsActive = false,
    this.downloadBadge,
  });

  final Skin skin;

  final Presentation? presentation;
  final AppState state;

  final ValueListenable<Duration> duration;

  final bool playing;
  final bool lyricsActive;
  final ImageProvider? cover;

  final void Function(Duration to) onSeek;

  final VoidCallback onPlayPause;
  final VoidCallback onCycleRepeat;

  final VoidCallback onToggleLyrics;

  final VoidCallback onOpenQueue;

  final VoidCallback? onDisband;

  final VoidCallback? onSwipeNext;
  final VoidCallback? onSwipePrevious;

  final void Function(Track)? onDragToQueue;

  final Widget? downloadBadge;

  @override
  Widget build(BuildContext context) {
    final track = state.currentTrack;

    if (track == null) return const SizedBox.shrink();

    return ValueListenableBuilder<Duration>(
      valueListenable: state.position,
      builder: (_, pos, __) => ValueListenableBuilder<Duration>(
        valueListenable: duration,
        builder: (_, dur, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            if (downloadBadge != null)
              Padding(
                padding: const EdgeInsets.only(right: 14, bottom: 6),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: downloadBadge!,
                ),
              ),
            MiniPlayer(
          skin: skin,
          presentation: presentation,
          lyricsActive: lyricsActive,
          track: track,
          position: pos,
          duration: dur,
          onSeek: onSeek,
          cover: cover,
          playing: playing,
          onPlayPause: onPlayPause,
          onCycleRepeat: onCycleRepeat,
          repeatMode: state.repeatMode,
          onOpen: onToggleLyrics,
          onSwipeUp: onOpenQueue,
          onDisband: onDisband,
          onSwipeNext: onSwipeNext,
          onSwipePrevious: onSwipePrevious,

          onAcceptTrack: (onDragToQueue == null || state.queue == null)
              ? null
              : onDragToQueue,
            ),
          ],
        ),
      ),
    );
  }
}
