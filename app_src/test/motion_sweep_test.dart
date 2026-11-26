library;

// The app answers "how long is this?" in one place: `Motion.of(context, token)`.
// That claim was true of the animated call sites a screenshot can see and false
// of four others — the cover's 620ms slide-in, the panel's 180ms open, the row
// highlight's 120ms fade and the lyrics' 420ms glide — and of `SwapSlide`'s
// stagger, which held the row blank for 60ms before swapping it with a
// zero-duration animation. A user who asks the system to stop moving got all
// five.
//
// This scans the source so the claim stays true: every numeric duration in
// `lib/` must ask `Motion`, live in `theme/motion.dart` (the tokens), or be
// listed below with the reason it is not motion. A timer is not motion, an
// audio fade is not motion, and how long a toast stays up is not motion. A
// stale entry fails too, so dead reasons cannot accumulate.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/widgets/transport_motion.dart';

/// Durations that are time rather than motion, each with the reason. Keyed by
/// the exact source line (trimmed) so a rewrite that removes one has to remove
/// its entry.
const _notMotion = <String, String>{
  'await Future<void>.delayed(const Duration(milliseconds: 900));':
      'A settle before the splash is dismissed. Nothing moves.',
  '_saveDebounce = Timer(const Duration(milliseconds: 400), _flushState);':
      'Debounce: how long until a write happens, not how long it takes.',
  'const Duration kDefaultCrossfade = Duration(milliseconds: 0);':
      'The default audio crossfade. Sound, not pixels.',
  '_poll = Timer.periodic(const Duration(milliseconds: 350), (_) async {':
      'How often a download is asked for its progress.',
  'poller = Timer.periodic(const Duration(milliseconds: 350), (_) async {':
      'How often an import is asked for its progress.',
  '_repaint = Timer.periodic(const Duration(milliseconds: 500), (_) {':
      'How often the FPS overlay redraws its number.',
  'await _fadeTo(0, const Duration(milliseconds: 140));':
      'An audio volume ramp. Silencing it would click.',
  'await _fadeTo(_targetVolume, const Duration(milliseconds: 200));':
      'An audio volume ramp, on resume and on pause.',
  'const Duration kPlaybackTick = Duration(milliseconds: 250);':
      'How often the position is read. Not drawn on its own.',
  'static const Duration _typingPause = Duration(milliseconds: 120);':
      'A typing debounce before a search runs.',
  'this.settle = const Duration(milliseconds: 400),':
      'How long presets wait before they are written.',
  'duration: const Duration(milliseconds: 1400),':
      "How long a toast stays up once it is there.",
  // Passed to SwapSlide, which is what asks Motion for it — the value here is
  // the intended stagger, honoured or dropped at the widget.
  'stagger: const Duration(milliseconds: 60),':
      'SwapSlide applies Motion to it; the literal is the wanted stagger.',
};

final _duration = RegExp(r'Duration\(milliseconds:\s*\d+\)');

List<String> _offenders() {
  final root = Directory('lib');
  final found = <String>[];
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final rel = entity.path.replaceAll(r'\', '/');
    if (rel.endsWith('theme/motion.dart')) continue;
    for (final line in entity.readAsLinesSync()) {
      if (!_duration.hasMatch(line)) continue;
      if (line.contains('Motion.')) continue;
      final trimmed = line.trim();
      if (_notMotion.containsKey(trimmed)) continue;
      found.add('$rel: $trimmed');
    }
  }
  return found;
}

void main() {
  test('every duration in lib/ asks Motion or says why it is not motion', () {
    final offenders = _offenders();
    expect(
      offenders,
      isEmpty,
      reason: 'These durations decide how long something moves without asking '
          'Motion, so they all still run for a user who turned motion off:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the exceptions list has no entries for code that is gone', () {
    final source = <String>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        source.addAll(entity.readAsLinesSync().map((l) => l.trim()));
      }
    }
    final stale = _notMotion.keys.where((k) => !source.contains(k)).toList();
    expect(stale, isEmpty,
        reason: 'These lines were removed, so their reasons describe code that '
            'no longer exists: $stale');
  });

  testWidgets('with motion off a swap does not hold the row blank',
      (tester) async {
    // The MediaQuery must sit inside MaterialApp: the app inserts its own from
    // the view and would throw this one away with it.
    Widget wrap(String key, {required bool still}) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: still),
            child: Material(
              child: SwapSlide(
                keyValue: key,
                stagger: const Duration(milliseconds: 60),
                child: Text(key),
              ),
            ),
          ),
        );

    await tester.pumpWidget(wrap('a', still: true));
    await tester.pump();
    await tester.pumpWidget(wrap('b', still: true));
    await tester.pump();
    // A zero timer is flushed by the next frame's tick, not by the build, so
    // one 16ms frame is the honest "same frame" allowance.
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
        Offset.zero,
        reason: 'SwapSlide answered Motion for the slide but not for its own '
            'stagger, so under Reduce Motion the row goes blank for 60ms and '
            'then snaps back.');

    // The other end: with motion wanted, the same 16ms is still inside the
    // 60ms stagger, so the row is held — which is what makes the assertion
    // above a measurement of the stagger rather than of a widget that never
    // moves at all.
    await tester.pumpWidget(wrap('c', still: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
        isNot(Offset.zero),
        reason: 'A swap that is already at rest 16ms in holds no stagger, so '
            'the zero-offset assertion above would pass for the wrong reason.');
  });
}
