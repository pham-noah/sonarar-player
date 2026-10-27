library;

import 'package:flutter/material.dart';

import '../theme/skin.dart';

class CoverButton extends StatefulWidget {
  const CoverButton({
    super.key,
    required this.skin,
    required this.cover,
    required this.playing,
    required this.onPlayPause,
    this.size = 156,
  });

  final Skin skin;

  final ImageProvider? cover;

  final bool playing;
  final VoidCallback? onPlayPause;
  final double size;

  @override
  State<CoverButton> createState() => _CoverButtonState();
}

class _CoverButtonState extends State<CoverButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;

    final show = (_hovered || _pressed) && widget.onPlayPause != null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPlayPause,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            border: Border.all(color: skin.accent.withValues(alpha: 0.8), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.cover == null)
                ColoredBox(color: skin.panel)
              else
                Image(

                  image: ResizeImage(widget.cover!, width: (widget.size * 3).round()),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => ColoredBox(color: skin.panel),
                ),

              if (show)
                ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
              if (show)
                Center(
                  child: Icon(
                    widget.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: widget.size * 0.34,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
