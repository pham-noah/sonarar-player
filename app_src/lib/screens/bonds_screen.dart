library;

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../library/bonds.dart';
import '../library/play_log.dart';
import '../library/track.dart';
import '../theme/layout.dart';
import '../theme/skin.dart';
import '../theme/slab.dart';
import '../widgets/pressable.dart';

class BondsScreen extends StatelessWidget {
  const BondsScreen({
    super.key,
    required this.state,
    required this.events,
    required this.tracks,
    this.inline = false,
    this.onNoteSaved,
    this.onReset,
  });

  final AppState state;

  final List<PlayEvent> events;
  final List<Track> tracks;

  final bool inline;

  final VoidCallback? onNoteSaved;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final skin = state.uiSkin;
    final board = buildBonds(events, state: state.bondState, limit: 100);
    final byId = {for (final t in tracks) t.id: t};

    final list = ListView(
      shrinkWrap: inline,
      physics: inline
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: inline
          ? const EdgeInsets.fromLTRB(20, 8, 20, 24)
          : LayoutSpec.screenPadding,
      children: [
        if (!inline) ...[
          ScreenTitle(
            skin: skin,
            text: state.languageSkin.word(WordKey.affinityRoom, 'RANKS'),
          ),
          const SizedBox(height: 16),
        ],

        if (board.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(
              board.consideredEvents == 0 &&
                      state.bondState.config.resetAt != null
                  ? 'Nothing played since the last reset.'
                  : 'Nothing played yet.',
              style: TextStyle(
                fontSize: LayoutSpec.fontBase,
                color: skin.textSecondary,
              ),
            ),
          )
        else
          for (final b in board.bonds)
            _bondRow(context, skin, b, byId[b.trackId]),

        if (onReset != null) ...[
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Pressable(
              child: TextButton.icon(
                onPressed: onReset,
                icon: Icon(Icons.restart_alt_rounded,
                    size: 18, color: skin.textSecondary),
                label: Text(
                  'START THE RANKS OVER',
                  style: TextStyle(
                    fontSize: LayoutSpec.fontLabel,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                    color: skin.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );

    if (inline) return list;
    return ColoredBox(
      color: PresentationScope.of(context, fallback: skin).palette.pageFill ??
              PresentationScope.of(context, fallback: skin).palette.background,
      child: SafeArea(child: list),
    );
  }

  Widget _bondRow(BuildContext context, Skin skin, Bond bond, Track? track) {
    final info = bond.rankInfo;
    final note = state.bondState.noteFor(bond.trackId);
    final canNote = bond.rank >= BondState.kNoteRank;
    final held = bond.rank > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slab(
        presentation: PresentationScope.of(context, fallback: skin),
        skin: skin,

        fill: skin.background,
        active: held,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    track?.title ?? bond.trackId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: LayoutSpec.fontSmall,
                      fontWeight: FontWeight.w800,
                      color: track == null
                          ? skin.textSecondary
                          : (held ? skin.textPrimary : skin.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                Text(
                  '${bond.rank}',
                  style: TextStyle(
                    fontSize: LayoutSpec.fontBase,
                    fontWeight: FontWeight.w900,
                    color: held ? skin.accent : skin.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                for (var i = 0; i < 5; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == 4 ? 0 : 4),
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: i < bond.rank
                              ? skin.accent
                              : skin.textSecondary.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),

            Row(
              children: [
                Expanded(
                  child: Text(
                    info.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: LayoutSpec.fontLabel,
                      letterSpacing: 1,
                      color: held ? skin.accent : skin.textSecondary,
                    ),
                  ),
                ),

                if (canNote)
                  Pressable(
                    child: InkWell(
                      onTap: () => _note(context, skin, bond, note),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        child: Icon(
                          note == null
                              ? Icons.note_add_outlined
                              : Icons.sticky_note_2_rounded,
                          size: 18,
                          color: skin.accent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            if (note != null) ...[
              const SizedBox(height: 6),
              Text(
                note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: LayoutSpec.fontLabel,
                  color: skin.textPrimary.withValues(alpha: 0.9),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _note(
    BuildContext context,
    Skin skin,
    Bond bond,
    String? existing,
  ) async {
    final controller = TextEditingController(text: existing ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PresentationScope.uiSkin(context, skin).background,
        title: Text(
          'Note on this bond',
          style: TextStyle(color: skin.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          minLines: 1,
          style: TextStyle(color: skin.textPrimary),
          decoration: const InputDecoration(hintText: 'Why this one matters'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null) return;
    state.setBondNote(bond.trackId, text, rank: bond.rank);
    onNoteSaved?.call();
  }
}
