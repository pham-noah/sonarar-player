library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'poi_types.dart';

enum PoiLookup {
  found,

  none,

  unavailable,
}

class PoiResult {
  const PoiResult(this.outcome, {this.kind, this.name});

  const PoiResult.unavailable() : this(PoiLookup.unavailable);

  final PoiLookup outcome;

  final PoiKind? kind;

  final String? name;

  bool get isFound => outcome == PoiLookup.found;
}

class PoiService {
  PoiService({http.Client? client, Duration? timeout})
      : _client = client ?? http.Client(),
        _timeout = timeout ?? const Duration(seconds: 12);

  final http.Client _client;
  final Duration _timeout;

  static const String _endpoint = 'https://overpass-api.de/api/interpreter';

  static const double kSearchRadiusM = 150.0;

  static const List<String> _keys = [
    'leisure',
    'amenity',
    'shop',
    'tourism',
    'railway',
    'office',
  ];

  static const int _attempts = 3;

  Future<PoiResult> lookup({
    required double latitude,
    required double longitude,
  }) async {
    var anyAnswered = false;

    for (var i = 0; i < _keys.length; i++) {
      final tags = await _tagsNear(
        latitude: latitude,
        longitude: longitude,
        key: _keys[i],
      );

      if (tags == null) {
        if (i == 0 && !anyAnswered) return const PoiResult.unavailable();
        continue;
      }

      anyAnswered = true;
      if (tags.isEmpty) continue;

      final kind = poiKindFor(tags);
      if (kind != null) {
        return PoiResult(PoiLookup.found, kind: kind, name: _nameOf(tags));
      }
    }

    if (!anyAnswered) return const PoiResult.unavailable();

    return const PoiResult(PoiLookup.none);
  }

  Future<Map<String, String>?> _tagsNear({
    required double latitude,
    required double longitude,
    required String key,
  }) async {
    final query = '[out:json][timeout:15];'
        'node(around:$kSearchRadiusM,$latitude,$longitude)[$key];'
        'out tags 12;';

    for (var attempt = 0; attempt < _attempts; attempt++) {
      try {
        final res = await _client
            .post(
              Uri.parse(_endpoint),

              headers: {
                'User-Agent': 'Sonarar/1.0 (personal offline music player)',
                'Content-Type': 'application/x-www-form-urlencoded',
              },
              body: {'data': query},
            )
            .timeout(_timeout);

        if (res.statusCode != 200) {
          continue;
        }

        return _nearestTags(res.body, latitude, longitude);
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  Map<String, String> _nearestTags(String body, double lat, double lon) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return const {};
      final elements = decoded['elements'];
      if (elements is! List) return const {};

      Map<String, String>? bestTags;
      var bestDistance = double.infinity;
      for (final e in elements) {
        if (e is! Map) continue;
        final tags = e['tags'];
        if (tags is! Map) continue;
        final eLat = e['lat'];
        final eLon = e['lon'];
        if (eLat is! num || eLon is! num) continue;

        final dLat = (eLat.toDouble() - lat);
        final dLon = (eLon.toDouble() - lon) * 0.98;
        final d = dLat * dLat + dLon * dLon;
        if (d < bestDistance) {
          bestDistance = d;
          bestTags = {
            for (final entry in tags.entries)
              if (entry.key is String && entry.value is String)
                entry.key as String: entry.value as String,
          };
        }
      }
      return bestTags ?? const {};
    } catch (_) {
      return const {};
    }
  }

  String? _nameOf(Map<String, String> tags) {
    final n = tags['name'];
    return n != null && n.trim().isNotEmpty ? n.trim() : null;
  }

  void dispose() => _client.close();
}

bool shouldReportLookupFailure({
  required PoiResult result,
  required bool alreadyHasKind,
  required int consecutiveFailures,
}) {
  if (result.outcome != PoiLookup.unavailable) return false;
  if (alreadyHasKind) return false;
  return consecutiveFailures >= 3;
}

bool isHtmlBody(String body) {
  final t = body.trimLeft();
  return t.startsWith('<');
}
