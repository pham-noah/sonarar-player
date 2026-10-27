library;

import 'distance.dart' show distanceMetres;

const Duration kPlaceRefreshInterval = Duration(minutes: 5);

bool isPlaceRefreshDue({
  required DateTime? lastAsked,
  required DateTime now,
  Duration interval = kPlaceRefreshInterval,
}) {
  if (lastAsked == null) return true;
  return now.difference(lastAsked) >= interval;
}

enum PlaceAction {
  ignore,

  publishAndSwitch,

  publishOnly,

  travelling,
}

PlaceAction placeActionFor({
  required String? previousPlaceId,
  required String? newPlaceId,
  required bool trustworthy,
  required bool moved,
}) {
  if (previousPlaceId == newPlaceId) return PlaceAction.ignore;
  if (newPlaceId == null) {
    return moved ? PlaceAction.travelling : PlaceAction.ignore;
  }
  return trustworthy ? PlaceAction.publishAndSwitch : PlaceAction.publishOnly;
}

double? speedMetresPerSecond({
  required double? fromLat,
  required double? fromLon,
  required double? toLat,
  required double? toLon,
  required double seconds,
}) {
  if (fromLat == null || fromLon == null || toLat == null || toLon == null) {
    return null;
  }
  if (seconds <= 0) return null;
  return distanceMetres(
        lat1: fromLat,
        lon1: fromLon,
        lat2: toLat,
        lon2: toLon,
      ) /
      seconds;
}

const double kWalkingMaxMetresPerSecond = 2.2;
const double kStillMaxMetresPerSecond = 0.5;

bool looksLikeWalking(double? metresPerSecond) {
  final v = metresPerSecond;
  if (v == null) return false;
  return v > kStillMaxMetresPerSecond && v < kWalkingMaxMetresPerSecond;
}

const double kMovementToleranceMetres = 60.0;

bool hasMoved({
  required double? fromLat,
  required double? fromLon,
  required double? toLat,
  required double? toLon,
  double toleranceMetres = kMovementToleranceMetres,
}) {
  if (fromLat == null || fromLon == null || toLat == null || toLon == null) {
    return false;
  }
  return distanceMetres(
        lat1: fromLat,
        lon1: fromLon,
        lat2: toLat,
        lon2: toLon,
      ) >
      toleranceMetres;
}
