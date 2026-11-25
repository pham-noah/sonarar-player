library;

// The tab strips are the one place in the app where a label has no room to
// escape: three tabs share the width, so the longest word decides whether the
// others fit. Finnish is the longest of the five shipped locales and 320dp the
// narrowest phone the app supports, and there "JÄRJESTELMÄ" was being clipped
// mid-glyph — drawn as "JÄRJESTEL", which is not a word.
//
// The fix scales a label down rather than cutting it, which is a compromise:
// past a point the label is technically whole and practically unreadable. This
// test pins both ends — nothing may clip, and nothing may shrink below 65%,
// which is the worst the five locales actually reach (Finnish at 320dp with the
// system font at 130%). A fourth tab or a longer translation trips it.
//
// Fonts are loaded for real. The test font is a box per glyph, which overstates
// narrow labels and would have missed this.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/l10n/app_localizations.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/settings_screen.dart';

/// The narrowest phone still in the Play catalogue, and the one the layout is
/// allowed to be dense on.
const _narrowest = 320.0;

/// Below this a label is whole but too small to read, which is not a fix.
const _floor = 0.65;

Track _t(String id) => Track(
      id: id,
      title: 'Living With Determination',
      artist: 'ATLUS Sound Team',
      album: 'Persona 3 Reload',
      duration: const Duration(seconds: 208),
      file: '$id.opus',
      cover: '',
      gainDb: -3.0,
    );

/// One tab label as it was actually painted: the width it wanted, the width it
/// was given, and the fraction it had to give up.
class _Fit {
  _Fit(this.label, this.natural, this.avail);

  final String label;
  final double natural;
  final double avail;

  double get factor => avail / natural;

  @override
  String toString() =>
      '"$label" wants ${natural.round()} in ${avail.round()} '
      '(${(factor * 100).round()}%)';
}

Future<List<_Fit>> _tabFits(WidgetTester tester, String locale, double width,
    double scale) async {
  tester.view.physicalSize = Size(width, 860) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MediaQuery(
    data: MediaQueryData(
        size: Size(width, 860), textScaler: TextScaler.linear(scale)),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SettingsScreen(state: AppState()..attachLibrary([_t('a')]))),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  final fits = <_Fit>[];
  for (final element in find.byType(Text).evaluate()) {
    // Only labels inside a scale-down box: those are the tab strip's.
    if (element.findAncestorWidgetOfExactType<FittedBox>() == null) continue;
    final paragraph = element.renderObject;
    final box = paragraph?.parent;
    if (paragraph is! RenderParagraph || box is! RenderFittedBox) continue;
    final avail = box.constraints.maxWidth;
    if (!avail.isFinite) continue;
    fits.add(_Fit(paragraph.text.toPlainText(), paragraph.size.width, avail));
  }
  return fits;
}

Future<void> _loadFonts() async {
  final dir = _materialFontsDir();
  if (dir == null) {
    fail('no material fonts under the Flutter SDK: this test needs real glyph '
        'widths, and the test font would make it pass vacuously');
  }
  for (final face in const [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ]) {
    final file = File('${dir.path}/$face');
    if (!file.existsSync()) continue;
    final bytes = ByteData.sublistView(await file.readAsBytes());
    await (FontLoader('Roboto')..addFont(Future.value(bytes))).load();
  }
  final icons = File('${dir.path}/materialicons-regular.otf');
  if (icons.existsSync()) {
    final bytes = ByteData.sublistView(await icons.readAsBytes());
    await (FontLoader('MaterialIcons')..addFont(Future.value(bytes))).load();
  }
}

Directory? _materialFontsDir() {
  final candidates = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final root?)
      '$root/bin/cache/artifacts/material_fonts',
  ];
  // flutter_tester lives a few levels below the SDK root.
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 6; i++) {
    candidates.add('${dir.path}/bin/cache/artifacts/material_fonts');
    dir = dir.parent;
  }
  for (final path in candidates) {
    final d = Directory(path);
    if (d.existsSync()) return d;
  }
  return null;
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('every tab label fits a 320dp phone in every locale',
      (tester) async {
    final complaints = <String>[];

    for (final locale in AppLocalizations.supportedLocales.map((l) => l.languageCode)) {
      for (final scale in const [1.0, 1.3]) {
        final fits = await _tabFits(tester, locale, _narrowest, scale);
        expect(fits, isNotEmpty,
            reason: 'no tab labels found for $locale — the probe is measuring '
                'nothing, which is worse than a failure');

        for (final fit in fits) {
          if (fit.factor < _floor) {
            complaints.add('$locale @ ${scale}x: $fit');
          }
        }
      }
    }

    expect(complaints, isEmpty,
        reason: 'these tab labels had to shrink past ${(_floor * 100).round()}% '
            'to fit a ${_narrowest.round()}dp phone, so they are painted too '
            'small to read:\n${complaints.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
