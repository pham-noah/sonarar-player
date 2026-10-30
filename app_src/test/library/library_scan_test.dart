library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/library_scan.dart';

/// The scan is the part that says where a file *is*, so these tests write real
/// files to a real directory and ask it. No fakes: the whole point is that the
/// filesystem is the authority.
void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sonarar-scan-test');
  });

  tearDown(() async {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  File put(String relative, {int bytes = 8}) {
    final file = File('${root.path}/$relative');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(List<int>.filled(bytes, 0));
    return file;
  }

  test('a file at the path the manifest names resolves to itself', () async {
    put('Artist/Album/01 Song.mp3');
    final scan = await LibraryScan.of(root.path);

    expect(scan.holds('Artist/Album/01 Song.mp3'), isTrue);
    expect(scan.resolve('Artist/Album/01 Song.mp3'),
        '${root.path}/Artist/Album/01 Song.mp3');
  });

  test('a file that is not there resolves to nothing, and is not guessed at',
      () async {
    put('Artist/Album/01 Song.mp3');
    final scan = await LibraryScan.of(root.path);

    expect(scan.resolve('Artist/Album/02 Gone.mp3'), isNull);
    expect(scan.holds('Artist/Album/02 Gone.mp3'), isFalse);
  });

  test('a renamed or moved file is found by name, so the track still plays',
      () async {
    put('New Folder/01 Song.mp3');
    final scan = await LibraryScan.of(root.path);

    expect(scan.resolve('Artist/Album/01 Song.mp3'),
        '${root.path}/New Folder/01 Song.mp3');
    expect(scan.resolveRelative('Artist/Album/01 Song.mp3'),
        'New Folder/01 Song.mp3');
  });

  test('two files with the same name are ambiguous, so neither is chosen',
      () async {
    put('A/01 Song.mp3');
    put('B/01 Song.mp3');
    final scan = await LibraryScan.of(root.path);

    expect(scan.resolve('C/01 Song.mp3'), isNull,
        reason: 'playing the wrong song is worse than reporting a missing one');
  });

  test('only audio counts as audio', () async {
    put('a.mp3');
    put('b.FLAC');
    put('notes.txt');
    put('cover.jpg');
    final scan = await LibraryScan.of(root.path);

    expect(scan.audioFiles, unorderedEquals(['a.mp3', 'b.FLAC']));
    expect(LibraryScan.isAudio('x/y.opus'), isTrue);
    expect(LibraryScan.isAudio('x/y.jpg'), isFalse);
  });

  test('an unreadable root comes back readable=false, not an exception',
      () async {
    final scan = await LibraryScan.of('${root.path}/does-not-exist');

    expect(scan.isReadable, isFalse);
    expect(scan.resolve('anything.mp3'), isNull,
        reason: 'callers fall back to the stored path, as before');
  });

  test('a scan is stale after an hour and fresh before it', () async {
    final now = DateTime.now();
    put('a.mp3');
    final scan = await LibraryScan.of(root.path, now: now);

    expect(scan.isStale(now.add(const Duration(minutes: 59))), isFalse);
    expect(scan.isStale(now.add(const Duration(minutes: 61))), isTrue);
    expect(const LibraryScan.unreadable('').isStale(now), isTrue);
  });

  test('windows separators in the manifest still resolve on a posix path',
      () async {
    put('Artist/01 Song.mp3');
    final scan = await LibraryScan.of(root.path);

    expect(scan.resolve(r'Artist\01 Song.mp3'),
        '${root.path}/Artist/01 Song.mp3');
  });

  test('a leading slash in the manifest is not a second root', () async {
    put('Artist/01 Song.mp3');
    final scan = await LibraryScan.of(root.path);

    expect(scan.resolve('/Artist/01 Song.mp3'),
        '${root.path}/Artist/01 Song.mp3');
  });

  test('the walk does not follow symlinks into a loop', () async {
    put('Artist/01 Song.mp3');
    final loop = Link('${root.path}/Artist/back');
    try {
      loop.createSync(root.path);
    } on FileSystemException {
      markTestSkipped('this filesystem does not allow links');
      return;
    }
    final scan = await LibraryScan.of(root.path);

    expect(scan.holds('Artist/01 Song.mp3'), isTrue);
  });
}
