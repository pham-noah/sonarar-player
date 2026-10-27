library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no song surface is left on the old replace-on-press entry point', () {
    final src = File('lib/main.dart').readAsStringSync();

    final bare = RegExp(r'widget\.state\.playTrack\(t\)').allMatches(src).length;
    expect(bare, lessThanOrEqualTo(1),
        reason: 'a song row is still calling `playTrack`, which REPLACES the queue — "pressing the song in '
            'the library, search and home will add the song and then play that song". Found $bare bare calls; '
            'at most one is allowed (the "why this song" panel pick), and any song row must use '
            '`playTrackElsewhere`.');

    final shared = RegExp(r'widget\.state\.playTrackElsewhere\(').allMatches(src).length;
    expect(shared, greaterThanOrEqualTo(3),
        reason: 'expected the Library (both arrangements), Search and Home to route through '
            '`playTrackElsewhere`; found $shared call sites');
  });
}
