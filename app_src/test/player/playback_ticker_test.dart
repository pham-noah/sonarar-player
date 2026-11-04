library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/player/playback_ticker.dart';

/// A timer that only runs when a test says so.
class _FakeTimer implements Timer {
  _FakeTimer(this._onFire);

  final void Function(Timer) _onFire;
  bool _active = true;
  int fired = 0;

  void fire() {
    if (!_active) return;
    fired++;
    _onFire(this);
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => fired;
}

class _Harness {
  final List<_FakeTimer> timers = [];
  int created = 0;
  int ticks = 0;

  PeriodicTimerFactory get factory => (interval, callback) {
        created++;
        final t = _FakeTimer(callback);
        timers.add(t);
        return t;
      };

  PlaybackTicker build({Duration interval = kPlaybackTick}) => PlaybackTicker(
        () => ticks++,
        interval: interval,
        timerFactory: factory,
      );
}

void main() {
  group('the playback ticker', () {
    test('starts only when asked, and calls back per tick', () {
      final h = _Harness();
      final ticker = h.build();

      expect(ticker.isRunning, isFalse);
      expect(h.created, 0);

      ticker.sync(run: true);

      expect(ticker.isRunning, isTrue);
      expect(h.created, 1);
      h.timers.single.fire();
      h.timers.single.fire();
      expect(h.ticks, 2);
    });

    test('asking twice does not start a second timer', () {
      final h = _Harness();
      final ticker = h.build();

      ticker.sync(run: true);
      ticker.sync(run: true);
      ticker.sync(run: true);

      expect(h.created, 1, reason: 'a state change per frame must not restart the clock');
      expect(h.timers.single.isActive, isTrue);
    });

    test('stopping cancels the timer and a stopped timer does not tick', () {
      final h = _Harness();
      final ticker = h.build();

      ticker.sync(run: true);
      ticker.sync(run: false);

      expect(ticker.isRunning, isFalse);
      expect(h.timers.single.isActive, isFalse);
      h.timers.single.fire();
      expect(h.ticks, 0, reason: 'a cancelled timer is not heard from again');
    });

    test('stopping when it never started is harmless', () {
      final h = _Harness();
      final ticker = h.build();

      ticker.sync(run: false);

      expect(ticker.isRunning, isFalse);
      expect(h.created, 0);
    });

    test('it can be stopped and started again', () {
      final h = _Harness();
      final ticker = h.build();

      ticker.sync(run: true);
      ticker.sync(run: false);
      ticker.sync(run: true);

      expect(h.created, 2);
      expect(ticker.isRunning, isTrue);
      h.timers.last.fire();
      expect(h.ticks, 1);
    });

    test('restart replaces a live timer without changing whether it runs', () {
      final h = _Harness();
      final ticker = h.build();

      ticker.sync(run: true);
      ticker.restart();

      expect(h.created, 2);
      expect(ticker.isRunning, isTrue);
      expect(h.timers.first.isActive, isFalse);
      expect(h.timers.last.isActive, isTrue);
    });

    test('restart on a stopped ticker leaves it stopped', () {
      final h = _Harness();
      final ticker = h.build();

      ticker.restart();

      expect(ticker.isRunning, isFalse);
      expect(h.created, 0);
    });

    test('the wanted flag follows the last answer', () {
      final h = _Harness();
      final ticker = h.build();

      ticker.sync(run: true);
      expect(ticker.wanted.value, isTrue);
      ticker.sync(run: false);
      expect(ticker.wanted.value, isFalse);
    });

    test('a tick may stop the clock from inside itself', () {
      final h = _Harness();
      late PlaybackTicker ticker;
      var ticks = 0;
      ticker = PlaybackTicker(
        () {
          ticks++;
          ticker.sync(run: false);
        },
        timerFactory: h.factory,
      );

      ticker.sync(run: true);
      h.timers.single.fire();

      expect(ticks, 1);
      expect(ticker.isRunning, isFalse, reason: 'the sleep timer stops playback mid-tick');
    });

    test('dispose cancels the timer', () {
      final h = _Harness();
      final ticker = h.build();

      ticker.sync(run: true);
      ticker.dispose();

      expect(h.timers.single.isActive, isFalse);
      expect(ticker.isRunning, isFalse);
    });

    test('the default interval is a quarter second', () {
      expect(kPlaybackTick, const Duration(milliseconds: 250));
    });
  });
}
