library;

import 'package:flutter/material.dart';

import '../theme/skin.dart';
import 'cross_fade_slot.dart';

class CoverPlayButton extends StatelessWidget {
  const CoverPlayButton({
    super.key,
    required this.skin,
    required this.cover,
    required this.size,
    this.onTogglePlay,
    this.isPlaying = false,
    this.showBorder = false,
    this.fallbackIcon,
    this.fallbackIconColor,
    this.fallbackIconSize,
    this.fadeKey,
  });

  final Skin skin;

  final ImageProvider? cover;
  final double size;

  final VoidCallback? onTogglePlay;

  final bool isPlaying;

  final bool showBorder;

  final IconData? fallbackIcon;
  final Color? fallbackIconColor;

  final double? fallbackIconSize;

  final Object? fadeKey;

  @override
  Widget build(BuildContext context) {
    final enabled = onTogglePlay != null;

    return _HoverableCover(
      skin: skin,
      cover: cover,
      size: size,
      fallbackIcon: fallbackIcon,
      fallbackIconColor: fallbackIconColor,
      fallbackIconSize: fallbackIconSize,
      showBorder: showBorder,
      onTap: onTogglePlay,
      builder: (hovered) => Stack(
        fit: StackFit.expand,
        children: [

          if (fadeKey == null)
            _art()
          else
            CrossFadeSlot(keyValue: fadeKey!, child: _art()),

          if (hovered && enabled)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              alignment: Alignment.center,
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: skin.accent,
                size: size * 0.44,
              ),
            ),
        ],
      ),
    );
  }

  Widget _art() {
    if (cover == null) return _fallback();
    return Image(
      image: cover!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() {
    final icon = fallbackIcon;
    if (icon == null) return ColoredBox(color: skin.panel);
    return ColoredBox(
      color: skin.panel,
      child: Icon(
        icon,
        color: fallbackIconColor ?? skin.accent,
        size: fallbackIconSize ?? size * 0.5,
      ),
    );
  }
}

class _HoverableCover extends StatefulWidget {
  const _HoverableCover({
    required this.skin,
    required this.cover,
    required this.size,
    required this.showBorder,
    required this.fallbackIcon,
    required this.fallbackIconColor,
    required this.fallbackIconSize,
    required this.onTap,
    required this.builder,
  });

  final Skin skin;

  final ImageProvider? cover;
  final double size;

  final bool showBorder;
  final IconData? fallbackIcon;
  final Color? fallbackIconColor;
  final double? fallbackIconSize;
  final VoidCallback? onTap;
  final Widget Function(bool hovered) builder;

  @override
  State<_HoverableCover> createState() => _HoverableCoverState();
}

class _HoverableCoverState extends State<_HoverableCover> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            border: widget.showBorder
                ? Border.all(
                    color: widget.skin.accentAt(0.5),
                  )
                : null,
          ),
          child: widget.builder(_hovered),
        ),
      ),
    );
  }
}
