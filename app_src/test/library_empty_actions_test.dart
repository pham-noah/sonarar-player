library;

// "No music yet" is the first screen a new install sees, and it offers exactly
// two exits: pick a folder, or find music online. They were two different
// widths — 172 dp and 192 dp — stacked on the same centre line, which reads as
// a layout accident rather than a hierarchy: it is not obvious which one is the
// primary action when the secondary is the wider box.
//
// They are now one block (IntrinsicWidth + stretch) and the labels are centred
// inside it. Both facts are what a reader sees first, so both are asserted
// here: equal width, shared edges, and a thumb-sized height on each.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/l10n/app_localizations.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/theme/skin.dart';

const _floor = 48.0;

Future<void> _openEmpty(WidgetTester tester, {bool withFind = true}) async {
  tester.view.physicalSize = const Size(360, 780) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Material(
        child: LibraryScreen(
          view: LibraryScreenView(
            tracks: const <Track>[],
            coverPathFor: (_) => null,
            skin: skinFor(SkinId.crimson),
            libraryRoot: '/storage/emulated/0/Music/Sonarar',
            onChooseFolder: () {},
            onFindMusic: withFind ? () {} : null,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Rect _boxOf(WidgetTester tester, String label) {
  final node = find.ancestor(
    of: find.text(label),
    matching: find.byType(GestureDetector),
  );
  expect(node, findsOneWidget, reason: 'The "$label" control is gone.');
  return tester.getRect(node);
}

void main() {
  testWidgets('the two exits from an empty library are one size', (
    tester,
  ) async {
    await _openEmpty(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(LibraryScreen)),
    );
    final pick = _boxOf(tester, l10n.libraryChooseFolder);
    final online = _boxOf(tester, l10n.libraryFindMusic);

    expect(
      pick.width,
      closeTo(online.width, 0.5),
      reason:
          'The empty state\'s two controls are ${pick.width} and '
          '${online.width} dp wide. Two widths on one centre line reads as a '
          'mistake, and it hides which one is the primary action.',
    );
    expect(
      pick.left,
      closeTo(online.left, 0.5),
      reason:
          'The two exits are centred on the same axis only if they share both '
          'edges; they start at ${pick.left} and ${online.left} dp.',
    );
    for (final box in <Rect>[pick, online]) {
      expect(
        box.height,
        greaterThanOrEqualTo(_floor),
        reason:
            'An exit from the empty state is ${box.height} dp tall, under the '
            '48 dp floor — the two things a new user must press.',
      );
    }
  });

  testWidgets('a lone primary still fills the block', (tester) async {
    await _openEmpty(tester, withFind: false);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(LibraryScreen)),
    );
    final pick = _boxOf(tester, l10n.libraryChooseFolder);

    expect(
      find.text(l10n.libraryFindMusic),
      findsNothing,
      reason: 'The fixture asked for no "find music online" exit.',
    );
    expect(
      pick.width,
      greaterThan(200),
      reason:
          'With one control the block must still size to the content, not '
          'collapse to the glyph: the button measured ${pick.width} dp.',
    );
  });
}
