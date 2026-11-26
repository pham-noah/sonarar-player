library;

import 'package:flutter/material.dart';

import '../theme/skin.dart';

/// What a track with no picture shows.
///
/// A track without a cover file used to draw a flat panel — on the player a
/// 156 dp black square inside a teal border, on the mini player a 40 dp one.
/// A void reads as a load that failed, so the app looked broken in the one
/// case it could never fix. One glyph in the skin's own palette says "there is
/// no picture" and stops every caller inventing a different emptiness.
class NoCover extends StatelessWidget {
  const NoCover({
    super.key,
    required this.skin,
    required this.size,
    this.radius = 0,
    this.panel,
  });

  final Skin skin;

  /// The shortest side of the slot the glyph is centred in.
  final double size;

  final double radius;

  /// The wash behind the glyph. The default is the skin's panel; a caller on a
  /// different surface passes its own so the square does not become a patch.
  final Color? panel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: panel ?? skin.panel,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: (size * 0.34).clamp(12.0, 64.0),
          // Dim enough to be furniture, bright enough to survive a dark panel.
          color: skin.textPrimary.withValues(alpha: 0.28),
        ),
      ),
    );
  }
}
