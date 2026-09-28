import 'package:flutter/material.dart';

/// One choice in a [Segmented] group.
class SegmentOption<T> {
  const SegmentOption({
    required this.value,
    required this.label,
    this.icon,
    this.leading,
  });

  final T value;
  final String label;

  /// An icon above the label: the Appearance theme choice.
  final IconData? icon;

  /// Something before the label on the same line, like a script's first
  /// letter in the drill's "How to type the answer" choice.
  final Widget? leading;
}

/// M3 Expressive's connected button group, as the design draws its choices:
/// Progress's time range, Appearance's theme and contrast, the drill's input
/// mode.
///
/// Every segment is an equal share of the width, 4 px apart. The selected
/// one is a full pill in `primary`; the others are `surfaceContainerHigh`,
/// round only at the group's outer ends, and morph as the choice moves.
///
/// Pass null [onSelected] for a group that cannot be changed (a feature that
/// is incoming: wrap it in `IncomingFeature` as well). Segments grow taller
/// than [height] if their text needs it.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.semanticLabel,
    this.height = 40,
  });

  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T>? onSelected;

  /// The group's name for screen readers, such as "Time range".
  final String semanticLabel;

  /// 40 for a range, 44 for input mode, 48 for contrast, 72 with icons.
  final double height;

  /// The design's springy curve, cubic-bezier(.3, 1.4, .5, 1).
  static const Curve morph = Cubic(0.3, 1.4, 0.5, 1);

  @override
  Widget build(BuildContext context) {
    final n = options.length;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      // As tall as the tallest segment, and every segment that tall: equal
      // heights when one label wraps, and no stretching to the parent.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var i = 0; i < n; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: _Segment<T>(
                  option: options[i],
                  selected: options[i].value == selected,
                  first: i == 0,
                  last: i == n - 1,
                  height: height,
                  onTap: onSelected == null
                      ? null
                      : () => onSelected!(options[i].value),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.option,
    required this.selected,
    required this.first,
    required this.last,
    required this.height,
    required this.onTap,
  });

  final SegmentOption<T> option;
  final bool selected;
  final bool first;
  final bool last;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pill = Radius.circular(height / 2);
    const square = Radius.circular(8);
    final radius = selected
        ? BorderRadiusDirectional.all(pill)
        : BorderRadiusDirectional.horizontal(
            start: first ? pill : square,
            end: last ? pill : square,
          );
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    final label = Text(
      option.label,
      textAlign: TextAlign.center,
      style: theme.textTheme.labelLarge!.copyWith(color: fg),
    );

    final Widget content = option.icon != null
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(option.icon, color: fg),
              const SizedBox(height: 4),
              label,
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (option.leading != null) ...<Widget>[
                DefaultTextStyle.merge(
                  style: TextStyle(color: fg),
                  child: ExcludeSemantics(child: option.leading!),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(child: label),
            ],
          );

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Segmented.morph,
        constraints: BoxConstraints(minHeight: height),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerHigh,
          borderRadius: radius.resolve(Directionality.of(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
