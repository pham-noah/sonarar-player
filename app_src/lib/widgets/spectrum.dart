library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/skin.dart';

class TrackSpectrum {
  const TrackSpectrum(this.frames, this.bands, this.framesPerSecond);

  final Uint8List frames;
  final int bands;
  final int framesPerSecond;

  int get frameCount => bands == 0 ? 0 : frames.length ~/ bands;

  bool get isEmpty => frameCount == 0;

  List<int> at(Duration position) {
    if (isEmpty) return const [];
    final frame = (position.inMilliseconds * framesPerSecond) ~/ 1000;
    if (frame < 0) return _row(0);
    if (frame >= frameCount) return _row(frameCount - 1);
    return _row(frame);
  }

  List<int> _row(int frame) {
    final base = frame * bands;
    return [for (var b = 0; b < bands; b++) frames[base + b]];
  }

  static TrackSpectrum parse(Uint8List bytes, {int bands = kSpectrumBands}) {
    if (bands <= 0) return TrackSpectrum(bytes, bands, kSpectrumFps);
    final usable = bytes.length - (bytes.length % bands);
    return TrackSpectrum(
      usable == bytes.length ? bytes : Uint8List.sublistView(bytes, 0, usable),
      bands,
      kSpectrumFps,
    );
  }

  static const int kSpectrumBands = 7;
  static const int kSpectrumFps = 20;
}

class SpectrumLibrary {
  SpectrumLibrary(this.libraryRoot);

  final String? libraryRoot;

  final _cache = <String, TrackSpectrum?>{};
  static const int _cacheLimit = 8;

  void forget(String trackId) => _cache.remove(trackId);

  Future<TrackSpectrum?> load(String trackId) async {
    if (_cache.containsKey(trackId)) return _cache[trackId];

    TrackSpectrum? result;
    final root = libraryRoot;
    if (root != null) {
      try {
        final file = File('$root/spectrum/$trackId.bin');
        if (file.existsSync()) {
          result = TrackSpectrum.parse(await file.readAsBytes());
        }
      } on FileSystemException {
        result = null;
      }
    }

    if (_cache.length >= _cacheLimit) _cache.remove(_cache.keys.first);
    _cache[trackId] = result;
    return result;
  }
}

enum SpectrumShape {
  rounded('ROUNDED'),

  square('SQUARE'),

  pill('PILL'),

  tapered('TAPERED'),

  notched('NOTCHED');

  const SpectrumShape(this.label);

  final String label;

  static SpectrumShape byName(String? raw) {
    for (final s in SpectrumShape.values) {
      if (s.name == raw) return s;
    }
    return SpectrumShape.rounded;
  }
}

class SpectrumBars extends StatefulWidget {
  const SpectrumBars({
    super.key,
    required this.skin,
    required this.spectrum,
    required this.position,
    required this.playing,

    this.ease = 0.35,
    this.shape = SpectrumShape.rounded,
    this.height,
  });

  final Skin skin;

  final TrackSpectrum? spectrum;
  final Duration position;
  final bool playing;

  final double ease;

  final SpectrumShape shape;
  final double? height;

  @override
  State<SpectrumBars> createState() => _SpectrumBarsState();
}

class _SpectrumBarsState extends State<SpectrumBars>
    with SingleTickerProviderStateMixin {
  final _clock = ValueNotifier<int>(0);

  late final Ticker _ticker;
  late final _BarsPainter _painter;

  bool get _shouldAnimate =>
      widget.playing &&
      widget.spectrum != null &&
      !(widget.spectrum?.isEmpty ?? true);

  void _syncTicker() {
    if (_shouldAnimate && !_ticker.isActive) {
      _ticker.start();
    } else if (!_shouldAnimate && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void didUpdateWidget(SpectrumBars old) {
    super.didUpdateWidget(old);
    _syncTicker();
  }

  @override
  void initState() {
    super.initState();
    _painter = _BarsPainter(
      _clock,
      skin: widget.skin,
      spectrum: widget.spectrum,
      position: widget.position,
      paused: !widget.playing,
      ease: widget.ease,
      shape: widget.shape,
    );

    _ticker = createTicker((_) => _clock.value++);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _painter
      ..skin = widget.skin
      ..spectrum = widget.spectrum
      ..position = widget.position
      ..paused = !widget.playing

      ..ease = widget.ease
      ..shape = widget.shape;

    if (!_shouldAnimate) _clock.value++;

    final s = widget.spectrum;
    if (s == null || s.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: SizedBox(
        height: widget.height,
        child: CustomPaint(painter: _painter),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(
    Listenable clock, {
    required this.skin,
    required this.spectrum,
    required this.position,
    required this.paused,
    this.ease = 0.35,
    this.shape = SpectrumShape.rounded,
  }) : super(repaint: clock);

  Skin skin;
  TrackSpectrum? spectrum;
  Duration position;
  bool paused;

  double ease;

  SpectrumShape shape = SpectrumShape.rounded;

  List<double> _shown = const [];

  List<double> _target() {
    final s = spectrum;
    if (s == null || s.isEmpty) return const [];
    final values = s.at(position);
    if (values.isEmpty) return const [];
    return [for (final v in values) v / 255.0];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final target = _target();
    if (target.isEmpty || size.height <= 0) return;

    if (_shown.length != target.length) {
      _shown = List<double>.from(target);
    } else {
      final ease = this.ease.clamp(0.0, 1.0);
      _shown = [
        for (var i = 0; i < target.length; i++)
          _shown[i] + (target[i] - _shown[i]) * ease,
      ];
    }

    final n = _shown.length;
    final slant = skin.skewDegrees * (3.141592653589793 / 180);
    canvas.save();
    canvas.transform(Matrix4.skewX(-slant).storage);

    final slot = size.width / n;
    final barW = slot * 0.62;

    final paint = Paint();
    if (paused) {
      paint.color = skin.accentAt(0.45);
    }

    for (var i = 0; i < n; i++) {
      final v = _shown[i].clamp(0.0, 1.0);

      final h = (size.height * (0.06 + 0.94 * v)).clamp(1.0, size.height);
      final x = i * slot + (slot - barW) / 2;
      final rect = Rect.fromLTWH(x, size.height - h, barW, h);

      if (!paused) {
        paint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skin.accent, skin.accentDeep],
        ).createShader(rect);
      }

      switch (shape) {
        case SpectrumShape.rounded:
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(barW * 0.25)),
            paint,
          );
        case SpectrumShape.square:
          canvas.drawRect(rect, paint);
        case SpectrumShape.pill:

          canvas.drawRRect(
            RRect.fromRectAndRadius(
              rect,
              Radius.circular((barW / 2).clamp(0.0, h / 2)),
            ),
            paint,
          );
        case SpectrumShape.tapered:

          final inset = barW * 0.125;
          canvas.drawPath(
            Path()
              ..moveTo(rect.left, rect.bottom)
              ..lineTo(rect.right, rect.bottom)
              ..lineTo(rect.right - inset, rect.top)
              ..lineTo(rect.left + inset, rect.top)
              ..close(),
            paint,
          );
        case SpectrumShape.notched:

          final notch = barW * 0.24;
          if (h > notch * 2) {
            canvas.drawPath(
              Path()
                ..moveTo(rect.left, rect.bottom)
                ..lineTo(rect.right, rect.bottom)
                ..lineTo(rect.right, rect.top + notch)
                ..lineTo(rect.right - notch, rect.top + notch)
                ..lineTo(rect.right - notch, rect.top)
                ..lineTo(rect.left + notch, rect.top)
                ..lineTo(rect.left + notch, rect.top + notch)
                ..lineTo(rect.left, rect.top + notch)
                ..close(),
              paint,
            );
          } else {
            canvas.drawRect(rect, paint);
          }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BarsPainter old) => false;
}
