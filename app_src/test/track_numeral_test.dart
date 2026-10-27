@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/widgets/devices.dart';

Future<Size> _render(WidgetTester tester, int value) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BigNumeral(skin: kSkinCrimson, value: value, dim: true),
      ),
    ),
  );
  await tester.pump();
  return tester.getSize(find.byType(BigNumeral));
}

void main() {
  testWidgets('it is narrower than it was — 38 -> 30', (tester) async {
    expect((await _render(tester, 42)).width, 30.0,
        reason: 'the numeral column is wider than the 30 he asked for');
  });

  testWidgets('THREE digits and FOUR digits occupy the SAME width',
      (tester) async {
    final three = await _render(tester, 999);
    final four = await _render(tester, 1000);
    expect(four.width, three.width,
        reason: 'the column changes width at four digits, so the rows stop aligning');
  });

  testWidgets('a four-digit number does not overflow its column',
      (tester) async {
    final size = await _render(tester, 1234);
    expect(size.width, lessThanOrEqualTo(30.0),
        reason: 'the numeral grew past the width it is given');
  });

  testWidgets('one digit takes the same column as four', (tester) async {
    expect((await _render(tester, 7)).width, (await _render(tester, 1000)).width);
  });
}
