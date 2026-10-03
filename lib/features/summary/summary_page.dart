import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/memory_progress.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../app/shell_tab.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/skill_visuals.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/bar_row.dart';
import '../../ui/widgets/expressive_shape.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/stat_tile.dart';

/// How many new cards the summary offers to teach next, as the design does.
/// Fewer are offered when today's cap leaves fewer, and none hides the button.
const int summaryLearnNewCount = 5;

/// Above this text scale the three numbers stack, so each keeps its width.
const double _rowMaxScale = 1.5;

/// The end of a session: cards and correct, minutes, streak, a score per skill, what is due tomorrow.
///
/// Design screen `summary`. The numbers come from [result] and from the
/// progress store, never from the design's sample (whose streak, 13, did not
/// match Today's 12). Done returns to Today; "Learn 5 new cards" starts a
/// session of new cards only.
///
/// After one language's part of Today, it is the break between languages:
/// that language is done for today, and each other language with something
/// left is offered next, one at a time.
class SummaryPage extends StatelessWidget {
  const SummaryPage({super.key, required this.result});

  /// The finished session, from the drill.
  final SessionResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = state.now();
    final empty = result.total == 0;
    final finished = <LanguageInfo>[
      for (final language in state.languages)
        if (language.code == result.language) language,
    ].firstOrNull;
    final next = finished == null
        ? const <LanguageInfo>[]
        : <LanguageInfo>[
            for (final language in state.todayLanguages)
              if (language.code != finished.code) language,
          ];
    // New cards of every language at once would undo taking them one at a
    // time, so the offer waits until no other language is.
    final learnNew = next.isNotEmpty
        ? 0
        : state
              .buildSession(const DrillRequest.learnNew(summaryLearnNewCount))
              .length;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 56, 16, 0),
              sliver: SliverList.list(
                children: <Widget>[
                  const _Tick(),
                  const SizedBox(height: 20),
                  Semantics(
                    header: true,
                    child: Text(
                      finished == null
                          ? l10n.summaryTitle
                          : l10n.summaryLanguageDone(finished.name),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    empty
                        ? l10n.summaryEmpty
                        : l10n.summaryLine(result.total, result.correct),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (!empty) ...<Widget>[
                    const SizedBox(height: 24),
                    _Numbers(
                      result: result,
                      streak: state.progress.streakAt(now),
                    ),
                    const SizedBox(height: 24),
                    _BySkill(result: result),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    l10n.summaryNextDue(state.dueTomorrow()),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 24, 16, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: <Widget>[
                    if (next.isNotEmpty) ...<Widget>[
                      Text(
                        l10n.summaryNextLanguage,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                      for (final language in next)
                        FilledButton.tonal(
                          style: AppButtonStyles.secondary(context),
                          onPressed: () => AppNavigator.nextDrill(
                            context,
                            DrillRequest.today(language: language.code),
                          ),
                          child: Text(
                            l10n.summaryStartLanguage(
                              language.name,
                              state
                                  .buildSession(
                                    DrillRequest.today(language: language.code),
                                  )
                                  .length,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                    FilledButton(
                      style: AppButtonStyles.closing(context),
                      onPressed: () => AppNavigator.backToShell(
                        context,
                        tab: ShellTab.today,
                      ),
                      child: Text(l10n.commonDone),
                    ),
                    if (learnNew > 0)
                      FilledButton.tonal(
                        style: AppButtonStyles.secondary(context),
                        onPressed: () => AppNavigator.startDrill(
                          context,
                          DrillRequest.learnNew(learnNew),
                        ),
                        child: Text(l10n.summaryLearnNew(learnNew)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The design's tick in a sunny shape, in `tertiaryContainer`. Decorative:
/// the title says the same.
class _Tick extends StatelessWidget {
  const _Tick();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: ShapeDecoration(
            color: scheme.tertiaryContainer,
            shape: const ExpressiveShapeBorder(ExpressiveShape.sunny),
          ),
          child: Icon(
            Icons.check_rounded,
            size: 52,
            color: scheme.onTertiaryContainer,
          ),
        ),
      ),
    );
  }
}

/// Percentage correct, minutes and streak, side by side, or stacked at large
/// text sizes.
class _Numbers extends StatelessWidget {
  const _Numbers({required this.result, required this.streak});

  final SessionResult result;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final count = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final tiles = <Widget>[
      StatTile(
        value: l10n.commonPercent(result.accuracy),
        label: l10n.summaryCorrect,
        variant: StatTileVariant.summaryEmphasis,
      ),
      StatTile(
        value: count.format(result.minutes),
        label: l10n.summaryMinutes(result.minutes),
        variant: StatTileVariant.summary,
      ),
      StatTile(
        value: count.format(streak),
        label: l10n.summaryStreak(streak),
        variant: StatTileVariant.summary,
      ),
    ];
    final scale = MediaQuery.textScalerOf(context).scale(100) / 100;
    if (scale > _rowMaxScale) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: tiles,
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: <Widget>[for (final tile in tiles) Expanded(child: tile)],
      ),
    );
  }
}

/// One bar per skill drilled: "Production 2/2".
class _BySkill extends StatelessWidget {
  const _BySkill({required this.result});

  final SessionResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GroupedList(
      outerRadius: AppRadii.card,
      children: <Widget>[
        for (final score in result.bySkill)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: BarRow(
              label: score.skill.label(l10n),
              value: score.correct / score.total,
              valueText: l10n.summaryScore(score.correct, score.total),
              semanticsLabel: l10n.summaryScoreSemantics(
                score.skill.label(l10n),
                score.correct,
                score.total,
              ),
              thickness: 8,
              labelWidth: 110,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}
