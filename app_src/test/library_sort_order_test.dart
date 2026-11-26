library;

// A library sorted by artist put Björk, Beyoncé, Motörhead and Sigur Rós at the
// bottom, after ZZ Top. The list was in order — alphabetically, by byte — but ö
// is 246 and z is 122, so every name carrying a mark fell past the end of the
// alphabet. Someone scrolling to B for Björk met a wall of ASCII names first,
// and the four artists they own most of were the four furthest away.
//
// The comparator folds before comparing, with the same table the search box
// uses, so the list is ordered by the letters a reader sees. What these tests
// pin is not "it sorted" but "it landed under its letter".

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/search_fold.dart';

const _names = <String>[
  'ZZ Top',
  'Björk',
  'ABBA',
  'Motörhead',
  'Sigur Rós',
  'Beyoncé',
  'Øya',
  'Zbigniew Preisner',
  '宇多田ヒカル',
];

List<String> _sorted() => [..._names]..sort(compareFolded);

void main() {
  test('a marked name lands under its letter, not after Z', () {
    final order = _sorted();
    int at(String name) => order.indexOf(name);

    expect(at('Björk'), greaterThan(at('Beyoncé')),
        reason: 'Björk sits after Beyoncé, not before ABBA or after ZZ Top');
    expect(at('Björk'), lessThan(at('Motörhead')));
    expect(at('Motörhead'), greaterThan(at('Björk')));
    expect(at('Motörhead'), lessThan(at('Sigur Rós')));
    expect(at('Øya'), greaterThan(at('Motörhead')),
        reason: 'Ø folds to O, so it sorts under O, not past Z');
    expect(at('Øya'), lessThan(at('Sigur Rós')));
    expect(at('Sigur Rós'), lessThan(at('Zbigniew Preisner')));
    expect(at('Zbigniew Preisner'), lessThan(at('ZZ Top')),
        reason: 'and the ASCII end of the alphabet is still the end');
  });

  test('a name with no marks sorts exactly as it did before', () {
    final plain = ['ABBA', 'Beyonce', 'Motorhead', 'Sigur Ros', 'ZZ Top']
      ..sort(compareFolded);
    expect(plain, ['ABBA', 'Beyonce', 'Motorhead', 'Sigur Ros', 'ZZ Top']);
  });

  test('the sort is stable for names that fold alike', () {
    const a = 'ABBA';
    const b = 'abba';
    expect(compareFolded(a, b), isNot(0),
        reason: 'a tie broken by the raw text keeps the row from swapping '
            'places on every rebuild');
    expect(compareFolded(a, b).sign, -compareFolded(b, a).sign);
  });
}

