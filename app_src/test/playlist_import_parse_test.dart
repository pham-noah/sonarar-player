@Tags(['slow'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/screens/playlist_import_sheet.dart';

void main() {
  group('playlistIdFrom reads the real links', () {
    test('a share link with a tracking suffix', () {
      expect(
        playlistIdFrom(
            'https://youtube.com/playlist?list=OLAK5uy_nCEOviuThU9V0LgO4UVybwNc9qZb-SlIs&si=S_gMN6yVS1TbsNvk'),
        'OLAK5uy_nCEOviuThU9V0LgO4UVybwNc9qZb-SlIs',
      );
    });

    test('a plain playlist URL', () {
      expect(playlistIdFrom('https://www.youtube.com/playlist?list=PLabc123XYZ'),
          'PLabc123XYZ');
    });

    test('a watch URL carrying a list', () {
      expect(playlistIdFrom('https://www.youtube.com/watch?v=abcd&list=PLxyz789'),
          'PLxyz789');
    });

    test('a music.youtube URL', () {
      expect(playlistIdFrom('https://music.youtube.com/playlist?list=OLAK5uy_abc'),
          'OLAK5uy_abc');
    });

    test('a bare id is accepted', () {
      expect(playlistIdFrom('OLAK5uy_nCEOviuThU9V0LgO4UVybwNc9qZb-SlIs'),
          'OLAK5uy_nCEOviuThU9V0LgO4UVybwNc9qZb-SlIs');
    });

    test('a short word is refused rather than saved as a broken source', () {
      expect(playlistIdFrom('hello'), isNull);
      expect(playlistIdFrom(''), isNull);
      expect(playlistIdFrom('   '), isNull);
    });
  });
}
