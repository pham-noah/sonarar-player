library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sonarar/context/poi_service.dart';

class _FakeClient extends http.BaseClient {
  _FakeClient(this.responses);

  final List<(int, String)> responses;
  int calls = 0;
  final List<String> bodies = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    bodies.add((request as http.Request).body);
    final i = calls < responses.length ? calls : responses.length - 1;
    calls++;
    final (code, body) = responses[i];
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      code,
    );
  }
}

String _overpass(List<Map<String, Object?>> elements) =>
    jsonEncode({'elements': elements});

Map<String, Object?> _gymTaggable() => {
      'lat': 10.8235,
      'lon': 106.6297,
      'tags': {'leisure': 'fitness_centre', 'name': 'Iron Temple'},
    };

void main() {
  group('a real answer is classified', () {
    test('found, with the kind and the name', () async {
      final fake = _FakeClient([(200, _overpass([_gymTaggable()]))]);
      final svc = PoiService(client: fake);

      final r = await svc.lookup(latitude: 10.8231, longitude: 106.6297);
      expect(r.outcome, PoiLookup.found);
      expect(r.kind?.id, 'gym');
      expect(r.name, 'Iron Temple');
    });

    test('the CLOSEST element wins, not the first in the list', () async {
      final fake = _FakeClient([
        (200, _overpass([
          {
            'lat': 10.8300,
            'lon': 106.6297,
            'tags': {'leisure': 'swimming_pool'},
          },
          _gymTaggable(),
        ])),
      ]);
      final svc = PoiService(client: fake);
      final r = await svc.lookup(latitude: 10.8231, longitude: 106.6297);
      expect(r.kind?.id, 'gym', reason: 'the 40m gym beats the 900m pool');
    });

    test('an answered query with nothing usable is "none", not a failure', () async {
      final fake = _FakeClient([(200, _overpass([]))]);
      final svc = PoiService(client: fake);
      final r = await svc.lookup(latitude: 0.5, longitude: 0.5);
      expect(r.outcome, PoiLookup.none);
      expect(r.kind, isNull);
    });

    test('an element with no tags is skipped rather than matching', () async {
      final fake = _FakeClient([
        (200, _overpass([
          {'lat': 10.8231, 'lon': 106.6297},
        ])),
      ]);
      final svc = PoiService(client: fake);
      final r = await svc.lookup(latitude: 10.8231, longitude: 106.6297);
      expect(r.outcome, PoiLookup.none);
    });
  });

  group('THE 504 CASE: a failure is never "no kind"', () {
    test('every request failing returns unavailable, not none', () async {
      final fake = _FakeClient([(504, 'gateway timeout')]);
      final svc = PoiService(client: fake);

      final r = await svc.lookup(latitude: 10.8231, longitude: 106.6297);
      expect(r.outcome, PoiLookup.unavailable);
      expect(r.outcome, isNot(PoiLookup.none),
          reason: 'a server failure is not an answer about the world');
    });

    test('a flaky server RECOVERS: 504 then 200 still finds the gym', () async {
      final fake = _FakeClient([
        (504, 'gateway timeout'),
        (200, _overpass([_gymTaggable()])),
      ]);
      final svc = PoiService(client: fake);

      final r = await svc.lookup(latitude: 10.8231, longitude: 106.6297);
      expect(r.outcome, PoiLookup.found);
      expect(r.kind?.id, 'gym');
      expect(fake.calls, greaterThan(1), reason: 'it must have retried');
    });

    test('a down server costs three requests, not eighteen', () async {
      final fake = _FakeClient([(504, 'nope')]);
      final svc = PoiService(client: fake);
      final r = await svc.lookup(latitude: 10.8231, longitude: 106.6297);

      expect(r.outcome, PoiLookup.unavailable);
      expect(fake.calls, 3, reason: 'one key, three attempts, then stop');
    });

    test('a single key failing does NOT abort when others answered', () async {
      final fake = _FakeClient([
        (200, _overpass([])),
        (504, 'flaky'),
        (200, _overpass([_gymTaggable()])),
      ]);
      final svc = PoiService(client: fake);

      final r = await svc.lookup(latitude: 10.8231, longitude: 106.6297);
      expect(r.outcome, isNot(PoiLookup.unavailable));
    });

    test('a malformed body does not crash the lookup', () async {
      final fake = _FakeClient([
        (200, 'not json at all'),
        (200, _overpass([_gymTaggable()])),
      ]);
      final svc = PoiService(client: fake);
      final r = await svc.lookup(latitude: 10.8231, longitude: 106.6297);

      expect(r.outcome, isNotNull);
    });
  });

  group('the query is shaped to survive the server', () {
    test('one tag key per request, never several ORed together', () async {
      final fake = _FakeClient([(200, _overpass([]))]);
      final svc = PoiService(client: fake);
      await svc.lookup(latitude: 10.8231, longitude: 106.6297);

      for (final body in fake.bodies) {
        final decoded = Uri.splitQueryString(body)['data'] ?? '';

        final keys = RegExp(r'\[([a-z_]+)\]').allMatches(decoded).toList();
        expect(keys.length, 1, reason: 'query asked for ${keys.length} keys');
      }
    });

    test('it stops asking once a kind is found', () async {
      final fake = _FakeClient([(200, _overpass([_gymTaggable()]))]);
      final svc = PoiService(client: fake);
      await svc.lookup(latitude: 10.8231, longitude: 106.6297);
      expect(fake.calls, 1, reason: 'leisure answered first; the rest are waste');
    });
  });

  group('when a failure is worth telling the user about', () {
    test('a one-off failure is silent', () {
      expect(
        shouldReportLookupFailure(
          result: const PoiResult.unavailable(),
          alreadyHasKind: false,
          consecutiveFailures: 1,
        ),
        isFalse,
      );
    });

    test('a repeated failure with nothing saved is reported', () {
      expect(
        shouldReportLookupFailure(
          result: const PoiResult.unavailable(),
          alreadyHasKind: false,
          consecutiveFailures: 3,
        ),
        isTrue,
      );
    });

    test('a failure is silent when a kind is already known', () {
      expect(
        shouldReportLookupFailure(
          result: const PoiResult.unavailable(),
          alreadyHasKind: true,
          consecutiveFailures: 9,
        ),
        isFalse,
      );
    });

    test('a success is never reported as a failure', () {
      for (final outcome in [PoiLookup.found, PoiLookup.none]) {
        expect(
          shouldReportLookupFailure(
            result: PoiResult(outcome),
            alreadyHasKind: false,
            consecutiveFailures: 9,
          ),
          isFalse,
        );
      }
    });
  });

  group('an HTML page at HTTP 200 is recognised', () {
    test('Overpass sometimes answers an error page with a 200', () {
      expect(isHtmlBody('<!DOCTYPE HTML><html>...'), isTrue);
      expect(isHtmlBody('  <html>'), isTrue);
      expect(isHtmlBody('{"elements":[]}'), isFalse);
    });
  });
}
