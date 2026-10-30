import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/lyrics.dart';

void main() {
  test('an upload title is read down to the song title', () {
    const upload = 'April Encounter - 很美味 (Hen Meiwei)'
        '《当我飞奔向你 When I Fly Towards You》Chi/Eng/Pinyin lyrics';

    final readings = queryReadings(upload).toList();

    expect(readings, contains('April Encounter'),
        reason: 'the song is named first; the rest is credit and show name');
    expect(readings.first, isNot(contains('Pinyin')));
  });

  test('the usual artist-first title still reads both ways', () {
    final readings = queryReadings('ヨルシカ - 雲を抜け風下へ私だけ').toList();

    expect(readings, contains('雲を抜け風下へ私だけ'));
    expect(readings, contains('ヨルシカ'));
  });
}
