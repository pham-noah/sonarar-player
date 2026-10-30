/// Scratch: does a floating bar raised inside a modal sheet actually show?
///
///     flutter test test/shots/toast_over_sheet_shot.dart --update-goldens
///
/// Writes three PNGs. Not part of the suite.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/widgets/toasts.dart';

const Size _phone = Size(390, 844);

Widget _app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: home,
      theme: ThemeData(fontFamily: 'Roboto'),
    );

final _skin = kSkinAbyss;

Widget _miniPlayer() => Container(
      key: const Key('mini'),
      height: 64,
      color: _skin.panel,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(width: 44, height: 44, color: _skin.accent.withValues(alpha: 0.35)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Burn My Dread',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _skin.textPrimary, fontSize: 14)),
                Text('Lotus Juice',
                    maxLines: 1,
                    style: TextStyle(color: _skin.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.play_arrow_rounded, color: _skin.accent),
        ],
      ),
    );

Widget _sheetBody() => Container(
      color: _skin.background,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              color: _skin.textSecondary.withValues(alpha: 0.4),
            ),
          ),
          Text('IMPORT PLAYLIST',
              style: TextStyle(
                  color: _skin.accent, fontSize: 12, letterSpacing: 4, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          for (final line in const [
            'Persona 3 Reload — Full OST',
            'Persona 5 Royal — Jazz Covers',
            'Chained together, 42 tracks',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(width: 40, height: 40, color: _skin.panel),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _skin.textPrimary, fontSize: 14)),
                  ),
                  Icon(Icons.download_rounded, size: 18, color: _skin.textSecondary),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(height: 46, child: Center(
            child: Text('PASTE A LINK',
                style: TextStyle(
                    color: _skin.accent, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w700)),
          )),
        ],
      ),
    );

void main() {
  testWidgets('shell case: floating bar above the mini player', (tester) async {
    await tester.binding.setSurfaceSize(_phone);
    await tester.pumpWidget(_app(Builder(builder: (context) {
      return Scaffold(
        backgroundColor: _skin.background,
        body: Center(
          child: TextButton(
            onPressed: () => toast(context, 'Saved "Night Drive" with 12 tracks.'),
            child: const Text('raise'),
          ),
        ),
        bottomNavigationBar: _miniPlayer(),
      );
    })));
    await tester.tap(find.text('raise'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // ignore: avoid_print
    print('SHELL bar=${tester.getRect(find.byType(SnackBar))} '
        'mini=${tester.getRect(find.byKey(const Key('mini')))}');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../.hermes/tmp/toast_shell.png'),
    );
  });

  testWidgets('sheet case: bar raised from inside a modal sheet', (tester) async {
    await tester.binding.setSurfaceSize(_phone);
    await tester.pumpWidget(_app(Builder(builder: (context) {
      return Scaffold(
        backgroundColor: _skin.background,
        body: Center(
          child: TextButton(
            onPressed: () {
              unawaited(showModalBottomSheet<void>(
                context: context,
                backgroundColor: _skin.background,
                showDragHandle: false,
                isScrollControlled: true,
                builder: (ctx) => _sheetBody(),
              ));
            },
            child: const Text('open'),
          ),
        ),
        bottomNavigationBar: _miniPlayer(),
      );
    })));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final ctx = tester.element(find.text('IMPORT PLAYLIST'));
    toast(ctx, 'Added 3 tracks to "Jazz"');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // ignore: avoid_print
    print('SHEET sheet=${tester.getRect(find.byType(BottomSheet))} '
        'bars=${tester.widgetList(find.byType(SnackBar)).length} '
        'barRect=${tester.widgetList(find.byType(SnackBar)).isEmpty ? 'none' : tester.getRect(find.byType(SnackBar)).toString()}');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../.hermes/tmp/toast_sheet.png'),
    );
  });
}
