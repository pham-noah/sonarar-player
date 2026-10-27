library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/diag_log.dart';

void main() {
  group('DiagLog', () {
    test('captures a printed line', () {
      final log = DiagLog();
      log.add('[Sonarar][LOAD] #1 first items=24');
      expect(log.length, 1);
      expect(log.lines.first.text, contains('items=24'));
    });

    test('keeps the newest lines and drops the oldest at capacity', () {
      final log = DiagLog(capacity: 3);
      for (var i = 1; i <= 5; i++) {
        log.add('line $i');
      }
      expect(log.length, 3);
      expect(log.lines.map((l) => l.text), ['line 3', 'line 4', 'line 5']);
    });

    test('problems keeps only the lines that look wrong, newest first', () {
      final log = DiagLog();
      log.add('[Sonarar][LOAD] #1 first items=24');
      log.add('[Sonarar][LOAD] #2 FAILED: Connection aborted');
      log.add('[Sonarar][QUEUE] context switch admitted 220 of 279');
      log.add('[Sonarar][SHORTQUEUE] order=1');

      final problems = log.problems;
      expect(problems.length, 2);

      expect(problems.first.text, contains('SHORTQUEUE'));
      expect(problems.last.text, contains('Connection aborted'));

      expect(problems.any((l) => l.text.contains('220 of 279')), isFalse);
    });

    test('a superseded load counts as worth reading, because it moved the queue', () {
      final log = DiagLog();
      log.add('[Sonarar][LOAD] #4 superseded mid-setup, ignored');
      expect(log.problems, hasLength(1));
    });

    test('clear empties it', () {
      final log = DiagLog();
      log.add('something');
      log.clear();
      expect(log.isEmpty, isTrue);
      expect(log.problems, isEmpty);
    });

    test('asText stamps every line in reading order', () {
      final log = DiagLog();
      log.add('first');
      log.add('second');
      final text = log.asText();
      expect(text.indexOf('first'), lessThan(text.indexOf('second')));

      expect(text, matches(RegExp(r'\d\d:\d\d:\d\d  first')));
    });

    test('attach captures prints AND still forwards them', () {
      final log = DiagLog();
      final original = debugPrint;
      var forwarded = 0;
      debugPrint = (String? message, {int? wrapWidth}) {
        forwarded++;
        original(message, wrapWidth: wrapWidth);
      };
      try {
        log.attach();
        debugPrint('hello from a probe');
        expect(log.length, 1, reason: 'the line must be captured');
        expect(log.lines.first.text, contains('hello from a probe'));
        expect(forwarded, 1, reason: 'and still forwarded to whoever had it');
      } finally {
        debugPrint = original;
      }
    });

    test('the mirror file round-trips through disk', () async {
      final dir = Directory.systemTemp.createTempSync('diag');
      final file = File('${dir.path}/diagnostics.log');
      try {
        final first = DiagLog(capacity: 10);
        await first.restore(file: file);
        first.add('[Sonarar][LOAD] #1 first items=24');
        first.add('[Sonarar][LOAD] #2 FAILED: Connection aborted');
        await first.flush();

        expect(file.existsSync(), isTrue);
        final onDisk = file.readAsStringSync();
        expect(onDisk, contains('items=24'));
        expect(onDisk, contains('Connection aborted'));

        final second = DiagLog(capacity: 10);
        await second.restore(file: file);
        expect(second.length, 2);
        expect(second.problems, hasLength(1));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('attach twice does not double-capture', () {
      final log = DiagLog();
      final original = debugPrint;
      try {
        log.attach();
        log.attach();
        debugPrint('once');
        expect(log.length, 1);
      } finally {
        debugPrint = original;
      }
    });
  });
}
