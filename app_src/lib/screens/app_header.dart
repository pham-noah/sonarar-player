library;

import 'package:flutter/material.dart';

import '../theme/skin.dart';
import '../theme/slab.dart';
import 'app_sidebar.dart';

class AppScreenHeader extends StatelessWidget {
  const AppScreenHeader({
    super.key,
    required this.skin,
    required this.title,
    this.mark,
    this.trailing,
    this.leading,
    this.hero = false,
  });

  final Skin skin;

  final String title;

  final Widget? mark;

  final Widget? trailing;

  final Widget? leading;

  /// The greeting on Home is the one `hero` in the app; every other header is
  /// a `display` title.
  final bool hero;

  static const double markSize = 40;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),      child: Row(
        children: [
          if (leading != null) leading!,
          if (mark != null)
            SidebarMarkButton(mark: mark!, size: markSize),
          Expanded(
            child: ScreenTitle(skin: skin, text: title, hero: hero),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
