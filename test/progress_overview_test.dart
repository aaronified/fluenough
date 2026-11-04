// Split out of progress_test.dart so that CI can spread it over its shards;
// the tests and their names are unchanged. This file holds: the numbers, Progress, streaks and words learned, Known, Learning and New, a unit, a deck's status, toward B1, the script skills, the script skills per script, hours.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/data/course_path.dart'
    show CoursePath, Milestone, PlanUnit;
import 'package:fluenough/core/data/log_jsonl.dart';
import 'package:fluenough/core/decks/language_catalog.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/scheduling/skill_map.dart';
import 'package:fluenough/core/scheduling/study_hours.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/decks/path_model.dart';
import 'package:fluenough/features/decks/path_parts.dart';
import 'package:fluenough/features/decks/unit_page.dart';
import 'package:fluenough/features/decks/word_mastery.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/walkthrough_page.dart';
import 'package:fluenough/ui/widgets/learn_button.dart';
import 'package:fluenough/features/stats/leeches.dart';
import 'package:fluenough/features/stats/stats_numbers.dart';
import 'package:fluenough/features/stats/stats_page.dart';
import 'package:fluenough/ui/widgets/deck_tile.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/progress_shared.dart';

// From stats_numbers_test.dart.
/// A known log on real cards of `es-en-core-100`, whose tags are `people`
/// (0001) and `home` (0006–0009). The clock is Mon 28 Sep 2026, 19:00.
///
/// | day | card, mode, grade |
/// | --- | --- |
/// | −100 | 0009 recognition 4 (outside the grid) |
/// | −40 | 0001 recognition 4 |
/// | −20 | 0001 production 1, 0006 recognition 5 |
/// | −3 | 0006 production 2, 0007 recognition 4 |
/// | −2 | 0007 recognition 4 |
/// | −1 | 0008 recognition 4 |
/// | 0 | 0001 recognition 3 |
MemoryProgress knownLog(DateTime now) {
  final progress = MemoryProgress();
  final today = dateOnly(now);
  void at(int day, String card, DrillMode mode, int grade) => progress.record(
    deckId: 'es-en-core-100',
    cardId: 'es-$card',
    mode: mode,
    grade: grade,
    now: addDays(today, day).add(const Duration(hours: 9)),
  );
  const r = DrillMode.recognition;
  const p = DrillMode.production;
  at(-100, '0009', r, 4);
  at(-40, '0001', r, 4);
  at(-20, '0001', p, 1);
  at(-20, '0006', r, 5);
  at(-3, '0006', p, 2);
  at(-3, '0007', r, 4);
  at(-2, '0007', r, 4);
  at(-1, '0008', r, 4);
  at(0, '0001', r, 3);
  return progress;
}

// From word_mastery_test.dart.
/// [grades] for [card], a day apart from [start], in alternating skills.
void answer(
  MemoryProgress progress,
  String card,
  List<int> grades, {
  DateTime? start,
}) {
  final from = start ?? DateTime(2026, 9, 1);
  for (final (i, grade) in grades.indexed) {
    progress.record(
      deckId: 'xx-deck',
      cardId: card,
      mode: i.isEven ? DrillMode.recognition : DrillMode.production,
      grade: grade,
      now: from.add(Duration(days: i)),
    );
  }
}

/// [grades] for [card] in [mode], a minute apart, so that each right answer
/// is at nearly full recall.
void minutesApart(
  MemoryProgress progress,
  String card,
  List<int> grades, {
  DrillMode mode = DrillMode.recognition,
}) {
  for (final (i, grade) in grades.indexed) {
    progress.record(
      deckId: 'xx-deck',
      cardId: card,
      mode: mode,
      grade: grade,
      now: DateTime(2026, 9, 1).add(Duration(minutes: i)),
    );
  }
}

/// The same learner, who also knows Telugu and reads its script, and
/// reviews it (#525): the one who is offered Review.
Future<AppState> teluguReviewer() async {
  final app = await teluguLearner();
  app.settings
    ..spokenLanguages = const <String>['en', 'te']
    ..scriptsRead = const <String, bool>{'en': true, 'te': true}
    ..reviewLanguages = const <String>{'te'};
  return app;
}

/// A phone tall enough for the unit's lazy list to build every row.
void useTallPhone(WidgetTester tester) {
  usePhone(tester);
  tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
}

/// A course of one unit: a word whose partner sounds almost the same and
/// is rude, the partner, and a phrase.
MemoryDeckSource tinyCourse() => MemoryDeckSource(const <String, String>{
  'decks/es/es-en-tiny.yaml': '''
schema: 1
id: es-en-tiny
name: Tiny
kind: vocab
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native:   { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: es-9001
    target: "gato"
    native: "cat"
    ipa: "ˈɡato"
    notes: "A plain note."
    pair: "es-9002"
  - id: es-9002
    target: "gatu"
    native: "a rude word"
    tags: ["offensive"]
  - id: es-9003
    target: "buenos días a todos"
    native: "good morning, everyone"
    pos: "phrase"
''',
  'decks/es/es-path.yaml': '''
schema: 1
kind: path
id: es-path
language: es
units:
  - [es-tiny]
''',
});

// From deck_status_test.dart.
const String tiny = 'es-en-tiny';

/// Two cards, drilled by sight and typed: no voice in tests.
AppState tinyState({
  SettingsNotifier? settings,
  ProgressStore? progress,
  DateTime? now,
}) => AppState.test(
  decks: MemoryDeckSource(<String, String>{
    'decks/es/$tiny.yaml':
        '''
schema: 1
id: $tiny
name: "Tiny"
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: $tiny-0001, target: "hola", native: "hello" }
  - { id: $tiny-0002, target: "adiós", native: "goodbye" }
''',
  }),
  settings: settings,
  progress: progress,
  now: now,
);

DeckBadgeKind badgeOf(AppState state, String deckId) =>
    DeckBadge.forEntry(state, state.deckById(deckId)!).kind;

// From language_catalog_test.dart.
/// The language picker's catalog (#211, `docs/plans/language-picker.md`):
/// completeness toward B1 from a path's plan, the Alpha and Beta stages,
/// search, and the picker's order. No Flutter: these run in milliseconds.

B1Unit written(int has, {int? words, Milestone? milestone, List<String>? g}) =>
    B1Unit(
      has: has,
      words: words,
      milestone: milestone,
      grammar: g ?? const <String>[],
    );

B1Unit planned(int words, {Milestone? milestone, List<String>? g}) => B1Unit(
  planned: true,
  words: words,
  milestone: milestone,
  grammar: g ?? const <String>[],
);

// From script_skills_test.dart.
/// Reading and writing the script are skills of their own (#556; owner,
/// 2026-10-17: "Both" and "Rebuild from the log"): the answers to the script
/// decks count for the word skills as today and, in full, for Read script and
/// Write script, which are worked out from the log.

// From script_skills_per_script_test.dart.
/// Each script a course is learned in has a Read and a Write of its own
/// (#653; owner, 2026-10-19: "Yes, per script."): Hindustani has Devanagari
/// and Perso-Arabic Read and Write. Read is fed by the script decks'
/// Recognition, by choosing script text, and by reading a word for its
/// meaning; Write by the script decks' Write and by typing in the script.
/// Outside the script decks an answer counts for half a review; shown or
/// typed in transliteration, it feeds none.

// From study_hours_test.dart.
final DateTime t0 = DateTime.utc(2026, 10, 1);

FsrsState stateWith(int intervalDays, {double stability = 2}) => FsrsState(
  stability: stability,
  difficulty: 5,
  intervalDays: intervalDays,
  dueAt: t0.add(Duration(days: intervalDays)),
  lastReviewAt: t0,
);

/// Asserts the Learn / Relearn label is drawn whole: not ellipsized or cut.
void expectLabelFits(WidgetTester tester) {
  final label = find.descendant(
    of: find.byKey(LearnButton.textKey),
    matching: find.byType(RichText),
  );
  expect(label, findsWidgets);
  final paragraph = tester.renderObject<RenderParagraph>(label.first);
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(
    paragraph.size.width,
    lessThanOrEqualTo(
      tester.getSize(find.byKey(LearnButton.textKey)).width + 0.5,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the numbers', () {
    late AppState app;
    late CardLookup cardOf;
    late MemoryProgress progress;
    setUpAll(() async {
      app = AppState.test();
      await app.load();
      cardOf = cardLookupOf(app);
    });
    setUp(() => progress = knownLog(app.now()));

    StatsNumbers numbers(StatsRange range) =>
        StatsNumbers.of(progress, now: app.now(), range: range, cardOf: cardOf);

    test('7 days, 30 days and all time: each widens every number', () {
      final n = numbers(StatsRange.week);
      expect(n.reviews, 5);
      expect(n.remembered, 4 / 5);
      expect(n.streak, 4);
      expect(n.learned, 2, reason: '0011 and 0012 were first remembered');
      expect(n.bySkill.keys, <Skill>[Skill.recognition, Skill.production]);
      expect(n.bySkill[Skill.recognition]!.ratio, 1.0);
      expect(n.bySkill[Skill.production]!.ratio, 0.0);
      // Weakest tags are of what is known now, whatever the range: of the
      // five home pairs only 0007 (two days running) is known; neither
      // people pair is.
      expect(n.weakestTags.keys, <String>['people', 'home']);
      expect(n.weakestTags['home']!.correct, 1);
      expect(n.weakestTags['home']!.total, 5);
      expect(n.weakestTags['people']!.ratio, 0.0);

      final month = numbers(StatsRange.month);
      expect(month.reviews, 7);
      expect(month.remembered, 5 / 7);
      expect(month.learned, 3);

      final all = numbers(StatsRange.all);
      expect(all.reviews, 9);
      expect(all.remembered, 7 / 9);
      expect(all.learned, 5);
      expect(all.longestStreak, 4);
      expect(all.bySkill[Skill.production]!.ratio, 0.0);
      expect(all.weakestTags.keys, n.weakestTags.keys);
      expect(all.weakestTags['home']!.ratio, 1 / 5);
    });

    test('a card remembered in two decks is learned once; one language counts '
        'its own reviews and streak', () {
      final progress = MemoryProgress();
      for (final (i, deck) in <String>[
        'es-en-core-100',
        'es-en-other',
      ].indexed) {
        progress.record(
          deckId: deck,
          cardId: 'es-0001',
          mode: DrillMode.values[i],
          grade: 5,
          now: addDays(app.now(), -1 - i),
        );
      }
      final n = StatsNumbers.of(
        progress,
        now: app.now(),
        range: StatsRange.week,
        cardOf: cardOf,
      );
      expect(n.reviews, 2);
      expect(n.learned, 1);

      {
        // The group's log of known Spanish reviews, beside which Hindi goes.
        final progress = knownLog(app.now());
        final languageOf = languageLookupOf(app);

        /// A Hindi review on each of [days], counted from today, beside the
        /// Spanish log.
        void addHindi(MemoryProgress progress, List<int> days) {
          final deck = app.deckById('hi-en-script-vowels')!;
          for (final day in days) {
            progress.record(
              deckId: deck.id,
              cardId: deck.cards.first.id,
              mode: DrillMode.recognition,
              grade: 4,
              now: addDays(
                dateOnly(app.now()),
                day,
              ).add(const Duration(hours: 9)),
            );
          }
        }

        StatsNumbers numbersIn(String? code) => StatsNumbers.of(
          progress,
          now: app.now(),
          range: StatsRange.week,
          cardOf: cardOf,
          deckFilter: code == null ? null : (deck) => languageOf(deck) == code,
        );

        addHindi(progress, <int>[-6, -5]);
        final spanish = numbersIn('es');
        expect(spanish.reviews, 5);
        expect(spanish.streak, 4);
        expect(spanish.heatmapReviews, 8);

        final hindi = numbersIn('hi');
        expect(hindi.reviews, 2);
        expect(hindi.remembered, 1.0);
        expect(hindi.streak, 0, reason: 'nothing since five days ago');
        expect(hindi.learned, 1);
        expect(hindi.weakestTags.keys, isNot(contains('home')));
        expect(hindi.heatmapReviews, 2);

        final all = numbersIn(null);
        expect(all.reviews, 7);
        expect(all.streak, 4);
        expect(all.heatmapReviews, 10);
      }
    });

    test('a leech is a pair at or over the threshold, found in the states', () {
      for (var i = 0; i < kLeechThreshold; i++) {
        progress
          ..record(
            deckId: 'es-en-core-100',
            cardId: 'es-0002',
            mode: DrillMode.production,
            grade: 4,
            now: app.now(),
          )
          ..record(
            deckId: 'es-en-core-100',
            cardId: 'es-0002',
            mode: DrillMode.production,
            grade: 1,
            now: app.now(),
          );
      }
      final leeches = findLeeches(progress, cardOf: cardOf);
      expect(leeches.map((l) => l.card.id), <String>['es-0002']);
      expect(leeches.single.lapses, kLeechThreshold);
      expect(
        findLeeches(progress, cardOf: cardOf, threshold: kLeechThreshold + 1),
        isEmpty,
      );
    });
  });

  group('Progress', () {
    testWidgets('with no reviews it says so', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        const StatsPage(),
        state: AppState.test(features: FeatureRegistry.all()),
      );
      expect(find.text(l10nOf(tester).statsNoReviews), findsOneWidget);
    });
  });

  group('streaks and words learned', () {
    final monday = DateTime(2026, 9, 28, 19);

    ReviewEvent answer(
      MemoryProgress progress,
      String card,
      int grade, {
      DateTime? at,
      DrillMode mode = DrillMode.recognition,
      String deck = 'es-en-core-100',
    }) => progress.record(
      deckId: deck,
      cardId: card,
      mode: mode,
      grade: grade,
      now: at ?? monday,
    );

    group('streak', () {
      MemoryProgress onDays(List<int> daysAgo) {
        final progress = MemoryProgress();
        for (final d in daysAgo) {
          answer(progress, 'c$d', 5, at: monday.subtract(Duration(days: d)));
        }
        return progress;
      }

      test('a streak counts consecutive days ending today, across a daylight '
          'saving change', () {
        expect(onDays([0, 1, 2]).streakAt(monday), 3);

        expect(addDays(DateTime(2026, 10, 24, 12), 1), DateTime(2026, 10, 25));
        expect(dateOnly(DateTime(2026, 9, 28, 23, 59)), DateTime(2026, 9, 28));
        expect(
          isSameDay(DateTime(2026, 9, 28), DateTime(2026, 9, 28, 23)),
          isTrue,
        );
      });
    });

    test('learned counts distinct cards remembered at least once', () {
      final progress = MemoryProgress();
      answer(progress, 'a', 5);
      answer(progress, 'a', 5, mode: DrillMode.production);
      answer(progress, 'b', 1);
      answer(progress, 'c', 4, deck: 'hi-en-script-vowels');
      expect(progress.learnedIn(<String>['a', 'b']), 1);
      expect(progress.learnedIn(<String>['c']), 1);
      // A card is learned in every deck that lists it (ADR-0018).
      expect(progress.learnedIn(<String>['c', 'd']), 1);
    });
  });

  group('Known, Learning and New', () {
    test('known is the Progress star\'s known: the last review in every skill '
        'was right and FSRS gave it 85% recall; a later miss makes it '
        'learning again', () {
      final progress = MemoryProgress();
      // Right every time, a minute apart: recall is near certain.
      minutesApart(progress, 'xx-0001', [1, 1, 1, 4, 4, 4]);
      // Right in one skill, missed in the other: not known.
      minutesApart(progress, 'xx-0002', [4, 4], mode: DrillMode.recognition);
      minutesApart(progress, 'xx-0002', [4, 1], mode: DrillMode.production);
      // Right, but 400 days after the last review: recall has gone.
      progress.record(
        deckId: 'xx-deck',
        cardId: 'xx-0003',
        mode: DrillMode.recognition,
        grade: 4,
        now: DateTime(2026, 9, 1),
      );
      progress.record(
        deckId: 'xx-deck',
        cardId: 'xx-0003',
        mode: DrillMode.recognition,
        grade: 4,
        now: DateTime(2027, 10, 5),
      );
      // One review is no recall to measure yet.
      minutesApart(progress, 'xx-0004', [4]);
      final answers = RecentAnswers(progress.log);
      expect(answers.of('xx-0001').level, MasteryLevel.known);
      expect(answers.of('xx-0001').share, 1.0);
      expect(answers.of('xx-0002').level, MasteryLevel.learning);
      expect(answers.of('xx-0002').share, closeTo(0.5, 1e-9));
      expect(answers.of('xx-0003').level, MasteryLevel.learning);
      expect(answers.of('xx-0004').level, MasteryLevel.learning);
      expect(answers.of('xx-0005').level, MasteryLevel.fresh);
      // The first right answer, not the first answer.
      expect(answers.firstPassed('xx-0001'), DateTime(2026, 9, 1, 0, 3));
    });
  });

  group('a unit', () {
    testWidgets(
      'each word is Known, Learning or New; Review with reviewing off says '
      'to turn it on',
      (tester) async {
        useTallPhone(tester);
        final state = await pumpScreen(
          tester,
          const UnitPage(deckId: 'te-en-directions'),
          state: await teluguLearner(upTo: 'te-en-directions'),
        );
        final l10n = l10nOf(tester);
        final content = UnitContent(
          unitOfDeck(state, 'te-en-directions')!.decks,
        );
        final answers = RecentAnswers(state.progress.log);
        final known = content.words
            .where((c) => answers.of(c.id).level == MasteryLevel.known)
            .length;
        expect(known, greaterThan(0));
        expect(
          find.text(l10n.unitFraction('$known', '${content.words.length}')),
          findsOneWidget,
        );
        expect(find.text(l10n.unitWordsKnown), findsOneWidget);
        expect(find.text(l10n.unitRulesKnown), findsOneWidget);
        expect(find.text(l10n.unitSentencesOpen), findsOneWidget);
        expect(find.text(l10n.unitKnownMeans(85)), findsOneWidget);

        // The first six words, then all of them.
        final chips = find.byType(MasteryChip);
        final shownFirst = tester.widgetList(chips).length;
        expect(
          tester
              .widgetList<MasteryChip>(chips)
              .take(6)
              .map((c) => c.mastery.level),
          [for (final c in content.words.take(6)) answers.of(c.id).level],
        );
        await tester.scrollUntilVisible(
          find.text(l10n.unitShowAll(content.words.length)),
          200,
          scrollable: downward.first,
        );
        await tester.tap(find.text(l10n.unitShowAll(content.words.length)));
        await tester.pumpAndSettle();
        expect(tester.widgetList(chips).length, greaterThan(shownFirst));
        expect(find.text(l10n.unitShowFewer), findsOneWidget);
        // Some are still being learned, and some are new.
        final levels = <MasteryLevel>{
          for (final c in content.words) answers.of(c.id).level,
        };
        expect(levels, containsAll(MasteryLevel.values));
        expect(find.textContaining(RegExp(r'^Learning \d+%$')), findsWidgets);

        {
          usePhone(tester);
          final state = await pumpScreen(
            tester,
            const UnitPage(deckId: 'te-en-family'),
            state: await teluguReviewer(),
          );
          final l10n = l10nOf(tester);
          await tester.tap(find.text(l10n.unitReview));
          await tester.pumpAndSettle();
          expect(find.text(l10n.reviewFirstTitle), findsOneWidget);
          expect(find.text(l10n.reviewFirstBody('Telugu')), findsOneWidget);
          await tester.tap(find.text(l10n.reviewFirstNotNow));
          await tester.pumpAndSettle();
          expect(find.text(l10n.reviewFirstTitle), findsNothing);
          expect(state.shellTab.value, isNot(ShellTab.settings));

          await tester.tap(find.text(l10n.unitReview));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.reviewFirstOpenSettings));
          await tester.pumpAndSettle();
          expect(state.shellTab.value, ShellTab.settings);
        }
      },
    );

    testWidgets(
      'Learn walks every card of the unit, with its new and due counts as '
      'subtext, and is Relearn once all are taught',
      (tester) async {
        usePhone(tester);
        final state = await pumpScreen(
          tester,
          const UnitPage(deckId: 'te-en-family'),
          state: await teluguLearner(),
        );
        final l10n = l10nOf(tester);
        final decks = unitOfDeck(state, 'te-en-family')!.decks;
        final walk = state.walkCards(decks);
        final due = state
            .buildSession(
              DrillRequest(deckIds: <String>{for (final e in decks) e.id}),
            )
            .due
            .length;
        final fresh = state.newToWalk(<Card>[for (final w in walk) w.card]);
        expect(due, greaterThan(0));
        expect(fresh, greaterThan(0));
        // One control: Learn, its counts under it, no Continue, no badge.
        expect(find.text(l10n.deckLearn), findsOneWidget);
        expect(find.text(l10n.deckRelearn), findsNothing);
        expect(find.text(l10n.unitLearnSubtext(fresh, due)), findsOneWidget);
        expect(find.textContaining('Continue'), findsNothing);
        expect(find.byType(Badge), findsNothing);
        expect(find.byType(FilterChip), findsNothing);

        await tester.tap(find.text(l10n.deckLearn));
        await tester.pumpAndSettle();
        final request = tester
            .widget<WalkthroughPage>(find.byType(WalkthroughPage))
            .request;
        expect(request.deckIds, <String>[for (final e in decks) e.id]);
        expect(request.tags, isEmpty);
        // The whole unit, taught or not: one count across every deck.
        expect(
          find.text(l10n.drillPositionShort(1, walk.length)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the unit page says Relearn when every card is taught, and walks the '
      'same cards writing nothing',
      (tester) async {
        usePhone(tester);
        final progress = MemoryProgress();
        final state = AppState.test(decks: tinyCourse(), progress: progress);
        await state.load();
        for (final card in state.deckById('es-en-tiny')!.cards) {
          for (final mode in card.modesIn(ttsAvailable: false)) {
            progress.record(
              deckId: 'es-en-tiny',
              cardId: card.id,
              mode: mode,
              grade: 4,
              now: state.now(),
            );
          }
        }
        await pumpScreen(
          tester,
          const UnitPage(deckId: 'es-en-tiny'),
          state: state,
        );
        final l10n = l10nOf(tester);
        expect(find.text(l10n.deckRelearn), findsOneWidget);
        expect(find.text(l10n.deckLearn), findsNothing);
        expect(find.text(l10n.unitLearnSubtext(0, 0)), findsOneWidget);
        final logged = progress.log.length;
        await tester.tap(find.text(l10n.deckRelearn));
        await tester.pumpAndSettle();
        expect(find.byType(WalkthroughPage), findsOneWidget);
        expect(
          find.text(
            l10n.drillPositionShort(
              1,
              state.walkCards(<DeckEntry>[
                state.deckById('es-en-tiny')!,
              ]).length,
            ),
          ),
          findsOneWidget,
        );
        expect(progress.log, hasLength(logged));
      },
    );

    testWidgets(
      'the Learn icon is as tall as the label and subtext together, the '
      'same for Relearn, at 1.4x text with no overflow',
      (tester) async {
        usePhone(tester, textScale: 1.4);
        await pumpScreen(
          tester,
          const UnitPage(deckId: 'te-en-family'),
          state: await teluguLearner(),
        );
        Size size(Key key) => tester.getSize(find.byKey(key));
        final learnIcon = size(LearnButton.iconKey);
        final text = size(LearnButton.textKey);
        expect(learnIcon.height, greaterThanOrEqualTo(text.height - 1));
        expect(learnIcon.height, learnIcon.width);
        expect(
          tester.getCenter(find.byKey(LearnButton.iconKey)).dy,
          closeTo(tester.getCenter(find.byKey(LearnButton.textKey)).dy, 1),
        );
        expect(tester.takeException(), isNull);
        expectLabelFits(tester);

        final done = tinyState();
        await done.load();
        learnAll(done, tiny);
        await pumpScreen(
          tester,
          const DeckDetailPage(deckId: tiny),
          state: done,
        );
        // The deck page has no subtext: its icon is as tall as the label.
        final relearnIcon = size(LearnButton.iconKey);
        expect(relearnIcon.height, relearnIcon.width);
        expect(relearnIcon.height, lessThan(learnIcon.height));
        expect(
          relearnIcon.height,
          greaterThanOrEqualTo(size(LearnButton.textKey).height - 1),
        );
        expect(tester.takeException(), isNull);
        expectLabelFits(tester);
      },
    );
  });

  group('a deck\'s status', () {
    test('a deck is Done once every card is learned in every skill on, and '
        'says how many are due again when they are', () async {
      final state = tinyState();
      addTearDown(state.dispose);
      await state.load();
      final entry = state.deckById(tiny)!;
      expect(state.notStudiedIn(entry), 2);

      // Learned by sight only: production is still to learn. Its course's only
      // deck, so it is the unit Today teaches.
      for (final item in state.buildSession(DrillRequest.deck(tiny)).items) {
        state.record(item, 5);
      }
      expect(badgeOf(state, tiny), DeckBadgeKind.pending);

      learnAll(state, tiny);
      expect(state.notStudiedIn(entry), 0);
      expect(badgeOf(state, tiny), DeckBadgeKind.done);

      final later = tinyState(
        progress: state.progress,
        now: state.now().add(const Duration(days: 8)),
      );
      addTearDown(later.dispose);
      await later.load();
      final badge = DeckBadge.forEntry(later, later.deckById(tiny)!);
      expect(badge.kind, DeckBadgeKind.due);
      expect(badge.count, 2);
    });

    testWidgets(
      'a finished deck offers Relearn, and Practice records every answer',
      (tester) async {
        usePhone(tester);
        final state = tinyState();
        await state.load();
        learnAll(state, tiny);
        await pumpScreen(
          tester,
          const DeckDetailPage(deckId: tiny),
          state: state,
        );
        final l10n = l10nOf(tester);

        // Every word is taught: Learn has become Relearn, with no badge.
        expect(find.text(l10n.deckLearn), findsNothing);
        expect(find.text(l10n.deckRelearn), findsOneWidget);
        expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, false);
        await tester.tap(find.text(l10n.deckPractice));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.deckPracticeStart));
        await tester.pumpAndSettle();
        expect(find.byType(DrillPage), findsOneWidget);
        // Titled with the deck, not as number practice.
        expect(find.text('Tiny'), findsOneWidget);

        final logged = state.progress.log.length;
        final states = Map.of(state.progress.states);
        // Recognition comes first (ADR-0034), rated with only two cards to
        // choose among.
        await tester.tap(find.text(l10n.drillShowAnswer));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.rateGood));
        await tester.pumpAndSettle();
        expect(state.progress.log, hasLength(logged + 1));
        expect(state.progress.states, isNot(states));

        // Ending part-way says the answers so far are recorded (ADR-0033).
        await tester.tap(find.byTooltip(l10n.drillEndSession));
        await tester.pumpAndSettle();
        expect(find.text(l10n.drillEndBody), findsOneWidget);
        expect(find.text(l10n.drillEndBodyNotRecorded), findsNothing);
      },
    );
  });

  group('toward B1', () {
    test('a path\'s own words per level are the words B1 holds, else the sum '
        'of its units up to B1', () {
      const units = <PlanUnit>[
        PlanUnit(words: 5, milestone: Milestone.a1),
        PlanUnit(words: 5, milestone: Milestone.a2),
        PlanUnit(words: 5, milestone: Milestone.b1),
        PlanUnit(words: 500),
      ];
      CoursePath path(Map<Milestone, int>? levels) => CoursePath(
        id: 'zz-path',
        language: 'zz',
        native: 'en',
        units: const <List<String>>[],
        plan: units,
        levels: levels,
      );
      expect(path(null).plannedWords, 15);
      expect(
        path(<Milestone, int>{
          Milestone.a1: 120,
          Milestone.a2: 60,
          Milestone.b1: 80,
        }).plannedWords,
        260,
      );
    });

    group('completeness toward B1', () {
      test(
        'completeness is the words written over the words planned, up to B1, '
        'and the stage is Alpha, Beta, then Complete',
        () {
          final p = B1Progress.of(<B1Unit>[
            written(30, words: 40, milestone: Milestone.a1),
            written(20, words: 20, milestone: Milestone.a2),
            planned(40, milestone: Milestone.b1),
            // After B1: not counted.
            written(500, words: 500),
          ]);
          expect(p.hasPlan, isTrue);
          expect(p.plannedWords, 100);
          expect(p.writtenWords, 50);
          expect(p.percent, 50);

          {
            final p = B1Progress.of(<B1Unit>[
              written(10, words: 10),
              planned(10, milestone: Milestone.a1),
              planned(10, milestone: Milestone.b1),
            ]);
            expect(p.stage, CourseStage.alpha);
          }

          {
            final p = B1Progress.of(<B1Unit>[
              written(10, words: 10, milestone: Milestone.a1),
              planned(10, milestone: Milestone.a2),
              planned(10, milestone: Milestone.b1),
            ]);
            expect(p.stage, CourseStage.beta);
          }

          expect(
            B1Progress.of(<B1Unit>[
              written(5),
              written(5),
            ], isNotation: true).stage,
            CourseStage.complete,
          );
          expect(
            B1Progress.of(<B1Unit>[
              written(5),
              planned(5),
            ], isNotation: true).stage,
            CourseStage.alpha,
          );
          // Braille's path: six units written and the open last one, for decks
          // a learner adds and the contractions to come (ADR-0043).
          expect(
            B1Progress.of(<B1Unit>[
              for (var i = 0; i < 6; i++) written(10),
              const B1Unit(),
            ], isNotation: true).stage,
            CourseStage.complete,
          );
          expect(B1Progress.of(<B1Unit>[written(5)]).stage, CourseStage.alpha);
        },
      );
    });

    group('search', () {
      final hindi = language('hi', 'Hindi', own: 'हिन्दी');
      final marathi = language('mr', 'Marathi', own: 'मराठी');
      final spanish = language('es', 'Spanish', own: 'Español');
      final telugu = language('te', 'Telugu', own: 'తెలుగు');
      final all = <CatalogLanguage>[hindi, marathi, spanish, telugu];
      List<String> codes(String q) => <String>[
        for (final l in all)
          if (LanguageSearch.matches(l, q)) l.code,
      ];

      test(
        'search matches English names, and own names with accents ignored',
        () {
          expect(codes('hi'), <String>['hi', 'mr']);
          expect(codes('TELU'), <String>['te']);

          expect(codes('espanol'), <String>['es']);
          expect(codes('Español'), <String>['es']);
          expect(codes('తెలు'), <String>['te']);
        },
      );
    });
  });

  group('the script skills', () {
    final day = DateTime(2026, 10, 1, 9);
    const script = 'hi-script-vowels';
    const words = 'hi-first-words';
    const map = SkillMap(
      formHeardIn: <String>{script},
      scriptDecks: <String>{script},
      primaryScripts: <String, String>{'hi': 'devanagari'},
    );

    // Script-deck answers from before the script was kept per answer count
    // for the course's primary script (#653).
    const read = (
      cardId: 'hi-0001',
      mode: DrillMode.readScript,
      script: 'devanagari',
    );
    const write = (
      cardId: 'hi-0001',
      mode: DrillMode.writeScript,
      script: 'devanagari',
    );
    const recognition = (cardId: 'hi-0001', mode: DrillMode.recognition);

    LoggedReview review(
      DrillMode mode,
      int grade,
      DateTime at, {
      String deck = script,
      String card = 'hi-0001',
    }) => (
      key: (cardId: card, mode: mode),
      deckId: deck,
      at: at,
      grade: grade,
      elapsed: Duration.zero,
      answerGiven: mode == DrillMode.recognition ? null : 'x',
      script: null,
      asked: null,
    );

    group('rebuilt from the log', () {
      final log = <LoggedReview>[
        review(DrillMode.recognition, 4, day),
        review(DrillMode.production, 3, day.add(const Duration(hours: 1))),
        review(DrillMode.recognition, 5, day.add(const Duration(days: 3))),
        review(DrillMode.recognition, 3, day, deck: words, card: 'hi-0002'),
      ];

      test(
        'script-deck answers give Read and Write states of their own; a word '
        'deck feeds no script skill',
        () {
          final replayed = replayReviews(log, skills: map);
          expect(replayed.scriptStates.keys.toSet(), {read, write});
          expect(replayed.scriptStates[read]!.repetitions, 2);
          expect(replayed.scriptStates[write]!.repetitions, 1);
          expect(replayed.scriptEvents, hasLength(3));
          expect(replayed.scriptEvents.first.mode, DrillMode.readScript);
          expect(replayed.scriptEvents.first.wasNew, isTrue);
          expect(replayed.scriptEvents.last.before, isNotNull);

          {
            final replayed = replayReviews(<LoggedReview>[
              review(DrillMode.recognition, 4, day, deck: words),
            ], skills: map);
            expect(replayed.scriptStates, isEmpty);
          }
        },
      );

      test('each skill is scheduled with its own fit', () {
        final fitted = FittedParameters(
          values: <double>[
            for (final (i, w) in Fsrs.w.indexed) i == 8 ? w + 0.6 : w,
          ],
          fittedAt: day,
          reviewCount: 30,
        );
        final parameters = SkillParameters(
          fitted: <SkillKey, FittedParameters>{
            (language: 'hi', mode: DrillMode.readScript): fitted,
          },
        );
        final replayed = replayReviews(
          log,
          skills: map,
          parameters: parameters,
        );
        final plain = replayReviews(log, skills: map);
        expect(
          replayed.scriptStates[read]!.stability,
          isNot(plain.scriptStates[read]!.stability),
        );
        expect(
          replayed.scriptStates[write]!.stability,
          plain.scriptStates[write]!.stability,
        );
        expect(
          replayed.states[recognition]!.stability,
          plain.states[recognition]!.stability,
        );
      });
    });
  });

  group('the script skills per script', () {
    const devanagari = 'devanagari';
    const persoArabic = 'perso_arabic';
    const letters = 'hi-en-letters';
    const words = 'hi-en-words';
    const map = SkillMap(
      formHeardIn: <String>{letters},
      scriptDecks: <String>{letters},
      primaryScripts: <String, String>{'hi': devanagari},
    );
    final day = DateTime(2026, 10, 1, 9);

    LoggedReview review(
      DrillMode mode, {
      String deck = words,
      String card = 'hi-0001',
      int grade = 4,
      DateTime? at,
      String? script,
      Ask? asked,
    }) => (
      key: (cardId: card, mode: mode),
      deckId: deck,
      at: at ?? day,
      grade: grade,
      elapsed: Duration.zero,
      answerGiven: mode == DrillMode.recognition ? null : 'x',
      script: script,
      asked: asked,
    );

    group('replayed per script', () {
      test(
        'one word read in both scripts has a Read of each; an answer elsewhere '
        'is half a review, one in a script deck a whole one',
        () {
          final replayed = replayReviews(<LoggedReview>[
            review(DrillMode.recognition, script: devanagari, asked: Ask.own),
            review(
              DrillMode.recognition,
              script: persoArabic,
              asked: Ask.own,
              at: day.add(const Duration(days: 1)),
            ),
            review(
              DrillMode.production,
              script: persoArabic,
              asked: Ask.own,
              at: day.add(const Duration(days: 2)),
            ),
          ], skills: map);
          expect(replayed.scriptStates.keys.toSet(), <ScriptKey>{
            (cardId: 'hi-0001', mode: DrillMode.readScript, script: devanagari),
            (
              cardId: 'hi-0001',
              mode: DrillMode.readScript,
              script: persoArabic,
            ),
            (
              cardId: 'hi-0001',
              mode: DrillMode.writeScript,
              script: persoArabic,
            ),
          });
          expect(replayed.scriptEvents.map((e) => e.share), <double>[
            0.5,
            0.5,
            0.5,
          ]);
          expect(replayed.scriptEvents.map((e) => e.script), <String>[
            devanagari,
            persoArabic,
            persoArabic,
          ]);

          final half = replayReviews(<LoggedReview>[
            review(DrillMode.recognition, script: devanagari, asked: Ask.own),
          ], skills: map);
          final whole = replayReviews(<LoggedReview>[
            review(
              DrillMode.recognition,
              deck: letters,
              script: devanagari,
              asked: Ask.own,
            ),
          ], skills: map);
          const key = (
            cardId: 'hi-0001',
            mode: DrillMode.readScript,
            script: devanagari,
          );
          expect(
            half.scriptStates[key]!.stability,
            closeTo(whole.scriptStates[key]!.stability / 2, 1e-9),
          );
        },
      );
    });

    group('kept in the log', () {
      test(
        'a backup keeps the script an answer was in, and Progress shows Read '
        'and Write per script',
        () {
          final text = LogJsonl.encode(<LoggedReview>[
            review(
              DrillMode.production,
              script: persoArabic,
              asked: Ask.rearrange,
            ),
            review(DrillMode.recognition),
          ], const []);
          final back = LogJsonl.decode(text).reviews;
          expect(back.first.script, persoArabic);
          expect(back.first.asked, Ask.rearrange);
          expect(back.last.script, isNull);
          expect(back.last.asked, isNull);

          final progress = MemoryProgress()..skills = map;
          void answer(DrillMode mode, String script, int hours) =>
              progress.record(
                deckId: words,
                cardId: 'hi-0001',
                mode: mode,
                grade: 4,
                now: day.add(Duration(hours: hours)),
                answerGiven: mode == DrillMode.recognition ? null : 'x',
                script: script,
                asked: Ask.own,
              );
          answer(DrillMode.production, persoArabic, 0);
          answer(DrillMode.recognition, devanagari, 1);
          answer(DrillMode.recognition, persoArabic, 2);
          final n = StatsNumbers.of(
            progress,
            now: day.add(const Duration(days: 1)),
            range: StatsRange.all,
            cardOf: (id, {deckId}) => null,
          );
          expect(n.scriptSkills.keys, <ScriptSkill>[
            (script: persoArabic, mode: DrillMode.readScript),
            (script: persoArabic, mode: DrillMode.writeScript),
            (script: devanagari, mode: DrillMode.readScript),
          ]);
          expect(n.reviews, 3);
        },
      );
    });
  });

  group('hours', () {
    group('hours spent', () {
      test('hours spent count each answer for at most a minute; hours left are '
          'the reviews still needed times each skill\'s time', () {
        expect(StudyHours.capped(const Duration(seconds: 45)).inSeconds, 45);
        expect(StudyHours.capped(const Duration(minutes: 30)).inSeconds, 60);
        expect(StudyHours.capped(const Duration(seconds: -3)), Duration.zero);

        final right = StudyHours.rightAnswersToRemember(null);
        final left = StudyHours.left(
          <(DrillMode, FsrsState?)>[
            (DrillMode.recognition, null),
            (DrillMode.production, null),
            // Remembered: counts for nothing.
            (DrillMode.recognition, stateWith(40)),
          ],
          times: const <DrillMode, Duration>{
            DrillMode.recognition: Duration(seconds: 10),
          },
        );
        // Production has no time of its own, so takes the default 20 s.
        expect(left, Duration(seconds: right * (10 + 20)));
      });
    });
  });
}
