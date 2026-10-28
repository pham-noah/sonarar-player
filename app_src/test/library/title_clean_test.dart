import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/downloaded_tracks.dart';

void main() {
  test('ASCII tags are stripped', () {
    expect(cleanYoutubeTitle('Song (Official Video)'), 'Song');
    expect(cleanYoutubeTitle('Song [Lyrics]'), 'Song');
    expect(cleanYoutubeTitle('Song - Topic'), 'Song');
  });

  test('full-width tags are stripped too', () {
    expect(cleanYoutubeTitle('ヨルシカ - あぶく（OFFICIAL VIDEO）'), 'ヨルシカ - あぶく');
    expect(cleanYoutubeTitle('ヨルシカ - 春泥棒【Official Music Video】'), 'ヨルシカ - 春泥棒');
  });

  test('a title that is only a tag keeps its original text', () {
    expect(cleanYoutubeTitle('(Official Video)'), '(Official Video)');
  });

  test('a plain title is untouched', () {
    expect(cleanYoutubeTitle('Rivers In the Desert'), 'Rivers In the Desert');
  });
}
