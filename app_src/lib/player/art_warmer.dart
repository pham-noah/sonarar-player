import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/app_state.dart';
import 'boot_warm.dart';

/// Decodes the art the screens are about to want.
///
/// This used to run inside the boot sequence, which meant the app showed
/// nothing until the pictures were warm and dressed the wait up as a splash.
/// It runs after the shell is on screen now; it owns no state of its own.
class ArtWarmer {
  const ArtWarmer({required this.context, required this.state, this.cover});

  final BuildContext context;
  final AppState state;

  /// The cover of the track that opens the app, if there is one.
  final ImageProvider? Function()? cover;

  Future<void> warm() async {
    if (!context.mounted) return;
    final started = DateTime.now();
    for (final piece in artToWarmBeforeGate(
      pieces: state.artSet.pieces,
      current: state.art,
    )) {
      if (!context.mounted) return;
      await precacheImage(
        ResizeImage(AssetImage(piece.assetPath), width: kPlayerArtDecodeWidth),
        context,
      );
      if (!context.mounted) return;
      await precacheImage(
        ResizeImage(AssetImage(piece.assetPath), width: kHeaderArtDecodeWidth),
        context,
      );
    }
    final openCover = cover?.call();
    if (openCover != null && context.mounted) {
      await precacheImage(openCover, context);
    }
    // ignore: avoid_print
    print('[Sonarar][BOOT] warm=${DateTime.now().difference(started).inMilliseconds}ms '
        'cover=${openCover != null}');
    for (final piece in artToWarmAfterGate(
      pieces: state.artSet.pieces,
      current: state.art,
    )) {
      if (!context.mounted) return;
      unawaited(precacheImage(
        ResizeImage(AssetImage(piece.assetPath), width: 900),
        context,
      ));
    }
  }
}
