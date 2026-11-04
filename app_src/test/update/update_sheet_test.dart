library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/l10n/app_localizations.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/update/update_service.dart';
import 'package:sonarar/update/update_sheet.dart';
import 'package:sonarar/update/update_ui.dart';

const _update = AppUpdate(
  version: '9.9.9',
  build: 99,
  apkUrl: 'https://example.test/a.apk',
  notesUrl: 'https://example.test/n',
  sizeBytes: 65 * 1024 * 1024,
  notes: 'Fixed the thing that was broken.',
);

UpdateUi _ui({AppUpdate? found, File? file}) => UpdateUi(
      check: () async => found,
      fetch: (update, onProgress) async {
        onProgress(0.4);
        return file;
      },
      install: (_) async => true,
    );

Widget _host(UpdateUi ui) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: UpdateSheetBody(ui: ui, skin: kSkinAbyss),
        ),
      ),
    );

void main() {
  testWidgets('with nothing asked yet it offers a check', (tester) async {
    await tester.pumpWidget(_host(_ui(found: null)));

    expect(find.text('SOFTWARE UPDATE'), findsOneWidget);
    expect(find.textContaining('CHECK'), findsOneWidget);
  });

  testWidgets('an available build shows the version, what changed, and how big',
      (tester) async {
    final ui = _ui(found: _update);
    await tester.pumpWidget(_host(ui));
    await ui.checkNow();
    await tester.pump();

    expect(find.textContaining('v9.9.9'), findsOneWidget);
    expect(find.textContaining('Fixed the thing that was broken'), findsOneWidget,
        reason: 'the release notes are the point of a dedicated sheet');
    expect(find.textContaining('65 MB'), findsOneWidget);
    expect(find.textContaining('DOWNLOAD'), findsOneWidget);
    expect(find.textContaining('INSTALL'), findsNothing,
        reason: 'nothing is downloaded yet');
  });

  testWidgets('downloading shows the percentage, then the install button',
      (tester) async {
    final ui = _ui(found: _update, file: File('${Directory.systemTemp.path}/x.apk'));
    await tester.pumpWidget(_host(ui));
    await ui.checkNow();
    await tester.pump();

    await ui.downloadNow();
    await tester.pump();

    expect(find.textContaining('INSTALL'), findsOneWidget);
    expect(find.textContaining('unknown apps'), findsOneWidget,
        reason: 'the one refusal worth explaining is explained before it happens');
  });

  testWidgets('up to date says so and offers another check', (tester) async {
    final ui = _ui(found: null);
    await tester.pumpWidget(_host(ui));
    await ui.checkNow();
    await tester.pump();

    expect(find.textContaining('newest'), findsOneWidget);
    expect(find.textContaining('CHECK AGAIN'), findsOneWidget);
  });

  testWidgets('a failed check is a sentence, not a spinner that never stops',
      (tester) async {
    final ui = UpdateUi(
      check: () async => throw const SocketException('offline'),
      fetch: (_, __) async => null,
      install: (_) async => false,
    );
    await tester.pumpWidget(_host(ui));
    await ui.checkNow();
    await tester.pump();

    expect(find.textContaining('Try again'), findsOneWidget);
  });
}
