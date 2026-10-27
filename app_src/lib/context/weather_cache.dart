library;

import '../core/constants.dart';
import 'weather_codes.dart';

const Duration kWeatherTtl = kWeatherRefreshInterval;

class WeatherReading {
  const WeatherReading({
    required this.condition,
    required this.temperatureC,
    required this.wmoCode,
    required this.fetchedAt,
    required this.latitude,
    required this.longitude,
  });

  final WeatherCondition condition;

  final double temperatureC;

  final int wmoCode;

  final DateTime fetchedAt;

  final double latitude;
  final double longitude;

  bool isStaleAt(DateTime now) => now.difference(fetchedAt) > kWeatherTtl;

  static WeatherReading unknown({
    required double latitude,
    required double longitude,
    required DateTime at,
  }) =>
      WeatherReading(
        condition: WeatherCondition.unknown,
        temperatureC: 0,
        wmoCode: -1,
        fetchedAt: at,
        latitude: latitude,
        longitude: longitude,
      );

  Map<String, dynamic> toJson() => {
        'wmo_code': wmoCode,
        'temperature_c': temperatureC,
        'fetched_at': fetchedAt.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
      };

  static WeatherReading? fromJson(Map<String, dynamic> json) {
    final code = json['wmo_code'];
    final at = json['fetched_at'];
    if (code is! num || at is! String) return null;
    final parsed = DateTime.tryParse(at);
    if (parsed == null) return null;
    final lat = json['latitude'];
    final lon = json['longitude'];
    if (lat is! num || lon is! num) return null;

    return WeatherReading(
      condition: conditionForWmoCode(code.toInt()),
      temperatureC: (json['temperature_c'] as num?)?.toDouble() ?? 0,
      wmoCode: code.toInt(),
      fetchedAt: parsed,
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
    );
  }
}

WeatherReading resolveReading({
  required WeatherReading? cached,
  required double latitude,
  required double longitude,
  required WeatherReading? fetched,
  required DateTime now,
  double placeEpsilon = 0.01,
}) {
  final samePlace = cached != null &&
      (cached.latitude - latitude).abs() < placeEpsilon &&
      (cached.longitude - longitude).abs() < placeEpsilon;

  if (samePlace && !cached.isStaleAt(now)) return cached;

  if (fetched != null) return fetched;

  if (samePlace) return cached;

  return WeatherReading.unknown(
    latitude: latitude,
    longitude: longitude,
    at: now,
  );
}
