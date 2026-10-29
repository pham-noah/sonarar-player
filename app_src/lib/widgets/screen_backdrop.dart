library;

import 'package:flutter/material.dart';

import '../art/art_focus.dart';
import '../art/skin_art.dart';
import '../theme/skin.dart';
import 'framed_art.dart';

class ScreenBackdrop extends StatelessWidget {
  const ScreenBackdrop({
    super.key,
    required this.skin,
    this.art,
    this.focus,
    this.opacity = 0.16,
  });

  final Skin skin;

  final SkinArt? art;

  final ArtFocus? focus;

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final set = artFor(skin.id);
    if (!set.hasArt) return const SizedBox.shrink();
    final piece = art ?? set.atOrNull(0);
    if (piece == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: FramedArt(
        burn: 1.0,
        assetPath: piece.assetPath,
        aspect: piece.aspect,
        focus: focus ?? piece.focus,
        opacity: opacity,
      ),
    );
  }
}
