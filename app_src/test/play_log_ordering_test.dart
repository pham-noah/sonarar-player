library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/play_log.dart';

PlayEvent _e(String id, {bool completed = true}) => PlayEvent(
      trackId: id,
      at: DateTime(2026, 10, 3, 12),
      band: 'morning',
      positionMs: completed ? 200000 : 5000,
      durationMs: 200000,
      raining: null,
    );

void main() {
  late Directory dir;
  late PlayLog log;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('personar_playlog_');
    log = PlayLog(File('${dir.path}/plays.jsonl'));
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('a completed append is visible to the NEXT read', () async {
    final ok = await log.append(_e('t1'));
    expect(ok, isTrue, reason: 'the append must report success');

    final events = await log.read();
    expect(events.map((e) => e.trackId), contains('t1'),
        reason: 'a refresh run after this must see the play');
  });

  test('successive appends keep their order', () async {
    await log.append(_e('a'));
    await log.append(_e('b'));
    await log.append(_e('c'));

    final ids = (await log.read()).map((e) => e.trackId).toList();
    expect(ids, ['a', 'b', 'c']);
  });

  test('a refresh before the append lands would miss it — the race is real',
      () async {
    final pending = log.append(_e('raced'));
    final early = await log.read();
    await pending;

    final after = await log.read();
    expect(after.map((e) => e.trackId), contains('raced'),
        reason: 'after the append resolves the event must be there');
    expect(early.length, lessThanOrEqualTo(after.length));
  });

  test('a play recorded as incomplete is still written', () async {
    await log.append(_e('skipped', completed: false));
    final events = await log.read();
    expect(events.single.completed, isFalse);
  });
}
