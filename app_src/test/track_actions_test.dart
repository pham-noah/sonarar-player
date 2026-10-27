@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/widgets/track_actions.dart';

int _taps = 0;

Widget _host({
  int actions = 4,
  bool withAudio = true,
  bool audioOpen = false,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: TrackActions(
              skin: kSkinCrimson,
              audioOpen: audioOpen,
              onAudio: withAudio ? () => _taps++ : null,
              actions: [
                for (var i = 0; i < actions; i++)
                  SizedBox(
                    key: ValueKey('action-$i'),
                    width: LayoutSpec.secondaryActionWidth,
                    height: LayoutSpec.secondaryActionHeight,
                    child: const ColoredBox(color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  setUp(() => _taps = 0);

  testWidgets('FIVE buttons, all the same size', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      expect(
        tester.getSize(find.byKey(ValueKey('action-$i'))),
        const Size(
            LayoutSpec.secondaryActionWidth, LayoutSpec.secondaryActionHeight),
      );
    }
    expect(find.byKey(TrackActions.audioButtonKey), findsOneWidget);
  });

  testWidgets('the AUDIO button is the SAME device as its neighbours',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    final audio = tester.getSize(find.byKey(TrackActions.audioButtonKey));
    final other = tester.getSize(find.byKey(const ValueKey('action-0')));
    expect(audio, other,
        reason: 'the audio button is a different size from the row it sits in');
  });

  testWidgets('there is NO slider in the row', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('pressing AUDIO opens the door, and the row does NOT move',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    final before = tester.getRect(find.byKey(const ValueKey('action-0')));

    await tester.tap(find.byKey(TrackActions.audioButtonKey));
    await tester.pumpAndSettle();

    expect(_taps, 1, reason: 'the audio door was not called');

    final after = tester.getRect(find.byKey(const ValueKey('action-0')));
    expect(after, before, reason: 'the row moved when the door opened');
  });

  testWidgets('the actions stay TAPPABLE — nothing is parked or inert',
      (tester) async {
    await tester.pumpWidget(_host(audioOpen: true));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(ValueKey('action-$i')).hitTestable(), findsOneWidget,
          reason: 'action $i is not pressable while the audio panel is open');
    }
  });

  testWidgets('an open panel marks the button as the active one', (tester) async {
    await tester.pumpWidget(_host(audioOpen: true));
    await tester.pumpAndSettle();
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(TrackActions.audioButtonKey),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((container.decoration! as BoxDecoration).color, kSkinCrimson.accent,
        reason: 'the audio button does not show that its panel is open');
  });

  testWidgets('no AUDIO button when there is no panel to open', (tester) async {
    await tester.pumpWidget(_host(withAudio: false));
    await tester.pumpAndSettle();
    expect(find.byKey(TrackActions.audioButtonKey), findsNothing);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('the row is CENTRED, which is where the fold had left it flush',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final row = tester.getRect(find.byType(TrackActions));
    final first = tester.getRect(find.byKey(const ValueKey('action-0')));
    final last = tester.getRect(find.byKey(TrackActions.audioButtonKey));
    final leftGap = first.left - row.left;
    final rightGap = row.right - last.right;
    expect((leftGap - rightGap).abs(), lessThan(1.0),
        reason: 'the row is not centred (left $leftGap, right $rightGap)');
  });
}
