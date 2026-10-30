import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/memory_progress.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../app/shell_tab.dart';
import '../../app/unlocks.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/skill_visuals.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/expressive_shape.dart';
import '../../ui/widgets/mode_pill.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/stat_tile.dart';

/// The end of a session: a pill per skill with its right answers, the streak, what is due tomorrow.
///
/// Design screen `summary`. The numbers come from [result] and from the
/// progress store, never from the design's sample (whose streak, 13, did not
/// match Today's 12). Done returns to Today; the language's lesson, today's
/// or another, is offered once no other language waits (ADR-0024).
///
/// After one language's part of Today, it is the break between languages:
/// that language is done for today, and each other language with something
/// left is offered next, one at a time; starting one switches the language
/// bar to it (#528).
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
        : state.nextTodayLanguages(finished.code);
    // A lesson in the language just finished (ADR-0024), once no other
    // language is waiting for its reviews: today's, or another.
    final lesson = finished == null || next.isNotEmpty
        ? null
        : DrillRequest.lesson(language: finished.code);
    final offersLesson = lesson != null && state.lessonFor(lesson).isNotEmpty;
    final unlocked = empty || finished == null
        ? null
        : state.unlockedSince(finished.code, result.startedAt);

    return Scaffold(
      body: SafeArea(
        child: WithReportButton(
          detail: finished?.code,
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
                    if (empty) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        l10n.summaryEmpty,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (!empty) ...<Widget>[
                      const SizedBox(height: 24),
                      _BySkill(result: result),
                      const SizedBox(height: 24),
                      _Streak(streak: state.progress.streakAt(now)),
                      const SizedBox(height: 24),
                      if (unlocked != null) ...<Widget>[
                        _Unlocked(unlocked: unlocked),
                        const SizedBox(height: 24),
                      ],
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
                            onPressed: () {
                              // The bar follows: Today, Decks and Progress
                              // show the language started (#528).
                              state.showLanguage(language.code);
                              AppNavigator.nextDrill(
                                context,
                                DrillRequest.today(language: language.code),
                              );
                            },
                            child: Text(
                              l10n.summaryStartLanguage(
                                language.name,
                                state
                                    .buildSession(
                                      DrillRequest.today(
                                        language: language.code,
                                      ),
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
                      if (offersLesson)
                        FilledButton.tonal(
                          style: AppButtonStyles.secondary(context),
                          onPressed: () =>
                              AppNavigator.startDrill(context, lesson),
                          child: Text(
                            state.lessonDoneToday(lesson.language!)
                                ? l10n.summaryAnotherLesson
                                : l10n.summaryLesson,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Unlocked in this lesson": how many words and rules became known and how
/// many sentences opened (#418, owner, 2026-10-23: "the lesson end shows
/// counts"), each line only where there is something.
class _Unlocked extends StatelessWidget {
  const _Unlocked({required this.unlocked});

  final ({int words, int rules, int sentences}) unlocked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              l10n.summaryUnlockedTitle,
              style: theme.textTheme.titleMedium,
            ),
          ),
          if (unlocked.words > 0)
            Text(l10n.summaryUnlockedWords(unlocked.words)),
          if (unlocked.rules > 0)
            Text(l10n.summaryUnlockedRules(unlocked.rules)),
          if (unlocked.sentences > 0)
            Text(l10n.summaryUnlockedSentences(unlocked.sentences)),
        ],
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

/// The streak, in one tile.
class _Streak extends StatelessWidget {
  const _Streak({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final count = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    return StatTile(
      value: count.format(streak),
      label: l10n.summaryStreak(streak),
      variant: StatTileVariant.summary,
    );
  }
}

/// How each skill did (#486): one pill per skill that had answers, in the
/// skill's own icon and colour, with "3 right of 4" beside it, centred. Only
/// graded answers are counted; a taught card is not one. The pill and its
/// text wrap onto two lines at large text rather than overflow.
class _BySkill extends StatelessWidget {
  const _BySkill({required this.result});

  final SessionResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      spacing: 12,
      children: <Widget>[
        for (final score in result.bySkill)
          Semantics(
            container: true,
            label: l10n.summaryScoreSemantics(
              score.skill.label(l10n),
              score.correct,
              score.total,
            ),
            child: ExcludeSemantics(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: <Widget>[
                  ModePill(skill: score.skill),
                  Text(
                    l10n.summaryScore(score.correct, score.total),
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
