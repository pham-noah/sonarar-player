library;

import 'track.dart';

const List<String> kVariantTags = [
  'acoustic',
  'instrumental',
  'rain',
  'arrange',
  'long',
  'short',
];

bool isKnownVariantTag(String? tag) =>
    tag != null && kVariantTags.contains(tag);

String variantLabel(String tag) => tag.toUpperCase();

String variantGroupKey(Track t) => t.variantOf ?? t.id;

List<Track> variantsOf(Track t, List<Track> library) {
  final key = variantGroupKey(t);
  final others = library
      .where((o) =>
          o.id != t.id &&
          variantGroupKey(o) == key &&

          (o.variantOf == null || isKnownVariantTag(o.variantTag)))
      .toList();
  others.sort((a, b) {
    final ai = a.variantTag == null ? -1 : kVariantTags.indexOf(a.variantTag!);
    final bi = b.variantTag == null ? -1 : kVariantTags.indexOf(b.variantTag!);
    return ai.compareTo(bi);
  });
  return others;
}

String? preferredVariantFor({required bool raining, required bool snowing}) {
  if (raining) return 'rain';
  return null;
}

const double kShortRatio = 0.75;

const double kLongRatio = 1.35;

Set<String> effectiveVariantTags(Track t, List<Track> library) {
  final tags = <String>{if (isKnownVariantTag(t.variantTag)) t.variantTag!};
  final family = [
    for (final o in library)
      if (variantGroupKey(o) == variantGroupKey(t)) o,
  ];
  if (family.length < 2) return tags;
  final longest = family.map((o) => o.duration.inMilliseconds).reduce((a, b) => a > b ? a : b);
  final shortest = family.map((o) => o.duration.inMilliseconds).reduce((a, b) => a < b ? a : b);
  final mine = t.duration.inMilliseconds;
  if (longest > 0 && mine / longest <= kShortRatio) tags.add('short');
  if (shortest > 0 && mine / shortest >= kLongRatio) tags.add('long');
  return tags;
}

bool carriesVariantTag(Track t, String tag, List<Track> library) =>
    effectiveVariantTags(t, library).contains(tag);
