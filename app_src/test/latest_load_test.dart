@Tags(['slow'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/core/latest_load.dart';
import 'package:sonarar/theme/skin.dart';

void main() {
  test('a result for the CURRENT key is accepted', () {
    final load = LatestLoad<String>();
    load.start('a');
    expect(load.isLatest('a'), isTrue);
  });

  test('a result for a key that was superseded is REJECTED', () {
    final load = LatestLoad<String>();
    load.start('a');
    load.start('b');
    expect(load.isLatest('a'), isFalse, reason: 'a stale result would have been published');
    expect(load.isLatest('b'), isTrue);
  });

  test('starting the same key twice is not a change', () {
    final load = LatestLoad<String>();
    load.start('a');
    load.start('a');
    expect(load.isLatest('a'), isTrue);
  });

  test('nothing in flight means nothing is latest', () {
    final load = LatestLoad<String>();
    expect(load.inFlight, isFalse);
    expect(load.isLatest('a'), isFalse);
  });

  test('after clear, a matching key cannot pass by accident', () {
    final load = LatestLoad<String>();
    load.start('a');
    load.clear();
    expect(load.isLatest('a'), isFalse);
    expect(load.inFlight, isFalse);
  });

  test('it works for a null key without special-casing', () {
    final load = LatestLoad<String?>();
    load.start(null);
    expect(load.isLatest(null), isTrue);
    load.start('a');
    expect(load.isLatest(null), isFalse);
  });

  group('the skin notifier the shell watches', () {
    testWidgets('it fires on a skin change and the theme follows', (tester) async {
      final state = AppState();
      var fired = 0;
      state.skinListenable.addListener(() => fired++);

      expect(state.skinListenable.value.id, state.skin.id,
          reason: 'the notifier and the getter disagree from the start');

      state.chooseSkinManually(SkinId.crimson);
      expect(state.skin.id, SkinId.crimson, reason: 'the skin did not change');
      expect(fired, 1, reason: 'the notifier did not fire once for one change');
      expect(state.skinListenable.value.id, SkinId.crimson,
          reason: 'the notifier is stale, so the shell would keep the old theme');

      state.chooseSkinManually(SkinId.crimson);
      expect(fired, 1, reason: 'setting the same skin notified anyway');
    });
  });
}
