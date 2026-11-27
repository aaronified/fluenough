import 'package:flutter/material.dart' hide Card;

import '../../core/achievements/achievement.dart';
import '../../core/data/course_path.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/script_name.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/target_text.dart';
import '../stats/progress_tiles.dart' show LevelTile;
import 'achievement_texts.dart';
import 'badge_glyph.dart';
import 'badge_tile.dart';
import 'badge_view.dart';

/// One card a badge's sheet shows: a word the learner still has to know, or
/// one of the words they knew when they earned a word count.
class BadgeCardRow {
  const BadgeCardRow({
    required this.card,
    required this.language,
    this.started = false,
  });

  final Card card;

  /// The language the card is in, to draw it in its script and direction.
  final LanguageInfo language;

  /// Whether the learner has answered it before: Learning, else New.
  final bool started;
}

/// Opens the sheet of [view]: what the badge is, what remains and when it was
/// earned (the approved mockup `achievements`, "Badge sheets"). A level opens
/// [showLevelsSheet] instead.
Future<void> showBadgeSheet(
  BuildContext context, {
  required BadgeView view,
  required LanguageInfo language,
  List<BadgeCardRow> cards = const <BadgeCardRow>[],
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) =>
      BadgeSheet(view: view, language: language, cards: cards),
);

/// The sheet of one badge, in the mockup's three states and its skill and
/// set variants: earned with its date (and a few of the learner's words for a
/// word count), in progress with a bar and the cards still to know, locked
/// with how to earn it.
class BadgeSheet extends StatelessWidget {
  const BadgeSheet({
    super.key,
    required this.view,
    required this.language,
    this.cards = const <BadgeCardRow>[],
  });

  final BadgeView view;
  final LanguageInfo language;
  final List<BadgeCardRow> cards;

  /// What kind of badge it is, after the language's name: a set's kind, a
  /// script skill's script.
  String _kind(AppLocalizations l10n) {
    final def = view.def;
    if (def.kind == AchievementKind.deckSet) {
      return def.grammarSet
          ? l10n.achvSheetGrammarTable
          : l10n.achvSheetWordSet;
    }
    final skill = def.skill;
    if (skill != null && skill.kind.isScript) {
      return l10n.scriptNameOr(skill.script, language.name);
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final def = view.def;
    final result = view.result;
    final kind = _kind(l10n);
    final shown = view.shown;
    final progress = shown == BadgeShown.progress;
    final isWords = def.kind == AchievementKind.wordCount;
    final isCards =
        def.kind == AchievementKind.level ||
        def.kind == AchievementKind.skillMaster ||
        def.kind == AchievementKind.deckSet;
    final remaining = result.need - result.have;
    final haveText = achievementCount(l10n, result.have);
    final needText = achievementCount(l10n, result.need);
    final String have;
    if (isWords) {
      have = l10n.achvWordsKnown(haveText, needText);
    } else if (isCards) {
      have = l10n.achvCardsKnown(haveText, needText);
    } else {
      have = l10n.achvProgressOf(haveText, needText);
    }
    final waits = isWords || def.kind == AchievementKind.skillMaster;
    final level = def.level;
    final before = level == null || level.index == 0
        ? null
        : Milestone.values[level.index - 1];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: BadgeGlyph(view: view, size: BadgeSize.big),
            ),
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(
                def.fullName(l10n),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            Text(
              kind.isEmpty
                  ? language.name
                  : l10n.achvSubline(language.name, kind),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            if (shown == BadgeShown.earned && result.earnedAt != null)
              Text(
                l10n.achvEarnedOn(achievementDate(l10n, result.earnedAt!)),
                style: theme.textTheme.bodyLarge,
              ),
            if (progress) Text(have, style: theme.textTheme.bodyLarge),
            if (progress) ...<Widget>[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.mark),
                child: LinearProgressIndicator(
                  value: view.fraction,
                  minHeight: 8,
                  color: scheme.primary,
                  backgroundColor: scheme.outlineVariant,
                ),
              ),
            ],
            if (shown == BadgeShown.locked) ...<Widget>[
              Text(
                l10n.achvLocked,
                style: theme.textTheme.bodyLarge!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (shown == BadgeShown.left)
              Text(
                l10n.achvNotInPlan,
                style: theme.textTheme.bodyLarge!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 6),
            Text(
              def.how(l10n),
              style: theme.textTheme.bodyMedium!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (shown == BadgeShown.locked && before != null)
              Text(
                l10n.achvLevelFirst(LevelTile.levelName(l10n, before)),
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            if (progress && waits)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 6),
                child: Text(
                  isWords ? l10n.achvWordsWait : l10n.achvMasterWait,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (progress && def.kind == AchievementKind.deckSet)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 6),
                child: Text(
                  l10n.achvSetRule,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (progress && isCards && cards.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  l10n.achvStillToKnow(remaining),
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                l10n.achvNextCards,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              for (final row in cards) _CardRow(row: row),
            ],
            if (shown == BadgeShown.earned &&
                isWords &&
                cards.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  l10n.achvFewWords,
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: <Widget>[
                  for (final row in cards)
                    TargetText(
                      row.card.target,
                      language: row.language,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      textAlign: TextAlign.start,
                      card: row.card,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonClose),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A card still to know: its word in its script, its reading and meaning, and
/// whether the learner has started it.
class _CardRow extends StatelessWidget {
  const _CardRow({required this.row});

  final BadgeCardRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final card = row.card;
    final reading = card.reading;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TargetText(
                  card.target,
                  language: row.language,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  textAlign: TextAlign.start,
                  card: card,
                ),
                if (reading != null && reading.isNotEmpty)
                  Text(
                    reading,
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                Text(card.native, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 8,
              vertical: 2,
            ),
            decoration: row.started
                ? BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  )
                : BoxDecoration(
                    border: Border.all(color: scheme.outline),
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
            child: Text(
              row.started ? l10n.achvLearning : l10n.unitNew,
              style: theme.textTheme.labelSmall!.copyWith(
                fontWeight: FontWeight.w600,
                color: row.started
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the levels sheet: the three metals with their dates, the next
/// level's bar and the sentence that says what counts as known (decision 1).
Future<void> showLevelsSheet(
  BuildContext context, {
  required List<BadgeView> levels,
  required LanguageInfo language,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => LevelsSheet(levels: levels, language: language),
);

/// The levels of one course: A1 bronze, A2 silver and B1 gold, each with its
/// date, then the bar of the next one.
class LevelsSheet extends StatelessWidget {
  const LevelsSheet({super.key, required this.levels, required this.language});

  /// The course's level badges, in order.
  final List<BadgeView> levels;
  final LanguageInfo language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final next = levels.where((v) => v.shown != BadgeShown.earned).firstOrNull;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.achvLevelsTitle(language.name),
                style: theme.textTheme.headlineSmall,
              ),
            ),
            Text(
              l10n.achvLevelsFollow,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final view in levels)
                  Expanded(
                    child: Semantics(
                      container: true,
                      excludeSemantics: true,
                      label: badgeSemantics(l10n, view),
                      child: Column(
                        spacing: 4,
                        children: <Widget>[
                          BadgeGlyph(view: view),
                          Text(
                            view.def.name(l10n),
                            style: theme.textTheme.labelMedium!.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            badgeStatus(l10n, view),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall!.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (next != null) ...<Widget>[
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  l10n.achvNextLevel(next.def.name(l10n)),
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.mark),
                child: LinearProgressIndicator(
                  value: next.fraction,
                  minHeight: 8,
                  color: scheme.primary,
                  backgroundColor: scheme.outlineVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.achvLevelCards(
                  achievementCount(l10n, next.result.have),
                  achievementCount(l10n, next.result.need),
                  next.def.name(l10n),
                ),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.achvLevelRule,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonClose),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
