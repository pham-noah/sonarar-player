library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../library/track.dart';
import '../playback/loop_points.dart';
import '../rules/playlist_explanation.dart';
import '../screens/loop_editor_screen.dart';
import '../screens/queue_screen.dart';
import '../screens/track_panel.dart';
import '../screens/why_screen.dart';

class WhyBody extends StatelessWidget {
  const WhyBody({
    super.key,
    required this.state,
    required this.onPick,
    this.placeName,
    this.preciseFix = true,
  });

  final AppState state;
  final ValueChanged<Track> onPick;

  final String? placeName;
  final bool preciseFix;

  @override
  Widget build(BuildContext context) {
    final ctx = state.playlistContext;
    if (ctx == null) return const SizedBox.shrink();
    final current = state.currentTrack;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WhyPanel(
            state: state,
            explanation: explainPlaylist(
              current: current,
              library: state.library,
              ctx: ctx,
              engine: state.engine,
              memory: state.memory,
              preferredOrigin: state.skin.id.name.toUpperCase(),
              rule: state.activeRule,
              ruleTrackCount: state.activeRulePlaylistSize,
              placeName: placeName,
              preciseFix: preciseFix,
              situationTag: state.situationTag,
              sleeping: state.sleeping,
              isLive: state.source == QueueSource.live,
            ),
            alternatives: state.engine
                .select(state.library, ctx)
                .where((t) => t.id != current?.id)
                .take(5)
                .toList(growable: false),
            onPick: onPick,
          ),
        ],
      ),
    );
  }
}

class QueueBody extends StatelessWidget {
  const QueueBody({
    super.key,
    required this.state,
    required this.playing,
    required this.coverFor,
    required this.onPlay,
    required this.onTogglePlay,
    this.onReload,
    this.onSaveAsPlaylist,
    this.onReorder,
    this.onReloadAfterRemove,
  });

  final AppState state;
  final bool playing;

  final ImageProvider? Function(Track) coverFor;
  final ValueChanged<Track> onPlay;
  final VoidCallback onTogglePlay;

  final VoidCallback? onReload;

  final VoidCallback? onSaveAsPlaylist;

  final void Function(int from, int to)? onReorder;

  final VoidCallback? onReloadAfterRemove;

  @override

  Widget build(BuildContext context) => QueuePanel(
        state: state,
        onPlay: onPlay,
        onTogglePlay: onTogglePlay,
        isPlaying: playing,
        coverFor: coverFor,
        onReload: onReload,
        onSaveAsPlaylist: onSaveAsPlaylist,
        onReorder: onReorder,
        onReloadAfterRemove: onReloadAfterRemove,
      );
}

class LoopBody extends StatelessWidget {
  const LoopBody({
    super.key,
    required this.state,
    required this.track,
    required this.position,
    required this.duration,
    required this.onPreview,
    required this.onSave,
    this.points,
  });

  final AppState state;
  final Track track;
  final ValueListenable<Duration> position;
  final ValueListenable<Duration> duration;

  final LoopPoints? points;

  final Future<void> Function(bool playing)? onPreview;
  final Future<void> Function(LoopPoints) onSave;

  @override
  Widget build(BuildContext context) => LoopEditorScreen(
        state: state,
        track: track,
        points: points,
        position: position,
        duration: duration,
        onPreview: onPreview,
        onSave: onSave,
      );
}

class TrackBody extends StatelessWidget {
  const TrackBody({
    super.key,
    required this.state,
    required this.track,
    required this.position,
    required this.onToggleBookmark,
    required this.onFixTags,
    required this.onLoopPoints,
    required this.onAddToPlaylist,
    required this.onNeverInShuffle,
    this.playCount,
    this.completionCount,
  });

  final AppState state;
  final Track track;
  final Duration position;

  final VoidCallback onToggleBookmark;
  final VoidCallback onFixTags;
  final VoidCallback onLoopPoints;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onNeverInShuffle;

  final int? playCount;
  final int? completionCount;

  @override
  Widget build(BuildContext context) => TrackPanel(
        state: state,
        track: track,
        position: position,
        onToggleBookmark: onToggleBookmark,
        onFixTags: onFixTags,
        onLoopPoints: onLoopPoints,
        onAddToPlaylist: onAddToPlaylist,
        onNeverInShuffle: onNeverInShuffle,
        playCount: playCount,
        completionCount: completionCount,
      );
}

final Map<String, bool> _coverExists = <String, bool>{};

/// Test seam: a `FileImage` never decodes inside the test zone's fake async.
@visibleForTesting
ImageProvider? Function(String path)? debugCoverProvider;

ImageProvider? coverProviderFor(String? path) {
  if (path == null || path.isEmpty) return null;
  final override = debugCoverProvider;
  if (override != null) return override(path);
  final seen = _coverExists[path] ??= File(path).existsSync();
  if (!seen) return null;
  return FileImage(File(path));
}

@visibleForTesting
int get coverExistsCacheSize => _coverExists.length;

@visibleForTesting
void clearCoverCache() => _coverExists.clear();
