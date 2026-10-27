library;

const double kMinArtZoom = 1.0;
const double kMaxArtZoom = 3.0;

class ArtFocus {
  const ArtFocus({this.dx = 0.0, this.dy = 0.0, this.zoom = 1.0});

  static const ArtFocus centre = ArtFocus();

  final double dx;
  final double dy;
  final double zoom;

  ArtFocus clamped() => ArtFocus(
        dx: dx.clamp(-1.0, 1.0),
        dy: dy.clamp(-1.0, 1.0),
        zoom: zoom.clamp(kMinArtZoom, kMaxArtZoom),
      );

  ArtFocus copyWith({double? dx, double? dy, double? zoom}) => ArtFocus(
        dx: dx ?? this.dx,
        dy: dy ?? this.dy,
        zoom: zoom ?? this.zoom,
      ).clamped();

  bool get isCentre => dx == 0.0 && dy == 0.0 && zoom == kMinArtZoom;

  Map<String, dynamic> toJson() => {'dx': dx, 'dy': dy, 'zoom': zoom};

  static ArtFocus? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final dx = raw['dx'];
    final dy = raw['dy'];
    final zoom = raw['zoom'];
    if (dx is! num || dy is! num || zoom is! num) return null;

    for (final v in [dx, dy, zoom]) {
      if (!v.toDouble().isFinite) return null;
    }
    return ArtFocus(
      dx: dx.toDouble(),
      dy: dy.toDouble(),
      zoom: zoom.toDouble(),
    ).clamped();
  }

  @override
  bool operator ==(Object other) =>
      other is ArtFocus &&
      other.dx == dx &&
      other.dy == dy &&
      other.zoom == zoom;

  @override
  int get hashCode => Object.hash(dx, dy, zoom);

  @override
  String toString() =>
      'ArtFocus(${dx.toStringAsFixed(2)}, ${dy.toStringAsFixed(2)}'
      ' x${zoom.toStringAsFixed(2)})';
}

class ArtFrame {
  const ArtFrame(this.scale, this.offsetX, this.offsetY);

  final double scale;

  final double offsetX;
  final double offsetY;

  @override
  String toString() => 'ArtFrame(x$scale, ${offsetX.toStringAsFixed(1)}, '
      '${offsetY.toStringAsFixed(1)})';
}

ArtFrame frameFor({
  required double srcW,
  required double srcH,
  required double slotW,
  required double slotH,
  required ArtFocus focus,
}) {
  if (srcW <= 0 || srcH <= 0 || slotW <= 0 || slotH <= 0) {
    return const ArtFrame(1.0, 0.0, 0.0);
  }

  final f = focus.clamped();

  final coverScale = _max(slotW / srcW, slotH / srcH);
  final scale = coverScale * f.zoom;

  final scaledW = srcW * scale;
  final scaledH = srcH * scale;

  final roomX = (scaledW - slotW) / 2;
  final roomY = (scaledH - slotH) / 2;

  final wantX = -(f.dx / 2) * scaledW;
  final wantY = -(f.dy / 2) * scaledH;

  return ArtFrame(
    scale,
    _clamp(wantX, -roomX, roomX),
    _clamp(wantY, -roomY, roomY),
  );
}

({double x, double y}) reachFor({
  required double srcW,
  required double srcH,
  required double slotW,
  required double slotH,
  required double zoom,
}) {
  if (srcW <= 0 || srcH <= 0 || slotW <= 0 || slotH <= 0) {
    return (x: 0.0, y: 0.0);
  }
  final z = zoom.clamp(kMinArtZoom, kMaxArtZoom);
  final coverScale = _max(slotW / srcW, slotH / srcH);
  final scale = coverScale * z;
  final scaledW = srcW * scale;
  final scaledH = srcH * scale;

  return (
    x: scaledW <= 0 ? 0.0 : _clamp(2 * ((scaledW - slotW) / 2) / scaledW, 0.0, 1.0),
    y: scaledH <= 0 ? 0.0 : _clamp(2 * ((scaledH - slotH) / 2) / scaledH, 0.0, 1.0),
  );
}

double _max(double a, double b) => a > b ? a : b;
double _clamp(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
