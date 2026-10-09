import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_state.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/expressive_shape.dart';
import 'path_model.dart';
import 'word_mastery.dart';

/// The words of the path's lines, and the small pieces both the Decks tab
/// and a unit's screen draw.

/// [parts] joined into one line, "18 words · 2 rules", by the translator's
/// separator.
String joinParts(AppLocalizations l10n, List<String> parts) {
  if (parts.isEmpty) return '';
  return parts.skip(1).fold(parts.first, l10n.pathMetaJoin);
}

/// A unit's line: its letters for a script unit, else its words, rules,
/// sentences open and passages, each where it has some.
String unitMeta(AppLocalizations l10n, AppState state, UnitContent content) {
  if (content.isScript && content.words.isNotEmpty) {
    return l10n.pathUnitLetters(content.words.length);
  }
  final sentences = content.sentences;
  return joinParts(l10n, <String>[
    if (content.words.isNotEmpty) l10n.pathUnitWords(content.words.length),
    if (content.rules.isNotEmpty) l10n.pathUnitRules(content.rules.length),
    if (sentences.isNotEmpty)
      l10n.pathUnitSentences(
        sentences.where(state.isTaught).length,
        sentences.length,
      ),
    if (content.passages > 0) l10n.pathUnitPassages(content.passages),
  ]);
}

/// "Earned 24 Sep", "Earned today", or "Earned" when the log does not say.
String earnedLine(BuildContext context, DateTime? at, DateTime now) {
  final l10n = AppLocalizations.of(context)!;
  if (at == null) return l10n.pathEarned;
  if (at.year == now.year && at.month == now.month && at.day == now.day) {
    return l10n.pathEarnedToday;
  }
  return l10n.pathEarnedOn(DateFormat.MMMd(l10n.localeName).format(at));
}

/// A level's can-do line.
String levelLine(AppLocalizations l10n, CefrLevel level) => switch (level) {
  CefrLevel.a1 => l10n.pathLevelA1,
  CefrLevel.a2 => l10n.pathLevelA2,
  CefrLevel.b1 => l10n.pathLevelB1,
};

/// The status pill of a word, a rule or a sentence: Known, Learning 64%,
/// New, or for a sentence not taught, Not open yet.
class MasteryChip extends StatelessWidget {
  const MasteryChip({super.key, required this.mastery, this.notOpen = false});

  final Mastery mastery;

  /// A sentence no lesson has taught yet.
  final bool notOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = notOpen
        ? (scheme.surfaceContainerHighest, scheme.onSurfaceVariant)
        : switch (mastery.level) {
            MasteryLevel.known => (
              scheme.primaryContainer,
              scheme.onPrimaryContainer,
            ),
            MasteryLevel.learning => (
              scheme.secondaryContainer,
              scheme.onSecondaryContainer,
            ),
            MasteryLevel.fresh => (
              scheme.surfaceContainerHighest,
              scheme.onSurfaceVariant,
            ),
          };
    return Pill(
      text: masteryName(l10n, mastery, notOpen: notOpen),
      background: bg,
      foreground: fg,
    );
  }
}

/// Where a word, rule or sentence stands, as its chip says it: Known,
/// Learning 64%, New, or for a sentence no lesson has taught, Not open yet.
String masteryName(
  AppLocalizations l10n,
  Mastery mastery, {
  bool notOpen = false,
}) => notOpen
    ? l10n.unitNotOpen
    : switch (mastery.level) {
        MasteryLevel.known => l10n.unitKnown,
        MasteryLevel.learning => l10n.unitLearning(
          (mastery.share * 100).round(),
        ),
        MasteryLevel.fresh => l10n.unitNew,
      };

/// A small rounded label: a status, a level, a count.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 26),
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Center(
      widthFactor: 1,
      heightFactor: 1,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium!
            .copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

/// A milestone on the path: a trophy, its name, and when it was earned or
/// what is left.
class MilestoneMark extends StatelessWidget {
  const MilestoneMark({super.key, required this.step, required this.now});

  final MilestoneStep step;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = switch (step.kind) {
      MilestoneKind.firstDeck => l10n.pathFirstDeck,
      MilestoneKind.words => l10n.pathWordsLearned(step.count),
      MilestoneKind.script => l10n.pathScriptLearned,
      MilestoneKind.rules => l10n.pathRulesKnown(step.count),
      MilestoneKind.firstPassage => l10n.pathFirstPassage,
    };
    final line = step.earned
        ? earnedLine(context, step.earnedAt, now)
        : switch (step.kind) {
            MilestoneKind.firstDeck => l10n.pathFirstDeckToGo,
            MilestoneKind.words => l10n.pathWordsToGo(step.toGo),
            MilestoneKind.script => l10n.pathScriptToGo(step.toGo),
            MilestoneKind.rules => l10n.pathRulesToGo(step.toGo),
            MilestoneKind.firstPassage => l10n.pathFirstPassageToGo,
          };
    final fg = step.earned ? scheme.onTertiaryContainer : scheme.onSurface;
    return MergeSemantics(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 14, 8),
        decoration: BoxDecoration(
          color: step.earned
              ? scheme.tertiaryContainer
              : scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadii.small),
          border: step.earned
              ? null
              : Border.all(color: scheme.outlineVariant, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: step.earned
                    ? scheme.onTertiaryContainer
                    : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.emoji_events_outlined,
                size: 18,
                color: step.earned
                    ? scheme.tertiaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.labelLarge!.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    line,
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: step.earned ? fg : scheme.onSurfaceVariant,
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

/// A level reached, or to reach: its code on a scalloped medallion, solid
/// once earned, its name, and when or what is left.
class AchievementMark extends StatelessWidget {
  const AchievementMark({super.key, required this.step, required this.now});

  final AchievementStep step;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = step.level.label;
    final line = step.earned
        ? earnedLine(context, step.earnedAt, now)
        : step.coming > 0
        ? l10n.pathUnitsToGoComing(step.unitsToGo, step.coming)
        : l10n.pathUnitsToGo(step.unitsToGo);
    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: step.earned
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHigh,
              shape: ExpressiveShapeBorder(
                ExpressiveShape.cookie,
                side: step.earned
                    ? BorderSide.none
                    : BorderSide(color: scheme.outline, width: 1.5),
              ),
            ),
            child: Text(
              label,
              textScaler: TextScaler.noScaling,
              style: theme.textTheme.headlineSmall!.copyWith(
                fontWeight: FontWeight.w800,
                color: step.earned
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step.earned
                ? l10n.pathLevelReached(label)
                : l10n.pathAchievement(label),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall!.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            line,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The start of a level on the path: its code, what it lets the learner
/// do, and its size. Highlighted while the learner is in it.
class LevelHeader extends StatelessWidget {
  const LevelHeader({super.key, required this.step});

  final LevelStep step;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = step.current;
    final fg = current ? scheme.onPrimaryContainer : scheme.onSurface;
    final line = joinParts(l10n, <String>[
      l10n.pathLevelUnits(step.units + step.coming),
      if (step.done > 0) l10n.pathLevelDone(step.done),
      if (step.words > 0) l10n.pathUnitWords(step.words),
      if (step.coming > 0) l10n.pathLevelComing(step.coming),
    ]);
    return Semantics(
      header: true,
      child: MergeSemantics(
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 16, 14),
          decoration: BoxDecoration(
            color: current
                ? scheme.primaryContainer
                : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadii.group),
          ),
          child: Row(
            children: <Widget>[
              Container(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 36),
                alignment: Alignment.center,
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: current
                      ? scheme.onPrimaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  step.level.label,
                  style: theme.textTheme.titleSmall!.copyWith(
                    fontWeight: FontWeight.w800,
                    color: current
                        ? scheme.primaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      levelLine(l10n, step.level),
                      style: theme.textTheme.titleMedium!.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line,
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: current ? fg : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
