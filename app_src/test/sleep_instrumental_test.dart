library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/library/weather_variants.dart';
import 'package:sonarar/theme/skin_policy.dart';

Track _t(String id, {String? variant}) => Track(
      id: id,
      title: 'Title $id',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(minutes: 3),
      file: '$id.opus',
      cover: '',
      gainDb: null,
      variantTag: variant);

void main() {
  group('the tag', () {
    test('sleeping returns instrumental', () {
      expect(
        situationVariantTag(sky: Sky.unknown, sleeping: true),
        'instrumental');
    });

    test('sleeping OUTRANKS snow, rain and place', () {
      expect(
        situationVariantTag(sky: Sky.snow, sleeping: true),
        'instrumental',
        reason: 'a weather situation outranked the sleep override');
      expect(
        situationVariantTag(
            sky: Sky.unknown, whereabouts: Whereabouts.commuting, sleeping: true),
        'instrumental');
      expect(
        situationVariantTag(
            sky: Sky.unknown, whereabouts: Whereabouts.home, sleeping: true),
        'instrumental');
    });

    test('the day bands tag morning, afternoon and evening', () {
      expect(situationVariantTag(sky: Sky.unknown, band: ContextBand.morning), 'morning');
      expect(situationVariantTag(sky: Sky.unknown, band: ContextBand.afternoon), 'afternoon');
      expect(situationVariantTag(sky: Sky.unknown, band: ContextBand.evening), 'evening');
    });

    test('NIGHT and DARK HOUR tag nothing', () {
      expect(situationVariantTag(sky: Sky.unknown, band: ContextBand.night), isNull);
      expect(situationVariantTag(sky: Sky.unknown, band: ContextBand.darkHour), isNull);
    });

    test('a band OUTRANKS the place rules', () {
      expect(
        situationVariantTag(sky: Sky.unknown, whereabouts: Whereabouts.home, band: ContextBand.morning),
        'morning');
      expect(
        situationVariantTag(sky: Sky.unknown, whereabouts: Whereabouts.commuting, band: ContextBand.evening),
        'evening');
    });

    test('weather still outranks a band — the sky is a fact, the hour is a guess', () {
      expect(
        situationVariantTag(sky: Sky.rain, band: ContextBand.morning),
        'rain');
      expect(
        situationVariantTag(sky: Sky.snow, band: ContextBand.evening),
        'snow');
    });

    test('sleeping outranks a band too', () {
      expect(
        situationVariantTag(sky: Sky.unknown, sleeping: true, band: ContextBand.morning),
        'instrumental');
    });

    test('the other order is unchanged when not sleeping', () {
      expect(situationVariantTag(sky: Sky.snow), 'snow');
      expect(situationVariantTag(sky: Sky.rain), 'rain');
      expect(
        situationVariantTag(sky: Sky.unknown, whereabouts: Whereabouts.commuting),
        'short');
      expect(
        situationVariantTag(sky: Sky.unknown, whereabouts: Whereabouts.home),
        'long');
      expect(situationVariantTag(sky: Sky.unknown), isNull);
    });
  });

  group('the queue', () {
    test('ARMING adds the instrumental list to a live queue', () {
      final state = AppState();
      state.attachLibrary([for (var i = 0; i < 8; i++) _t('t$i')]);

      state.playTrackNow('t0');
      state.setSleeping(true);

      expect(state.sleeping, isTrue);

      expect(
        situationVariantTag(

          sky: state.playlistContext?.sky ?? Sky.unknown,
          whereabouts: state.playlistContext?.whereabouts ?? Whereabouts.unknown,
          sleeping: state.sleeping),
        'instrumental');
    });

    test('DISARMING clears it — "they are not sleeping yet"', () {
      final state = AppState();
      state.attachLibrary([for (var i = 0; i < 4; i++) _t('t$i')]);
      state.setSleeping(true);
      expect(state.sleeping, isTrue);

      state.setSleeping(false);
      expect(state.sleeping, isFalse, reason: 'the override was left armed');
    });

    test('setting the same value twice is not a change', () {
      final state = AppState();
      state.attachLibrary([for (var i = 0; i < 4; i++) _t('t$i')]);
      state.setSleeping(true);
      state.setSleeping(true);
      expect(state.sleeping, isTrue);
    });

    test('it survives a context change while armed', () {
      final state = AppState();
      state.attachLibrary([for (var i = 0; i < 4; i++) _t('t$i')]);
      state.playTrackNow('t0');
      state.setSleeping(true);

      state.updateContext(
        const PlayContext(
          band: ContextBand.morning,
          sky: Sky.rain,
          localHour: 9));

      expect(state.sleeping, isTrue,
          reason: 'a context change disarmed the sleep override');
      expect(
        situationVariantTag(
          sky: Sky.rain,
          sleeping: state.sleeping),
        'instrumental',
        reason: 'rain took over a queue that is meant to be instrumentals');
    });
  });
}
