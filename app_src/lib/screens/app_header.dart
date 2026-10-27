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
  });

  final Skin skin;

  final String title;

  final Widget? mark;

  final Widget? trailing;

  final Widget? leading;

  static const double markSize = 40;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 20, 6),
      child: Row(
        children: [
          if (leading != null) leading!,
          if (mark != null)
            SidebarMarkButton(mark: mark!, size: markSize),
          Expanded(
            child: ScreenTitle(skin: skin, text: title),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
