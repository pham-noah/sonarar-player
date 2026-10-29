library;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/prefs.dart';
import '../theme/layout.dart';
import '../theme/skin.dart';
import '../theme/slab.dart';
import '../theme/surface.dart';
import '../widgets/devices.dart';
import '../widgets/pressable.dart';

class FirstRunScreen extends StatelessWidget {
  const FirstRunScreen({
    super.key,
    required this.skin,
    required this.prefs,
    required this.layoutId,
    required this.onPrefs,
    required this.onDone,
  });

  final Skin skin;

  final AppPrefs prefs;

  final LayoutKind layoutId;

  final ValueChanged<AppPrefs> onPrefs;

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final p = PresentationScope.of(context, fallback: skin);
    final pal = p.palette;

    final palettes = _palettes();

    return Scaffold(
      backgroundColor: skin.background,

      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 28),
          children: [

            ScreenTitle(skin: skin, text: kAppName),
            const SizedBox(height: 8),
            Text(
              'Music for where you are and what the weather is doing.',
              style: TextStyle(
                fontSize: LayoutSpec.fontSmall,
                color: pal.textSecondary,
              ),
            ),
            const SizedBox(height: 28),

            SectionBand(skin: skin, label: 'LAYOUT'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in LayoutKind.values)
                  SkinChip(
                    skin: skin,

                    label: option.kit.displayName,
                    icon: switch (option) {
                      LayoutKind.sonar => Icons.auto_awesome_rounded,
                      LayoutKind.solid => Icons.crop_square_rounded,
                      LayoutKind.glass => Icons.blur_on_rounded,
                    },
                    selected: layoutId == option,

                    onTap: () => onPrefs(prefs.copyWith(layoutId: option.name)),
                  ),
              ],
            ),
            const SizedBox(height: 26),

            SectionBand(skin: skin, label: 'COLOURS'),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, entry) in palettes.indexed)
                  SkinChip(
                    skin: skin,
                    label: entry.name.toUpperCase(),
                    selected: i == 0,
                    onTap: () {},
                  ),
              ],
            ),
            const SizedBox(height: 26),

            SectionBand(skin: skin, label: 'SONG LIST'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SkinChip(
                  skin: skin,
                  label: 'GRID',
                  icon: Icons.grid_view_rounded,

                  selected: prefs.libraryIsGrid ?? (layoutId != LayoutKind.sonar),
                  onTap: () => onPrefs(prefs.copyWith(libraryIsGrid: true)),
                ),
                SkinChip(
                  skin: skin,
                  label: 'LIST',
                  icon: Icons.view_list_rounded,
                  selected: !(prefs.libraryIsGrid ??
                      (layoutId != LayoutKind.sonar)),
                  onTap: () => onPrefs(prefs.copyWith(libraryIsGrid: false)),
                ),
              ],
            ),
            const SizedBox(height: 34),

            Pressable(
              onTap: onDone,
              child: Surface(
                presentation: p,
                role: SurfaceRole.panel,
                accentEdge: false,
                fill: pal.accent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'START LISTENING',
                    style: TextStyle(
                      fontSize: LayoutSpec.fontBase,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: pal.onAccent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You can change all of this later in Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: LayoutSpec.fontLabel,
                color: pal.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<({String name})> _palettes() {
    if (layoutId == LayoutKind.sonar) {
      return [for (final s in kAllSkins) (name: s.displayName)];
    }
    final named =
        layoutId == LayoutKind.glass ? kGlassPalettes : kSolidPalettes;
    return [for (final n in named) (name: n.name)];
  }
}
