library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/player/spectrum_builder.dart';
import 'package:sonarar/widgets/spectrum.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late MethodChannel channel;
  late List<String> asked;
  Uint8List? reply;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('spectrum_builder_test');
    asked = <String>[];
    reply = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7]);
    channel = const MethodChannel('test/spectrum');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      asked.add(call.method);
      return reply;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  File binFor(String id) =>
      File('${dir.path}${Platform.pathSeparator}spectrum'
          '${Platform.pathSeparator}$id.bin');

  test('a miss builds the file, beside the audio where the player looks',
      () async {
    final builder = SpectrumBuilder(libraryRoot: dir.path, channel: channel);

    final built = await builder.ensure(trackId: 'abc', audioPath: '/x/abc.opus');

    expect(built, isTrue, reason: 'no file was built, so the bars would never appear');
    expect(binFor('abc').existsSync(), isTrue,
        reason: 'the file must land in <root>/spectrum/<id>.bin — the path SpectrumLibrary reads');
    expect(binFor('abc').readAsBytesSync(), reply);
    expect(asked, ['build']);
  });

  test('an EXISTING file is never rebuilt and never overwritten', () async {
    binFor('abc').parent.createSync(recursive: true);
    binFor('abc').writeAsBytesSync([9, 9, 9]);

    final builder = SpectrumBuilder(libraryRoot: dir.path, channel: channel);
    final built = await builder.ensure(trackId: 'abc', audioPath: '/x/abc.opus');

    expect(built, isFalse);
    expect(asked, isEmpty, reason: 'the bridge was asked to build a file that already exists');
    expect(binFor('abc').readAsBytesSync(), [9, 9, 9], reason: 'the good file was overwritten');
  });

  test('a decode that yields nothing writes NO file and is not retried', () async {
    reply = null;
    final builder = SpectrumBuilder(libraryRoot: dir.path, channel: channel);

    expect(await builder.ensure(trackId: 'abc', audioPath: '/x/abc.opus'), isFalse);
    expect(binFor('abc').existsSync(), isFalse,
        reason: 'an empty file would be read as "a spectrum with no frames"');
    expect(await builder.ensure(trackId: 'abc', audioPath: '/x/abc.opus'), isFalse);
    expect(asked.length, 1, reason: 'a failed decode was attempted twice');
  });

  test('no library root means it does nothing rather than guessing a path', () async {
    final builder = SpectrumBuilder(libraryRoot: null, channel: channel);
    expect(await builder.ensure(trackId: 'abc', audioPath: '/x/abc.opus'), isFalse);
    expect(asked, isEmpty);
  });

  test('the bytes the device writes parse as the format the player reads', () async {
    expect(TrackSpectrum.kSpectrumBands, 7);
    expect(TrackSpectrum.kSpectrumFps, 20);

    reply = Uint8List.fromList(List<int>.generate(21, (i) => i));
    final builder = SpectrumBuilder(libraryRoot: dir.path, channel: channel);
    await builder.ensure(trackId: 'abc', audioPath: '/x/abc.opus');

    final parsed = TrackSpectrum.parse(binFor('abc').readAsBytesSync());
    expect(parsed.bands, 7);
    expect(parsed.frameCount, 3);

    expect(parsed.at(const Duration(milliseconds: 0))[1], 1);

    expect(parsed.at(const Duration(milliseconds: 50))[0], 7);
  });
}
