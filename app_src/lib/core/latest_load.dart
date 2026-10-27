class LatestLoad<K> {
  K? _current;

  bool get inFlight => _current != null;

  void start(K key) => _current = key;

  bool isLatest(K key) => _current == key;

  void clear() => _current = null;
}
