library;

import 'package:flutter/material.dart';

import '../theme/layout.dart';
import '../theme/surface.dart';
import '../theme/skin.dart';

class SidebarEntry {
  const SidebarEntry({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.skin,
    required this.mark,
    required this.entries,
    this.footer,
  });

  final Skin skin;

  final Widget mark;

  final List<SidebarEntry> entries;

  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final panelSkin = PresentationScope.uiSkin(context, skin);
    return Drawer(

      width: width > 520 ? 340 : width * 0.78,
      backgroundColor: Colors.transparent,

      elevation: 0,
      child: Surface(
        presentation: PresentationScope.of(context, fallback: skin),
        role: SurfaceRole.sheet,
        accentEdge: true,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Row(
                  children: [
                    SizedBox(width: 34, height: 34, child: mark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'PERSONAR',
                        style: TextStyle(
                          fontSize: 16,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w900,
                          color: panelSkin.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: panelSkin.accent.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 8),
              for (final e in entries)
                _entry(context, panelSkin, e),
              const Spacer(),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: footer!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _entry(BuildContext context, Skin panelSkin, SidebarEntry e) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        e.onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(e.icon, size: 22, color: panelSkin.accent),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                e.label,
                style: TextStyle(
                  fontSize: 16,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                  color: panelSkin.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: panelSkin.textSecondary.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

class SidebarMarkButton extends StatelessWidget {
  const SidebarMarkButton({
    super.key,
    required this.mark,

    this.size = 34,
  });

  final Widget mark;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(

      onTap: () => Scaffold.of(context).openDrawer(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
        child: SizedBox(width: size, height: size, child: mark),
      ),
    );
  }
}
