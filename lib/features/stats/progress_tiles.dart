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
                  icon: Icons.translate,
                  taught: counts.wordsTaught,
                  count: counts.wordsKnown,
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
                  icon: Icons.text_fields,
                  taught: counts.rulesTaught,
                  count: counts.rulesKnown,
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
            ],
          ),
        ),
        LevelTile(level: level, started: started, allLanguages: allLanguages),
      ],
    );
  }
}

/// A tile of the two counts, words and rules (owner, 2026-10-26: two tiles
/// on top, not three): an icon and its title, **312** on one line at any text
/// size (it shrinks to fit rather than wrap) with what is counted, "known",
/// beside it, a thin bar of how much of what is taught is known, and under
/// it "of 540 taught", which may take two lines.
class UnlockTile extends StatelessWidget {
  const UnlockTile({
    super.key,
    required this.icon,
    required this.title,
    required this.figure,
    required this.count,
    required this.taught,
    required this.known,
    required this.outOf,
    required this.semantics,
  });

  final IconData icon;
  final String title;
  final String figure;

  /// The figure and what it is out of, for the bar.
  final int count;
  final int taught;

  /// What the figure counts: known, or open.
  final String known;

  /// What it is out of: "of 540 taught".
  final String outOf;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final share = taught <= 0 ? 0.0 : (count / taught).clamp(0.0, 1.0);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semantics,
      child: Container(
        padding: const EdgeInsetsDirectional.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadii.group),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              spacing: 8,
              children: <Widget>[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: scheme.onPrimaryContainer),
                ),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall!.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                spacing: 6,
                children: <Widget>[
                  Text(
                    figure,
                    maxLines: 1,
                    style: theme.textTheme.headlineMedium!.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    known,
                    style: theme.textTheme.titleSmall!.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 6,
                color: scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 4),
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
    // Before A1 the tile is the primary container, with a trophy, so that
    // the level is the one filled tile on Progress (owner, 2026-10-26).
    final notYet = !allLanguages && shown == null;
    final ink = badge != null
        ? LevelBadge.text
        : notYet
        ? scheme.onPrimaryContainer
        : scheme.onSurface;
    final soft = badge != null
        ? LevelBadge.text
        : notYet
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

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
    // One slim row, the level big and its title and start date beside it, so
    // that the three counts, this tile and the hours tiles leave the star in
    // reach at 1.4x text (owner-approved screens keep it on screen).
    final title = allLanguages
        ? l10n.progressStartedTitle
        : l10n.progressLevelTitle;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: label,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: notYet ? scheme.primaryContainer : scheme.surfaceContainerLow,
          gradient: badge?.gradient,
          borderRadius: BorderRadius.circular(AppRadii.group),
        ),
        child: Row(
          spacing: 12,
          children: <Widget>[
            if (notYet)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.emoji_events_outlined,
                  size: 22,
                  color: scheme.onPrimary,
                ),
              ),
            Flexible(
              child: fit(
                Text(
                  allLanguages
                      ? date
                      : shown == null
                      ? l10n.progressLevelNone
                      : levelName(l10n, shown),
                  maxLines: 1,
                  style: theme.textTheme.headlineMedium!.copyWith(
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge!.copyWith(color: soft),
                  ),
                  if (!allLanguages && started != null)
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
    this.icon,
  });

  /// An icon in a round chip before the title, or none.
  final IconData? icon;

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
        Row(
          spacing: 8,
          children: <Widget>[
            if (icon != null)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge!
                    .copyWith(color: titleColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        child,
      ],
    ),
  );
}
