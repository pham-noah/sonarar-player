library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The play log is append-only and capped at four megabytes, and a play is
/// what writes to it. Re-reading it to find out what was just written is a
/// pass over that whole file — on the isolate that draws — for a line the
/// shell already holds in memory. One 4 MB read measured 59–100 ms in a
/// widget-test VM, and the append path used to do three of them per play plus
/// one per track change.
///
/// These are the four places that could quietly put the file back in front of
/// the tap, so they are pinned here rather than left to be rediscovered.
void main() {
  late final String src;

  setUpAll(() {
    src = File('lib/main.dart').readAsStringSync();
  });

  String bodyOf(String signature) {
    final start = src.indexOf(signature);
    expect(start, greaterThan(-1), reason: '$signature not found — did it move or get renamed?');

    var j = src.indexOf('(', start);
    var pdepth = 0;
    for (; j < src.length; j++) {
      if (src[j] == '(') pdepth++;
      if (src[j] == ')') {
        pdepth--;
        if (pdepth == 0) break;
      }
    }
    var i = src.indexOf('{', j);
    final open = i;
    var depth = 0;
    for (; i < src.length; i++) {
      if (src[i] == '{') depth++;
      if (src[i] == '}') {
        depth--;
        if (depth == 0) break;
      }
    }
    return src.substring(open, i + 1);
  }

  test('a recorded play does not read the log back off disk', () {
    final body = bodyOf('Future<void> _appendThenRefresh(');
    expect(body.contains('playLog.read('), isFalse,
        reason: 'the append path reads the log it just wrote — that is a pass over up to 4 MB, '
            'three times per play, on the frame the play is waiting for');
    expect(body.contains('_notePlay('), isTrue,
        reason: 'the event no longer reaches the in-memory log, so the new play is invisible '
            'to Archive, History and the Home rails until the app restarts');
  });

  test('the rails are derived twice on that path, and neither one reads disk', () {
    expect(bodyOf('void _applyRails(').contains('playLog'), isFalse,
        reason: '_applyRails went back to the file — it takes the events it was given');
    expect(bodyOf('Future<void> _refreshDerivedPlaylists(').contains('from ??'),
        isTrue,
        reason: '_refreshDerivedPlaylists no longer accepts the log it is handed, so the caller '
            'has to re-read the file to give it one');
  });

  test('a track change refreshes the rails on the NEXT frame, not this one', () {
    final changed = bodyOf('void _onTrackChanged(');
    expect(changed.contains('_refreshHomeRailsAfterFrame()'), isTrue,
        reason: 'the tap is waiting on a frame, and the rails are being derived in front of it');
    expect(changed.contains('_refreshHomeRails()'), isFalse);
    expect(bodyOf('void _refreshHomeRailsAfterFrame()').contains('addPostFrameCallback'),
        isTrue);
  });

  test('the playlist ranking reuses the play counts instead of re-walking the log', () {
    // The ranking runs inside build. Walking every event on every rebuild is
    // the part that grows with the log; the fold over playlists is not.
    final site = src.substring(src.indexOf('List<PlaylistPlays> get _libraryPlaylists'));
    expect(site.contains('counts: _playsByTrackCount'), isTrue,
        reason: '_libraryPlaylists fell back to counting every event per rebuild');
  });
}
