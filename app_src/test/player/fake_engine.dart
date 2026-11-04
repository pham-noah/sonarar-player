library;

import 'package:sonarar/playback/loop_controller.dart';
import 'package:sonarar/player/engine_window.dart';
import 'package:sonarar/player/playback_engine.dart';

/// An engine that records what was asked of it and answers what the test scripts.
///
/// Shared by the loader and the transport tests: both talk to `PlaybackEngine` and
/// neither should need just_audio to do it.
class FakeEngine implements PlaybackEngine {
  final List<String> calls = [];

  List<EngineEntry>? queued;
  List<EngineEntry>? edited;
  int? queuedIndex;
  String? singlePath;
  Duration? soughtTo;
  int? soughtIndex;
  double volume = 1;

  bool setQueueAnswer = true;
  bool loadAnswer = true;
  bool matchesAnswer = false;
  bool editAnswer = false;
  @override
  bool hasNext = false;

  @override
  bool hasPrevious = false;

  Duration _position = Duration.zero;
  bool _playing = false;
  String? _path;
  LoopController? _loop;

  @override
  Duration get position => _position;

  set position(Duration value) => _position = value;

  @override
  Duration? get duration => null;

  @override
  bool get isPlaying => _playing;

  @override
  String? get playingPath => _path;

  set playingPath(String? value) => _path = value;

  @override
  LoopController? get loop => _loop;

  @override
  set loop(LoopController? value) {
    _loop = value;
    calls.add('loop');
  }

  @override
  bool queueMatches(List<String> paths) {
    calls.add('queueMatches');
    return matchesAnswer;
  }

  @override
  Future<bool> setQueue(List<EngineEntry> items, {required int initialIndex}) async {
    calls.add('setQueue');
    queued = items;
    queuedIndex = initialIndex;
    return setQueueAnswer;
  }

  @override
  Future<bool> editQueue(List<EngineEntry> items, {required String keepPlaying}) async {
    calls.add('editQueue');
    edited = items;
    return editAnswer;
  }

  @override
  Future<bool> loadAndPlay(
    String absolutePath, {
    Duration? startAt,
    bool autoPlay = true,
    String title = '',
    String artist = '',
    String album = '',
    Uri? coverUri,
  }) async {
    calls.add('loadAndPlay');
    singlePath = absolutePath;
    return loadAnswer;
  }

  @override
  Future<void> skipNext() async {
    calls.add('skipNext');
  }

  @override
  Future<void> skipPrevious() async {
    calls.add('skipPrevious');
  }

  @override
  Future<void> seekToIndex(int index) async {
    calls.add('seekToIndex');
    soughtIndex = index;
  }

  @override
  Future<void> seek(Duration to) async {
    calls.add('seek');
    soughtTo = to;
  }

  @override
  Future<void> play() async {
    calls.add('play');
    _playing = true;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _playing = false;
  }

  @override
  Future<void> setVolume(double value) async {
    calls.add('setVolume');
    volume = value;
  }
}
