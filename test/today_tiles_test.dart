// Today's numbers (#1009): a skill tile counts every card waiting in its
// skill, whatever the day's time budget, and exactly what tapping it serves;
// a skill whose drills cannot run counts nothing; and the ring shows minutes
// for reviews and for new words, never card counts.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/daily_plan.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/daily_budget.dart';
import 'package:fluenough/core/scheduling/daily_timer.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/stats/how_you_learn_page.dart';
import 'package:fluenough/features/summary/summary_page.dart';
import 'package:fluenough/features/today/daily_card.dart';
import 'package:fluenough/features/today/due_card.dart';
import 'package:fluenough/features/today/today_numbers.dart';
import 'package:fluenough/features/today/today_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/skill_visuals.dart';
import 'package:fluenough/ui/widgets/drill_frame.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';
import 'package:fluenough/ui/widgets/mode_pill.dart';
import 'package:fluenough/ui/widgets/wave_progress.dart';

import 'support/harness.dart';

/// The clock of every fixture, which AppState.test also starts at.
final DateTime _now = DateTime(2026, 9, 28, 19);

/// The four skills a word is drilled in, which every fixture word is due in.
const List<DrillMode> _modes = <DrillMode>[
  DrillMode.recognition,
  DrillMode.production,
  DrillMode.listening,
  DrillMode.speaking,
];

String _id(int n) => 'hi-en-words-${n.toString().padLeft(4, '0')}';

/// A deck of [words] Hindustani words, each with a unique spelling.
Map<String, String> _course(int words) {
  const letters = <String>['क', 'ख', 'ग', 'घ', 'च', 'छ', 'ज', 'झ', 'ट', 'ठ'];
  const sounds = <String>[
    'ka',
    'kha',
    'ga',
    'gha',
    'ca',
    'cha',
    'ja',
    'jha',
    'ta',
    'tha',
  ];
  final cards = <String>[
    for (var i = 0; i < words; i++)
      '  - { id: ${_id(i + 1)}, '
          'target: "${letters[i ~/ 10]}${letters[i % 10]}", '
          'native: "word ${i + 1}", '
          'reading: "${sounds[i ~/ 10]}${sounds[i % 10]}" }',
  ];
  return <String, String>{
    'decks/hi/hi-en-words.yaml':
        '''
schema: 1
id: hi-en-words
name: "Words"
language: { code: hi, iso639_3: hin, name: Hindustani, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
${cards.join('\n')}
''',
  };
}

/// Every word reviewed once in every skill, long ago: due in all of them,
/// and never "known", so no card is held back by the deck's sampling.
MemoryProgress _allDue(int words) {
  final progress = MemoryProgress();
  for (var n = 1; n <= words; n++) {
    for (final mode in _modes) {
      progress.record(
        deckId: 'hi-en-words',
        cardId: _id(n),
        mode: mode,
        grade: 4,
        now: _now.subtract(const Duration(days: 60)),
      );
    }
  }
  return progress;
}

/// A learner of Hindustani with [words] words due in every skill, Say on.
AppState _learner({int words = 6, FixedTtsEngine? tts, SpeechEngine? speech}) {
  final state = AppState.test(
    decks: MemoryDeckSource(_course(words)),
    progress: _allDue(words),
    tts: tts ?? FixedTtsEngine(const <String>{'hi'}),
    speech: speech ?? FixedSpeechEngine(onDevice: const <String>{'hi'}),
    now: _now,
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['hi'],
      learningChosen: true,
      enabledSkills: <Skill>{
        ...Skill.values.where((s) => s.onByDefault),
        Skill.speaking,
      },
    ),
  );
  addTearDown(state.dispose);
  return state;
}

/// A voice check that answers only when [answer] completes.
class _SlowTts extends FixedTtsEngine {
  _SlowTts(super.voices);

  final Completer<void> answer = Completer<void>();

  @override
  Future<bool> isLanguageAvailable(String bcp47) async {
    await answer.future;
    return super.isLanguageAvailable(bcp47);
  }
}

/// A recogniser that readies itself only when [ready] completes.
class _SlowSpeech extends FixedSpeechEngine {
  _SlowSpeech() : super(onDevice: const <String>{'hi'});

  final Completer<void> ready = Completer<void>();

  @override
  Future<bool> start() async {
    await ready.future;
    return super.start();
  }
}

/// How many cards [items] ask, each match's cards counted.
int _asked(List<SessionItem> items) => <SessionItem>[
  for (final item in items)
    ...item.group.isEmpty ? <SessionItem>[item] : item.group,
].length;

/// The property of the issue: for every tile, the number it shows is the
/// number of cards the queue its tap starts serves, all of them in the tile's
/// skill, and each one can be drilled now.
void _expectTilesServeTheirCount(AppState state) {
  final numbers = TodayNumbers.of(state);
  expect(numbers.bySkill, isNotEmpty);
  for (final MapEntry(key: skill, value: count) in numbers.bySkill.entries) {
    final request = DrillRequest.tile(skill);
    final queue = state.buildSession(request);
    expect(count, queue.length, reason: '${skill.name}: tile and queue');
    expect(numbers.dueIn[skill], count, reason: '${skill.name}: dueIn');
    expect(
      _asked(state.sessionItems(request)),
      count,
      reason: '${skill.name}: what the drill asks',
    );
    for (final item in queue.items) {
      expect(skill.modes, contains(item.mode), reason: skill.name);
      final language = state.deckOf(item.card)!.language;
      if (item.mode == DrillMode.listening) {
        expect(state.canSpeak(language), isTrue, reason: 'Hear can be said');
      }
      if (item.mode == DrillMode.speaking) {
        expect(state.canHear(language), isTrue, reason: 'Say can be heard');
      }
    }
  }
}

int _tile(AppState state, Skill skill) =>
    TodayNumbers.of(state).bySkill[skill] ?? -1;

void main() {
  group('a skill tile counts what tapping it serves', () {
    test(
      'with every drill able to run, each tile holds all its cards',
      () async {
        final state = _learner();
        await state.load();
        await state.startSpeech();
        _expectTilesServeTheirCount(state);
        for (final skill in <Skill>[
          Skill.recognition,
          Skill.production,
          Skill.listening,
          Skill.speaking,
        ]) {
          expect(_tile(state, skill), 6, reason: skill.name);
        }
      },
    );

    test(
      'a word due in two skills is counted in each, as each tap asks it',
      () async {
        final progress = MemoryProgress();
        for (final mode in <DrillMode>[
          DrillMode.recognition,
          DrillMode.production,
        ]) {
          progress.record(
            deckId: 'hi-en-words',
            cardId: _id(1),
            mode: mode,
            grade: 4,
            now: _now.subtract(const Duration(days: 60)),
          );
        }
        final state = AppState.test(
          decks: MemoryDeckSource(_course(1)),
          progress: progress,
          now: _now,
          settings: SettingsNotifier(
            spokenLanguages: const <String>['en'],
            learningLanguages: const <String>['hi'],
            learningChosen: true,
          ),
        );
        addTearDown(state.dispose);
        await state.load();
        expect(state.buildSession(const DrillRequest.today()).length, 1);
        expect(_tile(state, Skill.recognition), 1);
        expect(_tile(state, Skill.production), 1);
        _expectTilesServeTheirCount(state);
      },
    );

    test('a skill whose drills cannot run counts nothing, and the others '
        'keep their cards', () async {
      // No voice on the phone: Hear has nothing to say with.
      final noVoice = _learner(tts: FixedTtsEngine(const <String>{}));
      await noVoice.load();
      await noVoice.startSpeech();
      _expectTilesServeTheirCount(noVoice);
      expect(_tile(noVoice, Skill.listening), 0);
      expect(_tile(noVoice, Skill.recognition), 6);
      expect(_tile(noVoice, Skill.speaking), 6);

      // Sound off in Settings.
      final muted = _learner();
      await muted.load();
      await muted.startSpeech();
      muted.settings.soundOn = false;
      _expectTilesServeTheirCount(muted);
      expect(_tile(muted, Skill.listening), 0);
      expect(_tile(muted, Skill.production), 6);

      // The microphone refused: Say cannot listen.
      final refused = _learner(
        speech: FixedSpeechEngine(
          onDevice: const <String>{'hi'},
          grants: false,
        ),
      );
      await refused.load();
      await refused.startSpeech();
      _expectTilesServeTheirCount(refused);
      expect(_tile(refused, Skill.speaking), 0);
      expect(_tile(refused, Skill.listening), 6);
      expect(_tile(refused, Skill.recognition), 6);

      // Say switched on but the recogniser never readied.
      final unready = _learner();
      await unready.load();
      _expectTilesServeTheirCount(unready);
      expect(_tile(unready, Skill.speaking), 0);
    });

    test(
      'a voice still being checked counts nothing until it answers',
      () async {
        final tts = _SlowTts(const <String>{'hi'});
        final state = _learner(tts: tts);
        final loading = state.load();
        while (state.status != CatalogStatus.ready) {
          await Future<void>.delayed(Duration.zero);
        }
        final hindi = state.deckById('hi-en-words')!.language;
        expect(state.voiceStatus(hindi), VoiceStatus.checking);
        _expectTilesServeTheirCount(state);
        expect(
          _tile(state, Skill.listening),
          0,
          reason: 'checking: unavailable',
        );
        expect(_tile(state, Skill.recognition), 6);

        tts.answer.complete();
        await loading;
        expect(state.voiceStatus(hindi), VoiceStatus.available);
        _expectTilesServeTheirCount(state);
        expect(_tile(state, Skill.listening), 6);
      },
    );

    test(
      'a recogniser still being readied counts nothing until it is',
      () async {
        final speech = _SlowSpeech();
        final state = _learner(speech: speech);
        await state.load();
        final hindi = state.deckById('hi-en-words')!.language;
        final starting = state.startSpeech();
        expect(state.speechStatus(hindi), SpeechStatus.checking);
        _expectTilesServeTheirCount(state);
        expect(
          _tile(state, Skill.speaking),
          0,
          reason: 'checking: unavailable',
        );
        expect(_tile(state, Skill.listening), 6);

        speech.ready.complete();
        await starting;
        expect(state.speechStatus(hindi), SpeechStatus.onDevice);
        _expectTilesServeTheirCount(state);
        expect(_tile(state, Skill.speaking), 6);
      },
    );

    testWidgets('a tile shows every card, beyond what the day\'s minutes '
        'hold, and tapping it drills exactly those', (tester) async {
      usePhone(tester);
      final handle = tester.ensureSemantics();
      const words = 40;
      final state = _learner(words: words);
      await state.load();
      await state.startSpeech();
      state.settings.setDailyMinutes('hi', 5);
      final hindi = state.deckById('hi-en-words')!.language;
      // Five minutes buy far fewer than the forty waiting.
      expect(state.dailyPlanFor(hindi).split.reviews, lessThan(words));

      await pumpScreen(tester, const TodayPage(), state: state);
      final l10n = AppLocalizations.of(tester.element(find.byType(TodayPage)))!;
      for (final skill in <Skill>[
        Skill.recognition,
        Skill.production,
        Skill.listening,
        Skill.speaking,
      ]) {
        expect(
          find.bySemanticsLabel(
            l10n.todaySkillSemantics(skill.label(l10n), words),
          ),
          findsOneWidget,
          reason: skill.name,
        );
      }

      final label = find.descendant(
        of: find.byType(DueCard),
        matching: find.text(l10n.skillRecognition),
      );
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      await tester.tap(label);
      await tester.pumpAndSettle();
      final request = tester.widget<DrillPage>(find.byType(DrillPage)).request;
      expect(request.skill, Skill.recognition);
      expect(request.revise, isFalse);
      expect(_asked(state.sessionItems(request)), words);
      handle.dispose();
    });
  });

  group('the ring shows minutes, not cards', () {
    test(
      'the minutes are the planner\'s split at the learner\'s pace',
      () async {
        final state = _learner();
        await state.load();
        final hindi = state.deckById('hi-en-words')!.language;
        DailyPlan plan(int reviews, int fresh) => DailyPlan(
          language: hindi,
          goalMinutes: 15,
          extraMinutes: 0,
          spent: Duration.zero,
          secondsPerCard: 15,
          secondsPerTeach: 10,
          due: reviews,
          newAvailable: fresh,
          split: DailySplit(
            reviews: reviews,
            newWords: fresh,
            catchingUp: false,
          ),
        );
        // 40 reviews of 15 s; 3 words, each taught for 10 s and asked twice.
        expect(plan(40, 3).reviewMinutes, 10);
        expect(plan(40, 3).newMinutes, 2);
        // Any card is at least a minute; none is none.
        expect(plan(1, 1).reviewMinutes, 1);
        expect(plan(0, 0).reviewMinutes, 0);
        expect(plan(0, 0).newMinutes, 0);
      },
    );

    testWidgets('under the ring: "N min review" and "N min new", with no card '
        'count in the text or the screen reader\'s label', (tester) async {
      usePhone(tester, textScale: 1.4);
      final handle = tester.ensureSemantics();
      const words = 40;
      final state = _learner(words: words);
      await state.load();
      await state.startSpeech();
      state.settings.setDailyMinutes('hi', 5);
      final hindi = state.deckById('hi-en-words')!.language;
      final plan = state.dailyPlanFor(hindi);
      expect(plan.showsSplit, isTrue);

      await pumpScreen(tester, const TodayPage(), state: state);
      expect(tester.takeException(), isNull, reason: 'fits at 1.4x');
      final l10n = AppLocalizations.of(tester.element(find.byType(TodayPage)))!;
      expect(
        find.text(l10n.todayDailyReviewMinutes(plan.reviewMinutes)),
        findsOneWidget,
      );
      expect(
        find.text(l10n.todayDailyNewMinutes(plan.newMinutes)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          '${l10n.todayDailyReviewMinutesSemantics(plan.reviewMinutes)}, '
          '${l10n.todayDailyNewMinutesSemantics(plan.newMinutes)}',
        ),
        findsOneWidget,
      );
      // The ring's card says nothing of how many cards wait or are planned.
      final texts = <String>[
        for (final text in tester.widgetList<Text>(
          find.descendant(
            of: find.byType(DailyCard),
            matching: find.byType(Text),
          ),
        ))
          text.data ?? '',
      ];
      expect(texts, isNotEmpty);
      for (final text in texts) {
        expect(
          RegExp(r'^\d+ (reviews?|new)$').hasMatch(text),
          isFalse,
          reason: text,
        );
        expect(text, isNot(contains('$words')));
      }
      handle.dispose();
    });
  });
  group('the hint above the tiles', () {
    testWidgets(
      'reads what a tap does, and its info dot opens a short popover of How you learn',
      (tester) async {
        usePhone(tester, textScale: 1.4);
        final handle = tester.ensureSemantics();
        final state = _learner();
        await state.load();
        await state.startSpeech();
        await pumpScreen(tester, const TodayPage(), state: state);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(TodayPage)),
        )!;
        expect(tester.takeException(), isNull, reason: 'fits at 1.4x');
        expect(find.text(l10n.todayDueHint), findsOneWidget);
        expect(find.bySemanticsLabel(l10n.todayDueHintInfo), findsOneWidget);
        // The older "Adjusted to you" strip is gone from Today.
        expect(find.text(l10n.adjustedTitle), findsNothing);
        final dot = find.descendant(
          of: find.byType(DueCard),
          matching: find.byTooltip(l10n.hintInfo),
        );
        expect(dot, findsOneWidget);
        await tester.ensureVisible(dot);
        await tester.pumpAndSettle();
        // Ask for the figures now: they are worked out off the main thread, so
        // the popover is not settled on (a spinner never settles).
        expect(state.pacing.paces, anyOf(isNull, isNotNull));
        await tester.tap(dot);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        // A popover with this language's part of the page, not the page.
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byType(HowYouLearnView), findsOneWidget);
        expect(
          find.text(
            l10n.howYouLearnTitleIn(
              state.deckById('hi-en-words')!.language.name,
            ),
          ),
          findsOneWidget,
        );
        expect(find.byType(HowYouLearnPage), findsNothing);
        final dialog = find.byType(AlertDialog);
        // This language's rows, one skill pill each.
        expect(
          find.descendant(of: dialog, matching: find.byType(ModePill)),
          findsWidgets,
        );
        // The intro is the small subtitle, once; the "not yet" card with its
        // Settings button and the privacy line stay on the full page.
        final intro = tester.widget<Text>(
          find.descendant(
            of: dialog,
            matching: find.text(l10n.howYouLearnIntro),
          ),
        );
        expect(
          intro.style!.fontSize,
          Theme.of(tester.element(dialog)).textTheme.bodySmall!.fontSize,
        );
        // Flat: no cards or grouped surfaces, the sections over the full
        // width of the dialog's content with thin dividers between.
        expect(
          find.descendant(of: dialog, matching: find.byType(Card)),
          findsNothing,
        );
        expect(
          find.descendant(of: dialog, matching: find.byType(GroupedList)),
          findsNothing,
        );
        final dividers = find.descendant(
          of: dialog,
          matching: find.byType(Divider),
        );
        expect(dividers, findsWidgets);
        expect(
          tester.getSize(dividers.first).width,
          tester.getSize(find.byType(HowYouLearnView)).width,
        );
        expect(find.text(l10n.howYouLearnNone), findsNothing);
        expect(find.text(l10n.howYouLearnOpenSettings), findsNothing);
        expect(find.text(l10n.adjustedPrivacy), findsNothing);
        await tester.tap(find.text(l10n.commonClose));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(AlertDialog), findsNothing);
        handle.dispose();
      },
    );
  });

  group('the end of the day', () {
    testWidgets('the summary is the end screen: with no answer of its own it '
        'still carries the day\'s total and Keep going, and Keep going time '
        'is added to the total (#1009)', (tester) async {
      usePhone(tester, textScale: 1.4);
      final state = _learner();
      await state.load();
      state.settings.addClockTime('hi', _now, const Duration(minutes: 15));
      await pumpScreen(
        tester,
        SummaryPage(
          result: SessionResult(
            answers: const <SessionAnswer>[],
            startedAt: _now,
            endedAt: _now,
            language: 'hi',
          ),
        ),
        state: state,
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(SummaryPage)),
      )!;
      expect(tester.takeException(), isNull, reason: 'fits at 1.4x');
      expect(find.text(l10n.summaryEmpty), findsNothing);
      expect(find.byType(ModePill), findsNothing);
      expect(find.text(l10n.todayDailyTotal(15)), findsOneWidget);
      expect(find.text(l10n.summaryKeepGoing), findsOneWidget);
      expect(find.text(l10n.commonDone), findsOneWidget);

      await tester.ensureVisible(find.text(l10n.summaryKeepGoing));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.summaryKeepGoing));
      await tester.pumpAndSettle();
      final request = tester.widget<DrillPage>(find.byType(DrillPage)).request;
      expect(request.daily, isTrue);
      expect(request.language, 'hi');
    });

    test(
      'time after the goal is the day\'s total, and the ring stays done',
      () async {
        final state = _learner();
        await state.load();
        final hindi = state.deckById('hi-en-words')!.language;
        state.settings.addClockTime('hi', _now, const Duration(minutes: 15));
        expect(state.dailyPlanFor(hindi).keptGoing, isFalse);
        state.settings.addClockTime('hi', _now, const Duration(minutes: 8));
        final plan = state.dailyPlanFor(hindi);
        expect(plan.keptGoing, isTrue);
        expect(plan.totalMinutes, 23);
        expect(plan.done, isTrue);
        expect(plan.fraction, 1.0);
      },
    );

    testWidgets('Today reads the total once Keep going time exists, with no '
        'chips and no Keep going button', (tester) async {
      usePhone(tester, textScale: 1.4);
      final state = _learner();
      await state.load();
      state.settings.addClockTime('hi', _now, const Duration(minutes: 23));
      await pumpScreen(tester, const TodayPage(), state: state);
      final l10n = AppLocalizations.of(tester.element(find.byType(TodayPage)))!;
      expect(find.text(l10n.todayDailyTotal(23)), findsOneWidget);
      expect(find.text(l10n.todayDailyDone), findsOneWidget);
      expect(find.textContaining(' min review'), findsNothing);
      expect(find.text(l10n.summaryKeepGoing), findsNothing);
    });
  });
  group('the session clock', () {
    /// A header under [clock] after eight screens of 24 s each, so 3:12 used
    /// (a screen counts for 30 s at most), with the clock reading that time.
    Future<void> pumpHeader(
      WidgetTester tester,
      AppState state,
      DailyCountdown clock,
    ) async {
      var at = _now;
      for (var i = 0; i < 8; i++) {
        at = at.add(const Duration(seconds: 24));
        clock.screenShown(at);
      }
      final shown = at;
      await pumpScreen(
        tester,
        Scaffold(
          body: DrillClockScope(
            clock: clock,
            now: () => shown,
            child: const DrillHeader(
              progress: 0,
              position: 1,
              total: 8,
              onClose: null,
              reportDetail: 'test',
            ),
          ),
        ),
        state: state,
        settle: false,
      );
      await tester.pump();
    }

    testWidgets('a Keep going stretch counts the time taken up, with the bar '
        'full', (tester) async {
      usePhone(tester);
      final state = _learner();
      await state.load();
      await pumpHeader(
        tester,
        state,
        DailyCountdown(
          budget: const Duration(minutes: 5),
          now: _now,
          countsUp: true,
        ),
      );
      expect(find.text('3:12'), findsOneWidget);
      expect(tester.widget<WaveProgress>(find.byType(WaveProgress)).value, 1.0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a normal session counts the time left down, with the bar '
        'part full', (tester) async {
      usePhone(tester);
      final state = _learner();
      await state.load();
      await pumpHeader(
        tester,
        state,
        DailyCountdown(budget: const Duration(minutes: 15), now: _now),
      );
      expect(find.text('11:48'), findsOneWidget);
      final bar = tester.widget<WaveProgress>(find.byType(WaveProgress));
      expect(bar.value, greaterThan(0));
      expect(bar.value, lessThan(1));
      await tester.pumpWidget(const SizedBox());
    });

    test('a day\'s session started with the budget spent is a Keep going '
        'stretch; one with time left is not', () async {
      final state = _learner();
      await state.load();
      expect(state.startDaily('hi')!.clock.countsUp, isFalse);
      state.settings.addClockTime('hi', _now, const Duration(minutes: 15));
      expect(state.startDaily('hi')!.clock.countsUp, isTrue);
    });
  });
}
