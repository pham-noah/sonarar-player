library;

import '../l10n/l10n.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/pressable.dart';

import '../theme/layout.dart';
import '../theme/motion.dart';
import '../theme/skin.dart';
import '../theme/surface.dart';
import '../theme/tokens.dart';

/// The three places the app has. Downloads are not one of them: a tab that
/// opens onto "no network" or "the engine is not installed" is a dead end
/// standing in the bar, so the downloader is a page the Library opens.
enum AppTab { home, library, settings }

class TabBarView2 extends StatelessWidget {
  const TabBarView2({
    super.key,
    required this.skin,
    required this.current,
    required this.onSelect,
    this.onReselect,
    this.presentation,
    this.showHome = true,
  });

  final Skin skin;
  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  /// Tapping the tab you are already on. Every list app returns to the top of
  /// the list it is already showing; without this the only way back from three
  /// hundred rows down is to flick until it stops.
  final ValueChanged<AppTab>? onReselect;

  final Presentation? presentation;

  /// A tab onto nothing is worse than no tab.
  final bool showHome;

  @override
  Widget build(BuildContext context) {
    final p = presentation ?? Presentation.forSkin(skin);
    final pal = p.palette;
    final floating = p.arrangement.tabBarIsFloating;

    final bar = SizedBox(
      height: LayoutSpec.tabBarHeight,
      child: floating
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Surface(
                presentation: p,
                role: SurfaceRole.bar,
                radius: 32,
                child: _row(context, pal),
              ),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                color: pal.background,
                border: Border(
                  top: BorderSide(color: pal.accent.withValues(alpha: 0.24)),
                ),
              ),
              child: _row(context, pal),
            ),
    );

    return floating
        ? Padding(padding: p.arrangement.tabBarInsets, child: bar)
        : bar;
  }

  Widget _row(BuildContext context, LayoutPalette pal) {
    final l10n = l10nOf(context);
    return Row(
      children: [
        if (showHome)
          _tab(context, AppTab.home, Icons.home_rounded, l10n.tabHome),
        _tab(
          context,
          AppTab.library,
          Icons.library_music_rounded,
          l10n.libraryTitle,
        ),
        _tab(
          context,
          AppTab.settings,
          Icons.settings_rounded,
          l10n.settingsTitle,
        ),
      ],
    );
  }

  Widget _tab(BuildContext context, AppTab tab, IconData icon, String label) {
    final active = tab == current;
    // The active tab is ink, not a fill: `skin.accent` as a label is 1.88:1 on
    // Minimal, so the state you are in used to be the least legible thing in the
    // bar. The fill stays on the 2px underline, where it is a shape.
    final colour = active ? skin.accentInk : skin.textMuted;
    final skew = skin.skewDegrees * (3.14159265 / 180);

    return Expanded(
      key: ValueKey('tab-${tab.name}'),
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        excludeSemantics: true,
        child: Pressable(
          child: InkWell(
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              if (active) {
                // Already here: this is a "take me back" tap, not a navigation.
                onReselect?.call(tab);
              } else {
                onSelect(tab);
              }
            },
            // The state is the label, not a rule under it: the chosen tab is ink
            // while the rest are muted, and its icon sits a size larger. The 2px
            // accent underline that used to sit here was the third copy of that
            // fact, and the only one that read as a border of the bar.
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform(
                        transform: Matrix4.skewX(-skew),

                        child: AnimatedScale(
                          scale: active ? 1.0 : 0.86,
                          duration: Motion.of(context, Motion.morph),
                          curve: MotionCurve.morph,
                          child: Icon(icon, size: 25, color: colour),
                        ),
                      ),
                      const SizedBox(height: 4),

                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Transform(
                          transform: Matrix4.skewX(-skew),
                          child: Text(
                            label,
                            maxLines: 1,
                            style: Type.caps(context, color: colour),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
