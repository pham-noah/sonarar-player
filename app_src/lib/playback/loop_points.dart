library;

import 'dart:convert';
import 'dart:io';

class LoopPoints {
  const LoopPoints({
    required this.trackId,
    this.introEnd,
    this.loopStart,
    this.loopEnd,
    this.loopCount = 0,
    this.fade = const Duration(seconds: 8),
  });

  final String trackId;

  final Duration? introEnd;

  final Duration? loopStart;

  final Duration? loopEnd;

  final int loopCount;

  final Duration fade;

  bool get hasLoop =>
      loopStart != null &&
      loopEnd != null &&
      loopEnd! > loopStart! &&
      loopCount > 0;

  bool get hasIntro => introEnd != null && introEnd! > Duration.zero;

  Map<String, dynamic> toJson() => {
        'track_id': trackId,
        if (introEnd != null) 'intro_end_ms': introEnd!.inMilliseconds,
        if (loopStart != null) 'loop_start_ms': loopStart!.inMilliseconds,
        if (loopEnd != null) 'loop_end_ms': loopEnd!.inMilliseconds,
        'loop_count': loopCount,
        'fade_ms': fade.inMilliseconds,
      };

  static LoopPoints? fromJson(Map<String, dynamic> json) {
    final id = json['track_id'];
    if (id is! String || id.isEmpty) return null;

    Duration? ms(String key) {
      final v = json[key];
      if (v is! num) return null;
      final d = Duration(milliseconds: v.toInt());
      return d > Duration.zero ? d : null;
    }

    return LoopPoints(
      trackId: id,
      introEnd: ms('intro_end_ms'),
      loopStart: ms('loop_start_ms'),
      loopEnd: ms('loop_end_ms'),
      loopCount: (json['loop_count'] as num?)?.toInt() ?? 0,
      fade: ms('fade_ms') ?? const Duration(seconds: 8),
    );
  }
}

class LoopPointStore {
  LoopPointStore(this.file);

  final File file;

  Future<Map<String, LoopPoints>> load() async {
    if (!file.existsSync()) return {};
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) return {};
      final out = <String, LoopPoints>{};
      for (final entry in raw) {
        if (entry is! Map<String, dynamic>) continue;
        final p = LoopPoints.fromJson(entry);
        if (p != null) out[p.trackId] = p;
      }
      return out;
    } on FormatException {
      return {};
    } on FileSystemException {
      return {};
    }
  }

  Future<void> save(Map<String, LoopPoints> points) async {
    final list = points.values.map((p) => p.toJson()).toList();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(list));
  }
}
