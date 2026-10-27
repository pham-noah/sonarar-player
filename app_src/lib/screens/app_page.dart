library;

import 'package:flutter/material.dart';

import '../theme/layout.dart';
import '../theme/skin.dart';
import 'app_header.dart';

Future<void> openAppPage(
  BuildContext context, {
  Listenable? rebuildOn,
  required String title,
  required Widget Function(BuildContext) builder,
  Widget? mark,
  Presentation? presentation,
  Skin? skin,
}) {
  final chosen = skin ?? kSkinCrimson;
  final resolved =
      presentation ?? PresentationScope.of(context, fallback: chosen);
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (ctx) => PresentationScope(
        presentation: resolved,
        child: rebuildOn == null
            ? AppPage(title: title, mark: mark, skin: chosen, child: builder(ctx))
            : ListenableBuilder(
                listenable: rebuildOn,
                builder: (_, __) => AppPage(
                  title: title,
                  mark: mark,
                  skin: chosen,
                  child: builder(ctx),
                ),
              ),
      ),
    ),
  );
}

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.mark,
    this.skin = kSkinCrimson,
  });

  final String title;
  final Widget child;

  final Widget? mark;

  final Skin skin;

  @override
  Widget build(BuildContext context) {
    final resolved = PresentationScope.uiSkin(context, skin);
    return Scaffold(
      backgroundColor: resolved.background,
      body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppScreenHeader(
                skin: resolved,
                title: title,
                mark: mark,
                leading: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child:
                        Icon(Icons.arrow_back_rounded, color: resolved.accent, size: 28),
                  ),
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
    );
  }
}
