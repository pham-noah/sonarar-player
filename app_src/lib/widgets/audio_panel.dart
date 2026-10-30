library;

import 'package:flutter/material.dart';

import '../player/audio_route.dart';
import '../theme/skin.dart';

String _kindLabel(String kind) => switch (kind) {
      'bluetooth' => 'BLUETOOTH',
      'headphones' => 'WIRED',
      'usb' => 'USB / DAC',
      'hdmi' => 'HDMI',
      _ => 'THIS PHONE',
    };

class AudioPanel extends StatelessWidget {
  const AudioPanel({
    super.key,
    required this.skin,
    required this.volume,
    required this.onVolume,
    this.muted = false,
    this.outputs = const [],
    this.onPickOutput,
  });

  static const Key volumeKey = Key('audio-panel-volume');

  final Skin skin;
  final double volume;
  final ValueChanged<double> onVolume;
  final bool muted;

  final List<AudioOutput> outputs;

  final VoidCallback? onPickOutput;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _SectionLabel(skin: skin, text: 'VOLUME'),
        Row(
          children: [

            GestureDetector(
              onTap: () => onVolume(muted ? 1.0 : 0.0),
              child: Icon(
                muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: muted ? skin.accent : skin.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  activeTrackColor: skin.accent,
                  inactiveTrackColor: skin.secondary(0.3),
                  thumbColor: skin.accent,
                ),
                child: Slider(
                  key: volumeKey,
                  value: volume.clamp(0.0, 1.0),
                  onChanged: onVolume,
                ),
              ),
            ),
            const SizedBox(width: 8),

            Text(
              '${(volume.clamp(0.0, 1.0) * 100).round()}',
              style: TextStyle(
                fontSize: LayoutSpec.fontLabel,
                fontWeight: FontWeight.w800,
                color: skin.textPrimary,
              ),
            ),
          ],
        ),

        if (outputs.isNotEmpty) ...[
          const SizedBox(height: 6),
          _SectionLabel(skin: skin, text: 'PLAYS THROUGH'),
          _PanelRow(
            skin: skin,
            icon: Icons.swap_horiz_rounded,
            label: 'CHANGE OUTPUT',
            blurb: 'Opens your phone\'s output picker',
            onTap: onPickOutput,
          ),
          const SizedBox(height: 4),
          for (final o in outputs)
            _PanelRow(
              skin: skin,
              icon: o.icon,
              label: o.name,

              blurb: _kindLabel(o.kind),

              trailing: o.active
                  ? Icon(Icons.check_rounded, color: skin.accent, size: 20)
                  : null,
            ),
        ],

      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.skin, required this.text});

  final Skin skin;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: LayoutSpec.fontMicro,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w900,
            color: skin.accent,
          ),
        ),
      );
}

class _PanelRow extends StatelessWidget {
  const _PanelRow({
    required this.skin,
    required this.icon,
    required this.label,
    this.blurb,
    this.trailing,
    this.onTap,
  });

  final Skin skin;
  final IconData icon;
  final String label;

  final String? blurb;
  final Widget? trailing;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
        margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(

            color: skin.panel,
            border: Border(left: BorderSide(color: skin.accent, width: 3)),
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: skin.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: LayoutSpec.fontLabel,
                        fontWeight: FontWeight.w800,
                        color: skin.textPrimary,
                      ),
                    ),
                    if (blurb != null)
                      Text(
                        blurb!,
                        style: TextStyle(
                          fontSize: LayoutSpec.fontMicro,
                          letterSpacing: 1.2,
                          color: skin.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      );
}
