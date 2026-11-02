library;

import 'package:flutter/material.dart';

/// The darkening the player lays over its picture, in one place: light falls from
/// the right, so the left third carries the title and the picture is pushed back
/// there. The framing editor draws it too, because a picture must be judged on what
/// the player will actually show.
class ArtScrim extends StatelessWidget {
  const ArtScrim({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0.88),
            color.withValues(alpha: 0.52),
            color.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const [0.0, 0.42, 0.80, 1.0],
        ),
      ),
    ),
  );
}
