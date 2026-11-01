import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/l10n/script.dart';

void main() {
  test('a script without upper case is recognised, a script subtag is not a language', () {
    expect(isCaseless('ja'), isTrue);
    expect(isCaseless('zh-Hans'), isTrue);
    expect(isCaseless('ko'), isTrue);
    expect(isCaseless('en'), isFalse);
    expect(isCaseless('fi'), isFalse);
    expect(isCaseless('vi'), isFalse);
  });

  testWidgets('a Japanese label keeps its case and its grid', (tester) async {
    late String shouted;
    late String kept;
    late double tracking;

    // Localizations, not MaterialApp: without a delegate for the locale the
    // app falls back to English and this test would pass for the wrong reason.
    await tester.pumpWidget(Localizations(
      locale: const Locale('ja'),
      delegates: const [DefaultWidgetsLocalizations.delegate],
      child: Builder(builder: (context) {
        shouted = capsFor(context, 'Night Hour');
        kept = capsFor(context, '夜の時間');
        tracking = trackingFor(context, 4);
        return const SizedBox();
      }),
    ));

    // Japanese has no upper case, so a label that was shouted in English is
    // simply not shouted — and it is not stretched off its grid either.
    expect(shouted, 'Night Hour');
    expect(kept, '夜の時間');
    expect(tracking, 0);
  });

  testWidgets('an English label still shouts', (tester) async {
    late String shouted;
    late double tracking;

    await tester.pumpWidget(Localizations(
      locale: const Locale('en'),
      delegates: const [DefaultWidgetsLocalizations.delegate],
      child: Builder(builder: (context) {
        shouted = capsFor(context, 'Night Hour');
        tracking = trackingFor(context, 4);
        return const SizedBox();
      }),
    ));

    expect(shouted, 'NIGHT HOUR');
    expect(tracking, 4);
  });
}
