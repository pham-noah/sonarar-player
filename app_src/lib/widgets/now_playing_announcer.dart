library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../core/app_state.dart';
import '../l10n/l10n.dart';

/// Says the song's name when the song changes.
///
/// A screen reader reads what is on screen, and what is on screen is a title, an
/// artist and a row of controls. Pressing "next" changes all of it silently: the
/// labels describe the buttons, not the music, so a blind user could skip five
/// tracks and have nothing to tell them apart. Playlists and the queue are the
/// same story — selecting a row is a tap with no confirmation.
///
/// This listens to the player and announces each new track once. It is not gated
/// on whether a screen reader is running: the platform ignores announcements
/// that nothing is listening for, and a gate is one more thing that can be wrong
/// on a device where accessibility was switched on after launch.
class NowPlayingAnnouncer extends StatefulWidget {
  const NowPlayingAnnouncer({
    super.key,
    required this.state,
    required this.child,
  });

  final AppState state;
  final Widget child;

  @override
  State<NowPlayingAnnouncer> createState() => _NowPlayingAnnouncerState();
}

class _NowPlayingAnnouncerState extends State<NowPlayingAnnouncer> {
  /// The track already described. Starts as the track playing at build time so
  /// the app opening does not talk over itself.
  String? _last;

  @override
  void initState() {
    super.initState();
    _last = widget.state.currentTrack?.id;
    widget.state.addListener(_changed);
  }

  @override
  void didUpdateWidget(NowPlayingAnnouncer old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      old.state.removeListener(_changed);
      widget.state.addListener(_changed);
      _last = widget.state.currentTrack?.id;
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final track = widget.state.currentTrack;
    if (track == null || track.id == _last) return;
    _last = track.id;
    if (!mounted) return;

    // `announce` is deprecated because it cannot say which window to speak in;
    // the view from this context can. And not every platform has announcements
    // at all — `supportsAnnounceOf` is the framework's own answer to whether
    // calling this is worth anything on the device in hand.
    final view = View.maybeOf(context);
    if (view == null) return;
    if (!MediaQuery.supportsAnnounceOf(context)) return;

    unawaited(SemanticsService.sendAnnouncement(
      view,
      l10nOf(context).playerNowPlayingAnnounce(track.title, track.artist),
      Directionality.of(context),
    ));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
