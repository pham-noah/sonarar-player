import 'dart:io';

import 'package:flutter/material.dart';

import '../widgets/kit.dart';
import '../theme/backdrop_layer.dart';
import '../theme/personalization.dart';
import '../theme/skin.dart';

/// Drag the picture to frame it.
class ReframeScreen extends StatefulWidget {
  const ReframeScreen({
    super.key,
    required this.skin,
    required this.file,
    required this.initial,
  });

  final Skin skin;
  final File file;
  final BackdropSpec initial;

  @override
  State<ReframeScreen> createState() => _ReframeScreenState();
}

class _ReframeScreenState extends State<ReframeScreen> {
  late BackdropSpec _spec = widget.initial;

  void _pan(Offset delta, Size size) {
    setState(() {
      _spec = _spec.copyWith(
        focusX: (_spec.focusX - delta.dx / size.width).clamp(0.0, 1.0),
        focusY: (_spec.focusY - delta.dy / size.height).clamp(0.0, 1.0),
      );
    });
  }

  /// Whether the picture in the editor differs from the one it opened with, so
  /// RESET can read as available only when there is something to reset.
  bool get _changed {
    final a = _spec.toJson();
    final b = widget.initial.toJson();
    for (final key in a.keys) {
      if (a[key].toString() != b[key].toString()) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    'REFRAME',
                    style: TextStyle(
                      color: skin.textPrimary,
                      fontSize: LayoutSpec.fontFloor + 2,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  // Undo the drag as easily as making it: the picture you
                  // started with is one tap away, not a careful reverse drag.
                  TextButton(
                    key: const Key('reframe-reset'),
                    onPressed: _changed
                        ? () => setState(() => _spec = widget.initial)
                        : null,
                    child: Text(
                      'RESET',
                      style: TextStyle(
                        color: _changed
                            ? skin.textSecondary
                            : skin.textSecondary.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'CANCEL',
                      style: TextStyle(color: skin.textSecondary),
                    ),
                  ),
                  TextButton(
                    key: const Key('reframe-done'),
                    onPressed: () => Navigator.of(context).pop(_spec),
                    child: Text(
                      'DONE',
                      style: TextStyle(
                        color: skin.accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  // The canvas is the shape of the screen it will fill. Any other
                  // shape crops the picture differently, so the preview and the app
                  // would disagree no matter how the maths lined up.
                  final screen = MediaQuery.sizeOf(context);
                  final aspect = screen.width / screen.height;
                  final size = box.maxWidth / box.maxHeight > aspect
                      ? Size(box.maxHeight * aspect, box.maxHeight)
                      : Size(box.maxWidth, box.maxWidth / aspect);
                  // A short box (landscape) can leave nothing to drag on, and a
                  // zero width divides the drag into infinity.
                  if (size.width < 1 || size.height < 1) {
                    return const SizedBox.shrink();
                  }
                  return Center(
                    child: SizedBox(
                      width: size.width,
                      height: size.height,
                      // The edge of the picture is the edge of the screen it
                      // will fill. Without a line there, a dark picture on a
                      // black page looks like it has no edge at all.
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: skin.textSecondary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: GestureDetector(
                            key: const Key('reframe-canvas'),
                            onPanUpdate: (d) => _pan(d.delta, size),
                            child: ClipRect(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // The runtime layer itself, not a copy of it: grain,
                                  // vignette, burn, blur and dim all land where they
                                  // will land on the phone.
                                  PersonalBackdrop(
                                    root: null,
                                    file: widget.file,
                                    spec: _spec,
                                    skin: widget.skin,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    _slider(
                      'ZOOM',
                      _spec.scale,
                      1.0,
                      BackdropSpec.maxScale,
                      (v) => setState(() => _spec = _spec.copyWith(scale: v)),
                    ),
                    _slider(
                      'ROTATION',
                      _spec.rotationDeg,
                      -BackdropSpec.maxRotation,
                      BackdropSpec.maxRotation,
                      (v) => setState(
                        () => _spec = _spec.copyWith(rotationDeg: v),
                      ),
                    ),
                    _slider(
                      'DIM',
                      _spec.dim,
                      0,
                      BackdropSpec.maxDim,
                      (v) => setState(() => _spec = _spec.copyWith(dim: v)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The app's own slider row, not a second one drawn here: the editor should
  /// feel like the screen that opened it.
  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) => KitSlider(
    skin: widget.skin,
    label: label,
    value: value,
    min: min,
    max: max,
    onChanged: onChanged,
    shown: value.toStringAsFixed(value <= 1 ? 2 : 1),
  );
}
