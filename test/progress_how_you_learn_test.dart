// Split out of progress_test.dart so that CI can spread it over its shards;
// the tests and their names are unchanged. This file holds: How you learn, the pace strip, leeches.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/pacing.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/skill_fit.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/stats/how_you_learn_page.dart';
import 'package:fluenough/features/stats/leeches.dart';
import 'package:fluenough/features/stats/leeches_page.dart';
import 'package:fluenough/features/today/due_card.dart';
import 'package:fluenough/features/today/today_numbers.dart';
import 'package:fluenough/features/today/today_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/skill_visuals.dart';
import 'package:fluenough/ui/widgets/pace_parts.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/paced_learner.dart';

// From how_you_learn_page_test.dart.
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

Future<void> scrollToHowYouLearnPage(WidgetTester tester, Finder finder) async {
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

// From pace_test.dart.
/// [skill]'s name on its tile.
Finder nameOf(WidgetTester tester, Skill skill) => find.descendant(
  of: find.byType(DueCard),
  matching: find.text(skill.label(l10nOf(tester))),
);

/// The mark on [skill]'s tile, if any.
Finder markOn(WidgetTester tester, Skill skill) => find.descendant(
  of: find
      .ancestor(of: nameOf(tester, skill), matching: find.byType(Material))
      .first,
  matching: find.byType(PaceMark),
);

Future<AppState> onToday(
  WidgetTester tester,
  Paced paced, {
  Set<Paced> also = const <Paced>{},
  double textScale = 1.0,
  PaceRunner paceRunner = paceInPlace,
}) async {
  usePhone(tester, textScale: textScale);
  final state = await pacedLearner(paced, also: also, paceRunner: paceRunner);
  await pumpScreen(tester, const TodayPage(), state: state);
  await tester.ensureVisible(find.byType(DueCard));
  await tester.pumpAndSettle();
  return state;
}

// From leeches_page_test.dart.
Future<AppState> fixtureLeechesPage({
  FeatureRegistry? features,
  bool history = true,
}) async {
  final app = AppState.test();
  await app.load();
  return GalleryFixtures.state(
    app,
    features: features ?? FeatureRegistry.all(),
    history: history,
  );
}

/// The first fixture leech: la leche, es-en-core-100, production, 5 lapses.
Finder firstCard() => find.byType(LeechCard).first;

Finder inFirst(Finder f) => find.descendant(of: firstCard(), matching: f);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('How you learn', () {
    group('How you learn', () {
      testWidgets(
        'before any fit it says what will happen; after one, slower or faster '
        'per skill',
        (tester) async {
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
          for (final mode in <String>[
            'recognition',
            'listening',
            'production',
          ]) {
            await scrollToHowYouLearnPage(
              tester,
              find.text(l10n.adjustedNotYet(mode)),
            );
            expect(find.text(l10n.adjustedNotYet(mode)), findsOneWidget);
          }
          expect(find.text(l10n.paceNotYet(8)), findsNWidgets(3));
          expect(state.progress.parameters.fitted, isEmpty);
          expect(find.text(l10n.paceAdjustedToday(24)), findsNothing);

          {
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
            await scrollToHowYouLearnPage(tester, find.text(verdict));
            expectAdjusted(tester, l10n, hear, verdict);
            expect(
              find.text(
                l10n.paceComesBack('listening', hear.now.days, hear.start.days),
              ),
              findsOneWidget,
            );
            final scheme = Theme.of(tester.element(find.text(verdict)))
                .colorScheme;
            expect(verdictColour(tester, verdict), scheme.primaryContainer);
            // The others are not adjusted yet.
            expect(
              find.text(l10n.adjustedNotYet('production')),
              findsOneWidget,
            );

            await scrollToHowYouLearnPage(
              tester,
              find.text(l10n.adjustedPrivacy),
            );
            expect(find.text(l10n.paceAdjustedToday(8)), findsOneWidget);
          }
        },
      );
    });
  });

  group('the pace strip', () {
    testWidgets(
      'Today has no Adjusted to you strip, before or after a fit; after a '
      'slower fit, the skill is marked Fewer reviews',
      (tester) async {
        var runs = 0;
        await onToday(
          tester,
          Paced.none,
          paceRunner: (job) {
            runs++;
            return paceInPlace(job);
          },
        );
        final l10n = l10nOf(tester);
        expect(find.text(l10n.adjustedTitle), findsNothing);
        expect(find.byType(PaceStrip), findsNothing);
        expect(find.byType(PaceMark), findsNothing);
        expect(runs, 0, reason: 'only stored fits are read before a fit');

        {
          final state = await onToday(tester, Paced.fewer);
          final l10n = l10nOf(tester);
          final pace = TodayNumbers.of(state).pace!;

          // The strip is gone from Today (owner, 2026-11-04); the tile's
          // arrow is how it shows, and How you learn opens from the info
          // dot, from Settings and from Progress.
          expect(find.text(l10n.adjustedTitle), findsNothing);
          expect(find.byType(PaceStrip), findsNothing);
          expect(pace.marks, {Skill.listening: PaceDirection.fewer});
          // An arrow with no words; the tile's label below names it.
          expect(markOn(tester, Skill.listening), findsOneWidget);
          expect(find.text(l10n.paceFewer), findsNothing);
          expect(markOn(tester, Skill.recognition), findsNothing);
          expect(markOn(tester, Skill.production), findsNothing);
          // The screen reader hears it too.
          expect(
            find.bySemanticsLabel(
              l10n.todaySkillAdjustedSemantics(
                Skill.listening.label(l10n),
                TodayNumbers.of(state).bySkill[Skill.listening]!,
                'fewer',
              ),
            ),
            findsOneWidget,
          );
        }
      },
    );
  });

  group('leeches', () {
    testWidgets('Reset, Undo, Set aside and Bring back append, never delete', (
      tester,
    ) async {
      usePhone(tester);
      final state = await pumpScreen(
        tester,
        const LeechesPage(),
        state: await fixtureLeechesPage(),
      );
      final l10n = l10nOf(tester);
      final deck = state.deckById('es-en-core-100')!.deck.name;
      final skill = l10n.skillProduction;
      final before = List<ReviewEvent>.of(state.progress.log);
      Map<ProgressKey, String> byValue() => {
        for (final MapEntry(:key, :value) in state.progress.states.entries)
          key:
              '${value.stability} ${value.difficulty} ${value.intervalDays} '
              '${value.dueAt} ${value.lapses}',
      };
      final statesBefore = byValue();
      final actions = LeechActions.of(state.progress);

      Future<void> tap(String label) async {
        await tester.tap(inFirst(find.text(label)));
        await tester.pumpAndSettle();
      }

      double opacity() => tester
          .widget<AnimatedOpacity>(
            find.descendant(
              of: firstCard(),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;

      await tap(l10n.leechesReset);
      expect(
        inFirst(find.text(l10n.leechesMetaReset(deck, skill))),
        findsOneWidget,
      );
      expect(inFirst(find.text(l10n.commonUndo)), findsOneWidget);
      expect(opacity(), lessThan(1));

      await tap(l10n.commonUndo);
      expect(inFirst(find.text(l10n.leechesMeta(deck, skill))), findsOneWidget);
      expect(opacity(), 1);

      await tap(l10n.leechesSetAside);
      expect(
        inFirst(find.text(l10n.leechesMetaSetAside(deck, skill))),
        findsOneWidget,
      );
      expect(inFirst(find.text(l10n.leechesReset)), findsOneWidget);

      await tap(l10n.leechesBringBack);
      expect(inFirst(find.text(l10n.leechesSetAside)), findsOneWidget);

      expect(actions.log.map((a) => a.kind), <LeechActionKind>[
        LeechActionKind.reset,
        LeechActionKind.undoReset,
        LeechActionKind.setAside,
        LeechActionKind.bringBack,
      ]);
      expect(state.progress.log, orderedEquals(before), reason: 'rule 9');
      expect(byValue(), statesBefore, reason: 'undone and brought back');
    });
  });
}
