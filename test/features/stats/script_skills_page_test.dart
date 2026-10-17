import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/pacing.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/features/stats/how_you_learn_page.dart';
import 'package:fluenough/features/stats/stats_numbers.dart';
import 'package:fluenough/features/stats/stats_page.dart';

import '../../support/harness.dart';
import '../../support/paced_learner.dart';

/// Reading and writing the script are skills of their own (#556): a Progress
/// row and a How you learn line each, for a learner with script-deck answers,
/// and neither for one without.
///
/// A Hindi learner who answered the first six cards of a script deck, three
/// days ago, in Recognition and Write, and one word deck's cards besides.
Future<AppState> hindiLearner({
  bool scriptAnswers = true,
  bool fitReadScript = false,
}) async {
  AppState build(MemoryProgress progress) => AppState.test(
    progress: progress,
    paceRunner: paceInPlace,
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['hi'],
    )..learningChosen = true,
  );
  final base = build(MemoryProgress());
  await base.load();
  final at = base.now().subtract(const Duration(days: 3));
  final script = base.decks.firstWhere(
    (e) => e.language.code == 'hi' && base.needsAlphabet(e),
  );
  final words = base.decks.firstWhere(
    (e) => e.language.code == 'hi' && !base.needsAlphabet(e),
  );
  final progress = MemoryProgress();
  void answer(String deckId, String cardId, DrillMode mode) => progress.record(
    deckId: deckId,
    cardId: cardId,
    mode: mode,
    grade: 3,
    now: at,
    answerGiven: mode == DrillMode.recognition ? null : 'x',
  );
  for (final card in words.cards.take(6)) {
    answer(card.deckId, card.id, DrillMode.recognition);
  }
  if (scriptAnswers) {
    for (final card in script.cards.take(6)) {
      answer(card.deckId, card.id, DrillMode.recognition);
      answer(card.deckId, card.id, DrillMode.production);
    }
  }
  final state = build(progress);
  await state.load();
  if (fitReadScript) {
    await state.progress.putFitted(
      (language: 'hi', mode: DrillMode.readScript),
      FittedParameters(
        values: w8By(0.6),
        fittedAt: state.now(),
        reviewCount: 6,
        lossBefore: 0.4,
        lossAfter: 0.3,
      ),
    );
  }
  return state;
}

void main() {
  group('Progress', () {
    test('script-deck answers are counted in the script skills and in '
        'the word skills (Both)', () async {
      final state = await hindiLearner();
      final cardOf = cardLookupOf(state);
      final n = StatsNumbers.of(
        state.progress,
        now: state.now(),
        range: StatsRange.all,
        cardOf: cardOf,
      );
      expect(n.scriptSkills.keys, <DrillMode>[
        DrillMode.readScript,
        DrillMode.writeScript,
      ]);
      expect(n.scriptSkills[DrillMode.readScript]!.total, 6);
      expect(n.scriptSkills[DrillMode.writeScript]!.total, 6);
      // The word skills count every answer, the script decks' included, and
      // the script skills' are not counted twice in the totals.
      expect(n.reviews, 18);
    });

    test('a learner without script answers has no script rows', () async {
      final state = await hindiLearner(scriptAnswers: false);
      final n = StatsNumbers.of(
        state.progress,
        now: state.now(),
        range: StatsRange.all,
        cardOf: cardLookupOf(state),
      );
      expect(n.scriptSkills, isEmpty);
      expect(n.bySkill, isNotEmpty);
    });

    test('a language in Latin script has no script rows', () async {
      final state = AppState.test();
      await state.load();
      final card = state.decks
          .firstWhere((e) => e.language.code == 'es')
          .cards
          .first;
      state.progress.record(
        deckId: card.deckId,
        cardId: card.id,
        mode: DrillMode.recognition,
        grade: 4,
        now: state.now(),
      );
      final n = StatsNumbers.of(
        state.progress,
        now: state.now(),
        range: StatsRange.all,
        cardOf: cardLookupOf(state),
      );
      expect(n.scriptSkills, isEmpty);
    });

    for (final dark in <bool>[false, true]) {
      testWidgets('the tab shows Read script and Write script at 1.4x text'
          '${dark ? ', dark' : ''}', (tester) async {
        usePhone(tester, textScale: 1.4);
        final state = await hindiLearner();
        await pumpScreen(
          tester,
          const StatsPage(),
          state: state,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        );
        final l10n = l10nOf(tester);
        await tester.scrollUntilVisible(
          find.text(l10n.skillWriteScript),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.skillReadScript), findsOneWidget);
        expect(find.text(l10n.skillWriteScript), findsOneWidget);
        expect(find.text(l10n.skillRecognition), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('without script answers the tab shows neither', (tester) async {
      usePhone(tester);
      final state = await hindiLearner(scriptAnswers: false);
      await pumpScreen(tester, const StatsPage(), state: state);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.skillReadScript), findsNothing);
      expect(find.text(l10n.skillWriteScript), findsNothing);
    });
  });

  group('How you learn', () {
    testWidgets('each script skill has its line, not adjusted yet', (
      tester,
    ) async {
      usePhone(tester, textScale: 1.4);
      final state = await hindiLearner();
      await pumpScreen(tester, const HowYouLearnPage(), state: state);
      final l10n = l10nOf(tester);
      for (final mode in <String>['readScript', 'writeScript']) {
        final line = l10n.adjustedNotYet(mode);
        await tester.scrollUntilVisible(
          find.text(line),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text(line), findsOneWidget);
        expect(find.text(l10n.paceSkillName(mode)), findsOneWidget);
      }
      expect(find.text(l10n.paceNotYet(6)), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    for (final dark in <bool>[false, true]) {
      testWidgets(
        'a fitted Read script says how it comes back, in its own words'
        '${dark ? ', dark' : ''}',
        (tester) async {
          usePhone(tester, textScale: 1.4);
          final state = await hindiLearner(fitReadScript: true);
          await pumpScreen(
            tester,
            const HowYouLearnPage(),
            state: state,
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          );
          final l10n = l10nOf(tester);
          final pace = state
              .pacing
              .paces![(language: 'hi', mode: DrillMode.readScript)]!;
          expect(pace.adjusted, isTrue);
          final sentence = pace.now.days == pace.start.days
              ? l10n.paceComesBackSame('readScript', pace.now.days)
              : l10n.paceComesBack(
                  'readScript',
                  pace.now.days,
                  pace.start.days,
                );
          await tester.scrollUntilVisible(
            find.text(sentence),
            200,
            scrollable: find.byType(Scrollable).last,
          );
          expect(find.text(sentence), findsOneWidget);
          expect(sentence, contains('letter you read'));
          // Write script was not fitted: it keeps the start's pace.
          expect(find.text(l10n.adjustedNotYet('writeScript')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('a learner without script answers has no script line', (
      tester,
    ) async {
      usePhone(tester);
      final state = await hindiLearner(scriptAnswers: false);
      await pumpScreen(tester, const HowYouLearnPage(), state: state);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.paceSkillName('readScript')), findsNothing);
      expect(find.text(l10n.paceSkillName('writeScript')), findsNothing);
    });
  });
}
