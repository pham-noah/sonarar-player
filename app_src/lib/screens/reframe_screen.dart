import 'dart:io';

import 'package:flutter/material.dart';

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
                    child: Text('CANCEL',
                        style: TextStyle(color: skin.textSecondary)),
                  ),
                  TextButton(
                    key: const Key('reframe-done'),
                    onPressed: () => Navigator.of(context).pop(_spec),
                    child: Text('DONE',
                        style: TextStyle(
                          color: skin.accent,
                          fontWeight: FontWeight.w900,
                        )),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final size = Size(box.maxWidth, box.maxHeight);
                  return GestureDetector(
                    key: const Key('reframe-canvas'),
                    onPanUpdate: (d) => _pan(d.delta, size),
                    child: ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Cover leaves no slack: overscan, then slide.
                          Transform.translate(
                            offset: Offset(
                              (_spec.focusX * 2 - 1) * size.width * -0.12,
                              (_spec.focusY * 2 - 1) * size.height * -0.12,
                            ),
                            child: Transform.scale(
                              scale: _spec.scale * 1.25,
                              child: Transform.rotate(
                                angle: _spec.rotationDeg * 3.1415926535 / 180,
                                child: Image.file(
                                  widget.file,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const ColoredBox(color: Colors.black26),
                                ),
                              ),
                            ),
                          ),
                          // The picture darkens the way the app will darken it.
                          IgnorePointer(
                            child: ColoredBox(
                              color: Colors.black.withValues(
                                alpha: _spec.dim.clamp(0.0, 0.85),
                              ),
                            ),
                          ),
                        ],
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
                  _slider('SIZE', _spec.scale, 1.0, 2.6,
                      (v) => setState(() => _spec = _spec.copyWith(scale: v))),
                  _slider('ROTATE', _spec.rotationDeg, -15, 15,
                      (v) => setState(() => _spec = _spec.copyWith(rotationDeg: v))),
                  _slider('DIM', _spec.dim, 0, 0.85,
                      (v) => setState(() => _spec = _spec.copyWith(dim: v))),
                  Text(
                    'Drag the picture: whatever you centre stays centred in '
                    'every shape the screen takes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: skin.textSecondary,
                      fontSize: LayoutSpec.fontFloor - 3,
                    ),
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
