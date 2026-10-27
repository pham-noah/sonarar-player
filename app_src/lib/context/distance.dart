library;

import 'dart:math' as math;

const double kDefaultPlaceRadiusM = 150.0;

double distanceMetres({
  required double lat1,
  required double lon1,
  required double lat2,
  required double lon2,
}) {
  const earthKm = 6371.0;
  double rad(double deg) => deg * math.pi / 180.0;

  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2).toDouble() +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2).toDouble();

  final c = 2 * math.asin(math.sqrt(a > 1.0 ? 1.0 : a));
  return earthKm * c * 1000.0;
}
