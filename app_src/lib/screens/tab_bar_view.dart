library;

import 'package:flutter/material.dart';

import '../widgets/pressable.dart';

import '../theme/layout.dart';
import '../theme/motion.dart';
import '../theme/skin.dart';
import '../theme/surface.dart';

enum AppTab { home, library, search, settings }

class TabBarView2 extends StatelessWidget {
  const TabBarView2({
    super.key,
    required this.skin,
    required this.current,
    required this.onSelect,
    this.presentation,
  });

  final Skin skin;
  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  final Presentation? presentation;

  @override
  Widget build(BuildContext context) {
    final p = presentation ?? Presentation.forSkin(skin);
    final pal = p.palette;
    final floating = p.arrangement.tabBarIsFloating;

    final bar = SizedBox(
      height: LayoutSpec.tabBarHeight,
      child: floating

          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Surface(
                presentation: p,
                role: SurfaceRole.bar,
                radius: 32,
                child: _row(pal),
              ),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                color: pal.background,
                border: Border(
                  top: BorderSide(color: pal.accent.withValues(alpha: 0.24)),
                ),
              ),
              child: _row(pal),
            ),
    );

    return floating
        ? Padding(padding: p.arrangement.tabBarInsets, child: bar)
        : bar;
  }

  Widget _row(LayoutPalette pal) {
    return Row(
        children: [

          _tab(AppTab.home, Icons.home_rounded, 'HOME'),
          _tab(AppTab.library, Icons.library_music_rounded, 'LIBRARY'),
          _tab(AppTab.search, Icons.search_rounded, 'SEARCH'),

        ],
    );
  }

  Widget _tab(AppTab tab, IconData icon, String label) {
    final active = tab == current;
    final colour = active ? skin.accent : skin.textSecondary;
    final skew = skin.skewDegrees * (3.14159265 / 180);

    return Expanded(
      child: Pressable(
        child: InkWell(
        onTap: () => onSelect(tab),
        child: Stack(
          children: [
            if (active)

              Positioned(
                top: 0,
                left: 16,
                right: 16,
                child: Transform(
                  transform: Matrix4.skewX(-skew),
                  child: Container(height: 3, color: skin.accent),
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform(
                    transform: Matrix4.skewX(-skew),

                    child: AnimatedScale(
                      scale: active ? 1.0 : 0.86,
                      duration: Motion.morph,
                      curve: MotionCurve.morph,
                      child: Icon(
                        icon,
                        size: 25,
                        color: colour,
                      ),
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
                        style: TextStyle(
                          fontSize: LayoutSpec.fontLabel,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: colour,
                        ),
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
    );
  }
}
