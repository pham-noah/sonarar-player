library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// How one picture is placed inside its frame.
///
/// This belongs to the picture, not to the app: it is written next to the image
/// as `spec.json`, so art you move to another machine arrives looking the same.
class ArtSpec {
  const ArtSpec({
    this.dx = 0,
    this.dy = 0,
    this.zoom = 1,
    this.rotationDeg = 0,
    this.flipX = false,
    this.fade = 0,
  });

  /// Slide the picture, in fractions of the frame's width and height.
  final double dx;
  final double dy;

  /// 1 fits the frame; above 1 crops in.
  final double zoom;

  final double rotationDeg;
  final bool flipX;

  /// How much the picture dissolves into the room at its edges, 0..1.
  final double fade;

  static const none = ArtSpec();

  bool get isDefault =>
      dx == 0 &&
      dy == 0 &&
      zoom == 1 &&
      rotationDeg == 0 &&
      !flipX &&
      fade == 0;

  static const minZoom = 1.0;
  static const maxZoom = 3.0;
  static const maxRotation = 15.0;

  /// Everything is clamped on the way in: a spec from another version, or a
  /// stray drag, must not be able to turn the art into a blank rectangle.
  ArtSpec copyWith({
    double? dx,
    double? dy,
    double? zoom,
    double? rotationDeg,
    bool? flipX,
    double? fade,
  }) => ArtSpec(
    dx: (dx ?? this.dx).clamp(-1.0, 1.0),
    dy: (dy ?? this.dy).clamp(-1.0, 1.0),
    zoom: (zoom ?? this.zoom).clamp(minZoom, maxZoom),
    rotationDeg: (rotationDeg ?? this.rotationDeg).clamp(
      -maxRotation,
      maxRotation,
    ),
    flipX: flipX ?? this.flipX,
    fade: (fade ?? this.fade).clamp(0.0, 1.0),
  );

  Map<String, Object?> toJson() => {
    'dx': _round(dx),
    'dy': _round(dy),
    'zoom': _round(zoom),
    'rotationDeg': _round(rotationDeg),
    if (flipX) 'flipX': true,
    if (fade > 0) 'fade': _round(fade),
  };

  static ArtSpec fromJson(Object? raw) {
    if (raw is! Map) return none;
    double value(Object? v, double fallback) =>
        v is num ? v.toDouble() : fallback;
    return const ArtSpec().copyWith(
      dx: value(raw['dx'], 0),
      dy: value(raw['dy'], 0),
      zoom: value(raw['zoom'], 1),
      rotationDeg: value(raw['rotationDeg'], 0),
      flipX: raw['flipX'] == true,
      fade: value(raw['fade'], 0),
    );
  }

  /// The transform that places the picture inside a frame of [size].
  ///
  /// One place computes this so the editor's preview and the real player cannot
  /// disagree about what the numbers mean.
  ({double tx, double ty, double scale, double angle}) place(
    double width,
    double height,
  ) => (
    tx: dx * width * 0.5,
    ty: dy * height * 0.5,
    scale: zoom,
    angle: rotationDeg * math.pi / 180,
  );

  static double _round(double v) => (v * 1000).roundToDouble() / 1000;

  static File fileFor(Directory bundle) => File('${bundle.path}/spec.json');

  /// Reads a bundle's spec; a missing or broken file is simply "untouched art".
  static ArtSpec read(Directory bundle) {
    try {
      final file = fileFor(bundle);
      if (!file.existsSync()) return none;
      return fromJson(jsonDecode(file.readAsStringSync()));
    } catch (_) {
      return none;
    }
  }

  static void write(Directory bundle, ArtSpec spec) {
    final file = fileFor(bundle);
    if (spec.isDefault) {
      if (file.existsSync()) file.deleteSync();
      return;
    }
    file.writeAsStringSync(jsonEncode(spec.toJson()));
  }
}
