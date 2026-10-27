library;

import 'dart:async';

import 'package:flutter/material.dart';
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
    setState(() {
      _lines.clear();
      _running = true;
    });

    _say('Platform: ${Theme.of(context).platform}');
    _say('');
    _say('STEP 1 — the permission');
    _say('The first attempt failed at the GRANT, so this is the question.');

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
    _say('STEP 2 — the audio session');
    _say('Android Visualizer attaches to a session id. just_audio does not expose it, so the native side has to');
    _say('find the active media session itself.');

    _say('');
    _say('STEP 3 — the Visualizer');
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
        title: const Text('SPECTRUM PROBE', style: TextStyle(fontSize: 18, letterSpacing: 2)),
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
                child: Text(_running ? 'RUNNING…' : 'RUN THE PROBE',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  _lines.isEmpty ? 'Press the button, then send me what appears here.' : _lines.join('\n'),
                  style: const TextStyle(
                    fontSize: 16,
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
