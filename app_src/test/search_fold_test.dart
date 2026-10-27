@Tags(['slow'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/screens/youtube_search_screen.dart';

void main() {
  test('punctuation and case do not matter', () {
    for (final q in ["its going down now", "IT'S GOING DOWN NOW", "its", "it's"]) {
      expect(foldForSearch(q).contains('its') || foldForSearch(q).contains('going'),
          isTrue, reason: 'fold("$q") lost the words');
    }

    expect(foldForSearch("it's"), foldForSearch('its'));
    expect(foldForSearch('Going-Down'), foldForSearch('goingdown'));
  });

  test('a hyphen inside a name does not split the word', () {
    expect(foldForSearch('re:zero'), 'rezero');
  });
}
