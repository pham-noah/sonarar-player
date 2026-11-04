/// One update check, from "is there anything?" to "install it".
///
/// The check used to be a bar you tapped, which downloaded immediately and handed
/// the file to the system installer — no notes, no size, no choice, and nowhere to
/// say why a download failed. This is the state behind a proper sheet: the phases
/// are explicit, and checking, downloading and installing are injected so each can
/// be driven in a test without a network or an installer.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'update_service.dart';

enum UpdatePhase {
  /// Nothing has been asked yet — the sheet offers a check.
  idle,

  checking,

  /// The check came back with nothing newer.
  upToDate,

  /// There is a build to offer: [UpdateUi.release] says which.
  available,

  downloading,

  /// The APK is on disk and waiting for the system installer.
  ready,

  /// The check itself failed (offline, GitHub unreachable).
  failed,
}

class UpdateUi extends ChangeNotifier {
  UpdateUi({
    required this.check,
    required this.fetch,
    required this.install,
    this.onOffer,
  });

  /// Asks the release feed. Null means "already newest".
  final Future<AppUpdate?> Function() check;

  /// Downloads [AppUpdate] and reports 0..1 through the callback. Null means the
  /// download did not finish and nothing should be installed.
  final Future<File?> Function(AppUpdate update, void Function(double) onProgress)
      fetch;

  /// Hands a finished APK to the system installer. False when it refused.
  final Future<bool> Function(File apk) install;

  /// Called whenever a check finds something, so the shell's bar can show it
  /// without polling this object.
  final void Function(AppUpdate? update)? onOffer;

  UpdatePhase _phase = UpdatePhase.idle;
  UpdatePhase get phase => _phase;

  AppUpdate? _release;
  AppUpdate? get release => _release;

  double _progress = 0;
  double get progress => _progress;

  File? _apk;
  File? get apk => _apk;

  String? _failure;
  String? get failure => _failure;

  bool _open = false;
  bool get isOpen => _open;

  /// Opens the sheet. [known] is an update already in hand (the bar was showing
  /// one); without it the sheet checks as soon as it is asked.
  void open({AppUpdate? known}) {
    _open = true;
    if (known != null) {
      _release = known;
      _apk = null;
      _failure = null;
      _phase = UpdatePhase.available;
      notifyListeners();
      return;
    }
    if (_phase == UpdatePhase.available ||
        _phase == UpdatePhase.downloading ||
        _phase == UpdatePhase.ready) {
      notifyListeners();
      return;
    }
    notifyListeners();
    unawaitedCheck();
  }

  void close() {
    if (!_open) return;
    _open = false;
    notifyListeners();
  }

  void unawaitedCheck() {
    // ignore: discarded_futures
    checkNow();
  }

  Future<void> checkNow() async {
    if (_phase == UpdatePhase.checking || _phase == UpdatePhase.downloading) return;
    _phase = UpdatePhase.checking;
    _release = null;
    _apk = null;
    _failure = null;
    notifyListeners();

    try {
      final found = await check();
      _phase = found == null ? UpdatePhase.upToDate : UpdatePhase.available;
      _release = found;
      onOffer?.call(found);
    } catch (e) {
      _phase = UpdatePhase.failed;
      _failure = '$e';
      onOffer?.call(null);
    }
    notifyListeners();
  }

  Future<void> downloadNow() async {
    final update = _release;
    if (update == null) return;
    if (_phase == UpdatePhase.downloading) return;

    _phase = UpdatePhase.downloading;
    _progress = 0;
    _failure = null;
    notifyListeners();

    try {
      final file = await fetch(update, (p) {
        _progress = p.clamp(0.0, 1.0);
        notifyListeners();
      });
      if (file == null) {
        _phase = UpdatePhase.failed;
        _failure = 'incomplete';
      } else {
        _apk = file;
        _phase = UpdatePhase.ready;
      }
    } catch (e) {
      _phase = UpdatePhase.failed;
      _failure = '$e';
    }
    notifyListeners();
  }

  /// Offers the finished APK to the installer.
  ///
  /// A refusal is not an error: Android's "install unknown apps" gate has to be
  /// allowed once, and the sheet says so next to the button that stays put.
  Future<void> installNow() async {
    final file = _apk;
    if (file == null) return;
    final started = await install(file);
    if (!started) {
      _phase = UpdatePhase.ready;
      _failure = 'refused';
      notifyListeners();
    }
  }
}

/// Sizes for the sheet, in whole megabytes.
int megabytesOf(int bytes) => (bytes / (1024 * 1024)).round();
