import 'package:flutter/material.dart';

import '../theme.dart';

/// Where a [StatTile] sits, which sets its size and colours.
enum StatTileVariant {
  /// A deck's Due / New today / Learned: 26 px, start-aligned, 20 px corners.
  compact,

  /// Progress's tiles: 30 px, start-aligned, 24 px corners.
  large,

  /// The summary's minutes and streak: centred, `surfaceContainerHigh`.
  summary,

  /// The summary's percentage correct: centred, `primaryContainer`.
  summaryEmphasis,
}

/// A number with its label under it.
///
/// [value] is already formatted (a count, "87%"); the label is a token. Both
/// are read as one screen-reader node.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.variant = StatTileVariant.compact,
  });

  final String value;
  final String label;
  final StatTileVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final centred =
        variant == StatTileVariant.summary ||
        variant == StatTileVariant.summaryEmphasis;
    final emphasis = variant == StatTileVariant.summaryEmphasis;

    final bg = switch (variant) {
      StatTileVariant.compact ||
      StatTileVariant.large => scheme.surfaceContainerLow,
      StatTileVariant.summary => scheme.surfaceContainerHigh,
      StatTileVariant.summaryEmphasis => scheme.primaryContainer,
    };
    final fg = emphasis ? scheme.onPrimaryContainer : scheme.onSurface;
    final labelColour = emphasis
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    final valueStyle = switch (variant) {
      StatTileVariant.compact => theme.textTheme.statValue.copyWith(
        fontSize: 26,
        height: 32 / 26,
      ),
      StatTileVariant.large => theme.textTheme.statValue.copyWith(
        fontSize: 30,
        height: 36 / 30,
        fontWeight: FontWeight.w800,
      ),
      _ => theme.textTheme.statValue.copyWith(fontWeight: FontWeight.w800),
    };

    return MergeSemantics(
      child: Container(
        padding: switch (variant) {
          StatTileVariant.compact => const EdgeInsetsDirectional.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          StatTileVariant.large => const EdgeInsetsDirectional.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          _ => const EdgeInsetsDirectional.symmetric(
            horizontal: 8,
            vertical: 16,
          ),
        },
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(
            variant == StatTileVariant.compact ? AppRadii.tile : AppRadii.card,
          ),
        ),
        child: Column(
          crossAxisAlignment: centred
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(value, style: valueStyle.copyWith(color: fg)),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: centred ? TextAlign.center : TextAlign.start,
              style: theme.textTheme.bodyMedium!.copyWith(color: labelColour),
            ),
          ],
        ),
      ),
    );
  }
}
