library;

import 'dart:convert';
import 'dart:io';

class PlayEvent {
  const PlayEvent({
    required this.trackId,
    required this.at,
    required this.band,
    required this.positionMs,
    required this.durationMs,
    this.raining,
    this.mode,
  });

  final String trackId;
  final DateTime at;

  final String band;

  final int positionMs;
  final int durationMs;

  final bool? raining;

  final String? mode;

  bool get completed =>
      durationMs > 0 && (durationMs - positionMs) <= 5000;

  Map<String, dynamic> toJson() => {
        'track_id': trackId,
        'at': at.toIso8601String(),
        'band': band,
        'position_ms': positionMs,
        'duration_ms': durationMs,

        if (raining != null) 'raining': raining,
        if (mode != null) 'mode': mode,
      };

  static PlayEvent? fromJson(Map<String, dynamic> json) {
    final id = json['track_id'];
    final at = json['at'];
    if (id is! String || id.isEmpty || at is! String) return null;
    final when = DateTime.tryParse(at);
    if (when == null) return null;
    return PlayEvent(
      trackId: id,
      at: when,
      band: (json['band'] ?? '').toString(),
      positionMs: (json['position_ms'] as num?)?.toInt() ?? 0,
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,

      raining: json['raining'] is bool ? json['raining'] as bool : null,
      mode: json['mode'] is String ? json['mode'] as String : null,
    );
  }
}

const int kMinPlayMs = 10000;

bool isCountedPlay(PlayEvent e) => e.completed || e.positionMs >= kMinPlayMs;

enum AutoAdvance { next, replay, stop }

class PlayLog {
  PlayLog(this.file, {this.maxReadBytes = 4 * 1024 * 1024});

  final File file;

  final int maxReadBytes;

  Future<bool> append(PlayEvent e) async {
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString('${jsonEncode(e.toJson())}\n',
          mode: FileMode.append);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  Future<List<PlayEvent>> read() async {
    if (!file.existsSync()) return const [];
    try {
      final stat = await file.stat();
      final start = stat.size > maxReadBytes ? stat.size - maxReadBytes : 0;
      final raf = await file.open();
      try {
        if (start > 0) await raf.setPosition(start);
        final raw = await raf.read(stat.size - start);
        var text = utf8.decode(raw, allowMalformed: true);

        if (start > 0) {
          final nl = text.indexOf('\n');
          text = nl < 0 ? '' : text.substring(nl + 1);
        }
        final out = <PlayEvent>[];
        for (final line in text.split('\n')) {
          if (line.trim().isEmpty) continue;
          try {
            final parsed = jsonDecode(line);
            if (parsed is! Map<String, dynamic>) continue;
            final e = PlayEvent.fromJson(parsed);
            if (e != null) out.add(e);
          } on FormatException {
            continue;
          }
        }
        return out;
      } finally {
        await raf.close();
      }
    } on FileSystemException {
      return const [];
    }
  }

  Future<int> count() async {
    if (!file.existsSync()) return 0;
    try {
      final text = await file.readAsString();
      return text.split('\n').where((l) => l.trim().isNotEmpty).length;
    } on FileSystemException {
      return 0;
    }
  }
}
