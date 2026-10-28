library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/romaji.dart';

void main() {
  group('detection is a range check, not a guess', () {
    test('hiragana, katakana and kanji are Japanese', () {
      expect(Romaji.isJapanese('きみのこえ'), isTrue, reason: 'hiragana');
      expect(Romaji.isJapanese('キミノコエ'), isTrue, reason: 'katakana');
      expect(Romaji.isJapanese('君の声'), isTrue, reason: 'kanji');
      expect(Romaji.isJapanese('Rivers In the Desert'), isFalse);
      expect(Romaji.isJapanese(''), isFalse);
    });

    test('hangul syllables and jamo are Korean', () {
      expect(Romaji.isKorean('안녕하세요'), isTrue);
      expect(Romaji.isKorean('ㅎㅏㄴ'), isTrue, reason: 'jamo');
      expect(Romaji.isKorean('君の声'), isFalse);
      expect(Romaji.isKorean('Hello'), isFalse);
    });

    test('the two do not claim each other', () {
      expect(Romaji.isKorean('君の声'), isFalse);
      expect(Romaji.isJapanese('안녕하세요'), isFalse);
    });

    test('`needs` is true only when there is something to convert', () {
      expect(Romaji.needs('君の声'), isTrue);
      expect(Romaji.needs('안녕하세요'), isTrue);

      expect(Romaji.needs('Rivers In the Desert'), isFalse);
      expect(Romaji.needs('1234 !?'), isFalse);
    });
  });

  group('Korean converts inline, and survives a bad line', () {
    test('hangul romanises', () {
      final out = Romaji.korean('안녕하세요');
      expect(out, isNotEmpty);
      expect(out, isNot('안녕하세요'), reason: 'the line came back unchanged');

      final latin = RegExp(r'^[A-Za-z0-9 .,!?-]+$');
      expect(latin.hasMatch(out), isTrue, reason: 'not romanised: $out');
    });

    test('a line it cannot handle comes back UNCHANGED rather than throwing', () {
      expect(Romaji.korean('Rivers In the Desert'), 'Rivers In the Desert');
      expect(Romaji.korean(''), '');
    });
  });

  group('Japanese romanises kana and leaves kanji alone', () {
    test('hiragana becomes romaji', () async {
      expect(await Romaji.japanese('さくら'), 'sakura');
      expect(await Romaji.japanese('ありがとう'), 'arigatou');
    });

    test('digraphs, gemination and the long mark are respected', () async {
      expect(await Romaji.japanese('きょう'), 'kyou');
      expect(await Romaji.japanese('がっこう'), 'gakkou');
      expect(await Romaji.japanese('まっちゃ'), 'matcha');
      expect(await Romaji.japanese('ラーメン'), 'raamen');
    });

    test('katakana is read as kana, not left behind', () async {
      expect(await Romaji.japanese('キミノコエ'), 'kiminokoe');
    });

    test('kanji survive untouched; a kanji-only line yields nothing', () async {
      expect(await Romaji.japanese('君の声'), '君no声');
      expect(await Romaji.japanese('東京'), isNull,
          reason: 'nothing was romanised, so there is nothing to show');
    });

    test('a latin line needs no romaji', () async {
      expect(await Romaji.japanese('Rivers In the Desert'), isNull);
    });
  });

  group('precompute', () {
    test('yields nothing for a latin sheet', () async {
      final out = await Romaji.precompute(const [
        'Rivers In the Desert',
        'It is now, or it is never',
      ]);
      expect(out, isEmpty, reason: 'an English sheet should produce no romaji at all');
    });

    test('indexes by LINE, not by text', () async {
      final out = await Romaji.precompute(const ['안녕하세요', '안녕하세요']);
      expect(out.keys.every((k) => k == 0 || k == 1), isTrue);
      if (out.isNotEmpty) {
        expect(out[0], isNotNull);
        expect(out[1], isNotNull, reason: 'a repeated line lost its own entry');
      }
    });
  });
}
