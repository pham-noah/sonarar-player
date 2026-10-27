library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/player/audio_engine.dart';

void main() {
  test('a plain path becomes a file uri', () {
    expect(
      fileUriForPath('/home/noah/Music/Sonarar/a.opus').toString(),
      'file:///home/noah/Music/Sonarar/a.opus',
    );
  });

  test('spaces are escaped, not left raw', () {
    final u = fileUriForPath('/m/Music/Album Artist/x.opus').toString();
    expect(u.contains(' '), isFalse, reason: 'a raw space breaks the loader');
    expect(u, contains('%20'));
  });

  test('non-ascii filenames survive, because this library is full of them', () {
    final u = fileUriForPath('/m/Sonarar/10年前の記憶 - 対峙.opus').toString();
    expect(u, startsWith('file:///'));

    expect(Uri.parse(u).pathSegments.isNotEmpty, isTrue);
  });

  test('a manifest-shaped path resolves to itself', () {
    const real =
        '/storage/emulated/0/Music/Sonarar/Album Artist/Album Name/3_31.opus';
    expect(Uri.decodeComponent(Uri.parse(fileUriForPath(real).toString()).path), real);
  });

  test('an ampersand in a folder name survives — the resume track is inside one',
      () {
    const real =
        '/storage/emulated/0/Music/Sonarar/Shayne Orok & Aliorok/I Like You The Most.m4a';
    final u = fileUriForPath(real).toString();
    expect(u, startsWith('file:///'));
    expect(u.contains(' '), isFalse, reason: 'raw space breaks the loader');
    final parsed = Uri.parse(u);
    expect(parsed.query, isEmpty,
        reason: 'the ampersand leaked into the query — the path was cut in two');
    expect(Uri.decodeComponent(parsed.path), real);
  });

  test('a folder and file both containing punctuation still resolves', () {
    const real =
        '/storage/emulated/0/Music/Sonarar/Album Artist/Gemini/Living With Determination -巌戸台分寮アレンジ.m4a';
    expect(Uri.decodeComponent(Uri.parse(fileUriForPath(real).toString()).path), real);
  });
}
