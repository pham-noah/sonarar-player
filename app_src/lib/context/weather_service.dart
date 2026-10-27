library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'weather_cache.dart';
import 'weather_codes.dart';

class WeatherService {
  WeatherService({http.Client? client, Duration? timeout})
      : _client = client ?? http.Client(),
        _timeout = timeout ?? const Duration(seconds: 10);

  final http.Client _client;
  final Duration _timeout;

  static const String _host = 'api.open-meteo.com';

  Future<WeatherReading?> fetch({
    required double latitude,
    required double longitude,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final uri = Uri.https(_host, '/v1/forecast', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),

      'current': 'weather_code,temperature_2m',

      'temperature_unit': 'celsius',
    });

    try {
      final resp = await _client.get(uri).timeout(_timeout);
      if (resp.statusCode != 200) return null;

      final body = jsonDecode(resp.body);
      if (body is! Map<String, dynamic>) return null;

      final current = body['current'];
      if (current is! Map<String, dynamic>) return null;

      final code = current['weather_code'];
      if (code is! num) return null;

      final temp = current['temperature_2m'];
      return WeatherReading(
        condition: conditionForWmoCode(code.toInt()),
        temperatureC: temp is num ? temp.toDouble() : 0,
        wmoCode: code.toInt(),
        fetchedAt: at,
        latitude: latitude,
        longitude: longitude,
      );
    } on SocketException {
      return null;
    } on HttpException {
      return null;
    } on FormatException {
      return null;
    } on Exception {
      return null;
    }
  }

  void dispose() => _client.close();
}
