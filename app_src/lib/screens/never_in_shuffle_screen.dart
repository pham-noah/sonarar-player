library;

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../library/track.dart';
import '../theme/layout.dart';
import '../theme/skin.dart';
import '../widgets/pressable.dart';

class NeverInShuffleScreen extends StatelessWidget {
  const NeverInShuffleScreen({
    super.key,
    required this.state,
    required this.tracks,
  });

  final AppState state;

  final List<Track> tracks;

  @override
  Widget build(BuildContext context) {
    final skin = state.uiSkin;
    final ids = state.exclusions.ids.toList()..sort();
    final byId = {for (final t in tracks) t.id: t};

    return ColoredBox(
      color: PresentationScope.of(context, fallback: skin).palette.pageFill ??
              PresentationScope.of(context, fallback: skin).palette.background,
      child: SafeArea(
        child: ListView(
          padding: LayoutSpec.screenPadding,
          children: [
            Text(
              'NEVER IN SHUFFLE',
              style: TextStyle(
                fontSize: LayoutSpec.fontTitle,
                fontWeight: FontWeight.w900,
                color: skin.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'These never come up, whatever the context. Bringing one back '
              'takes it off this list — nothing was deleted.',
              style: TextStyle(
                fontSize: LayoutSpec.fontSmall,
                color: skin.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),

            if (ids.isEmpty)
              Text(
                'Nothing excluded. Every track in the library is eligible.',
                style: TextStyle(
                  fontSize: LayoutSpec.fontBase,
                  color: skin.textPrimary,
                  height: 1.35,
                ),
              )
            else
              for (final id in ids) _row(skin, id, byId[id]),

            if (ids.isNotEmpty) ...[
              const SizedBox(height: 24),
              Pressable(
                child: OutlinedButton(
                  onPressed: () {
                    for (final id in ids) {
                      state.toggleExclusion(id);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: skin.textPrimary,
                    side: BorderSide(color: skin.textSecondary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('ALLOW EVERYTHING AGAIN'),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _row(Skin skin, String id, Track? track) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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

                    track?.title ?? 'Not in the library ($id)',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: LayoutSpec.fontBase,
                      fontWeight: FontWeight.w700,
                      color: track == null ? skin.textSecondary : skin.textPrimary,
                    ),
                  ),
                  if (track != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: LayoutSpec.fontSmall,
                        color: skin.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Pressable(
              child: OutlinedButton(
                onPressed: () => state.toggleExclusion(id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: skin.accent,
                  side: BorderSide(color: skin.accent),
                  minimumSize: const Size(80, LayoutSpec.tapTarget),
                ),
                child: const Text('ALLOW'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
