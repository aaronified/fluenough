import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/data/course_path.dart';
import '../../core/progress/mastery.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import 'level_badge.dart';

/// The top row of Progress: the Words tile and the Level tile.
class ProgressTiles extends StatelessWidget {
  const ProgressTiles({
    super.key,
    required this.words,
    required this.level,
    required this.started,
    required this.allLanguages,
  });

  final WordCounts words;

  /// The level the course has reached, or null before A1.
  final Milestone? level;

  /// The day of the first answer.
  final DateTime? started;

  /// Whether every language is counted: the Level tile then shows only the
  /// start date, since levels differ by course.
  final bool allLanguages;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(flex: 8, child: WordsTile(words: words)),
        const SizedBox(width: 8),
        Expanded(
          flex: 7,
          child: LevelTile(
            level: level,
            started: started,
            allLanguages: allLanguages,
          ),
        ),
      ],
    ),
  );
}

/// "Words mastered", with **312** in bold and "/ 540 taught" lighter, on one
/// line at any text size: the line shrinks to fit rather than wrap.
class WordsTile extends StatelessWidget {
  const WordsTile({super.key, required this.words});

  final WordCounts words;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = NumberFormat.decimalPattern(l10n.localeName);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: l10n.progressWordsSemantics(
        count.format(words.mastered),
        count.format(words.taught),
      ),
      child: ProgressTile(
        color: scheme.surfaceContainerLow,
        title: l10n.progressWordsTitle,
        titleColor: scheme.onSurfaceVariant,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                count.format(words.mastered),
                style: theme.textTheme.headlineMedium!.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                l10n.progressWordsTaught(count.format(words.taught)),
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The course's level, A1, A2 or B1, in bronze, silver or gold, with the day
/// it was started; before A1 a plain tile. On All languages only the start
/// date, in a plain tile.
class LevelTile extends StatelessWidget {
  const LevelTile({
    super.key,
    required this.level,
    required this.started,
    required this.allLanguages,
  });

  final Milestone? level;
  final DateTime? started;
  final bool allLanguages;

  static String levelName(AppLocalizations l10n, Milestone level) =>
      switch (level) {
        Milestone.a1 => l10n.progressLevelA1,
        Milestone.a2 => l10n.progressLevelA2,
        Milestone.b1 => l10n.progressLevelB1,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = started == null
        ? ''
        : DateFormat.yMMMd(l10n.localeName).format(started!);
    final shown = allLanguages ? null : level;
    final badge = shown == null ? null : LevelBadge.of(shown);
    final ink = badge == null ? scheme.onSurface : LevelBadge.text;
    final soft = badge == null ? scheme.onSurfaceVariant : LevelBadge.text;

    final String label;
    if (allLanguages) {
      label = l10n.progressStartedSemantics(date);
    } else if (shown == null) {
      label = l10n.progressLevelNoneSemantics(date);
    } else {
      label = l10n.progressLevelSemantics(levelName(l10n, shown), date);
    }

    Widget fit(Widget child) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: child,
    );
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: label,
      child: ProgressTile(
        color: scheme.surfaceContainerLow,
        gradient: badge?.gradient,
        title: allLanguages
            ? l10n.progressStartedTitle
            : l10n.progressLevelTitle,
        titleColor: soft,
        child: allLanguages
            ? fit(
                Text(
                  date,
                  maxLines: 1,
                  style: theme.textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  fit(
                    Text(
                      shown == null
                          ? l10n.progressLevelNone
                          : levelName(l10n, shown),
                      maxLines: 1,
                      style: theme.textTheme.headlineMedium!.copyWith(
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                  ),
                  if (started != null)
                    fit(
                      Text(
                        l10n.progressLevelStarted(date),
                        maxLines: 1,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: soft,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// A tile of the top rows of Progress: a title over its figure.
class ProgressTile extends StatelessWidget {
  const ProgressTile({
    super.key,
    required this.color,
    required this.title,
    required this.titleColor,
    required this.child,
    this.gradient,
  });

  final Color color;
  final Gradient? gradient;
  final String title;
  final Color titleColor;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: 12,
      vertical: 12,
    ),
    decoration: BoxDecoration(
      color: color,
      gradient: gradient,
      borderRadius: BorderRadius.circular(AppRadii.group),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge!
              .copyWith(color: titleColor),
        ),
        const SizedBox(height: 4),
        child,
      ],
    ),
  );
}
