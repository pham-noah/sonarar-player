library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/bootstrapper.dart';

/// The boot sequence, driven by hand.
///
/// The order of these steps is the contract: prefs before layout, layout before the
/// first frame. `_load()` could only prove that by printing as it went, so a boot that
/// ran the steps in another order looked exactly like one that did not.
void main() {
  group('the phases run in the order they are given', () {
    test('each one is noted as it starts, not when it ends', () async {
      final order = <String>[];
      final boot = Bootstrapper(onPhase: (_) {});

      await boot.run([
        (b) async {
          b.note(0.02, 'checking permissions');
          order.add('permissions work');
          return true;
        },
        (b) async {
          b.note(0.18, 'reading your library');
          order.add('library work');
          return true;
        },
      ]);

      expect(order, ['permissions work', 'library work']);
      expect(boot.labels, ['checking permissions', 'reading your library']);
    });

    test('a phase that reports a sub-step keeps it between its neighbours',
        () async {
      final boot = Bootstrapper(onPhase: (_) {});
      final seen = <String>[];
      await boot.run([
        (b) async {
          b.note(0.18, 'reading your library');
          seen.add(b.labels.last);
          b.note(0.52, 'found 3 tracks');
          seen.add(b.labels.last);
          return true;
        },
        (b) async {
          b.note(0.60, 'opening your saved state');
          seen.add(b.labels.last);
          return true;
        },
      ]);

      expect(seen, [
        'reading your library',
        'found 3 tracks',
        'opening your saved state',
      ]);
      expect(boot.labels.indexOf('found 3 tracks'), 1,
          reason: 'a sub-step is timed like a phase, where it happened');
    });
  });

  group('stopping', () {
    test('a step that says no ends the sequence', () async {
      final boot = Bootstrapper(onPhase: (_) {});
      var later = false;

      await boot.run([
        (b) async {
          b.note(0.02, 'checking permissions');
          return true;
        },
        (b) async {
          b.note(0.18, 'reading your library');
          return false;
        },
        (b) async {
          later = true;
          return true;
        },
      ]);

      expect(later, isFalse, reason: 'nothing runs after a stop');
      expect(boot.stopped, isTrue);
      expect(boot.labels, ['checking permissions', 'reading your library'],
          reason: 'the log ends where the work ended');
    });

    test('a re-run starts from a clean stop flag', () async {
      final boot = Bootstrapper(onPhase: (_) {});
      await boot.run([(b) async => false]);
      expect(boot.stopped, isTrue);

      await boot.run([(b) async => true]);

      expect(boot.stopped, isFalse);
    });
  });

  group('the timing the log prints', () {
    test('is recorded per label, and the last phase is in it', () async {
      final boot = Bootstrapper(onPhase: (_) {});

      await boot.run([
        (b) async {
          b.note(0.02, 'checking permissions');
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return true;
        },
        (b) async {
          b.note(1.0, 'ready');
          return true;
        },
      ]);

      expect(boot.costs.keys, contains('ready'),
          reason: '"ready" is timed against restoring your place');
      expect(boot.costs['ready'], greaterThanOrEqualTo(10));
    });

    test('the shell is repainted at every boundary', () async {
      final repaints = <double>[];
      final boot = Bootstrapper(onPhase: repaints.add);

      await boot.run([
        (b) async {
          b.note(0.02, 'checking permissions');
          return true;
        },
        (b) async {
          b.note(0.18, 'reading your library');
          b.note(0.52, 'found 3 tracks');
          return true;
        },
        (b) async {
          b.note(1.0, 'ready');
          return true;
        },
      ]);

      expect(repaints, [0.02, 0.18, 0.52, 1.0]);
    });
  });
}
