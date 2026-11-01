library;

enum PoiMood {
  focus,

  energy,

  social,

  transit,

  quiet,

  any,
}

class PoiKind {
  const PoiKind({
    required this.id,
    required this.mood,
    required this.suggestedPlaylist,
    required this.osmTags,
  });

  final String id;

  final PoiMood mood;

  final String suggestedPlaylist;

  final List<String> osmTags;

  bool matches(Map<String, String> tags) {
    for (final t in osmTags) {
      final eq = t.indexOf('=');
      if (eq < 0) continue;
      final key = t.substring(0, eq);
      final want = t.substring(eq + 1);
      if (tags[key] == want) return true;
    }
    return false;
  }
}

const List<PoiKind> kPoiKinds = [

  PoiKind(
    id: 'gym',
    mood: PoiMood.energy,
    suggestedPlaylist: 'Gym',
    osmTags: [
      'leisure=fitness_centre',
      'leisure=sports_centre',
      'leisure=exercise',
      'amenity=gym',
    ],
  ),
  PoiKind(
    id: 'library',
    mood: PoiMood.focus,
    suggestedPlaylist: 'Study',
    osmTags: ['amenity=library'],
  ),
  PoiKind(
    id: 'university',
    mood: PoiMood.focus,
    suggestedPlaylist: 'Campus',
    osmTags: [
      'amenity=university',
      'amenity=college',
      'building=university',
      'amenity=school',
    ],
  ),
  PoiKind(
    id: 'coworking',
    mood: PoiMood.focus,
    suggestedPlaylist: 'Deep Focus',
    osmTags: ['amenity=coworking_space', 'office=coworking'],
  ),
  PoiKind(
    id: 'cafe_study',
    mood: PoiMood.social,
    suggestedPlaylist: 'Cafe',
    osmTags: ['amenity=cafe'],
  ),

  PoiKind(
    id: 'restaurant',
    mood: PoiMood.social,
    suggestedPlaylist: 'Dinner',
    osmTags: ['amenity=restaurant', 'amenity=fast_food', 'amenity=food_court'],
  ),
  PoiKind(
    id: 'bar',
    mood: PoiMood.social,
    suggestedPlaylist: 'Night Out',
    osmTags: ['amenity=bar', 'amenity=pub', 'amenity=nightclub', 'amenity=biergarten'],
  ),
  PoiKind(
    id: 'mall',
    mood: PoiMood.social,
    suggestedPlaylist: 'Wandering',
    osmTags: [
      'shop=mall',
      'shop=department_store',
      'shop=supermarket',
      'amenity=marketplace',
    ],
  ),
  PoiKind(
    id: 'cinema',
    mood: PoiMood.quiet,
    suggestedPlaylist: 'Silence',
    osmTags: ['amenity=cinema', 'amenity=theatre', 'amenity=arts_centre'],
  ),

  PoiKind(
    id: 'transit',
    mood: PoiMood.transit,
    suggestedPlaylist: 'Commute',
    osmTags: [
      'railway=station',
      'railway=subway_entrance',
      'amenity=bus_station',
      'highway=bus_stop',
      'amenity=ferry_terminal',
      'aeroway=terminal',
    ],
  ),
  PoiKind(
    id: 'parking',
    mood: PoiMood.transit,
    suggestedPlaylist: 'Commute',
    osmTags: ['amenity=parking', 'amenity=fuel', 'amenity=charging_station'],
  ),

  PoiKind(
    id: 'place_of_worship',
    mood: PoiMood.quiet,
    suggestedPlaylist: 'Silence',
    osmTags: [
      'amenity=place_of_worship',
      'building=church',
      'building=mosque',
      'building=temple',
    ],
  ),
  PoiKind(
    id: 'hospital',
    mood: PoiMood.quiet,
    suggestedPlaylist: 'Silence',
    osmTags: [
      'amenity=hospital',
      'amenity=clinic',
      'amenity=doctors',
      'amenity=pharmacy',
    ],
  ),

  PoiKind(
    id: 'park',
    mood: PoiMood.energy,
    suggestedPlaylist: 'Walk',
    osmTags: [
      'leisure=park',
      'leisure=garden',
      'leisure=nature_reserve',
      'leisure=pitch',
      'leisure=track',
    ],
  ),
  PoiKind(
    id: 'stadium',
    mood: PoiMood.energy,
    suggestedPlaylist: 'Gym',
    osmTags: ['leisure=stadium', 'leisure=sports_hall'],
  ),
  PoiKind(
    id: 'swimming',
    mood: PoiMood.energy,
    suggestedPlaylist: 'Gym',
    osmTags: ['leisure=swimming_pool', 'leisure=water_park', 'amenity=public_bath'],
  ),

  PoiKind(
    id: 'hotel',
    mood: PoiMood.quiet,
    suggestedPlaylist: 'Night',
    osmTags: ['tourism=hotel', 'tourism=hostel', 'tourism=guest_house', 'tourism=motel'],
  ),
];

PoiKind? poiKindFor(Map<String, String> tags) {
  for (final k in kPoiKinds) {
    if (k.matches(tags)) return k;
  }
  return null;
}
