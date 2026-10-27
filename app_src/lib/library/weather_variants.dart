library;

import '../theme/skin_policy.dart';
import 'track.dart';
import 'variants.dart';

class WeatherVariantPlan {
  const WeatherVariantPlan({
    required this.replaceCurrent,
    required this.add,
    required this.replacedFrom,
  });

  final Track? replaceCurrent;

  final List<Track> add;

  final Track? replacedFrom;

  bool get isEmpty => replaceCurrent == null && add.isEmpty;

  static const WeatherVariantPlan empty = WeatherVariantPlan(
    replaceCurrent: null,
    add: <Track>[],
    replacedFrom: null,
  );
}

String? situationVariantTag({
  required Sky sky,
  Whereabouts whereabouts = Whereabouts.unknown,
  bool sleeping = false,
  ContextBand? band,
}) {
  if (sleeping) return 'instrumental';

  if (sky == Sky.snow) return 'snow';
  if (sky == Sky.rain || sky == Sky.drizzle || sky == Sky.thunder) return 'rain';

  if (band != null) {
    switch (band) {
      case ContextBand.morning:
        return 'morning';
      case ContextBand.afternoon:
        return 'afternoon';
      case ContextBand.evening:
        return 'evening';
      case ContextBand.night:
      case ContextBand.darkHour:
        break;
    }
  }

  if (whereabouts == Whereabouts.commuting) return 'short';
  if (whereabouts == Whereabouts.home) return 'long';
  return null;
}

String? weatherVariantTag({required Sky sky}) => situationVariantTag(sky: sky);

WeatherVariantPlan planWeatherVariants({
  required List<Track> queue,
  required int currentIndex,
  required List<Track> library,
  required Sky sky,
  Whereabouts whereabouts = Whereabouts.unknown,
}) {
  final tag = situationVariantTag(sky: sky, whereabouts: whereabouts);
  if (tag == null) return WeatherVariantPlan.empty;
  if (queue.isEmpty) return WeatherVariantPlan.empty;

  final playing = (currentIndex >= 0 && currentIndex < queue.length)
      ? queue[currentIndex]
      : null;

  Track? replacement;
  if (playing != null && !carriesVariantTag(playing, tag, library)) {
    replacement = _weatherCutOf(playing, library, tag);
  }

  final queued = {for (final t in queue) t.id};
  final add = <Track>[];
  for (final t in queue) {
    if (t.id == playing?.id) continue;
    if (carriesVariantTag(t, tag, library)) continue;
    final cut = _weatherCutOf(t, library, tag);
    if (cut == null) continue;
    if (queued.contains(cut.id)) continue;
    queued.add(cut.id);
    add.add(cut);
  }

  if (replacement == null && add.isEmpty) return WeatherVariantPlan.empty;
  return WeatherVariantPlan(
    replaceCurrent: replacement,
    add: add,
    replacedFrom: replacement == null ? null : playing,
  );
}

Track? _weatherCutOf(Track t, List<Track> library, String tag) {
  for (final o in library) {
    if (!carriesVariantTag(o, tag, library)) continue;
    if (o.id == t.id) continue;
    if (variantGroupKey(o) == variantGroupKey(t)) return o;
  }
  return null;
}
