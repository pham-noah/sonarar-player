library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'personalization.dart';
import 'skin.dart';

/// Where a backdrop's file actually lives. The spec stores only the file name,
/// so a library folder that moves — to a new phone, to a different mount — keeps
/// resolving without a rewrite.
File? backdropFile(Directory? root, BackdropSpec spec) {
  if (root == null || !spec.isSet) return null;
  final f = File('${root.path}${Platform.pathSeparator}backgrounds${Platform.pathSeparator}${spec.file}');
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
  });

  final Directory? root;
  final BackdropSpec spec;
  final Skin skin;

  /// A rectangle rotated by theta must grow by this much to still cover it.
  static double rotationPadding(double degrees) {
    final rad = degrees.abs() * 3.141592653589793 / 180;
    final s = 1.0 + (rad % 1.5707963267948966) / 1.5707963267948966; // 1..2
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final file = backdropFile(root, spec);
    if (file == null) return const SizedBox.shrink();

    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1;
    final width = MediaQuery.maybeOf(context)?.size.width ?? 1080;
    final cacheWidth = (width * dpr).round().clamp(360, 2160);

    Widget photo = Image.file(
      file,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      alignment: Alignment(spec.focusX * 2 - 1, spec.focusY * 2 - 1),
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );

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

    final pad = rotationPadding(spec.rotationDeg) * spec.scale;

    return ClipRect(
      child: Transform.rotate(
        angle: spec.rotationDeg * 3.141592653589793 / 180,
        child: Transform.scale(
          scale: pad,
          child: Stack(
            fit: StackFit.expand,
            children: [
              photo,
              if (spec.dim > 0)
                ColoredBox(color: Colors.black.withValues(alpha: spec.dim * 0.85)),
              if (spec.tint)
                ColoredBox(color: skin.accent.withValues(alpha: 0.10)),
            ],
          ),
        ),
      ),
    );
  }
}
