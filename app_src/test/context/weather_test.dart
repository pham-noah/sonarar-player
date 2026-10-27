library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sonarar/context/weather_cache.dart';
import 'package:sonarar/context/weather_codes.dart';
import 'package:sonarar/context/weather_service.dart';

class _FakeClient extends http.BaseClient {
  _FakeClient({this.status = 200, this.body = '', this.throw_});

  final int status;
  final String body;
  final Object? throw_;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (throw_ != null) throw throw_!;
    final bytes = utf8.encode(body);
    return http.StreamedResponse(Stream.value(bytes), status);
  }
}

String _ok(int code, double temp) => jsonEncode({
      'current': {'weather_code': code, 'temperature_2m': temp},
    });

void main() {
  group('WMO code mapping', () {
    test('the codes Open-Meteo actually emits map to a real bucket', () {
      expect(conditionForWmoCode(0), WeatherCondition.clear);
      for (final c in [1, 2, 3]) {
        expect(conditionForWmoCode(c), WeatherCondition.clouds, reason: '$c');
      }
      for (final c in [45, 48]) {
        expect(conditionForWmoCode(c), WeatherCondition.fog, reason: '$c');
      }
      for (final c in [51, 53, 55, 56, 57]) {
        expect(conditionForWmoCode(c), WeatherCondition.drizzle, reason: '$c');
      }
      for (final c in [61, 63, 65, 66, 67, 80, 81, 82]) {
        expect(conditionForWmoCode(c), WeatherCondition.rain, reason: '$c');
      }
      for (final c in [71, 73, 75, 77, 85, 86]) {
        expect(conditionForWmoCode(c), WeatherCondition.snow, reason: '$c');
      }
      for (final c in [95, 96, 99]) {
        expect(conditionForWmoCode(c), WeatherCondition.thunder, reason: '$c');
      }
    });

    test('an unrecognised code is UNKNOWN, never clear', () {
      for (final c in [4, 30, 70, 90, 100, -1]) {
        expect(conditionForWmoCode(c), WeatherCondition.unknown, reason: '$c');
      }
    });

    test('wet means rain, drizzle and thunder — but not snow', () {
      expect(WeatherCondition.rain.isWet, isTrue);
      expect(WeatherCondition.drizzle.isWet, isTrue);
      expect(WeatherCondition.thunder.isWet, isTrue);
      expect(WeatherCondition.snow.isWet, isFalse);
      expect(WeatherCondition.clear.isWet, isFalse);
      expect(WeatherCondition.unknown.isWet, isFalse);
    });
  });

  group('cache precedence', () {
    final now = DateTime(2026, 10, 2, 12);
    WeatherReading reading(int code, DateTime at, {double lat = 1.0}) =>
        WeatherReading(
          condition: conditionForWmoCode(code),
          temperatureC: 10,
          wmoCode: code,
          fetchedAt: at,
          latitude: lat,
          longitude: 2.0,
        );

    test('a fresh cache entry for this place wins', () {
      final cached = reading(0, now.subtract(const Duration(minutes: 5)));
      final out = resolveReading(
        cached: cached,
        latitude: 1.0,
        longitude: 2.0,
        fetched: reading(61, now),
        now: now,
      );

      expect(out.wmoCode, 0);
    });

    test('a stale entry is replaced by a fresh fetch', () {
      final cached = reading(0, now.subtract(const Duration(hours: 2)));
      final out = resolveReading(
        cached: cached,
        latitude: 1.0,
        longitude: 2.0,
        fetched: reading(61, now),
        now: now,
      );
      expect(out.wmoCode, 61);
      expect(out.condition.isWet, isTrue);
    });

    test('offline holds the last known reading instead of failing', () {
      final cached = reading(61, now.subtract(const Duration(hours: 5)));
      final out = resolveReading(
        cached: cached,
        latitude: 1.0,
        longitude: 2.0,
        fetched: null,
        now: now,
      );

      expect(out.wmoCode, 61);
    });

    test('no cache and no network reads as unknown, not as clear', () {
      final out = resolveReading(
        cached: null,
        latitude: 1.0,
        longitude: 2.0,
        fetched: null,
        now: now,
      );
      expect(out.condition, WeatherCondition.unknown);
      expect(out.condition.isWet, isFalse);
    });

    test('a cache for a DIFFERENT place is discarded, not reused', () {
      final out = resolveReading(
        cached: reading(61, now.subtract(const Duration(minutes: 5)), lat: 55.0),
        latitude: 1.0,
        longitude: 2.0,
        fetched: null,
        now: now,
      );
      expect(out.condition, WeatherCondition.unknown);
    });

    test('the TTL boundary is exclusive', () {
      final cached = reading(0, now.subtract(kWeatherTtl));
      expect(cached.isStaleAt(now), isFalse);
      final older = reading(0, now.subtract(kWeatherTtl + const Duration(seconds: 1)));
      expect(older.isStaleAt(now), isTrue);
    });
  });

  group('reading survives a round trip through JSON', () {
    test('a good reading comes back identical', () {
      final r = WeatherReading(
        condition: WeatherCondition.rain,
        temperatureC: 12.5,
        wmoCode: 61,
        fetchedAt: DateTime(2026, 10, 2, 9, 30),
        latitude: 10.75,
        longitude: 106.66,
      );
      final back = WeatherReading.fromJson(jsonDecode(jsonEncode(r.toJson())));
      expect(back, isNotNull);
      expect(back!.wmoCode, 61);
      expect(back.condition, WeatherCondition.rain);
      expect(back.temperatureC, 12.5);
      expect(back.fetchedAt, r.fetchedAt);
    });

    test('a corrupt entry reads as no-cache rather than crashing launch', () {
      expect(WeatherReading.fromJson(const {}), isNull);
      expect(WeatherReading.fromJson(const {'wmo_code': 61}), isNull);
      expect(
        WeatherReading.fromJson(const {'wmo_code': 61, 'fetched_at': 'not a date'}),
        isNull,
      );
      expect(
        WeatherReading.fromJson(
            const {'wmo_code': '61', 'fetched_at': '2026-10-02T09:00:00'}),
        isNull,
      );
    });
  });

  group('the fetch', () {
    test('a good response becomes a reading', () async {
      final svc = WeatherService(client: _FakeClient(body: _ok(61, 12.5)));
      final r = await svc.fetch(latitude: 10.75, longitude: 106.66);
      expect(r, isNotNull);
      expect(r!.condition, WeatherCondition.rain);
      expect(r.temperatureC, 12.5);
      expect(r.latitude, 10.75);
    });

    test('a non-200 is null, not a throw', () async {
      final svc = WeatherService(client: _FakeClient(status: 500, body: 'nope'));
      expect(await svc.fetch(latitude: 1, longitude: 2), isNull);
    });

    test('an offline socket failure is null, not a throw', () async {
      final svc = WeatherService(
          client: _FakeClient(throw_: const SocketException('offline')));
      expect(await svc.fetch(latitude: 1, longitude: 2), isNull);
    });

    test('a captive portal (HTML, not JSON) is null, not a throw', () async {
      final svc = WeatherService(
          client: _FakeClient(body: '<html>sign in to wifi</html>'));
      expect(await svc.fetch(latitude: 1, longitude: 2), isNull);
    });

    test('a response missing the current block is null', () async {
      final svc = WeatherService(client: _FakeClient(body: jsonEncode({'x': 1})));
      expect(await svc.fetch(latitude: 1, longitude: 2), isNull);
    });

    test('a response missing weather_code is null', () async {
      final svc = WeatherService(
          client: _FakeClient(body: jsonEncode({'current': {'temperature_2m': 5}})));
      expect(await svc.fetch(latitude: 1, longitude: 2), isNull);
    });
  });
}
