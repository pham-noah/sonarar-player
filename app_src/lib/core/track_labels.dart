/// Titles that carry their own artist — "[Artist] - [Title]" — spend a whole
/// line naming the artist a second time, and the line that identifies the track
/// is the one that gets cut. Where the artist has its own line, drop the prefix.
///
/// The artist line is often longer than the name in the title ("ヨルシカ /
/// n-buna Official" vs "ヨルシカ"), so the head only has to be part of it.
String titleWithoutArtist(String title, String artist) {
  final by = artist.toLowerCase();
  for (final sep in const [' - ', ' – ', ' — ']) {
    final at = title.indexOf(sep);
    if (at <= 0) continue;
    final head = title.substring(0, at).trim().toLowerCase();
    if (head.length >= 2 && by.contains(head)) {
      return title.substring(at + sep.length).trim();
    }
  }
  return title;
}
