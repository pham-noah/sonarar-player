library;

import 'package:flutter/material.dart';

/// The darkening the player lays over its picture, in one place.
///
/// Light falls from the right; the left third carries the wordmark and the
/// title, so the picture is pushed back there. The editor draws this too — a
/// picture framed against a clean image looks different once the player dims
/// half of it, and framing should be judged on what you will actually see.
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
