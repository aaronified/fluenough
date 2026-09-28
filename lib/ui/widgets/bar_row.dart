import 'package:flutter/material.dart';

/// A labelled horizontal bar: the summary's score per skill, Progress's
/// "Correct, by skill" and "Weakest tags".
///
/// [value] is 0–1. [valueText] is shown at the end, already formatted
/// ("6/8", "74%"). [semanticsLabel] replaces what screen readers hear, which
/// otherwise is the label and the value text.
class BarRow extends StatelessWidget {
  const BarRow({
    super.key,
    required this.label,
    required this.value,
    required this.valueText,
    this.semanticsLabel,
    this.color,
    this.thickness = 12,
    this.labelWidth = 100,
    this.labelStyle,
  });

  final String label;
  final double value;
  final String valueText;
  final String? semanticsLabel;

  /// The filled part. Defaults to `primary`; "Weakest tags" uses `tertiary`.
  final Color? color;

  /// 12 on Progress, 8 on the summary.
  final double thickness;

  /// The label column's width. Longer labels wrap.
  final double labelWidth;

  /// Merged onto the label's `bodyMedium`: the summary's labels are w600.
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(thickness / 2);
    final row = Row(
      children: <Widget>[
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium!.merge(labelStyle),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: radius,
            child: Container(
              height: thickness,
              color: scheme.secondaryContainer,
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color ?? scheme.primary,
                    borderRadius: radius,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 40),
          child: Text(
            valueText,
            textAlign: TextAlign.end,
            style: theme.textTheme.labelLarge!.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
    final semantic = semanticsLabel;
    return semantic == null
        ? MergeSemantics(child: row)
        : Semantics(
            container: true,
            label: semantic,
            excludeSemantics: true,
            child: row,
          );
  }
}
