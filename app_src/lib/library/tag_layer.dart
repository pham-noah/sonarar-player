/// The library as the user's tag edits make it.
///
/// `AppState` held three fields for one invariant — the overrides, the library as
/// the disk reported it, and the retitled copy the rest of the app reads — and
/// every mutation had to remember to rebuild the third from the other two. The
/// third going stale is invisible: tracks keep their old titles and the tag editor
/// looks broken.
///
/// So the triple is one object, and [library] is always [raw] with [overrides]
/// applied. Nothing outside can set it.
library;

import 'track.dart';
import 'tag_overrides.dart';

class TagLayer {
  TagLayer({List<Track> raw = const [], TagOverrides? overrides})
      : _raw = List<Track>.unmodifiable(raw),
        _overrides = overrides ?? TagOverrides() {
    _library = _apply();
  }

  List<Track> _raw;
  TagOverrides _overrides;
  late List<Track> _library;

  /// The library as the scan or manifest reported it.
  List<Track> get raw => _raw;

  /// The library the app reads: [raw] with the user's retitles applied.
  List<Track> get library => _library;

  TagOverrides get overrides => _overrides;

  /// A whole library arrived (a scan, a manifest, a download).
  void replaceRaw(List<Track> tracks) {
    _raw = List<Track>.unmodifiable(tracks);
    _library = _apply();
  }

  void replaceOverrides(TagOverrides overrides) {
    _overrides = overrides;
    _library = _apply();
  }

  void override(String trackId, TagField field, String value) {
    _overrides.set(trackId, field, value);
    _library = _apply();
  }

  void clear(String trackId, TagField field) {
    _overrides.clearField(trackId, field);
    _library = _apply();
  }

  void clearAll() {
    _overrides.clearAll();
    _library = _apply();
  }

  List<Track> _apply() =>
      _raw.isEmpty ? const [] : List<Track>.unmodifiable(_overrides.applyAll(_raw));
}
