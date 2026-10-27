library;

bool shouldAdvanceArt({
  required bool enabled,
  required bool trackChanged,
  required bool alreadyCycling,
}) {
  if (!enabled) return false;
  if (!trackChanged) return false;
  if (alreadyCycling) return false;
  return true;
}
