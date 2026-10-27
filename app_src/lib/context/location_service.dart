library;

import 'dart:convert';

import 'package:flutter/services.dart';

export 'distance.dart';

import 'place_refresh.dart';
import 'package:http/http.dart' as http;

enum PlaceSource {
  gps,

  ipLookup,

  unknown,
}

class PlaceReading {
  const PlaceReading({
    required this.latitude,
    required this.longitude,
    this.city,
    this.source = PlaceSource.gps,
    this.accuracyMetres,
  });

  final double latitude;
  final double longitude;

  final String? city;

  final PlaceSource source;

  final double? accuracyMetres;

  @override
  String toString() =>
      '${city ?? '?'} (${latitude.toStringAsFixed(5)}, '
      '${longitude.toStringAsFixed(5)}) via ${source.name}';
}

class LocationService {
  LocationService({http.Client? client, Duration? timeout})
      : _client = client ?? http.Client(),
        _timeout = timeout ?? const Duration(seconds: 8);

  final http.Client _client;
  final Duration _timeout;

  static const String _ipUrl = 'https://ipapi.co/json/';

  static const MethodChannel _location = MethodChannel('personar/location');

  PlaceReading? _last;

  PlaceReading? get last => _last;

  PlaceReading? _anchor;

  Future<PlaceReading?> resolve() async {
    final gps = await _resolveGps();
    if (gps != null) {
      _anchor = gps;
      return _last = gps;
    }

    final ip = await _resolveIp();
    if (ip != null) return _last = ip;

    return _last;
  }

  Future<PlaceReading?> _resolveGps() async {
    try {
      if (await _location.invokeMethod<bool>('enabled') != true) return null;

      var permission = await _location.invokeMethod<String>('checkPermission') ?? 'denied';
      if (permission == 'denied') {
        permission = await _location.invokeMethod<String>('requestPermission') ?? 'denied';
      }

      if (permission != 'granted') return null;

      final cached = _readingFrom(await _location.invokeMethod<Object?>('lastKnown'));
      if (cached != null) {
        final anchor = _anchor;
        if (anchor != null &&
            !hasMoved(
              fromLat: anchor.latitude,
              fromLon: anchor.longitude,
              toLat: cached.latitude,
              toLon: cached.longitude,
            )) {
          return _last = cached;
        }
      }

      return _readingFrom(await _location.invokeMethod<Object?>('current', {
        'timeoutMs': _timeout.inMilliseconds,
      }));
    } catch (_) {
      return null;
    }
  }

  static PlaceReading? _readingFrom(Object? raw) {
    if (raw is! Map) return null;
    final lat = raw['latitude'];
    final lon = raw['longitude'];
    if (lat is! num || lon is! num) return null;
    if (!lat.isFinite || !lon.isFinite) return null;
    final accuracy = raw['accuracy'];
    return PlaceReading(
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      source: PlaceSource.gps,
      accuracyMetres: accuracy is num ? accuracy.toDouble() : null,
    );
  }

  Future<PlaceReading?> _resolveIp() async {
    try {
      final res = await _client.get(Uri.parse(_ipUrl)).timeout(_timeout);
      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body);
      if (body is! Map) return null;

      final lat = body['latitude'];
      final lon = body['longitude'];
      if (lat is! num || lon is! num) return null;

      final latD = lat.toDouble();
      final lonD = lon.toDouble();

      if (!latD.isFinite || !lonD.isFinite) return null;
      if (latD == 0.0 && lonD == 0.0) return null;
      if (latD.abs() > 90 || lonD.abs() > 180) return null;

      final city = body['city'];
      return PlaceReading(
        latitude: latD,
        longitude: lonD,
        city: city is String && city.isNotEmpty ? city : null,
        source: PlaceSource.ipLookup,
      );
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}
