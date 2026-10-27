library;

import '../context/places.dart';
import 'context_rules.dart';

const int kPlaceRulePriority = 70;

List<ContextRule> placeRules(PlaceBook book) {
  final out = <ContextRule>[];
  for (final p in book.places) {
    final list = p.playlist;
    if (list == null || list.trim().isEmpty) continue;
    if (!p.isUsable) continue;

    out.add(ContextRule(
      id: 'place-${p.id}',
      priority: kPlaceRulePriority,
      placeId: p.id,
      playlist: list.trim(),
    ));
  }
  return out;
}

ContextRules withPlaceRules(ContextRules written, PlaceBook book) {
  final derived = placeRules(book);
  if (derived.isEmpty) return written;
  return ContextRules([...written.rules, ...derived]);
}

String? suggestedPlaylistFor(NamedPlace place) => place.playlist;
