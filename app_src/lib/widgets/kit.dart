import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/skin.dart';
import '../theme/tokens.dart';
import 'devices.dart';
import 'pressable.dart';

/// The one row shape for anything that reads as a setting: a panel-coloured slab
/// with an accent spine, an icon, a label and the row's own control. Settings,
/// Personalize, Archive and History all draw from here, so a toggle looks the same
/// wherever it is met.
class KitRow extends StatelessWidget {
  const KitRow({
    super.key,
    required this.skin,
    required this.label,
    this.labelSize = LayoutSpec.fontFloor,
    this.note,
    this.icon,
    this.trailing,
    this.onTap,
    this.below,
    this.dense = false,
    this.enabled = true,
  });

  final Skin skin;
  final String label;

  /// The row's own type size. Screens with many rows pass [LayoutSpec.fontRow].
  final double labelSize;
  final String? note;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Content that needs the row's full width — a slider, a strip of choices.
  final Widget? below;

  /// Tighter padding, for rows that sit on a busy surface.
  final bool dense;

  /// A row whose prerequisite is off: it stays where it was, so the setting
  /// does not move when something else is switched, but it says so — muted
  /// label, decoration-only edge, and no callback.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: EdgeInsets.fromLTRB(12, dense ? Space.xs : Space.sm, 12, dense ? Space.xs : Space.sm),
      decoration: BoxDecoration(
        color: skin.panel,
        border: Border(
          left: BorderSide(color: skin.accentAt(0.7), width: 3),
          // A hairline on the other three sides. Without it the panel and the
          // page are two greys meeting on a soft edge, and the slab — the one
          // shape this app repeats — stops reading as a plate. It is
          // `borderStrong` because a control's edge needs 3:1; the old
          // 22%-alpha hairline measured 1.77:1 and was effectively invisible.
          top: BorderSide(color: enabled ? skin.borderStrong : skin.edge(0.22)),
          right: BorderSide(color: enabled ? skin.borderStrong : skin.edge(0.22)),
          bottom: BorderSide(color: enabled ? skin.borderStrong : skin.edge(0.22)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: enabled ? skin.accentInk : skin.textMuted),
                const SizedBox(width: Space.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      // Two lines before an ellipsis: at 320dp a one-line limit
                      // turned FADE IN into "FADE…" beside an empty 104px slot.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Type.row(
                        context,
                        color: enabled ? skin.textPrimary : skin.textMuted,
                      ).copyWith(fontSize: labelSize),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: Space.xxs),
                      Text(
                        note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Type.bodyBase(context,
                                color: enabled ? skin.textSecondary : skin.textMuted)
                            .copyWith(
                          fontSize: math.max(LayoutSpec.fontMicro, labelSize - 4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: Space.xs),
                trailing!,
              ],
            ],
          ),
          if (below != null) ...[
            const SizedBox(height: Space.xxs),
            below!,
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
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
    trailing: KitSwitch(skin: skin, value: value, onChanged: onChanged),
  );
}

/// The app's switch, in the app's two states.
///
/// Explicit rather than inherited: a `Switch` with only `activeThumbColor` set
/// leaves the off state to Material, which draws an outline at 21:1 and a knob
/// that disappears into the track on the light skins. Both states are ours.
class KitSwitch extends StatelessWidget {
  const KitSwitch({
    super.key,
    required this.skin,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final Skin skin;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ink = SwitchInk.ofSkin(skin);
    return Semantics(
      label: semanticLabel,
      toggled: value,
      child: Switch(
        value: value,
        onChanged: onChanged,
        trackColor: ink.track,
        thumbColor: ink.thumb,
        trackOutlineColor: ink.outline,
      ),
    );
  }
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
        color: skin.accentInk,
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
    this.height = Space.tap,
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
                    duration: StateMotion.settle,
                    curve: Curves.easeOut,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entries[i].key == selected
                          ? skin.accent
                          : Colors.transparent,
                      border: Border.all(
                        // A control's edge, not a decoration: at 0.35 alpha
                        // this border measured under 2:1 and the unselected
                        // tabs read as empty space beside the selected one.
                        color: entries[i].key == selected
                            ? skin.accent
                            : skin.borderStrong,
                      ),
                      borderRadius: BorderRadius.circular(Corners.sm),
                    ),
                    // Three tabs share the width, so the longest label sets
                    // what fits: Finnish "JÄRJESTELMÄ" was clipped mid-glyph
                    // ("JÄRJESTEL") on a 320dp phone at every text size. A
                    // scale-down of a few percent keeps the word whole; the
                    // content under the tabs still follows the user's setting.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        entries[i].value,
                        maxLines: 1,
                        style: Type.caps(
                          context,
                          color: entries[i].key == selected
                              ? skin.onAccent
                              : skin.textMuted,
                        ),
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
    this.height = Space.tap,
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
                  constraints: BoxConstraints(minHeight: Space.tap),
                  decoration: BoxDecoration(
                    color: entry.key == selected ? skin.accent : skin.panel,
                    border: Border.all(
                      color: entry.key == selected
                          ? skin.accent
                          : skin.borderStrong,
                    ),
                  ),
                  child: Text(
                    entry.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Type.caps(
                      context,
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
      if (leading != null) ...[leading!, const SizedBox(height: 8)],
      SectionBand(skin: skin, label: label, trailing: trailing),
      const SizedBox(height: 8),
      ...children,
      const SizedBox(height: 12),
    ],
  );
}
