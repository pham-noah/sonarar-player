library;

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../library/track.dart';
import '../rules/playlist_explanation.dart';
import '../theme/skin.dart';
import '../widgets/pressable.dart';

class WhyPanel extends StatelessWidget {
  const WhyPanel({
    super.key,
    required this.state,
    required this.explanation,
    required this.alternatives,
    this.onPick,
    this.trailing,
  });

  final AppState state;
  final PlaylistExplanation explanation;

  final Widget? trailing;

  final List<Track> alternatives;

  final ValueChanged<Track>? onPick;

  @override
  Widget build(BuildContext context) {
    final skin = state.uiSkin;
    return ColoredBox(
      color: skin.background,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [

            if (explanation.moment != null)
              _moment(skin, explanation.moment!),

            if (onPick != null && alternatives.isNotEmpty) ...[
              const SizedBox(height: 30),
              _section(skin, 'NOT THIS ONE?'),
              const SizedBox(height: 12),
              for (final t in alternatives) _alternative(skin, t),
            ],

            if (trailing != null) trailing!,
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _moment(Skin skin, String sentence) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 34),
        child: Text(
          sentence,
          style: TextStyle(

            fontSize: LayoutSpec.fontTitle,
            fontWeight: FontWeight.w600,
            height: 1.45,
            color: skin.textPrimary,
          ),
        ),
      );

  Widget _section(Skin skin, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          label,
          style: TextStyle(
            fontSize: LayoutSpec.fontLabel,
            letterSpacing: 4,
            fontWeight: FontWeight.w800,
            color: skin.accent,
          ),
        ),
      );

  Widget _alternative(Skin skin, Track t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Pressable(
          child: InkWell(
            onTap: () => onPick!(t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: skin.textSecondary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: LayoutSpec.fontBase,
                            fontWeight: FontWeight.w700,
                            color: skin.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: LayoutSpec.fontSmall,
                            color: skin.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.play_arrow_rounded, color: skin.accent, size: 28),
                ],
              ),
            ),
          ),
        ),
      );
}
