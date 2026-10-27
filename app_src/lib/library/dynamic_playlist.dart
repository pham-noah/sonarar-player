library;

import '../context/location_service.dart';
import '../theme/skin_policy.dart';
import 'playlists.dart';
import 'track.dart';

const String kDynamicId = '__dynamic__';

const String kDynamicName = 'Dynamic';

Playlist dynamicPlaylist(List<Track> tracks) => Playlist(
      id: kDynamicId,
      name: kDynamicName,
      trackIds: [for (final t in tracks) t.id],
    );

String dynamicBlurb({
  required ContextBand band,
  required bool raining,
  required bool snowing,
  required String? placeName,
  ManualMode? mode,

  bool preciseFix = true,
}) {
  final parts = <String>[];

  if (mode != null) {
    parts.add(mode.label);
  } else {
    if (placeName != null) {
      parts.add(placeName);

      if (!preciseFix) parts.add('approximate');
    } else {
      parts.add(_bandWord(band));
    }

    if (snowing) {
      parts.add('snow');
    } else if (raining) {
      parts.add('rain');
    }
  }

  return parts.isEmpty ? 'Decided by the time of day.' : parts.join(' · ');
}

bool fixCanTellPlacesApart(PlaceSource source, double? accuracyMetres) {
  if (source != PlaceSource.gps) return false;
  final a = accuracyMetres;
  return a != null && a <= kPlaceDiscriminatingAccuracy;
}

const double kPlaceDiscriminatingAccuracy = 250.0;

String _bandWord(ContextBand band) => switch (band) {
      ContextBand.morning => 'Morning',
      ContextBand.afternoon => 'Afternoon',
      ContextBand.evening => 'Evening',
      ContextBand.night => 'Night',
      ContextBand.darkHour => 'Night Hour',
    };
