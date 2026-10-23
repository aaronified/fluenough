import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/data/course_path.dart';
import '../../core/progress/unlocks.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import 'level_badge.dart';

/// The top of Progress (#418, owner, 2026-10-23: "3 tiles of taught"): a row
/// of three tiles, words, rules and sentences, counted against what is taught
/// so far, then the Level tile alone below.
class ProgressTiles extends StatelessWidget {
  const ProgressTiles({
    super.key,
    required this.counts,
    required this.level,
    required this.started,
    required this.allLanguages,
  });

  final UnlockCounts counts;

  /// The level the course has reached, or null before A1.
  final Milestone? level;

  /// The day of the first answer.
  final DateTime? started;

  /// Whether every language is counted: the Level tile then shows only the
  /// start date, since levels differ by course.
  final bool allLanguages;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final count = NumberFormat.decimalPattern(l10n.localeName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: <Widget>[
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: <Widget>[
              Expanded(
                child: UnlockTile(
                  title: l10n.progressWordsTitle,
                  figure: count.format(counts.wordsKnown),
                  known: l10n.progressKnown,
                  outOf: l10n.progressOfTaught(
                    count.format(counts.wordsTaught),
                  ),
                  semantics: l10n.progressWordsSemantics(
                    count.format(counts.wordsKnown),
                    count.format(counts.wordsTaught),
                  ),
                ),
              ),
              Expanded(
                child: UnlockTile(
                  title: l10n.progressRulesTitle,
                  figure: count.format(counts.rulesKnown),
                  known: l10n.progressKnown,
                  outOf: l10n.progressOfTaught(
                    count.format(counts.rulesTaught),
                  ),
                  semantics: l10n.progressRulesSemantics(
                    count.format(counts.rulesKnown),
                    count.format(counts.rulesTaught),
                  ),
                ),
              ),
              Expanded(
                child: UnlockTile(
                  title: l10n.progressSentencesTitle,
                  figure: count.format(counts.sentencesOpen),
                  known: l10n.progressOpen,
                  outOf: l10n.progressOfTaught(
                    count.format(counts.sentencesTotal),
                  ),
                  semantics: l10n.progressSentencesSemantics(
                    count.format(counts.sentencesOpen),
                    count.format(counts.sentencesTotal),
                  ),
                ),
              ),
            ],
          ),
        ),
        LevelTile(level: level, started: started, allLanguages: allLanguages),
      ],
    );
  }
}

/// A tile of the three counts: its title, **312** on one line at any text
/// size (it shrinks to fit rather than wrap), and under it what is counted,
/// "known", and "of 540 taught", which may take two lines.
class UnlockTile extends StatelessWidget {
  const UnlockTile({
    super.key,
    required this.title,
    required this.figure,
    required this.known,
    required this.outOf,
    required this.semantics,
  });

  final String title;
  final String figure;

  /// What the figure counts: known, or open.
  final String known;

  /// What it is out of: "of 540 taught".
  final String outOf;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semantics,
      child: ProgressTile(
        color: scheme.surfaceContainerLow,
        title: title,
        titleColor: scheme.onSurfaceVariant,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                figure,
                maxLines: 1,
                style: theme.textTheme.headlineMedium!.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ),
            Text(
              known,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Text(
              outOf,
              style: theme.textTheme.bodySmall!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
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
