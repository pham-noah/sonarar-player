library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/player/art_cycle.dart';

void main() {
  test('a track change with the setting on advances the art', () {
    expect(
      shouldAdvanceArt(enabled: true, trackChanged: true, alreadyCycling: false),
      isTrue,
    );
  });

  test('the setting OFF pins the piece — nothing advances, ever', () {
    expect(
      shouldAdvanceArt(enabled: false, trackChanged: true, alreadyCycling: false),
      isFalse,
    );
  });

  test('no track change means no advance, so a pause does not shuffle the art',
      () {
    expect(
      shouldAdvanceArt(enabled: true, trackChanged: false, alreadyCycling: false),
      isFalse,
    );
  });

  test('it cannot re-enter itself', () {
    expect(
      shouldAdvanceArt(enabled: true, trackChanged: true, alreadyCycling: true),
      isFalse,
    );
  });

  test('the guards are independent — any one of them is enough to stop it', () {
    for (final enabled in [true, false]) {
      for (final changed in [true, false]) {
        for (final cycling in [true, false]) {
          final advance =
              shouldAdvanceArt(enabled: enabled, trackChanged: changed, alreadyCycling: cycling);
          expect(
            advance,
            enabled && changed && !cycling,
            reason: 'enabled=$enabled changed=$changed cycling=$cycling',
          );
        }
      }
    }
  });
}
