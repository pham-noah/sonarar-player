import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/art/art_focus.dart';
import 'package:sonarar/widgets/framed_art.dart';

/// The burn must be a mask, and it must be off when it is not asked for.
///
/// Rendering to an image inside a widget test hangs on this compositor, so this
/// checks the layer that is actually inserted: `dstIn` against a radial
/// gradient is the dissolve. A painted overlay would be a dark child instead,
/// and that darkens the middle of the picture as well.
void main() {
  Future<void> pump(WidgetTester tester, double burn) async {
    await tester.pumpWidget(
      Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: FramedArt(
            assetPath: 'assets/brand/logo_mark.png',
            aspect: 1.0,
            focus: ArtFocus.centre,
            burn: burn,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('burn on inserts a dstIn mask', (tester) async {
    await pump(tester, 1.0);
    final masks = tester.widgetList<ShaderMask>(find.byType(ShaderMask));
    expect(masks, isNotEmpty,
        reason: 'no ShaderMask — the art still ends at a cut edge');
    expect(
      masks.any((m) => m.blendMode == BlendMode.dstIn),
      isTrue,
      reason: 'the mask is not dstIn, so it cannot dissolve the edges',
    );
  });

  testWidgets('burn off inserts none, so existing screens are untouched',
      (tester) async {
    await pump(tester, 0.0);
    expect(find.byType(ShaderMask), findsNothing);
  });
}
