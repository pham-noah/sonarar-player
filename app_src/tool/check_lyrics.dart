import 'package:sonarar/library/lyrics.dart';

/// Live check: does the pipeline find lyrics for a real upload title?
Future<void> main(List<String> args) async {
  final title = args.isNotEmpty
      ? args[0]
      : 'April Encounter - 很美味 (Hen Meiwei)'
          '《当我飞奔向你 When I Fly Towards You》Chi/Eng/Pinyin lyrics';
  final artist = args.length > 1 ? args[1] : 'Peachey Blossom';
  final seconds = args.length > 2 ? int.parse(args[2]) : 210;

  final service = LyricsService(cacheDirectory: null);
  final lyrics = await service.forTrack(
    trackId: 'live-check',
    title: title,
    artist: artist,
    duration: Duration(seconds: seconds),
  );

  stdout('source: ${lyrics?.source}');
  stdout('lines: ${lyrics?.lines.length} · plain: ${lyrics?.plain?.length ?? 0}');
  final first = lyrics?.lines.isNotEmpty == true
      ? lyrics!.lines.first.text
      : (lyrics?.plain ?? '').split('\n').first;
  stdout('first: $first');
}

void stdout(String line) => print(line);
