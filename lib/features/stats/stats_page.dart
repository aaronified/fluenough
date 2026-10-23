import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/features.dart';
import '../../app/routes.dart';
import '../../core/progress/practice_week.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/bar_row.dart';
import '../../ui/widgets/incoming.dart';
import '../../ui/widgets/language_bar.dart';
import '../../ui/widgets/page_parts.dart';
import 'leeches.dart';
import 'practice_week_card.dart';
import 'progress_mastery.dart';
import 'progress_tiles.dart';
import 'skill_star.dart';
import 'stats_numbers.dart';
import 'stats_section.dart';

/// The Progress tab (#678): the words mastered and the course's level, the
/// last seven days, the six-skill star (which opens the charts over time),
/// the weakest tags and the leeches. Shows a disabled empty state while
/// `Feature.stats` is incoming.
///
/// Design screen `stats`. Every number is computed from the review log, the
/// decks and the paths (`ProgressMastery`), none from the design.
///
/// The numbers are the language the language bar at the top shows (#528),
/// or with the bar's All button on, every review together, those whose
/// language cannot be told too.
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);

    if (state.features.isIncoming(Feature.stats)) {
      return _Frame(
        child: EmptyState(
          icon: Icons.insights_outlined,
          title: l10n.statsIncomingTitle,
          body: l10n.statsIncomingBody,
          action: const IncomingBadge(),
        ),
      );
    }

    final actions = LeechActions.of(state.progress);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[state.progress, actions]),
      builder: (context, _) {
        final languageOf = languageLookupOf(state);
        final language = state.progressLanguage;
        final none = language == null
            ? state.progress.log.isEmpty
            : !state.progress.log.any((e) => languageOf(e.deckId) == language);
        if (none) {
          return _Frame(
            child: EmptyState(
              icon: Icons.insights_outlined,
              title: l10n.statsNoReviews,
            ),
          );
        }
        return _Frame(
          child: _StatsBody(
            state: state,
            actions: actions,
            language: language,
            languageOf: languageOf,
          ),
        );
      },
    );
  }
}

/// The language bar (#528), fixed over the tab's scrolling content.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: LanguageBarFrame(
        screen: LanguageBarScreen.progress,
        reportDetail: 'Progress',
        child: child,
      ),
    ),
  );
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({
    required this.state,
    required this.actions,
    required this.language,
    required this.languageOf,
  });

  final AppState state;
  final LeechActions actions;

  /// The language counted, by code, or null for every review.
  final String? language;
  final LanguageLookup languageOf;

  bool _counts(String deckId) =>
      language == null || languageOf(deckId) == language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final cardOf = cardLookupOf(state);
    final mastery = ProgressMastery.of(state, language);
    // The weakest tags are over all time: the star is not ranged.
    const range = StatsRange.all;
    final numbers = StatsNumbers.of(
      state.progress,
      now: state.now(),
      range: range,
      cardOf: cardOf,
      deckFilter: language == null ? null : _counts,
    );
    final leeches = findLeeches(state.progress, cardOf: cardOf)
        .where(
          (l) =>
              _counts(l.card.deckId) &&
              actions.statusOf(l.key) == LeechStatus.active,
        )
        .length;

    BarRow bar(String label, Tally tally, {Color? color}) => BarRow(
      label: label,
      value: tally.ratio,
      valueText: l10n.commonPercent(tally.ratio),
      semanticsLabel: l10n.statsBarSemantics(label, tally.ratio),
      color: color,
    );

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
      children: <Widget>[
        ProgressTiles(
          words: mastery.words,
          level: mastery.level,
          started: mastery.started,
          allLanguages: language == null,
        ),
        const SizedBox(height: 8),
        PracticeWeekCard(week: mastery.week, quota: kDefaultDailyQuota),
        const SizedBox(height: 16),
        SkillStarCard(
          mastery: mastery.now,
          onTap: () => AppNavigator.openOverTime(context),
        ),
        if (numbers.weakestTags.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          StatsSection(
            title: l10n.statsWeakestTags,
            trailing: TextButton(
              onPressed: () => AppNavigator.openAllTags(context, range),
              child: Text(l10n.statsAllTags),
            ),
            children: <Widget>[
              for (final MapEntry(key: tag, value: tally)
                  in numbers.weakestTags.entries)
                bar(tag, tally, color: scheme.tertiary),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _LeechesRow(count: leeches, language: language),
      ],
    );
  }
}

/// "4 leeches · Cards you keep missing", which opens Leeches, in
/// [language] when one is counted. While `Feature.leeches` is incoming it is
/// dimmed, with the badge under its text so that it still fits at large text
/// sizes.
class _LeechesRow extends StatelessWidget {
  const _LeechesRow({required this.count, required this.language});

  final int count;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final incoming = isIncoming(context, Feature.leeches);
    final title = l10n.statsLeeches(count);
    // The error colour is for leeches there are; with none it is a plain card
    // like the ones above it, not a problem that is not there (#500).
    final hasLeeches = count > 0;
    final fg = hasLeeches ? scheme.onErrorContainer : scheme.onSurface;
    final subtitleFg = hasLeeches
        ? scheme.onErrorContainer
        : scheme.onSurfaceVariant;
    Widget dim(Widget child) =>
        incoming ? Opacity(opacity: kIncomingOpacity, child: child) : child;

    final row = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 16, 16),
      child: Row(
        children: <Widget>[
          dim(Icon(Icons.warning_amber_rounded, color: fg)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                dim(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleMedium!.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        l10n.statsLeechesSubtitle,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: subtitleFg,
                        ),
                      ),
                    ],
                  ),
                ),
                if (incoming) ...<Widget>[
                  const SizedBox(height: 8),
                  const IncomingBadge(),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          dim(Icon(Icons.chevron_right, color: fg)),
        ],
      ),
    );

    final tile = Material(
      color: hasLeeches ? scheme.errorContainer : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadii.group),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: incoming
            ? () => showIncomingSnackBar(context)
            : () => AppNavigator.openLeeches(context, language: language),
        child: row,
      ),
    );

    return incoming
        ? Semantics(
            container: true,
            button: true,
            enabled: false,
            label: l10n.incomingSemanticsLabel(title),
            hint: l10n.incomingSemanticsHint,
            excludeSemantics: true,
            onTap: () => showIncomingSnackBar(context),
            child: tile,
          )
        : MergeSemantics(child: tile);
  }
}
