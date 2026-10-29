import 'package:flutter/material.dart';

import '../theme/skin.dart';
import 'devices.dart';
import 'pressable.dart';

/// The one row shape for anything that reads as a setting.
///
/// A slab in the panel colour with an accent spine down its left edge, an icon,
/// a label and whatever control the row carries. Settings and Personalize both
/// draw from here so a toggle looks the same wherever it is met, and Archive
/// and History can borrow the spine for their own controls without growing a
/// second dialect.
class KitRow extends StatelessWidget {
  const KitRow({
    super.key,
    required this.skin,
    required this.label,
    this.note,
    this.icon,
    this.trailing,
    this.onTap,
    this.below,
    this.dense = false,
  });

  final Skin skin;
  final String label;
  final String? note;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Content that needs the row's full width — a slider, a strip of choices.
  final Widget? below;

  /// Tighter padding, for rows that sit on a busy surface.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: EdgeInsets.fromLTRB(12, dense ? 4 : 7, 8, dense ? 4 : 7),
      decoration: BoxDecoration(
        color: skin.panel,
        border: Border(
          left: BorderSide(color: skin.accent.withValues(alpha: 0.7), width: 3),
          // A hairline on the other three sides. Without it the panel and the
          // page are two dark greys meeting on a soft edge, and the slab — the
          // one shape this app repeats — stops reading as a plate.
          top: BorderSide(color: skin.textSecondary.withValues(alpha: 0.22)),
          right: BorderSide(color: skin.textSecondary.withValues(alpha: 0.22)),
          bottom: BorderSide(color: skin.textSecondary.withValues(alpha: 0.22)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: skin.accent),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: LayoutSpec.fontFloor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: skin.textPrimary,
                      ),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: LayoutSpec.fontFloor - 4,
                          height: 1.35,
                          color: skin.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          if (below != null) ...[
            const SizedBox(height: 2),
            below!,
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: onTap == null
          ? body
          : Pressable(
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: body,
              ),
            ),
    );
  }
}

/// A row carrying a switch, with an optional explanation underneath the label.
class KitToggle extends StatelessWidget {
  const KitToggle({
    super.key,
    required this.skin,
    required this.label,
    required this.value,
    required this.onChanged,
    this.note,
    this.icon,
    this.dense = false,
  });

  final Skin skin;
  final String label;
  final String? note;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) => KitRow(
    skin: skin,
    label: label,
    note: note,
    icon: icon,
    dense: dense,
    onTap: () => onChanged(!value),
    trailing: Switch(
      value: value,
      activeThumbColor: skin.accent,
      onChanged: onChanged,
    ),
  );
}

/// A row carrying a slider. The value reads on the right, so the row does not
/// have to grow a caption line of its own.
class KitSlider extends StatelessWidget {
  const KitSlider({
    super.key,
    required this.skin,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.note,
    this.icon,
    this.shown,
  });

  final Skin skin;
  final String label;
  final String? note;
  final IconData? icon;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  /// Formatted value shown at the right; defaults to the raw number.
  final String? shown;

  @override
  Widget build(BuildContext context) => KitRow(
    skin: skin,
    label: label,
    note: note,
    icon: icon,
    trailing: Text(
      shown ?? value.toStringAsFixed(value <= 1 ? 2 : 0),
      style: TextStyle(
        fontSize: LayoutSpec.fontFloor,
        fontWeight: FontWeight.w800,
        color: skin.accent,
      ),
    ),
    below: Slider(
      value: value.clamp(min, max),
      min: min,
      max: max,
      activeColor: skin.accent,
      onChanged: onChanged,
    ),
  );
}

/// Equal-width boxes. The tab strip Personalize wears, now shared, so a screen
/// can be split into pages without inventing a second kind of header.
class KitTabs<T> extends StatelessWidget {
  const KitTabs({
    super.key,
    required this.skin,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.keyBuilder,
    this.height = 34,
  });

  final Skin skin;
  final Map<T, String> labels;
  final T selected;
  final ValueChanged<T> onSelected;
  final Key Function(T)? keyBuilder;
  final double height;

  @override
  Widget build(BuildContext context) {
    final entries = labels.entries.toList();
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < entries.length; i++)
            Expanded(
              child: Padding(
                // No trailing gap on the last tab: the strip ends where the
                // content ends, instead of 5px short of it.
                padding: EdgeInsets.only(
                  right: i == entries.length - 1 ? 0 : 5,
                ),
                child: GestureDetector(
                  key: keyBuilder?.call(entries[i].key),
                  onTap: () => onSelected(entries[i].key),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entries[i].key == selected
                          ? skin.accent
                          : Colors.transparent,
                      border: Border.all(
                        color: entries[i].key == selected
                            ? skin.accent
                            : skin.textSecondary.withValues(alpha: 0.35),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      entries[i].value,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        color: entries[i].key == selected
                            ? skin.onAccent
                            : skin.textSecondary,
                        fontSize: LayoutSpec.fontFloor - 5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A strip of choices that belong together — grid/list, shapes, order. Sized to
/// the width it is given, so a choice row lines up with the tabs above it.
class KitSegment<T> extends StatelessWidget {
  const KitSegment({
    super.key,
    required this.skin,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.height = 36,
  });

  final Skin skin;
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Row(
      children: [
        for (final entry in options.entries)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: () => onSelected(entry.key),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  alignment: Alignment.center,
                  constraints: const BoxConstraints(minHeight: 36),
                  decoration: BoxDecoration(
                    color: entry.key == selected ? skin.accent : skin.panel,
                    border: Border.all(
                      color: entry.key == selected
                          ? skin.accent
                          : skin.textSecondary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    entry.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: LayoutSpec.fontFloor - 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: entry.key == selected
                          ? skin.onAccent
                          : skin.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// A titled group: the band, then the rows that belong to it.
class KitSection extends StatelessWidget {
  const KitSection({
    super.key,
    required this.skin,
    required this.label,
    required this.children,
    this.trailing,
    this.leading,
  });

  final Skin skin;
  final String label;
  final List<Widget> children;
  final Widget? trailing;

  /// Sits above the band — a sentence explaining the group.
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (leading != null) ...[leading!, const SizedBox(height: 6)],
      SectionBand(skin: skin, label: label, trailing: trailing),
      const SizedBox(height: 6),
      ...children,
      const SizedBox(height: 12),
    ],
  );
}
