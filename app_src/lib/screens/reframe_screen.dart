import 'dart:io';

import 'package:flutter/material.dart';

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
                  return Center(
                    child: SizedBox(
                      width: size.width,
                      height: size.height,
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
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  _slider(
                    'SIZE',
                    _spec.scale,
                    1.0,
                    6.0,
                    (v) => setState(() => _spec = _spec.copyWith(scale: v)),
                  ),
                  _slider(
                    'ROTATE',
                    _spec.rotationDeg,
                    -15,
                    15,
                    (v) =>
                        setState(() => _spec = _spec.copyWith(rotationDeg: v)),
                  ),
                  _slider(
                    'DIM',
                    _spec.dim,
                    0,
                    0.85,
                    (v) => setState(() => _spec = _spec.copyWith(dim: v)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    final skin = widget.skin;
    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: TextStyle(
              color: skin.textSecondary,
              fontSize: LayoutSpec.fontFloor - 4,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: skin.accent,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
