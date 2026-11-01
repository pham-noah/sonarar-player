library;

import '../l10n/app_localizations.dart';
import 'poi_types.dart';

/// The words for a place kind and for its mood.
///
/// [PoiKind.label] is gone rather than translated beside: the picker, the chip
/// and the "map says" sentence now read the reader's language, while
/// [PoiKind.suggestedPlaylist] stays exactly as it is — a playlist is the
/// listener's own file on disk, and a language change must not rename it.
String poiLabel(AppLocalizations l10n, PoiKind kind) => switch (kind.id) {
      'gym' => l10n.poiGym,
      'library' => l10n.poiLibrary,
      'university' => l10n.poiUniversity,
      'coworking' => l10n.poiCoworking,
      'cafe_study' => l10n.poiCafe,
      'restaurant' => l10n.poiRestaurant,
      'bar' => l10n.poiBar,
      'mall' => l10n.poiMall,
      'cinema' => l10n.poiCinema,
      'transit' => l10n.poiTransit,
      'parking' => l10n.poiParking,
      'place_of_worship' => l10n.poiPlaceOfWorship,
      'hospital' => l10n.poiHospital,
      'park' => l10n.poiPark,
      'stadium' => l10n.poiStadium,
      'swimming' => l10n.poiPool,
      'hotel' => l10n.poiHotel,
      _ => kind.id,
    };

String poiMoodLabel(AppLocalizations l10n, PoiMood mood) => switch (mood) {
      PoiMood.focus => l10n.moodFocus,
      PoiMood.energy => l10n.moodEnergy,
      PoiMood.social => l10n.moodSocial,
      PoiMood.transit => l10n.moodTransit,
      PoiMood.quiet => l10n.moodQuiet,
      PoiMood.any => l10n.moodAny,
    };
