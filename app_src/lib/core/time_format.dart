library;

/// How long something is, in the shape the app says it.
///
/// `4:07` under an hour, `1:04:07` over it — the rule was written out five
/// times across the screens and the shell, and one copy got the hours case and
/// the others did not.
String mmss(Duration d) {
  final minutes = d.inMinutes;
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  if (minutes < 60) return '$minutes:$seconds';
  final hours = minutes ~/ 60;
  final rest = (minutes % 60).toString().padLeft(2, '0');
  return '$hours:$rest:$seconds';
}
