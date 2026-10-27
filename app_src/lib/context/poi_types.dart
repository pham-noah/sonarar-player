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
    required this.label,
    required this.mood,
    required this.suggestedPlaylist,
    required this.osmTags,
  });

  final String id;

  final String label;

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
    label: 'Gym',
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
    label: 'Library',
    mood: PoiMood.focus,
    suggestedPlaylist: 'Study',
    osmTags: ['amenity=library'],
  ),
  PoiKind(
    id: 'university',
    label: 'University',
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
    label: 'Coworking',
    mood: PoiMood.focus,
    suggestedPlaylist: 'Deep Focus',
    osmTags: ['amenity=coworking_space', 'office=coworking'],
  ),
  PoiKind(
    id: 'cafe_study',
    label: 'Cafe',
    mood: PoiMood.social,
    suggestedPlaylist: 'Cafe',
    osmTags: ['amenity=cafe'],
  ),

  PoiKind(
    id: 'restaurant',
    label: 'Restaurant',
    mood: PoiMood.social,
    suggestedPlaylist: 'Dinner',
    osmTags: ['amenity=restaurant', 'amenity=fast_food', 'amenity=food_court'],
  ),
  PoiKind(
    id: 'bar',
    label: 'Bar',
    mood: PoiMood.social,
    suggestedPlaylist: 'Night Out',
    osmTags: ['amenity=bar', 'amenity=pub', 'amenity=nightclub', 'amenity=biergarten'],
  ),
  PoiKind(
    id: 'mall',
    label: 'Mall',
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
    label: 'Cinema',
    mood: PoiMood.quiet,
    suggestedPlaylist: 'Silence',
    osmTags: ['amenity=cinema', 'amenity=theatre', 'amenity=arts_centre'],
  ),

  PoiKind(
    id: 'transit',
    label: 'Transit',
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
    label: 'Parking',
    mood: PoiMood.transit,
    suggestedPlaylist: 'Commute',
    osmTags: ['amenity=parking', 'amenity=fuel', 'amenity=charging_station'],
  ),

  PoiKind(
    id: 'place_of_worship',
    label: 'Place of worship',
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
    label: 'Hospital',
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
    label: 'Park',
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
    label: 'Stadium',
    mood: PoiMood.energy,
    suggestedPlaylist: 'Gym',
    osmTags: ['leisure=stadium', 'leisure=sports_hall'],
  ),
  PoiKind(
    id: 'swimming',
    label: 'Pool',
    mood: PoiMood.energy,
    suggestedPlaylist: 'Gym',
    osmTags: ['leisure=swimming_pool', 'leisure=water_park', 'amenity=public_bath'],
  ),

  PoiKind(
    id: 'hotel',
    label: 'Hotel',
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

String moodLabel(PoiMood mood) => switch (mood) {
      PoiMood.focus => 'you are working here',
      PoiMood.energy => 'you are moving here',
      PoiMood.social => 'you are around people here',
      PoiMood.transit => 'you are passing through',
      PoiMood.quiet => 'somewhere to be quiet',
      PoiMood.any => 'nothing specific',
    };
