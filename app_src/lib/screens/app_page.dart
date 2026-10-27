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
}) {
  final resolved =
      presentation ?? PresentationScope.of(context, fallback: kSkinCrimson);
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (ctx) => PresentationScope(
        presentation: resolved,
        child: rebuildOn == null
            ? AppPage(title: title, mark: mark, child: builder(ctx))
            : ListenableBuilder(
                listenable: rebuildOn,
                builder: (_, __) =>
                    AppPage(title: title, mark: mark, child: builder(ctx)),
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
  });

  final String title;
  final Widget child;

  final Widget? mark;

  @override
  Widget build(BuildContext context) {
    final skin = PresentationScope.uiSkin(context, kSkinCrimson);
    return Scaffold(
      backgroundColor: skin.background,
      body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              AppScreenHeader(
                skin: skin,
                title: title,
                mark: mark,
                leading: GestureDetector(

                  onTap: () => Navigator.of(context).maybePop(),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Icon(Icons.arrow_back_rounded, color: skin.accent, size: 28),
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
