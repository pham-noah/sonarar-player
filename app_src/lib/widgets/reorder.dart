library;

const double kReorderCommitFraction = 0.5;

int reorderTarget({
  required int from,
  required double travelled,
  required double rowHeight,
  required int length,
}) {
  if (rowHeight <= 0 || length <= 0) return from;

  final rows = travelled / rowHeight;
  final shift = rows >= 0 ? (rows + kReorderCommitFraction).floor()
                          : (rows - kReorderCommitFraction).ceil();
  return (from + shift).clamp(0, length - 1);
}

double displacementFor({
  required int index,
  required int from,
  required int to,
  required double rowHeight,
}) {
  if (index == from) return 0;
  if (from < to) {
    if (index > from && index <= to) return -rowHeight;
  } else if (from > to) {
    if (index >= to && index < from) return rowHeight;
  }
  return 0;
}
