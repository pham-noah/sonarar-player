library;

import 'package:flutter/material.dart';

import '../art/art_focus.dart';
import '../art/skin_art.dart';

import '../core/app_state.dart';
import '../library/compendium.dart';
import '../library/track.dart';
import '../theme/skin.dart';
import '../theme/slab.dart';
import 'compendium_screen.dart';
import '../widgets/framed_art.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({
    super.key,
    required this.state,
    this.inline = false,
    this.compendiumEntries,
    this.playingTrackId,
    this.onSummon,
    this.onOpenBonds,
    this.onOpenRules,
    this.onOpenExclusions,
    this.onOpenTagEditor,
    this.onRevertAllTags,
  });

  final AppState state;

  final bool inline;

  final List<CompendiumEntry>? compendiumEntries;

  final String? playingTrackId;

  final void Function(Track)? onSummon;

  final void Function(Track)? onOpenTagEditor;
  final VoidCallback? onOpenBonds;

  final VoidCallback? onOpenRules;

  final VoidCallback? onOpenExclusions;

  final VoidCallback? onRevertAllTags;

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  int _order = 0;

  @override
  Widget build(BuildContext context) {
    final skin = widget.state.uiSkin;
    final entries = widget.compendiumEntries;
    final rows =
        entries == null ? <CompendiumEntry>[] : orderCompendium(entries, _order);
    final heard = entries == null ? 0 : entries.where((e) => !e.neverHeard).length;

    final body = CustomScrollView(
      slivers: [

        SliverToBoxAdapter(
          child: Padding(
            padding: widget.inline
                ? const EdgeInsets.fromLTRB(20, 8, 20, 12)
                : LayoutSpec.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.inline) ...[
                  ScreenTitle(
                    skin: skin,
                    text: widget.state.languageSkin.word(WordKey.libraryRoom, 'LIBRARY TOOLS'),
                  ),
                  const SizedBox(height: 14),
                ],

                if (entries != null) ...[
                  Text(
                    '$heard of ${entries.length} heard',
                    style: TextStyle(fontSize: LayoutSpec.fontSmall, color: skin.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final (i, label) in const [
                        (0, 'MOST HEARD'),
                        (1, 'RECENT'),
                        (2, 'A-Z'),
                      ]) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: SkinChip(
                            skin: skin,
                            label: label,
                            selected: _order == i,
                            onTap: () => setState(() => _order = i),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        if (entries != null)
          ...compendiumSliverList(
            skin: skin,
            rows: rows,
            playingTrackId: widget.playingTrackId,
            onSummon: widget.onSummon,
          ),

        SliverToBoxAdapter(child: SizedBox(height: widget.inline ? 24 : 18)),
      ],
    );

    if (widget.inline) return body;

    return Stack(
      children: [
        Positioned.fill(
          child: ArchiveBackdrop(
            skin: skin,
            focus: widget.state.artFocus,
            art: widget.state.art,
          ),
        ),
        SafeArea(child: body),
      ],
    );
  }
}

class ArchiveBackdrop extends StatelessWidget {
  const ArchiveBackdrop({
    super.key,
    required this.skin,
    required this.focus,
    this.art,
    this.opacity = 0.20,
  });

  final Skin skin;

  final ArtFocus focus;

  final SkinArt? art;

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final set = artFor(skin.id);
    if (!set.hasArt) return const SizedBox.shrink();
    final piece = art ?? set.atOrNull(0);
    if (piece == null) return const SizedBox.shrink();

    return FramedArt(
      assetPath: piece.assetPath,
      aspect: piece.aspect,
      focus: focus,
      opacity: opacity,
    );
  }
}
