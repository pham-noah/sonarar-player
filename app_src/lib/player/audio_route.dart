library;

import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter/services.dart';

const MethodChannel kAudioRouteChannel =
    MethodChannel('com.noah.personar/audio_route');

class AudioOutput {
  const AudioOutput({
    required this.id,
    required this.name,
    required this.kind,
    required this.active,
  });

  final int id;

  final String name;

  final String kind;

  final bool active;

  IconData get icon => switch (kind) {
        'bluetooth' => Icons.bluetooth_rounded,
        'headphones' => Icons.headphones_rounded,
        'usb' => Icons.usb_rounded,
        'hdmi' => Icons.tv_rounded,

        _ => Icons.phone_android_rounded,
      };

  static AudioOutput? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final kind = raw['kind'];
    if (id is! int || name is! String || kind is! String) return null;
    return AudioOutput(
      id: id,
      name: name,
      kind: kind,
      active: raw['active'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AudioOutput &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.active == active;

  @override
  int get hashCode => Object.hash(id, name, kind, active);
}

class AudioRoute {
  AudioRoute({MethodChannel? channel}) : _channel = channel ?? kAudioRouteChannel {
    _channel.setMethodCallHandler(_onCall);
  }

  final MethodChannel _channel;

  void Function(List<AudioOutput>)? onChanged;

  bool get canSwitch => _canSwitch;
  bool _canSwitch = false;

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'changed') return;
    final parsed = _parse(call.arguments);
    if (parsed.isNotEmpty) onChanged?.call(parsed);
  }

  Future<List<AudioOutput>> outputs() async {
    try {
      final canSwitch = await _channel.invokeMethod<bool>('canSwitch');
      _canSwitch = canSwitch ?? false;
      final raw = await _channel.invokeMethod<List<Object?>>('outputs');
      return _parse(raw);
    } on PlatformException {
      _canSwitch = false;
      return const [];
    } on MissingPluginException {
      _canSwitch = false;
      return const [];
    }
  }

  Future<bool> openSwitcher() async {
    try {
      return await _channel.invokeMethod<bool>('openSwitcher') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static List<AudioOutput> _parse(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (AudioOutput.fromMap(item) case final o?) o,
    ];
  }

  void dispose() => _channel.setMethodCallHandler(null);
}
