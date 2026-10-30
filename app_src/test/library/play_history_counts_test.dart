import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/compendium.dart';
import 'package:sonarar/library/play_log.dart';
import 'package:sonarar/library/track.dart';

/// Archive counts are read from the play log, and the log is only ever as good
/// as what close-out writes. This covers the join that kept going wrong: an
/// event on disk must be an event the archive counts.
void main() {
  test('a written play is a play the archive counts', () async {
    final dir = Directory.systemTemp.createTempSync('sonarar-plays-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final log = PlayLog(File('${dir.path}/plays.jsonl'));

    final track = Track(
      id: 'abc123',
      title: 'Last Train',
      artist: 'Sable Court',
      album: 'Downloaded',
      duration: Duration(milliseconds: 180000),
      file: 'Downloaded/last-train.mp3',
      cover: '',
      gainDb: null,
    );

    final at = DateTime(2026, 10, 30, 2, 0);
    // Two listens: the second is a repeat of the same track, which used to be
    // the case that never landed because the engine looped silently.
    await log.append(PlayEvent(
      trackId: track.id,
      at: at,
      band: 'night',
      positionMs: 45000,
      durationMs: 180000,
    ));
    await log.append(PlayEvent(
      trackId: track.id,
      at: at.add(const Duration(minutes: 3)),
      band: 'night',
      positionMs: 45000,
      durationMs: 180000,
    ));

    final events = await log.read();
    expect(events, hasLength(2), reason: 'a repeat is a second listen');

    final entries = buildCompendium(tracks: [track], events: events).entries;
    expect(entries, hasLength(1));
    expect(entries.first.plays, 2,
        reason: 'the archive counts every listen, repeats included');
  });
}
