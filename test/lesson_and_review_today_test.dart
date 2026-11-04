// Split out of lesson_and_review_test.dart so that CI can spread it over its shards;
// the tests and their names are unchanged. This file holds: Today, Can't now, the script guide, the daily fact, the summary.

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/daily_plan.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/routes.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/grading/self_grade.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/daily_budget.dart';
import 'package:fluenough/core/scheduling/daily_timer.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/script/script_guide_page.dart';
import 'package:fluenough/features/summary/summary_page.dart';
import 'package:fluenough/features/today/daily_card.dart';
import 'package:fluenough/features/today/due_card.dart';
import 'package:fluenough/features/today/today_fixtures.dart';
import 'package:fluenough/features/today/today_numbers.dart';
import 'package:fluenough/features/today/today_page.dart';
import 'package:fluenough/ui/skill_visuals.dart';
import 'package:fluenough/ui/widgets/deck_tile.dart';
import 'package:fluenough/ui/widgets/drill_frame.dart';
import 'package:fluenough/ui/widgets/mode_pill.dart';
import 'package:fluenough/ui/widgets/stat_tile.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/lesson_and_review_shared.dart';

// From today_page_test.dart.
Future<AppState> pumpToday(WidgetTester tester, {AppState? state}) =>
    pumpScreen(tester, const TodayPage(), state: state);

/// Aro's fixture state: twelve days of reviews ending yesterday.
Future<AppState> fixtureState({String profile = 'aro'}) async {
  final app = AppState.test();
  await app.load();
  return GalleryFixtures.state(app, currentProfileId: profile);
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Eight Hindi words, each reviewed in every mode of [ago] that long ago:
/// due again after a day. With [speaking], speaking is on and the phone
/// recognises Hindi.
Future<AppState> hindiReviewed(
  Map<DrillMode, Duration> ago, {
  bool speaking = false,
}) async {
  AppState build(MemoryProgress progress) => AppState.test(
    progress: progress,
    speech: FixedSpeechEngine(onDevice: const <String>{'hi'}),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['hi'],
      enabledSkills: <Skill>{
        ...Skill.values.where((s) => s.onByDefault),
        if (speaking) Skill.speaking,
      },
    ),
  );
  final base = build(MemoryProgress());
  await base.load();
  final progress = MemoryProgress();
  for (final card in base.deckById('hi-en-phrasebook')!.cards.take(8)) {
    for (final MapEntry(key: mode, value: back) in ago.entries) {
      progress.record(
        deckId: card.deckId,
        cardId: card.id,
        mode: mode,
        grade: 4,
        now: base.now().subtract(back),
      );
    }
  }
  final state = build(progress);
  await state.load();
  if (speaking) await state.startSpeech();
  return state;
}

/// [skill]'s tile on the due card.
Finder tileOf(WidgetTester tester, Skill skill) => find.descendant(
  of: find.byType(DueCard),
  matching: find.text(skill.label(l10nOf(tester))),
);

// From cant_now_test.dart.
/// "Can't speak now" and "Can't listen now" (#89): a pause for an hour, or
/// off for one language or everywhere, from a drill and from Settings.

AppState soundState({
  SettingsNotifier? settings,
  DateTime? now,
  MemoryProgress? progress,
  FixedSpeechEngine? speech,
}) => AppState.test(
  tts: FixedTtsEngine(<String>{'es', 'hi'}),
  speech: speech ?? FixedSpeechEngine(onDevice: <String>{'es'}, granted: true),
  settings:
      settings ??
      SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningChosen: true,
        enabledSkills: Skill.values.toSet(),
      ),
  now: now ?? noon,
  progress: progress,
);

Future<void> tapTextCantNow(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

// From script_guide_test.dart.
/// A script's guide (#30, ADR-0016): shown once before a language's first
/// script card, and from a script deck's Tips.

const String guide = '''
schema: 1
kind: script
id: bn-script
language: bn
name: "How Bengali script works"
intro: "A few ideas come back again and again."
features:
  - id: headline
    name: "The headline"
    term: "মাত্রা"
    reading: "matra"
    example: "ক"
    text: "Most letters hang from a line along the top."
    letters: ["ক", "খ"]
''';

AppState guided({bool withGuide = true, SettingsNotifier? settings}) =>
    AppState.test(
      decks: MemoryDeckSource(<String, String>{
        'decks/bn/bn-en-letters.yaml': deck('bn-en-letters'),
        'decks/bn/bn-en-words.yaml': deck('bn-en-words', script: false),
        if (withGuide) 'decks/bn/bn-script.yaml': guide,
      }),
      settings:
          settings ??
          SettingsNotifier(
            spokenLanguages: const <String>['en'],
            learningChosen: true,
          ),
    );

Future<void> tapTextScriptGuide(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

// From daily_fact_test.dart.
const facts = '''
schema: 1
id: hi-facts
name: Hindi facts
kind: facts
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
license: CC0-1.0
facts:
  - id: hi-fact-001
    text:
      en: "No Hindi word begins with ड़."
      bn: "কোনো হিন্দি শব্দ ড় দিয়ে শুরু হয় না।"
  - id: hi-fact-002
    text: { en: "Hindi writes conjuncts." }
  - id: hi-fact-101
    contrast: bn
    text: { bn: "হিন্দিতে স সবসময় 's'।" }
''';

const deckDailyFact = '''
schema: 1
id: hi-en-core
name: Hindi core
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: hi-en-core-0001, target: "घर", native: "house", reading: "ghar" }
''';

// From summary_page_test.dart.
final DateTime nowSummaryPage = DateTime(2026, 9, 28, 19);

/// Five answers over three minutes, four of them correct.
final SessionResult fiveAnswers = SessionResult(
  answers: const <SessionAnswer>[
    SessionAnswer(skill: Skill.recognition, grade: 4),
    SessionAnswer(skill: Skill.recognition, grade: 5),
    SessionAnswer(skill: Skill.production, grade: 4),
    SessionAnswer(skill: Skill.production, grade: 1),
    SessionAnswer(skill: Skill.listening, grade: 3),
  ],
  startedAt: nowSummaryPage.subtract(const Duration(minutes: 3)),
  endedAt: nowSummaryPage,
);

/// Scrolls [finder] into view, building it first if the list is lazy (the
/// buttons sit in the last sliver), then taps it.
Future<void> tapVisibleSummaryPage(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The value a [StatTile] with [label] shows.
String statFor(WidgetTester tester, String label) => tester
    .widget<StatTile>(
      find.byWidgetPredicate((w) => w is StatTile && w.label == label),
    )
    .value;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Today', () {
    testWidgets(
      'the skill tiles count what the session asks, and the one button opens '
      'the day\'s session',
      (tester) async {
        usePhone(tester);
        final state = await pumpToday(tester, state: await fixtureState());
        final l10n = l10nOf(tester);

        final queue = state.buildSession(const DrillRequest.today());
        expect(queue.length, greaterThan(0));
        final numbers = TodayNumbers.of(state);
        expect(numbers.due, queue.length);
        // Each language's day: its reviews add up to the session's, and the
        // card shows each one's split and minutes spent (none yet today).
        final plans = numbers.daily;
        expect(plans, isNotEmpty);
        expect(plans.map((p) => p.due).fold(0, (a, b) => a + b), queue.length);
        expect(find.byType(DailyCard), findsOneWidget);
        expect(
          find.text(l10n.todayDailyStart),
          findsNWidgets(plans.where((p) => !p.done && !p.inProgress).length),
        );
        for (final plan in plans) {
          expect(plan.spent, Duration.zero);
          expect(
            find.text(l10n.todayDailyReviewMinutes(plan.reviewMinutes)),
            findsNWidgets(
              plans.where((p) => p.reviewMinutes == plan.reviewMinutes).length,
            ),
          );
          expect(
            find.text(l10n.todayDailyProgress(0, plan.minutes)),
            findsNWidgets(plans.where((p) => p.minutes == plan.minutes).length),
          );
        }

        // Each tile counts what tapping it serves (#1009).
        // Recognition is scheduled, so it has a tile (ADR-0034).
        expect(
          find.descendant(
            of: find.byType(DueCard),
            matching: find.text(l10n.skillRecognition),
          ),
          findsOneWidget,
        );
        for (final (skill, label) in <(Skill, String)>[
          (Skill.recognition, l10n.skillRecognition),
          (Skill.production, l10n.skillProduction),
          // The grammar drill ships (#14).
          (Skill.grammar, l10n.skillGrammar),
        ]) {
          expect(
            find.bySemanticsLabel(
              l10n.todaySkillSemantics(label, numbers.bySkill[skill] ?? 0),
            ),
            findsOneWidget,
            reason: skill.name,
          );
        }

        usePhone(tester);
        final settings = SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['hi'],
        );
        await pumpToday(
          tester,
          state: await withReviewsDue(
            (progress) => AppState.test(settings: settings, progress: progress),
            const <String>['hi'],
          ),
        );
        await tapVisible(
          tester,
          find.descendant(
            of: find.byType(DailyCard),
            matching: find.byType(FilledButton),
          ),
        );
        final drill = tester.widget<DrillPage>(find.byType(DrillPage));
        expect(drill.request.daily, isTrue);
        expect(drill.request.language, 'hi');
        expect(drill.request.deckIds, isNull);
        expect(drill.request.revise, isFalse);
      },
    );

    testWidgets(
      'the day\'s session holds the words due, then the new words, and a '
      'shorter day buys fewer cards',
      (tester) async {
        usePhone(tester);
        final state = await hindiReviewed(<DrillMode, Duration>{
          DrillMode.production: const Duration(days: 3),
        });
        final hindi = state.languages.firstWhere((l) => l.code == 'hi');
        final plan = state.dailyPlanFor(hindi);
        expect(plan.goalMinutes, 15);
        expect(plan.due, 8);
        expect(plan.split.catchingUp, isFalse);
        expect(plan.split.reviews, 8);
        expect(plan.split.newWords, greaterThanOrEqualTo(3));

        final dueIds = <String>{
          for (final item
              in state
                  .buildSession(const DrillRequest.today(language: 'hi'))
                  .items)
            item.card.id,
        };
        // The session runs on a clock and builds a round at a time: the
        // first holds reviews before the first word taught, and no card is
        // asked again in the next.
        final run = state.startDaily('hi')!;
        final items = state.nextDailyRound(run);
        expect(items, isNotEmpty);
        // Every word taught is asked later in the round, never before it is
        // taught.
        final taughtAt = <String, int>{
          for (var i = items.length - 1; i >= 0; i--)
            if (items[i].ask == Ask.teach) items[i].card.id: i,
        };
        expect(taughtAt, isNotEmpty);
        for (final entry in taughtAt.entries) {
          final asks = <int>[
            for (var i = 0; i < items.length; i++)
              if (!items[i].ask.onlyShows &&
                  (items[i].card.id == entry.key ||
                      items[i].group.any((g) => g.card.id == entry.key)))
                i,
          ];
          expect(asks, isNotEmpty, reason: entry.key);
          expect(asks.first, greaterThan(entry.value), reason: entry.key);
        }
        final askedIds = <String>{
          for (final item in items)
            for (final entry
                in item.group.isEmpty ? <SessionItem>[item] : item.group)
              entry.card.id,
        };
        expect(askedIds.intersection(dueIds), isNotEmpty);
        final next = state.nextDailyRound(run);
        for (final item in next) {
          if (item.ask == Ask.own) {
            expect(askedIds.contains(item.card.id), isFalse);
          }
        }

        // A 5 minute day holds the planner's own split of 5 minutes: fewer
        // new words than a 15 minute day, and a day over by a few reviews
        // keeps some.
        state.settings.setDailyMinutes('hi', 5);
        final five = state.dailyPlanFor(hindi);
        expect(five.split.reviews, lessThanOrEqualTo(8));
        expect(five.split.newWords, greaterThanOrEqualTo(1));
        expect(five.split.newWords, lessThanOrEqualTo(plan.split.newWords));
      },
    );

    test('with nothing due, Today\'s numbers are the session\'s first round '
        '(#886, #885)', () async {
      final state = spanishLearner();
      await state.load();
      final spanish = state.languages.firstWhere((l) => l.code == 'es');
      final plan = state.dailyPlanFor(spanish);
      expect(plan.due, 0);
      expect(plan.nothingLeft, isFalse);
      final run = state.startDaily('es')!;
      final items = state.nextDailyRound(run);
      // The words Today says are taught, and no review is promised that
      // the session does not hold.
      expect(run.taught, greaterThan(0));
      expect(run.taught, lessThanOrEqualTo(plan.split.newWords));
      expect(plan.split.reviews, 0);
      expect(items.where((i) => i.ask == Ask.teach), isNotEmpty);
    });

    test('after the day\'s session, Today offers no review the session would '
        'not serve (#1007)', () async {
      // Eight words, every skill of each reviewed yesterday with Easy: none
      // is due and none has a skill left to teach, so the closest to due fill
      // the time.
      final state = await hindiReviewed(<DrillMode, Duration>{
        DrillMode.production: const Duration(days: 3),
      });
      final hindi = state.languages.firstWhere((l) => l.code == 'hi');
      final cards = state.deckById('hi-en-phrasebook')!.cards.take(8).toList();
      void review(int grade, DateTime at) {
        for (final card in cards) {
          for (final mode in state.drillableModes(card)) {
            state.progress.record(
              deckId: card.deckId,
              cardId: card.id,
              mode: mode,
              grade: grade,
              now: at,
            );
          }
        }
      }

      review(5, state.now().subtract(const Duration(days: 1)));
      expect(state.dailyPlanFor(hindi).due, 0);
      expect(state.dailyPlanFor(hindi).split.reviews, greaterThan(0));

      // The session asks them, and they are answered today.
      review(4, state.now());

      // A session would not ask them again, so Today does not promise them.
      expect(state.dailyPlanFor(hindi).split.reviews, 0);
      final served = <String>{
        for (final item in state.nextDailyRound(state.startDaily('hi')!))
          for (final member in item.group.isEmpty ? [item] : item.group)
            member.card.id,
      };
      expect(served.intersection({for (final c in cards) c.id}), isEmpty);
    });

    test('a day\'s session that has nothing left to ask ends with the full '
        'time, and Today reads the day done (#1007)', () async {
      final state = spanishLearner();
      await state.load();
      final spanish = state.languages.firstWhere((l) => l.code == 'es');
      final card = state.decks
          .firstWhere((d) => d.language.code == 'es')
          .cards
          .first;
      final run = state.startDaily('es')!;
      // No new word is left to teach today, and the one card is asked.
      run.taught = DailyPlanner.newCap;
      run.asked.add(card.id);
      final session = DrillSession(
        state: state,
        items: <SessionItem>[
          SessionItem(card: card, mode: DrillMode.recognition, state: null),
        ],
        daily: run,
      );
      addTearDown(session.dispose);
      session.reveal();
      session.rate(SelfGrade.good);

      // Nothing was left, so the session ended, with its time full rather
      // than a minute short.
      expect(session.finished, isTrue);
      expect(
        state.dailySpent('es'),
        greaterThanOrEqualTo(run.spentAtStart + run.clock.budget),
      );
      expect(state.dailyPlanFor(spanish).done, isTrue);
    });

    testWidgets('catching up says so, and "+ 5 min" adds five minutes a tap '
        'while a long press takes five away', (tester) async {
      usePhone(tester);
      final state = spanishLearner();
      await state.load();
      final spanish = state.languages.firstWhere((l) => l.code == 'es');
      final plan = DailyPlan(
        language: spanish,
        goalMinutes: 15,
        extraMinutes: 0,
        spent: Duration.zero,
        secondsPerCard: 17.5,
        due: 160,
        newAvailable: 9,
        split: DailyBudget.split(due: 160, budget: 51),
      );
      expect(plan.split.catchingUp, isTrue);
      await pumpScreen(
        tester,
        Scaffold(
          body: SingleChildScrollView(child: DailyCard(plans: [plan])),
        ),
        state: state,
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.todayDailyCatchingUp), findsOneWidget);
      expect(
        find.text(l10n.todayDailyCatchingUpPlan(160, 47, 15, 4)),
        findsOneWidget,
      );
      // No new words in the split.
      expect(find.text(l10n.todayDailyNewMinutes(0)), findsOneWidget);
      final add = find.text(l10n.todayDailyAddMinutes(5));
      await tester.tap(add);
      await tester.pump();
      await tester.tap(add);
      await tester.pump();
      expect(state.settings.dailyExtraFor('es', state.now()), 10);
      await tester.longPress(add);
      await tester.pump();
      expect(state.settings.dailyExtraFor('es', state.now()), 5);

      // A screen reader gets the same two actions on the button's own node:
      // a tap adds five, a custom action takes five away.
      final handle = tester.ensureSemantics();
      final button = find.byType(OutlinedButton);
      expect(
        tester.getSemantics(button),
        isSemantics(
          label: l10n.todayDailyAddMinutes(5),
          hint: l10n.todayDailyAddHint(5),
          isButton: true,
          hasTapAction: true,
          customActions: <CustomSemanticsAction>[
            CustomSemanticsAction(label: l10n.todayDailyTakeAway(5)),
          ],
        ),
      );
      final buttonNode = find.semantics.byLabel(l10n.todayDailyAddMinutes(5));
      tester.semantics.tap(buttonNode);
      await tester.pump();
      expect(state.settings.dailyExtraFor('es', state.now()), 10);
      final takeAway = CustomSemanticsAction.getIdentifier(
        CustomSemanticsAction(label: l10n.todayDailyTakeAway(5)),
      );
      tester.semantics.performAction(
        buttonNode,
        SemanticsAction.customAction,
        args: takeAway,
      );
      await tester.pump();
      expect(state.settings.dailyExtraFor('es', state.now()), 5);
      handle.dispose();
    });

    test('the extra minutes last the day: the next day starts at the goal, '
        'and a day never goes below five minutes', () async {
      final settings = SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningLanguages: const <String>['es'],
      );
      final today = DateTime(2026, 9, 28, 19);
      final state = AppState.test(settings: settings, now: today);
      await state.load();
      final spanish = state.languages.firstWhere((l) => l.code == 'es');

      state.addDailyMinutes('es', 10);
      expect(state.dailyPlanFor(spanish).extraMinutes, 10);
      expect(state.dailyPlanFor(spanish).minutes, 25);

      // Tomorrow, with the same settings, it is the goal again.
      final tomorrow = AppState.test(
        settings: settings,
        now: today.add(const Duration(days: 1)),
      );
      await tomorrow.load();
      final plan = tomorrow.dailyPlanFor(
        tomorrow.languages.firstWhere((l) => l.code == 'es'),
      );
      expect(plan.extraMinutes, 0);
      expect(plan.minutes, 15);

      // Taking minutes away stops at five minutes in all, however often.
      for (var i = 0; i < 5; i++) {
        state.addDailyMinutes('es', -5);
      }
      expect(state.dailyPlanFor(spanish).minutes, 5);
      expect(state.dailyPlanFor(spanish).extraMinutes, 5 - 15);
      state.addDailyMinutes('es', 5);
      expect(state.dailyPlanFor(spanish).minutes, 10);
    });

    test('the extra minutes are saved with their day and restored, and '
        'dropped the next day', () {
      final day = DateTime(2026, 9, 28, 19);
      final settings = SettingsNotifier()..setDailyExtra('es', 10, day);
      final restored = SettingsNotifier()..restore(settings.toStored());
      expect(restored.dailyExtraFor('es', day), 10);
      expect(
        restored.dailyExtraFor('es', day.add(const Duration(hours: 3))),
        10,
      );
      expect(restored.dailyExtraFor('es', day.add(const Duration(days: 1))), 0);
      expect(restored.dailyExtraFor('hi', day), 0);
    });

    test('with 14 minutes 47 seconds spent, the ring reads 14 of 15, the '
        'button stays on Continue, and Keep going is not yet needed', () async {
      final base = spanishLearner();
      await base.load();
      final card = base.decks
          .firstWhere((d) => d.language.code == 'es')
          .cards
          .first;
      final progress = MemoryProgress();
      for (var i = 0; i < 50; i++) {
        progress.record(
          deckId: card.deckId,
          cardId: card.id,
          mode: DrillMode.recognition,
          grade: 4,
          now: base.now(),
          elapsed: Duration(seconds: i < 49 ? 18 : 5),
        );
      }
      final state = AppState.test(
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['es'],
        ),
        progress: progress,
      );
      await state.load();
      final plan = state.dailyPlanFor(
        state.languages.firstWhere((l) => l.code == 'es'),
      );
      expect(plan.spent, const Duration(seconds: 49 * 18 + 5));
      expect(plan.budgetDone, isFalse);
      expect(plan.minutesDone, 14);
      expect(plan.inProgress, isTrue);
      // Under one card of time is left, and there are new words to teach:
      // the day is not done and the split still has a card to ask.
      expect(plan.split.cards, greaterThan(0));
      expect(plan.done, isFalse);
    });

    test('the time spent is counted again when the log grows', () async {
      final state = spanishLearner();
      await state.load();
      final spanish = state.languages.firstWhere((l) => l.code == 'es');
      expect(state.dailyPlanFor(spanish).spent, Duration.zero);
      final card = state.decks
          .firstWhere((d) => d.language.code == 'es')
          .cards
          .first;
      state.progress.record(
        deckId: card.deckId,
        cardId: card.id,
        mode: DrillMode.recognition,
        grade: 4,
        now: state.now(),
        elapsed: const Duration(seconds: 30),
      );
      expect(state.dailyPlanFor(spanish).spent, const Duration(seconds: 30));
    });

    testWidgets(
      'with the minutes spent the ring reads Done for today with no '
      'Keep going under it; it opens the summary, which keeps going (#1009)',
      (tester) async {
        usePhone(tester);
        final state = spanishLearner();
        await state.load();
        final spanish = state.languages.firstWhere((l) => l.code == 'es');
        state.settings.addClockTime(
          'es',
          state.now(),
          const Duration(minutes: 15),
        );
        final plan = state.dailyPlanFor(spanish);
        expect(plan.done, isTrue);
        expect(plan.keptGoing, isFalse);
        await pumpScreen(
          tester,
          Scaffold(
            body: SingleChildScrollView(child: DailyCard(plans: [plan])),
          ),
          state: state,
        );
        final l10n = l10nOf(tester);
        expect(find.text(l10n.todayDailyDone), findsOneWidget);
        expect(find.text(l10n.todayDailyProgress(15, 15)), findsOneWidget);
        expect(find.text(l10n.todayDailyStart), findsNothing);
        expect(find.text(l10n.summaryKeepGoing), findsNothing);
        // The split is for a day still to do.
        expect(find.textContaining(' min review'), findsNothing);
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(find.byType(SummaryPage), findsOneWidget);
        await tester.tap(find.text(l10n.summaryKeepGoing));
        await tester.pumpAndSettle();
        // Keep going is the clock's time added to the day, not extra minutes.
        expect(state.settings.dailyExtraFor('es', state.now()), 0);
        final drill = tester.widget<DrillPage>(find.byType(DrillPage));
        expect(drill.request.daily, isTrue);
        expect(drill.request.language, 'es');
      },
    );

    testWidgets('a day that has ended shows the full time and no pending, and '
        'its greyed ring opens the summary (#1007)', (tester) async {
      usePhone(tester);
      final state = spanishLearner();
      await state.load();
      final spanish = state.languages.firstWhere((l) => l.code == 'es');
      // The session ended at 14 of 15 minutes with nothing left to ask.
      final plan = DailyPlan(
        language: spanish,
        goalMinutes: 15,
        extraMinutes: 0,
        spent: const Duration(minutes: 14),
        secondsPerCard: 17.5,
        due: 0,
        newAvailable: 0,
        split: const DailySplit(reviews: 0, newWords: 0, catchingUp: false),
      );
      await pumpScreen(
        tester,
        Scaffold(
          body: SingleChildScrollView(child: DailyCard(plans: [plan])),
        ),
        state: state,
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.todayDailyProgress(15, 15)), findsOneWidget);
      expect(find.text(l10n.todayDailyReviewMinutes(0)), findsNothing);
      expect(find.text(l10n.todayDailyNewMinutes(0)), findsNothing);
      expect(find.bySemanticsLabel(l10n.todayDailyDoneOpens), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.byType(SummaryPage), findsOneWidget);
    });

    testWidgets(
      'Today has no Quick revision, and a tile with cards due reviews that '
      'skill',
      (tester) async {
        usePhone(tester);
        // A learner of Bengali: with nothing chosen, Today shows the first
        // language of the decks, which has no daily facts.
        await pumpToday(
          tester,
          state: AppState.test(
            settings: SettingsNotifier(
              spokenLanguages: const <String>['en'],
              learningLanguages: const <String>['bn'],
            ),
          ),
        );
        expect(find.byType(DeckTile), findsNothing);
        expect(find.text('Quick revision'), findsNothing);
        expect(find.byTooltip(l10nOf(tester).minutesMore), findsNothing);

        usePhone(tester);
        final state = await hindiReviewed(<DrillMode, Duration>{
          DrillMode.production: const Duration(days: 3),
        });
        await pumpToday(tester, state: state);
        expect(TodayNumbers.of(state).bySkill[Skill.production], 8);
        await tapVisible(tester, tileOf(tester, Skill.production));
        final drill = tester.widget<DrillPage>(find.byType(DrillPage));
        expect(drill.request.skill, Skill.production);
        expect(drill.request.revise, isFalse);
        expect(drill.request.language, isNull);
        final items = state.sessionItems(drill.request);
        expect(items, isNotEmpty);
        expect(
          <DrillMode>{
            for (final item in items)
              for (final asked in item.group.isEmpty ? [item] : item.group)
                asked.mode,
          },
          <DrillMode>{DrillMode.production},
        );
      },
    );

    testWidgets('with everything answered, no skill tile is due', (
      tester,
    ) async {
      usePhone(tester);
      final state = await fixtureState();
      await state.load();
      finishToday(state);
      await pumpToday(tester, state: state);
      final l10n = l10nOf(tester);

      final numbers = TodayNumbers.of(state);
      expect(numbers.allDone, isTrue);
      // Nothing is left to review in any language: each day's card says so,
      // with no reviews badge unless new words are still to come.
      final plans = numbers.daily;
      expect(plans, isNotEmpty);
      expect(plans.every((p) => p.due == 0), isTrue);
      // The time left may be filled with reviews of cards not yet due
      // (#886), which the split counts: a "0 reviews" badge shows only where
      // none are planned.
      final noReviews = plans
          .where((p) => p.showsSplit && p.split.reviews == 0)
          .length;
      expect(
        find.text(l10n.todayDailyReviewMinutes(0)),
        findsNWidgets(noReviews),
      );
      expect(
        find.text(l10n.todayDailyDone),
        findsNWidgets(plans.where((p) => !p.showsSplit).length),
      );
      // Today now counts towards the streak.
      expect(find.text(l10n.todayStreak(13)), findsOneWidget);
    });
  });

  group('Can\'t now', () {
    testWidgets(
      'Pause for an hour skips every listening card, and the pause survives '
      'a restart',
      (tester) async {
        final settings = SettingsNotifier()
          ..pause(Skill.listening, until: noon.add(const Duration(hours: 1)))
          ..setOffFor(Skill.speaking, 'hi', true)
          ..setOffFor(Skill.speaking, 'bn', true);
        final restored = SettingsNotifier()..restore(settings.toStored());
        expect(
          restored.pausedUntil(Skill.listening),
          noon.add(const Duration(hours: 1)),
        );
        expect(restored.offFor(Skill.speaking), <String>{'hi', 'bn'});
        final junk = SettingsNotifier()
          ..restore(const <String, String>{
            'paused_until': '{"listening": "soon", "nope": 1}',
            'off_for': '{"speaking": ["hi", "Hindi", 3], "nope": ["bn"]}',
          });
        expect(junk.pausedUntil(Skill.listening), isNull);
        expect(junk.offFor(Skill.speaking), <String>{'hi'});

        usePhone(tester);
        final state = soundState();
        await pumpScreen(
          tester,
          DrillPage(
            request: DrillRequest.untaught(spanish, skill: Skill.listening),
          ),
          state: state,
        );
        final l10n = l10nOf(tester);
        await tapTextCantNow(tester, l10n.drillCantListen);
        await tapTextCantNow(tester, l10n.cantNowPause);
        expect(
          state.settings.pausedUntil(Skill.listening),
          noon.add(const Duration(hours: 1)),
        );
        expect(state.progress.log, isEmpty);
        // Every card was listening, so the session is over.
        expect(find.text(l10n.drillCantListen), findsNothing);
      },
    );

    group('on a drill', () {
      testWidgets(
        'Turn off for Spanish switches speaking off for Spanish only',
        (tester) async {
          usePhone(tester);
          final state = soundState();
          await state.load();
          // The launch check of the recogniser is not awaited by load.
          await tester.pump();
          await state.startSpeech();
          await pumpScreen(
            tester,
            DrillPage(
              request: DrillRequest.untaught(spanish, skill: Skill.speaking),
            ),
            state: state,
          );
          final l10n = l10nOf(tester);
          await tapTextCantNow(tester, l10n.drillCantSpeak);
          await tapTextCantNow(tester, l10n.cantNowOffFor('Spanish'));
          expect(state.settings.offFor(Skill.speaking), <String>{'es'});
          expect(state.settings.isEnabled(Skill.speaking), isTrue);
          expect(state.progress.log, isEmpty);
          // Every card was Spanish speaking, so none is left to drill.
          expect(find.text(l10n.drillCantSpeak), findsNothing);
        },
      );
    });
  });

  group('the script guide', () {
    testWidgets(
      'a guide shows once, before the first script card, and Tips opens it',
      (tester) async {
        usePhone(tester);
        final state = guided();
        await pumpScreen(
          tester,
          DrillPage(request: DrillRequest.untaught('bn-en-letters')),
          state: state,
        );
        final l10n = l10nOf(tester);
        expect(find.text('How Bengali script works'), findsOneWidget);
        expect(find.text('The headline'), findsOneWidget);
        expect(find.text('মাত্রা'), findsOneWidget);
        expect(find.byType(DrillFrame), findsNothing);
        await tapTextScriptGuide(tester, l10n.scriptGuideStart);
        expect(state.settings.hasSeenScriptGuide('bn'), isTrue);
        expect(find.byType(DrillFrame), findsOneWidget);

        // Seen: the next session starts on the letters.
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpScreen(
          tester,
          DrillPage(request: DrillRequest.untaught('bn-en-letters')),
          state: state,
        );
        expect(find.text('How Bengali script works'), findsNothing);
        expect(find.byType(DrillFrame), findsOneWidget);

        {
          usePhone(tester);
          final state = guided();
          await pumpScreen(
            tester,
            const DeckDetailPage(deckId: 'bn-en-letters'),
            state: state,
          );
          final l10n = l10nOf(tester);
          await tapTextScriptGuide(
            tester,
            l10n.deckScriptTips('How Bengali script works'),
          );
          expect(find.byType(ScriptGuidePage), findsOneWidget);
          expect(find.text('The headline'), findsOneWidget);
          await tapTextScriptGuide(tester, l10n.commonDone);
          expect(find.byType(ScriptGuidePage), findsNothing);
          // Opening it from Tips doesn't count as seeing it before the letters.
          expect(state.settings.hasSeenScriptGuide('bn'), isFalse);
        }
      },
    );
  });

  group('the daily fact', () {
    testWidgets(
      'Today shows the fact in Bengali then English, and records it',
      (tester) async {
        usePhone(tester);
        final settings = SettingsNotifier(spokenLanguages: const ['bn', 'en']);
        final state = AppState.test(
          decks: MemoryDeckSource(const <String, String>{
            'decks/hi/hi-en-core.yaml': deckDailyFact,
            'decks/hi/hi-facts.yaml': facts,
          }),
          settings: settings,
        );
        await pumpScreen(tester, const TodayPage(), state: state);
        final l10n = l10nOf(tester);
        expect(state.brokenDecks, isEmpty);
        expect(find.text(l10n.todayFactFor('Hindi')), findsOneWidget);
        final bengali = find.text('কোনো হিন্দি শব্দ ড় দিয়ে শুরু হয় না।');
        final english = find.text('No Hindi word begins with ड़.');
        expect(bengali, findsOneWidget);
        expect(english, findsOneWidget);
        expect(
          tester.getTopLeft(bengali).dy,
          lessThan(tester.getTopLeft(english).dy),
        );
        expect(tester.widget<Text>(bengali).locale, const Locale('bn'));
        await tester.pump();
        expect(settings.factShownAt('hi', 'hi-fact-001'), isNotNull);
        settings.dispose();
      },
    );
  });

  group('the summary', () {
    testWidgets('the summary\'s skill scores come from the session, and Done '
        'returns to Today', (tester) async {
      usePhone(tester);
      await pumpScreen(tester, SummaryPage(result: fiveAnswers));
      final l10n = l10nOf(tester);

      expect(find.text(l10n.summaryTitle), findsOneWidget);
      // No history before this session in AppState.test.
      expect(statFor(tester, l10n.summaryStreak(0)), '0');

      for (final (label, correct, total) in <(String, int, int)>[
        (l10n.skillRecognition, 2, 2),
        (l10n.skillProduction, 1, 2),
        (l10n.skillListening, 1, 1),
      ]) {
        expect(
          find.bySemanticsLabel(
            l10n.summaryScoreSemantics(label, correct, total),
          ),
          findsOneWidget,
          reason: label,
        );
      }
      expect(find.byType(ModePill), findsNWidgets(3));
      expect(find.text(l10n.summaryNextDue(0)), findsOneWidget);

      usePhone(tester);
      final state = await pumpApp(tester);
      state.shellTab.value = ShellTab.decks;
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(AppShell)))
          .pushNamed(AppRoutes.summary, arguments: fiveAnswers);
      await tester.pumpAndSettle();
      expect(find.byType(SummaryPage), findsOneWidget);

      await tapVisibleSummaryPage(tester, find.text(l10nOf(tester).commonDone));
      expect(find.byType(SummaryPage), findsNothing);
      expect(state.shellTab.value, ShellTab.today);
    });
    testWidgets(
      'the result shows a pill per skill answered with its right of answered, '
      'at 1.4x text',
      (tester) async {
        usePhone(tester, textScale: 1.4);
        await pumpScreen(tester, SummaryPage(result: fiveAnswers));
        final l10n = l10nOf(tester);

        expect(
          tester
              .widgetList<ModePill>(find.byType(ModePill))
              .map((p) => p.skill),
          <Skill>[Skill.recognition, Skill.production, Skill.listening],
        );
        expect(find.text(l10n.summaryScore(2, 2)), findsOneWidget);
        expect(find.text(l10n.summaryScore(1, 2)), findsOneWidget);
        expect(find.text(l10n.summaryScore(1, 1)), findsOneWidget);
        expect(find.text(l10n.summaryEmpty), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a session with no graded answer shows no pills and says so, at 1.4x '
      'text',
      (tester) async {
        usePhone(tester, textScale: 1.4);
        await pumpScreen(
          tester,
          SummaryPage(
            result: SessionResult(
              answers: const <SessionAnswer>[],
              startedAt: nowSummaryPage.subtract(const Duration(minutes: 3)),
              endedAt: nowSummaryPage,
            ),
          ),
        );
        final l10n = l10nOf(tester);

        expect(find.byType(ModePill), findsNothing);
        expect(find.text(l10n.summaryEmpty), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
