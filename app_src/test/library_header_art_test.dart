@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/theme/skin.dart';

Track _t(String id, String title) => Track(
      id: id,
      title: title,
      artist: 'ATLUS Sound Team',
      album: 'Persona 5',
      duration: const Duration(minutes: 4),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

const _artKey = Key('test-header-art');

Widget _screen({Widget? art, bool search = false}) => MaterialApp(
      home: Scaffold(
        body: LibraryScreen(
          tracks: [_t('a', 'Beneath the Mask'), _t('b', 'Last Surprise')],
          coverPathFor: (_) => null,
          skin: kSkinCrimson,
          searchOnly: search,
          headerArt: art,
        ),
      ),
    );

void main() {
  testWidgets('with no art the header renders plain — no strip, nothing to clip',
      (tester) async {
    await tester.pumpWidget(_screen());
    await tester.pump();

    expect(find.byKey(_artKey), findsNothing);
    expect(find.text('LIBRARY'), findsOneWidget);
  });

  testWidgets('A FIGURE CANNOT REACH THE ROWS — its slot ends at the body list',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _screen(
        art: const SizedBox(
          key: _artKey,

          height: 900,
          child: ColoredBox(color: Colors.red),
        ),
      ),
    );
    await tester.pump();

    final art = tester.getRect(find.byKey(_artKey));

    final body = tester.getRect(find.byType(ListView).first);

    expect(art.bottom, lessThanOrEqualTo(body.top + 1),
        reason: 'the character reached the body — its ruled art will land under every word, '
            'which is the underline defect coming back');
  });

  testWidgets('the figure never eats a tap — it is behind an IgnorePointer',
      (tester) async {
    await tester.pumpWidget(
      _screen(
        art: const SizedBox(key: _artKey, child: ColoredBox(color: Colors.red)),
      ),
    );
    await tester.pump();

    expect(
      find.ancestor(
        of: find.byKey(_artKey),
        matching: find.byType(IgnorePointer),
      ),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('SEARCH wears the figure FULL-SCREEN, faint — not Library\'s header strip',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _screen(
        search: true,
        art: const SizedBox(key: _artKey, child: ColoredBox(color: Colors.red)),
      ),
    );
    await tester.pump();

    expect(find.byKey(_artKey), findsOneWidget, reason: 'Search should show the figure');

    final opacities = tester
        .widgetList<Opacity>(find.ancestor(
          of: find.byKey(_artKey),
          matching: find.byType(Opacity),
        ))
        .map((o) => o.opacity)
        .toList();
    expect(opacities, isNotEmpty, reason: 'Search\'s figure is not faded at all');
    expect(opacities.reduce((a, b) => a < b ? a : b), lessThanOrEqualTo(0.3),
        reason: 'Search\'s figure is too strong to read as a watermark');

    final art = tester.getRect(find.byKey(_artKey));
    final screen = tester.getRect(find.byType(MaterialApp));
    expect(art.height, greaterThan(screen.height * 0.8),
        reason: 'Search\'s art is still confined to a strip');

    expect(
      find.ancestor(of: find.byKey(_artKey), matching: find.byType(IgnorePointer)),
      findsAtLeastNWidgets(1),
    );
    expect(find.text('SEARCH'), findsOneWidget);
  });
}
