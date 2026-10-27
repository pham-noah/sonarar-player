library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/context/location_service.dart';
import 'package:sonarar/library/dynamic_playlist.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/theme/skin_policy.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Title $id',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(minutes: 3),
      file: '$id.m4a',
      cover: '',
      gainDb: 0,
    );

void main() {
  group('built, never stored', () {
    test('carries the mix in the order the engine chose', () {
      final p = dynamicPlaylist([_t('c'), _t('a'), _t('b')]);
      expect(p.trackIds, ['c', 'a', 'b']);
    });

    test('uses the reserved id, so it cannot collide with his own', () {
      expect(dynamicPlaylist([_t('a')]).id, kDynamicId);
      expect(dynamicPlaylist([_t('a')]).name, kDynamicName);
    });

    test('an EMPTY mix still produces a playlist, and it is empty', () {
      final p = dynamicPlaylist(const []);
      expect(p.isEmpty, isTrue);
      expect(p.trackIds, isEmpty);
    });
  });

  group('the blurb says WHY, in the order that matters', () {
    test('a mode he chose outranks the conditions', () {
      final s = dynamicBlurb(
        band: ContextBand.afternoon,
        raining: true,
        snowing: false,
        placeName: 'Gym',
        mode: ManualMode.battle,
      );
      expect(s, contains('Energy'));
      expect(s, isNot(contains('Gym')));
      expect(s, isNot(contains('rain')));
    });

    test('WHERE outranks the clock', () {
      final s = dynamicBlurb(
        band: ContextBand.afternoon,
        raining: false,
        snowing: false,
        placeName: 'University',
      );
      expect(s, startsWith('University'));
      expect(s, isNot(contains('Afternoon')));
    });

    test('the clock is the fallback when there is no place', () {
      final s = dynamicBlurb(
        band: ContextBand.evening,
        raining: false,
        snowing: false,
        placeName: null,
      );
      expect(s, 'Evening');
    });

    test('weather is named only when it is DOING something', () {
      final dry = dynamicBlurb(
        band: ContextBand.night,
        raining: false,
        snowing: false,
        placeName: null,
      );
      expect(dry, isNot(contains('rain')));

      final wet = dynamicBlurb(
        band: ContextBand.night,
        raining: true,
        snowing: false,
        placeName: null,
      );
      expect(wet, contains('rain'));
    });

    test('SNOW is named as snow, not as rain', () {
      final s = dynamicBlurb(
        band: ContextBand.night,
        raining: false,
        snowing: true,
        placeName: null,
      );
      expect(s, contains('snow'));
      expect(s, isNot(contains('rain')));
    });

    test('a place plus weather reads as both', () {
      final s = dynamicBlurb(
        band: ContextBand.afternoon,
        raining: true,
        snowing: false,
        placeName: 'Gym',
      );
      expect(s, contains('Gym'));
      expect(s, contains('rain'));
    });
  });

  group('it admits when it cannot tell two places apart', () {
    test('IP is NEVER precise enough, however good the accuracy says', () {
      expect(fixCanTellPlacesApart(PlaceSource.ipLookup, 10), isFalse);
      expect(fixCanTellPlacesApart(PlaceSource.ipLookup, null), isFalse);
    });

    test('GPS with a tight accuracy is trusted', () {
      expect(fixCanTellPlacesApart(PlaceSource.gps, 15), isTrue);
      expect(fixCanTellPlacesApart(PlaceSource.gps, 250), isTrue);
    });

    test('GPS that is too loose is NOT trusted', () {
      expect(fixCanTellPlacesApart(PlaceSource.gps, 400), isFalse);
      expect(fixCanTellPlacesApart(PlaceSource.gps, 5000), isFalse);
    });

    test('a GPS fix reporting NO accuracy is not trusted', () {
      expect(fixCanTellPlacesApart(PlaceSource.gps, null), isFalse);
    });

    test('an imprecise fix is SAID to be approximate', () {
      final s = dynamicBlurb(
        band: ContextBand.afternoon,
        raining: false,
        snowing: false,
        placeName: 'Gym',
        preciseFix: false,
      );
      expect(s, contains('approximate'));
    });

    test('a precise fix says nothing extra', () {
      final s = dynamicBlurb(
        band: ContextBand.afternoon,
        raining: false,
        snowing: false,
        placeName: 'Gym',
        preciseFix: true,
      );
      expect(s, 'Gym');
    });
  });
}
