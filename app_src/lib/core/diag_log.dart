library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class LogLine {
  const LogLine(this.at, this.text);

  final DateTime at;
  final String text;

  String get stamp {
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    final s = at.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  bool get looksWrong {
    final t = text;
    return t.contains('failed') ||
        t.contains('FAILED') ||
        t.contains('UNCAUGHT') ||
        t.contains('FLUTTER_ERROR') ||
        t.contains('SHORTQUEUE') ||
        t.contains('superseded') ||
        t.contains('aborted') ||
        t.contains('Error') ||
        t.contains('error');
  }
}

class DiagLog extends ChangeNotifier {
  DiagLog({this.capacity = 500});

  final int capacity;

  final List<LogLine> _lines = [];

  List<LogLine> get lines => List.unmodifiable(_lines);

  int get length => _lines.length;

  bool get isEmpty => _lines.isEmpty;

  List<LogLine> get problems =>
      _lines.reversed.where((l) => l.looksWrong).toList(growable: false);

  File? _file;

  File? get file => _file;

  void attach() {
    if (_attached) return;
    _attached = true;
    final previous = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null && message.isNotEmpty) add(message);

      previous(message, wrapWidth: wrapWidth);
    };
  }

  bool _attached = false;

  Future<void> restore({File? file}) async {
    try {
      final f = file ?? File('${(await getApplicationSupportDirectory()).path}/diagnostics.log');
      _file = f;
      if (await f.exists()) {
        final text = await f.readAsString();
        final tail = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
        final keep = tail.length > capacity ? tail.sublist(tail.length - capacity) : tail;
        for (final l in keep) {
          _lines.add(LogLine(DateTime.now(), l));
        }
        if (keep.isNotEmpty) notifyListeners();
      }
    } catch (_) {
    }
  }

  void add(String text) {
    _lines.add(LogLine(DateTime.now(), text.trimRight()));
    if (_lines.length > capacity) {
      _lines.removeRange(0, _lines.length - capacity);
    }
    notifyListeners();
    _scheduleFlush(text);
  }

  void clear() {
    _lines.clear();
    _pending.clear();
    notifyListeners();
    final f = _file;
    if (f != null) {
      // ignore: discarded_futures
      f.writeAsString('').catchError((_) => f);
    }
  }

  final List<String> _pending = [];
  Timer? _flush;

  void _scheduleFlush(String text) {
    if (_file == null) return;
    _pending.add(text);
    _flush ??= Timer(const Duration(seconds: 2), () {
      _flush = null;
      // ignore: discarded_futures
      flush();
    });
  }

  Future<void> flush() async {
    final f = _file;
    if (f == null) return;
    final batch = List<String>.from(_pending);
    _pending.clear();
    if (batch.isEmpty) return;
    try {
      await f.writeAsString('${batch.join('\n')}\n', mode: FileMode.append);
    } catch (_) {
    }
  }

  String asText() {
    final b = StringBuffer();
    for (final l in _lines) {
      b.writeln('${l.stamp}  ${l.text}');
    }
    return b.toString();
  }
}
