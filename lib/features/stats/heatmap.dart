import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import 'stats_numbers.dart';

/// "Reviews, last 12 weeks": one square per day, a column per week, oldest
/// at the start, today last, shaded by how many reviews the day had.
///
/// The shading is colour only, so screen readers get one node instead:
/// `statsHeatmapLabel` with `statsHeatmapSummary` as its value.
class ReviewHeatmap extends StatelessWidget {
  const ReviewHeatmap({super.key, required this.numbers});

  final StatsNumbers numbers;

  /// The five steps, from no reviews to the busiest days: the design's
  /// `surfaceContainerHighest`, then `primary` at 30, 50, 75 and 100%.
  static List<Color> levelColours(ColorScheme scheme) => <Color>[
    scheme.surfaceContainerHighest,
    scheme.primary.withValues(alpha: 0.3),
    scheme.primary.withValues(alpha: 0.5),
    scheme.primary.withValues(alpha: 0.75),
    scheme.primary,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colours = levelColours(scheme);
    final days = numbers.heatmap;

    Widget square(int count) => Container(
      height: 18,
      decoration: BoxDecoration(
        color: colours[numbers.levelOf(count)],
        borderRadius: BorderRadius.circular(5),
      ),
    );

    final grid = Semantics(
      container: true,
      label: l10n.statsHeatmapLabel,
      value: l10n.statsHeatmapSummary(
        numbers.activeDays,
        kHeatmapDays,
        numbers.heatmapReviews,
      ),
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          for (var week = 0; week < kHeatmapWeeks; week++) ...<Widget>[
            if (week > 0) const SizedBox(width: 4),
            Expanded(
              child: Column(
                children: <Widget>[
                  for (var day = 0; day < 7; day++) ...<Widget>[
                    if (day > 0) const SizedBox(height: 4),
                    square(days[week * 7 + day]),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );

    final legendStyle = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final legend = ExcludeSemantics(
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: <Widget>[
          Text(l10n.statsFewer, style: legendStyle),
          for (var level = 0; level < kHeatmapLevels; level++)
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: colours[level],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          Text(l10n.statsMore, style: legendStyle),
        ],
      ),
    );

    return StatsSection(
      title: l10n.statsHeatmapTitle(kHeatmapWeeks),
      children: <Widget>[grid, legend],
    );
  }
}

/// One of Progress's rounded panels: a heading and its rows, 12 apart.
class StatsSection extends StatelessWidget {
  const StatsSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.group),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          for (final child in children) ...<Widget>[
            const SizedBox(height: 12),
            child,
          ],
        ],
      ),
    );
  }
}
