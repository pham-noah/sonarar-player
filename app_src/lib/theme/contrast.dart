library;

import 'dart:math' as math;
import 'dart:ui' show Color;

/// WCAG contrast, 1..21. Used to warn rather than to refuse: the user may want
/// a low-contrast accent, but they should not get one by accident.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// The smallest alpha at which [ink] painted over [plate] reaches [target].
///
/// Solved rather than tabulated: `withAccent` and `withBase` mint skins at
/// runtime from whatever the user picked, and a table of nine themes would not
/// cover them. The answer is cached, because this is asked on every build of
/// every muted label and the search is only worth running once per colour pair.
double alphaFor(Color ink, Color plate, double target) {
  final key = Object.hash(ink.toARGB32(), plate.toARGB32(), target);
  final cached = _alphaCache[key];
  if (cached != null) return cached;

  // 12 halvings put the answer inside 1/4096 of an alpha step, well under what
  // 8-bit colour can express.
  var low = 0.0;
  var high = 1.0;
  for (var i = 0; i < 12; i++) {
    final mid = (low + high) / 2;
    final blended = Color.alphaBlend(ink.withValues(alpha: mid), plate);
    if (contrastRatio(blended, plate) >= target) {
      high = mid;
    } else {
      low = mid;
    }
  }
  return _alphaCache[key] = high;
}

/// [ink] moved toward [toward] only as far as [target] requires.
///
/// Keeps the hue and gives up the saturation the background cannot afford.
Color inkFor(Color ink, Color toward, Color plate, double target) {
  if (contrastRatio(ink, plate) >= target) return ink;

  final key = Object.hash(ink.toARGB32(), toward.toARGB32(), plate.toARGB32(), target);
  final cached = _inkCache[key];
  if (cached != null) return cached;

  var low = 0.0;
  var high = 1.0;
  for (var i = 0; i < 12; i++) {
    final mid = (low + high) / 2;
    final mixed = Color.lerp(ink, toward, mid)!;
    if (contrastRatio(mixed, plate) >= target) {
      high = mid;
    } else {
      low = mid;
    }
  }
  return _inkCache[key] = Color.lerp(ink, toward, high)!;
}

final Map<int, double> _alphaCache = <int, double>{};
final Map<int, Color> _inkCache = <int, Color>{};
