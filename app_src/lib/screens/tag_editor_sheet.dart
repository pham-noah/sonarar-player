library;

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../library/tag_overrides.dart';
import '../library/track.dart';
import '../theme/skin.dart';
import '../widgets/pressable.dart';

class TagEditorSheet extends StatefulWidget {
  const TagEditorSheet({
    super.key,
    required this.state,
    required this.track,
    this.onChanged,
  });

  final AppState state;
  final Track track;

  final VoidCallback? onChanged;

  @override
  State<TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<TagEditorSheet> {
  late final Map<TagField, TextEditingController> _fields;

  @override
  void initState() {
    super.initState();
    _fields = {
      for (final f in TagField.values) f: TextEditingController(text: _current(f)),
    };
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _current(TagField f) {
    final o = widget.state.tagOverrides.forTrack(widget.track.id);
    return o[_fieldKey(f)] ?? _original(f);
  }

  String _original(TagField f) {
    final raw = widget.state.rawLibrary
        .where((t) => t.id == widget.track.id)
        .firstOrNull;
    final t = raw ?? widget.track;
    return switch (f) {
      TagField.title => t.title,
      TagField.artist => t.artist,
      TagField.album => t.album,
    };
  }

  bool _isOverridden(TagField f) =>
      widget.state.tagOverrides.forTrack(widget.track.id).containsKey(_fieldKey(f));

  String _fieldKey(TagField f) => switch (f) {
        TagField.title => 'title',
        TagField.artist => 'artist',
        TagField.album => 'album',
      };

  void _save() {
    for (final f in TagField.values) {
      final text = _fields[f]!.text;
      if (text.trim() == _original(f).trim()) {
        widget.state.clearTagOverride(widget.track.id, f);
      } else {
        widget.state.setTagOverride(widget.track.id, f, text);
      }
    }
    widget.onChanged?.call();
    if (mounted) Navigator.of(context).pop();
  }

  void _revert(TagField f) {
    widget.state.clearTagOverride(widget.track.id, f);
    _fields[f]!.text = _original(f);
    widget.onChanged?.call();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.state.uiSkin;
    final anyOverride = TagField.values.any(_isOverridden);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'FIX THE TAGS',
              style: TextStyle(
                fontSize: LayoutSpec.fontTitle,
                fontWeight: FontWeight.w900,
                color: skin.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Corrects what the player shows. The audio file is never '
              'modified, so this can always be undone.',
              style: TextStyle(
                fontSize: LayoutSpec.fontSmall,
                color: skin.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            for (final f in TagField.values) _fieldRow(skin, f),

            const SizedBox(height: 6),
            Text(
              'Saved corrections survive a restart and are not overwritten by '
              're-scanning the library.',
              style: TextStyle(
                fontSize: LayoutSpec.fontLabel,
                color: skin.textSecondary.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                if (anyOverride)
                  Expanded(
                    child: Pressable(
                      child: OutlinedButton(
                        onPressed: () {
                          widget.state.clearAllTagOverrides();
                          for (final f in TagField.values) {
                            _fields[f]!.text = _original(f);
                          }
                          widget.onChanged?.call();
                          setState(() {});
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: skin.textPrimary,
                          side: BorderSide(
                              color: skin.textSecondary.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('UNDO ALL'),
                      ),
                    ),
                  ),
                if (anyOverride) const SizedBox(width: 12),
                Expanded(
                  child: Pressable(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: skin.accent,
                        foregroundColor: skin.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('SAVE'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldRow(Skin skin, TagField f) {
    final overridden = _isOverridden(f);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tagFieldLabel(f).toUpperCase(),
                  style: TextStyle(
                    fontSize: LayoutSpec.fontLabel,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w800,
                    color: overridden ? skin.accent : skin.textSecondary,
                  ),
                ),
              ),
              if (overridden)
                Pressable(
                  child: TextButton(
                    onPressed: () => _revert(f),
                    style: TextButton.styleFrom(
                      foregroundColor: skin.accent,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('REVERT'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _fields[f],
            style: TextStyle(
              fontSize: LayoutSpec.fontBase,
              color: skin.textPrimary,
            ),
            cursorColor: skin.accent,
            maxLines: 2,
            minLines: 1,
            decoration: InputDecoration(
              filled: true,
              fillColor: skin.panel,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderSide: BorderSide(
                  color: overridden
                      ? skin.accent
                      : skin.textSecondary.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
          if (overridden) ...[
            const SizedBox(height: 4),
            Text(

              'File says: ${_original(f)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: LayoutSpec.fontLabel,
                color: skin.textSecondary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
