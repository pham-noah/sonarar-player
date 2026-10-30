library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../art/skin_art.dart';
import 'personalization.dart';
import 'skin.dart';

/// Where a backdrop's file actually lives. The spec stores only the file name,
/// so a library folder that moves — to a new phone, to a different mount — keeps
/// resolving without a rewrite.
File? backdropFile(Directory? root, BackdropSpec spec) {
  if (root == null || !spec.isSet) return null;
  final f = File(
    '${root.path}${Platform.pathSeparator}backgrounds${Platform.pathSeparator}${spec.file}',
  );
  return f.existsSync() ? f : null;
}

/// The photo layer.
///
/// Sits UNDER everything the skin paints, so it never competes with the palette:
/// the focus point is carried by [BoxFit.cover]'s alignment, zoom and rotation
/// ride on top of that, and the scrim is black rather than a skin colour so a
/// warm photo cannot wash a cool skin off its own background.
///
/// Blur is [ImageFiltered] rather than a `BackdropFilter`: the latter samples
/// whatever is beneath it every frame, which is exactly what a background
/// behind a scrolling list must not do.
class PersonalBackdrop extends StatelessWidget {
  const PersonalBackdrop({
    super.key,
    required this.root,
    required this.spec,
    required this.skin,
    this.art,
  });

  final Directory? root;
  final BackdropSpec spec;
  final Skin skin;

  /// The art bundle piece, when the picture comes from art rather than a photo.
  /// Merge: an art folder is just another way to fill this same layer, so it
  /// inherits every control a photo has — including the ones art never had.
  final SkinArt? art;

  /// A rectangle rotated by theta must grow by this much to still cover it.
  static double rotationPadding(double degrees) {
    final rad = degrees.abs() * 3.141592653589793 / 180;
    final s = 1.0 + (rad % 1.5707963267948966) / 1.5707963267948966; // 1..2
    return s;
  }

  /// The one place a picture is framed.
  ///
  /// The editor and the app both call this, so what you drag is what you get.
  /// Offset runs against the focus, which is what makes the picture follow the
  /// finger instead of fighting it.
  static Widget frame({
    required Widget child,
    required Size size,
    required double scale,
    required double rotationDeg,
    required double focusX,
    required double focusY,
  }) {
    // A picture at 1x still needs room to move, or dragging does nothing until
    // you zoom. The overscan is the room, so it is part of the scale itself.
    final pad = (rotationPadding(rotationDeg) * scale * 1.25).clamp(1.0, 12.0);
    final slackX = (size.width * pad - size.width) / 2;
    final slackY = (size.height * pad - size.height) / 2;
    return Transform.rotate(
      angle: rotationDeg * 3.141592653589793 / 180,
      child: Transform.translate(
        offset: Offset(-(focusX * 2 - 1) * slackX, -(focusY * 2 - 1) * slackY),
        child: Transform.scale(scale: pad, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = backdropFile(root, spec);
    final picture = art;
    if (file == null && picture == null) return const SizedBox.shrink();

    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1;
    final width = MediaQuery.maybeOf(context)?.size.width ?? 1080;
    final cacheWidth = (width * dpr).round().clamp(360, 2160);
    // Cover centres the picture; the focus is carried by the frame's offset
    // alone. Applying it here as well shifted the picture twice, which is why
    // the app never matched the editor.
    const alignment = Alignment.center;

    Widget photo;
    if (picture != null) {
      final path = picture.assetPath;
      photo = path.startsWith('file:')
          ? Image.file(
              File(path.substring(5)),
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              alignment: alignment,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            )
          : Image.asset(
              path,
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              alignment: alignment,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            );
    } else {
      photo = Image.file(
        file!,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        alignment: alignment,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    if (spec.blur > 0) {
      photo = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: spec.blur,
          sigmaY: spec.blur,
          tileMode: ui.TileMode.decal,
        ),
        child: photo,
      );
    }

    if (spec.saturation != 1 || spec.contrast != 1) {
      photo = ColorFiltered(
        colorFilter: ColorFilter.matrix(_grade(spec.saturation, spec.contrast)),
        child: photo,
      );
    }

    // Focus only means something if it is applied here, not just in the editor.
    // The room to move is whatever the zoom has overflowed the frame by.
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, box) {
          return frame(
            size: Size(box.maxWidth, box.maxHeight),
            scale: spec.scale,
            rotationDeg: spec.rotationDeg,
            focusX: spec.focusX,
            focusY: spec.focusY,
            child: Stack(
              fit: StackFit.expand,
              children: [
                photo,
                if (spec.grain > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _GrainPainter(spec.grain)),
                    ),
                  ),
                if (spec.vignette > 0)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          radius: 0.95,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(
                              alpha: spec.vignette * 0.85,
                            ),
                          ],
                          stops: const [0.55, 1],
                        ),
                      ),
                    ),
                  ),
                if (spec.dim > 0)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: spec.dim * 0.85),
                  ),
                if (spec.tint)
                  ColoredBox(color: skin.accent.withValues(alpha: 0.10)),
                if (spec.burn > 0)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            skin.background.withValues(alpha: spec.burn * 0.9),
                          ],
                          stops: const [0.45, 1],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Saturation and contrast in one 5x4 matrix. Both are 1 by default, and the
  /// matrix is skipped entirely at 1/1 — a filter over a full-screen image is
  /// not free on a phone.
  static List<double> _grade(double saturation, double contrast) {
    const lumR = 0.2126, lumG = 0.7152, lumB = 0.0722;
    final s = saturation;
    final c = contrast;
    final r = (1 - s) * lumR;
    final g = (1 - s) * lumG;
    final b = (1 - s) * lumB;
    return [
      (r + s) * c,
      g * c,
      b * c,
      0,
      (1 - c) * 128,
      r * c,
      (g + s) * c,
      b * c,
      0,
      (1 - c) * 128,
      r * c,
      g * c,
      (b + s) * c,
      0,
      (1 - c) * 128,
      0,
      0,
      0,
      1,
      0,
    ];
  }
}

/// Grain that does not shimmer: a fixed seed per size, so the same pixels are
/// drawn every frame and the background stays still.
class _GrainPainter extends CustomPainter {
  const _GrainPainter(this.strength);

  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint();
    final count = (size.width * size.height / 900).clamp(400, 5000).round();
    for (var i = 0; i < count; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final v = rnd.nextDouble();
      paint.color = (v > 0.5 ? Colors.white : Colors.black).withValues(
        alpha: strength * 0.10 * v,
      );
      canvas.drawRect(Rect.fromLTWH(dx, dy, 1.2, 1.2), paint);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.strength != strength;
}
