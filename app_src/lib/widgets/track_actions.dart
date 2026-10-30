library;

import 'package:flutter/material.dart';

import '../theme/skin.dart';

class TrackActions extends StatelessWidget {
  const TrackActions({
    super.key,
    required this.skin,
    required this.actions,
    this.onAudio,
    this.audioOpen = false,
  });

  final Skin skin;

  final List<Widget> actions;

  final VoidCallback? onAudio;

  final bool audioOpen;

  static const Key audioButtonKey = Key('track-actions-audio');

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      ...actions,

      if (onAudio != null)
        _SquareButton(
          skin: skin,
          key: audioButtonKey,
          icon: Icons.speaker_rounded,
          tooltip: audioOpen ? 'Hide audio' : 'Audio',
          active: audioOpen,
          onTap: onAudio!,
        ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          buttons[i],
        ],
      ],
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    super.key,
    required this.skin,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.active = false,
  });

  final Skin skin;
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onTap,
      child: Container(
        width: LayoutSpec.secondaryActionWidth,
        height: LayoutSpec.secondaryActionHeight,
        decoration: BoxDecoration(
          color: active ? skin.accent : Colors.transparent,
          border: Border.all(
            color: active
                ? skin.accent
                : skin.secondary(0.42),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: active ? skin.onAccent : skin.textSecondary,
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}
