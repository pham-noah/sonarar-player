library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import '../theme/skin.dart';
import 'package:flutter/services.dart';

class SpectrumProbeScreen extends StatefulWidget {
  const SpectrumProbeScreen({super.key});

  @override
  State<SpectrumProbeScreen> createState() => _SpectrumProbeScreenState();
}

class _SpectrumProbeScreenState extends State<SpectrumProbeScreen> {
  final _lines = <String>[];
  bool _running = false;

  void _say(String s) {
    if (!mounted) return;
    setState(() => _lines.add(s));
    // ignore: avoid_print
    print('[SPECTRUM PROBE] $s');
  }

  Future<void> _run() async {
    final l10n = l10nOf(context);
    setState(() {
      _lines.clear();
      _running = true;
    });

    _say('Platform: ${Theme.of(context).platform}');
    _say('');
    _say(l10n.probeStep1);
    _say(l10n.probeStep1Note);

    const channel = MethodChannel('com.noah.personar/spectrum_probe');
    try {
      final has = await channel.invokeMethod<bool>('hasRecordAudio');
      _say('  hasRecordAudio -> $has');
      if (has == false) {
        final asked = await channel.invokeMethod<bool>('requestRecordAudio');
        _say('  requestRecordAudio -> $asked   (a dialog may have appeared)');
      }
    } on MissingPluginException {
      _say('  NO NATIVE HANDLER IS INSTALLED YET.');
      _say('  Expected: the Kotlin side of this probe is not written. See the note at the bottom.');
    } catch (e) {
      _say('  threw: $e');
    }

    _say('');
    _say(l10n.probeStep2);
    _say('Android Visualizer attaches to a session id. just_audio does not expose it, so the native side has to');
    _say('find the active media session itself.');

    _say('');
    _say(l10n.probeStep3);
    try {
      final code = await channel.invokeMethod<int>('attachVisualizer');
      _say('  attachVisualizer -> $code');
      _say(code == 0
          ? '  SUCCESS — the Visualizer attached. A live spectrum IS possible on this device.'
          : '  FAILED with result code $code.'
              ' -3 is ERROR_NO_INIT: no session, or the permission was not really granted.');
    } on MissingPluginException {
      _say('  NO NATIVE HANDLER IS INSTALLED YET.');
    } catch (e) {
      _say('  threw: $e');
    }

    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        foregroundColor: const Color(0xFFE3B84E),
        title: Text(l10nOf(context).probeTitle, style: TextStyle(fontSize: LayoutSpec.fontSmall, letterSpacing: 2)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _running ? null : _run,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE3B84E),
                  foregroundColor: Colors.black,
                ),
                child: Text(_running ? l10nOf(context).probeRunning : l10nOf(context).probeRun,
                    style: const TextStyle(fontSize: LayoutSpec.fontSmall, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  _lines.isEmpty ? l10nOf(context).probeHint : _lines.join('\n'),
                  style: const TextStyle(
                    fontSize: LayoutSpec.fontFloor,
                    height: 1.45,
                    color: Colors.white,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
