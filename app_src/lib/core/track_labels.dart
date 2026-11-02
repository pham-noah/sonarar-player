/// A title that carries its own artist — "[Artist] - [Title]" — spends a line naming
/// the artist twice, and the line that identifies the track is the one that gets
/// cut. Where the artist has its own line, drop the prefix.
///
/// The artist line is often longer than the name in the title, so the head only has
/// to be part of it.
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
