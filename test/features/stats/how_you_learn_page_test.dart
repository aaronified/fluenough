import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/pacing.dart';
import 'package:fluenough/app/routes.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/skill_fit.dart';
import 'package:fluenough/features/stats/heatmap.dart';
import 'package:fluenough/features/stats/how_you_learn_page.dart';
import 'package:fluenough/features/stats/stats_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/widgets/pace_parts.dart';

import '../../support/harness.dart';
import '../../support/paced_learner.dart';

/// The pace How you learn shows for Hindi [mode].
SkillPace paceOf(AppState state, DrillMode mode) =>
    state.pacing.paces![(language: 'hi', mode: mode)]!;

/// The verdict label's background, around [text].
Color? verdictColour(WidgetTester tester, String text) {
  final box = tester.widget<Container>(
    find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
  );
  return (box.decoration! as BoxDecoration).color;
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

/// What How you learn says of an adjusted skill: its sentence, its
/// verdict and its 30 days, worked out from [pace] as the page words it.
void expectAdjusted(
  WidgetTester tester,
  AppLocalizations l10n,
  SkillPace pace,
  String verdict,
) {
  final mode = pace.key.mode.name;
  final start = pace.start;
  final now = pace.now;
  expect(
    find.text(
      now.days == start.days
          ? l10n.paceComesBackSame(mode, now.days)
          : l10n.paceComesBack(mode, now.days, start.days),
    ),
    findsOneWidget,
  );
  expect(find.text(verdict), findsOneWidget);
  expect(
    find.text(
      now.reviews == start.reviews
          ? l10n.paceReviewsSteady(now.reviews)
          : l10n.paceReviews(now.reviews, start.reviews),
    ),
    findsOneWidget,
  );
}

void main() {
  group('How you learn', () {
    testWidgets('before any fit: what will happen, and the way to Settings', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pacedLearner(Paced.none);
      await pumpScreen(tester, const HowYouLearnPage(), state: state);
      final l10n = l10nOf(tester);

      expect(find.text(l10n.howYouLearnTitle), findsOneWidget);
      expect(find.text(l10n.howYouLearnIntro), findsOneWidget);
      expect(find.text(l10n.howYouLearnNone), findsOneWidget);
      expect(find.text(l10n.howYouLearnLegendYou), findsNothing);
      await tester.tap(find.text(l10n.howYouLearnOpenSettings));
      await tester.pumpAndSettle();
      expect(state.shellTab.value, ShellTab.settings);
      // Every skill with answers, not adjusted yet, with its count.
      for (final mode in <String>['recognition', 'listening', 'production']) {
        await scrollTo(tester, find.text(l10n.adjustedNotYet(mode)));
        expect(find.text(l10n.adjustedNotYet(mode)), findsOneWidget);
      }
      expect(find.text(l10n.paceNotYet(8)), findsNWidgets(3));
      expect(find.textContaining('Adjusted today'), findsNothing);

    });

    testWidgets('fitted slower: fewer reviews, in the plan\'s words', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pacedLearner(Paced.fewer);
      await pumpScreen(tester, const HowYouLearnPage(), state: state);
      final l10n = l10nOf(tester);
      final hear = paceOf(state, DrillMode.listening);
      expect(hear.adjusted, isTrue);
      expect(hear.now.days, greaterThan(hear.start.days));
      expect(SkillFit.direction(hear.start, hear.now), -1);

      expect(find.text(l10n.howYouLearnLegendYou), findsOneWidget);
      expect(find.text(l10n.howYouLearnLegendStart), findsOneWidget);
      final verdict = l10n.adjustedFewer('listening');
      await scrollTo(tester, find.text(verdict));
      expectAdjusted(tester, l10n, hear, verdict);
      expect(
        find.text(
          l10n.paceComesBack('listening', hear.now.days, hear.start.days),
        ),
        findsOneWidget,
      );
      final scheme = Theme.of(tester.element(find.text(verdict))).colorScheme;
      expect(verdictColour(tester, verdict), scheme.primaryContainer);
      // The others are not adjusted yet.
      expect(find.text(l10n.adjustedNotYet('production')), findsOneWidget);

      await scrollTo(tester, find.text(l10n.adjustedPrivacy));
      expect(find.text(l10n.paceAdjustedToday(8)), findsOneWidget);
    });

    testWidgets('fitted faster: more reviews, never in the error colour', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pacedLearner(Paced.more);
      await pumpScreen(tester, const HowYouLearnPage(), state: state);
      final l10n = l10nOf(tester);
      final write = paceOf(state, DrillMode.production);
      expect(write.now.reviews, greaterThan(write.start.reviews));

      final verdict = l10n.adjustedMore('production');
      await scrollTo(tester, find.text(verdict));
      expectAdjusted(tester, l10n, write, verdict);
      expect(
        find.text(l10n.paceReviews(write.now.reviews, write.start.reviews)),
        findsOneWidget,
      );
      final scheme = Theme.of(tester.element(find.text(verdict))).colorScheme;
      final colour = verdictColour(tester, verdict);
      expect(colour, scheme.tertiaryContainer);
      expect(colour, isNot(scheme.errorContainer));
      expect(colour, isNot(scheme.error));
    });

    testWidgets('about the same', (tester) async {
      usePhone(tester);
      final state = await pacedLearner(Paced.same);
      await pumpScreen(tester, const HowYouLearnPage(), state: state);
      final l10n = l10nOf(tester);
      final seen = paceOf(state, DrillMode.recognition);
      expect(seen.adjusted, isTrue);
      expect(SkillFit.direction(seen.start, seen.now), 0);

      final verdict = l10n.adjustedSame('recognition');
      await scrollTo(tester, find.text(verdict));
      expectAdjusted(tester, l10n, seen, verdict);
      expect(
        find.text(l10n.paceComesBackSame('recognition', seen.now.days)),
        findsOneWidget,
      );
    });

    testWidgets('waits for the figures, worked out by the runner', (
      tester,
    ) async {
      usePhone(tester);
      final gate = Completer<void>();
      final state = await pacedLearner(
        Paced.more,
        paceRunner: (job) async {
          await gate.future;
          return paceInPlace(job);
        },
      );
      await pumpScreen(tester, const Scaffold(), state: state);
      unawaited(
        AppNavigator.openHowYouLearn(tester.element(find.byType(Scaffold))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final l10n = l10nOf(tester, find.byType(HowYouLearnPage));
      expect(find.bySemanticsLabel(l10n.howYouLearnWorking), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(l10n.howYouLearnIntro), findsOneWidget);
    });

    testWidgets('a language with no answers shows no skills', (tester) async {
      usePhone(tester);
      final state = await pacedLearner(Paced.more);
      await pumpScreen(
        tester,
        const HowYouLearnPage(language: 'bn'),
        state: state,
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.howYouLearnIntro), findsOneWidget);
      expect(find.text(l10n.paceSkillName('production')), findsNothing);
    });
  });

  group('Progress', () {
    Future<AppState> onProgress(WidgetTester tester, Paced paced) async {
      usePhone(tester);
      final state = await pacedLearner(paced);
      await pumpScreen(tester, const StatsPage(), state: state);
      return state;
    }

    Future<void> scrollToCard(WidgetTester tester) async {
      final l10n = l10nOf(tester);
      await scrollTo(tester, find.text(l10n.howYouLearnTitle));
      await tester.ensureVisible(find.text(l10n.howYouLearnTitle));
      await tester.pumpAndSettle();
    }

    testWidgets('before any fit, the card says what will happen and where, '
        'and opens How you learn', (tester) async {
      await onProgress(tester, Paced.none);
      final l10n = l10nOf(tester);
      await scrollToCard(tester);
      expect(find.text(l10n.howYouLearnCardBefore), findsOneWidget);
      expect(find.text(l10n.howYouLearnCardMore), findsNothing);
      await tester.tap(find.text(l10n.howYouLearnTitle));
      await tester.pumpAndSettle();
      expect(find.byType(HowYouLearnPage), findsOneWidget);
      expect(find.text(l10n.howYouLearnNone), findsOneWidget);
    });

    testWidgets('once fitted, "Learn more about your pacing", for the '
        'language chosen', (tester) async {
      await onProgress(tester, Paced.fewer);
      final l10n = l10nOf(tester);
      await scrollToCard(tester);
      expect(find.text(l10n.howYouLearnCardMore), findsOneWidget);
      expect(find.text(l10n.howYouLearnCardBefore), findsNothing);
      await tester.tap(find.text(l10n.howYouLearnTitle));
      await tester.pumpAndSettle();
      final page = tester.widget<HowYouLearnPage>(find.byType(HowYouLearnPage));
      expect(page.language, 'hi');
    });

    testWidgets('one skills section: Correct, by skill with How you learn '
        'in it, and Weakest tags; no Your strengths', (tester) async {
      await onProgress(tester, Paced.fewer);
      final l10n = l10nOf(tester);
      await scrollToCard(tester);
      expect(find.text(l10n.statsBySkill), findsOneWidget);
      // The card sits in the skills section, after its bars.
      final section = find.ancestor(
        of: find.text(l10n.statsBySkill),
        matching: find.byType(StatsSection),
      );
      expect(
        find.descendant(of: section, matching: find.byType(PaceStrip)),
        findsOneWidget,
      );
      await scrollTo(tester, find.text(l10n.statsWeakestTags));
      expect(find.text(l10n.statsWeakestTags), findsOneWidget);
      expect(find.textContaining('strength'), findsNothing);
      expect(find.textContaining('Strength'), findsNothing);
    });
  });
}
