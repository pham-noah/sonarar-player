@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/theme/skin.dart';

List<Track> _tracks(int n) => [
      for (var i = 0; i < n; i++)
        Track(
          id: 't$i',
          title: 'Track number $i',
          artist: 'ATLUS Sound Team',
          album: 'Persona 5 Royal',
          duration: const Duration(seconds: 180),
          file: 't$i.m4a',
          cover: '',
          gainDb: 0,
        ),
    ];

Future<void> _pump(
  WidgetTester tester, {
  SwipeOutcome Function(Track)? onQueue,
  SwipeOutcome Function(Track)? onLike,
  Set<String> liked = const {},
  int count = 3,

  bool searchOnly = true,
}) async {
  final tracks = _tracks(count);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: LibraryScreen(

          searchOnly: searchOnly,
        tracks: tracks,
        coverPathFor: (_) => null,
        skin: kSkinCrimson,

        playlists: PlaylistList(),
        onQueue: onQueue,
        onLike: onLike,
        likedIds: liked,
      ),
    ),
  ));
  await tester.pump();
}

Future<void> _swipe(WidgetTester tester, double dx, {String title = 'Track number 0'}) async {
  final g = await tester.startGesture(tester.getCenter(find.text(title)));
  await g.moveBy(Offset(dx.sign * 20, 0));
  await tester.pump();
  final steps = 8;
  for (var i = 0; i < steps; i++) {
    await g.moveBy(Offset(dx / steps, 0));
    await tester.pump();
  }
  await g.up();
  await tester.pump();
}

void main() {
  group('swipe RIGHT queues', () {
    testWidgets('a long right swipe adds the track to the queue', (tester) async {
      Track? queued;
      await _pump(tester, onQueue: (t) {
        queued = t;
        return SwipeOutcome.queued;
      });

      await _swipe(tester, kQueueThreshold + 40);

      expect(queued, isNotNull, reason: 'the swipe did not queue anything');
      expect(queued!.id, 't0');
    });

    testWidgets('a short right swipe queues NOTHING', (tester) async {
      var called = false;
      await _pump(tester, onQueue: (_) {
        called = true;
        return SwipeOutcome.queued;
      });

      await _swipe(tester, 40);

      expect(called, isFalse,
          reason: 'a stray horizontal drift must not queue a track');
    });
  });

  group('swipe LEFT likes', () {
    testWidgets('a long left swipe likes the track', (tester) async {
      Track? liked;
      await _pump(tester, onLike: (t) {
        liked = t;
        return SwipeOutcome.liked;
      });

      await _swipe(tester, -(kLikeThreshold + 40));

      expect(liked, isNotNull);
      expect(liked!.id, 't0');
    });

    testWidgets('a short left swipe likes NOTHING', (tester) async {
      var called = false;
      await _pump(tester, onLike: (_) {
        called = true;
        return SwipeOutcome.liked;
      });

      await _swipe(tester, -40);

      expect(called, isFalse);
    });

    testWidgets('liking does NOT remove the track from the library',
        (tester) async {
      await _pump(tester, onLike: (_) => SwipeOutcome.liked, count: 3);
      expect(find.text('Track number 0'), findsOneWidget);

      await _swipe(tester, -(kLikeThreshold + 40));

      expect(find.text('Track number 0'), findsOneWidget,
          reason: 'liking is not deleting — the row must stay');
    });
  });

  group('the row FOLLOWS the finger', () {
    testWidgets('it moves while the drag is in progress', (tester) async {
      await _pump(tester,
          onQueue: (_) => SwipeOutcome.queued,
          onLike: (_) => SwipeOutcome.liked);
      final before = tester.getTopLeft(find.text('Track number 0')).dx;

      final g = await tester.startGesture(
          tester.getCenter(find.text('Track number 0')));
      await g.moveBy(const Offset(20, 0));
      await tester.pump();
      await g.moveBy(const Offset(60, 0));
      await tester.pump();

      final during = tester.getTopLeft(find.text('Track number 0')).dx;
      expect(during, greaterThan(before),
          reason: 'the row did not follow the finger — the gesture is invisible');

      await g.up();
      await tester.pump();

      expect(tester.getTopLeft(find.text('Track number 0')).dx, before);
    });
  });

  group('likes live in the Playlists view now', () {
    testWidgets('Liked Songs appears as a playlist, always present',
        (tester) async {
      await _pump(tester, liked: {'t1'}, count: 3, searchOnly: false);
      await tester.tap(find.text('PLAYLISTS'));
      await tester.pump();

      expect(find.text('Liked Songs'), findsOneWidget);
    });
  });
}
