library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/rules/playlist_explanation.dart';

void main() {
  group('the moment, one sentence', () {
    test('HIS EXAMPLE, word for word', () {
      final s = momentSentence(
        placeName: 'Home',
        raining: true,
        sleeping: true,
      );
      expect(s,
          "You are at Home. It's raining outside. And you wanna have easier time when sleeping.");
    });

    test('place and weather, no timer', () {
      expect(momentSentence(placeName: 'Home', raining: true),
          "You are at Home. It's raining outside.");
    });

    test('snow is named before rain — freezing rain reports as snow', () {
      expect(momentSentence(placeName: 'Gym', snowing: true, raining: true),
          "You are at Gym. It's snowing outside.");
    });

    test('on the move, raining', () {
      expect(momentSentence(commuting: true, raining: true),
          "You are on the move. It's raining outside.");
    });

    test('between saved places is NOT the same as no reading at all', () {
      expect(momentSentence(betweenPlaces: true, raining: true),
          "You are between your saved places. It's raining outside.");
    });

    test('an imprecise fix admits it rather than implying precision', () {
      final s = momentSentence(placeName: 'Home', preciseFix: false);
      expect(s, 'You are somewhere near Home.');
      expect(s, isNot(contains('You are at')));
    });

    test('the hour is named ONLY when nothing else is driving it', () {
      expect(momentSentence(placeName: 'Home', bandName: 'evening'),
          isNot(contains('evening')));

      expect(momentSentence(bandName: 'evening'), "It's evening.");
    });

    test('nothing to say is null, not a sentence about nothing', () {
      expect(momentSentence(), isNull);
    });

    test('NO ENGINE VOCABULARY LEAKS INTO THE SENTENCE', () {
      final s = momentSentence(
        placeName: 'Home',
        raining: true,
        snowing: false,
        sleeping: true,
        commuting: false,
        bandName: 'evening',
      )!;
      for (final term in [
        'Rule', 'rule', 'matched', 'weather=', 'energy', 'Energy', 'band', 'PlaylistContext',
        'band=', 'sting', 'tracks', 'rank', 'fit',
      ]) {
        expect(s, isNot(contains(term)),
            reason: 'the sentence leaked engine vocabulary: "$term"');
      }
    });
  });
}
