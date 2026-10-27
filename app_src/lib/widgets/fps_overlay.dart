library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/skin.dart';

class FpsOverlay extends StatefulWidget {
  const FpsOverlay({super.key, required this.skin});

  final Skin skin;

  @override
  State<FpsOverlay> createState() => _FpsOverlayState();
}

class _FpsOverlayState extends State<FpsOverlay> {
  static const Duration _window = Duration(seconds: 2);

  final Queue<(DateTime, Duration)> _frames = Queue();
  int _dropped = 0;
  DateTime? _last;

  late final Ticker _ticker;
  Timer? _repaint;

  @override
  void initState() {
    super.initState();

    _ticker = Ticker(_onFrame)..start();

    _repaint = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onFrame(Duration elapsed) {
    final now = DateTime.now();
    if (_last != null) {
      final delta = now.difference(_last!);

      if (delta.inMilliseconds > 33) _dropped++;
      _frames.add((now, delta));
    }
    _last = now;

    while (_frames.isNotEmpty && now.difference(_frames.first.$1) > _window) {
      _frames.removeFirst();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint?.cancel();
    super.dispose();
  }

  ({double fps, double worstMs, int dropped}) _read() {
    if (_frames.isEmpty) return (fps: 0, worstMs: 0, dropped: 0);
    var totalUs = 0;
    var worstMs = 0.0;
    for (final f in _frames) {
      totalUs += f.$2.inMicroseconds;
      final ms = f.$2.inMicroseconds / 1000.0;
      if (ms > worstMs) worstMs = ms;
    }
    final avgUs = totalUs / _frames.length;
    return (
      fps: avgUs == 0 ? 0 : 1000000 / avgUs,
      worstMs: worstMs,
      dropped: _dropped,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _read();
    final bad = r.worstMs > 40;
    final warn = r.worstMs > 22;
    final colour = bad ? const Color(0xFFFF5252) : (warn ? const Color(0xFFFFC107) : widget.skin.accent);

    return IgnorePointer(
      child: Container(
        key: const Key('fps-overlay'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          border: Border.all(color: colour, width: 1.5),
        ),
        child: Text(
          '${r.fps.toStringAsFixed(0)} fps  ·  worst ${r.worstMs.toStringAsFixed(0)}ms  ·  ${r.dropped} dropped',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: colour,

            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
