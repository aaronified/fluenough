import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/core/grading/self_grade.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/numbers/number_practice.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/drill/recognition_drill.dart';
import 'package:fluenough/features/drill/rtl_fixture.dart';
import 'package:fluenough/features/drill/typed_drill.dart';
import 'package:fluenough/features/summary/summary_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/widgets/drill_frame.dart';
import 'package:fluenough/ui/widgets/incoming.dart';
import 'package:fluenough/ui/widgets/play_button.dart';
import 'package:fluenough/ui/widgets/target_text.dart';

import '../../support/harness.dart';

const String spanish = 'es-en-core-100';
const String hiragana = 'ja-en-hiragana';

Future<AppState> pumpDrill(
  WidgetTester tester,
  DrillRequest request, {
  DrillPreset? preset,
  AppState? state,
  ThemeMode themeMode = ThemeMode.light,
}) => pumpScreen(
  tester,
  DrillPage(request: request, preset: preset),
  state: state,
  themeMode: themeMode,
);

Future<void> typeAndCheck(WidgetTester tester, String typed) async {
  await tester.enterText(find.byType(TextField), typed);
  await tester.pump();
  await tester.tap(find.text(l10nOf(tester).drillCheck));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('recognition: reveal, rate with the previewed interval, next', (
    tester,
  ) async {
    usePhone(tester);
    // Two good reviews, the second a week ago: due now, with an interval
    // each rating moves differently.
    final base = AppState.test();
    await base.load();
    final card = base.deckById(spanish)!.cards.first;
    final now = base.now();
    final progress = MemoryProgress();
    for (final daysAgo in <int>[8, 7]) {
      progress.record(
        deckId: spanish,
        cardId: card.id,
        mode: DrillMode.recognition,
        grade: 4,
        now: now.subtract(Duration(days: daysAgo)),
      );
    }
    final state = await pumpDrill(
      tester,
      DrillRequest.deck(spanish, skill: Skill.recognition),
      state: AppState.test(progress: progress),
    );
    final l10n = l10nOf(tester);
    final total = state.buildSession(DrillRequest.deck(spanish)).length;

    expect(find.text(card.target), findsOneWidget);
    expect(find.text(card.native), findsNothing);
    await tester.tap(find.text(l10n.drillShowAnswer));
    await tester.pumpAndSettle();
    expect(find.text(card.native), findsOneWidget);
    expect(find.text(l10n.drillRatePrompt), findsOneWidget);

    for (final grade in SelfGrade.values) {
      final days = progress
          .preview(
            spanish,
            card.id,
            DrillMode.recognition,
            grade.toSm2Grade(),
            now: now,
          )
          .intervalDays;
      expect(find.text(l10n.rateInterval(days)), findsWidgets);
    }
    final goodDays = progress
        .preview(spanish, card.id, DrillMode.recognition, 4, now: now)
        .intervalDays;
    expect(
      find.bySemanticsLabel(
        l10n.rateButtonSemantics(l10n.rateGood, l10n.rateInterval(goodDays)),
      ),
      findsOneWidget,
    );

    final before = progress.log.length;
    await tester.tap(find.text(l10n.rateGood));
    await tester.pumpAndSettle();
    expect(progress.log, hasLength(before + 1));
    expect(progress.log.last.cardId, card.id);
    expect(progress.log.last.grade, 4);
    expect(progress.log.last.answerGiven, isNull);
    expect(find.text(l10n.drillShowAnswer), findsOneWidget);
    expect(find.text(l10n.drillPositionShort(2, total)), findsOneWidget);
  });

  group('production records the right grade', () {
    final cases =
        <
          ({
            String name,
            String typed,
            String Function(AppLocalizations l10n) title,
            int grade,
          })
        >[
          (
            name: 'exact',
            typed: 'el niño',
            title: (l) => l.feedbackCorrect,
            grade: 5,
          ),
          (
            name: 'accent',
            typed: 'el nino',
            title: (l) => l.feedbackAccent,
            grade: 4,
          ),
          (
            name: 'article',
            typed: 'niño',
            title: (l) => l.feedbackArticle,
            grade: 4,
          ),
          (
            name: 'accent and article',
            typed: 'nino',
            title: (l) => l.feedbackAccentAndArticle,
            grade: 4,
          ),
          (
            name: 'wrong',
            typed: 'la mesa',
            title: (l) => l.feedbackWrong,
            grade: 1,
          ),
        ];

    for (final c in cases) {
      testWidgets('${c.name}: recorded on Check, then Continue', (
        tester,
      ) async {
        usePhone(tester);
        final state = await pumpDrill(
          tester,
          DrillRequest.deck(spanish, skill: Skill.production),
          preset: const DrillPreset(target: 'el niño'),
        );
        final l10n = l10nOf(tester);
        await typeAndCheck(tester, c.typed);

        expect(find.text(c.title(l10n)), findsOneWidget);
        final log = state.progress.log;
        expect(log, hasLength(1), reason: 'recorded before Continue');
        expect(log.single.grade, c.grade);
        expect(log.single.mode, DrillMode.production);
        expect(log.single.answerGiven, c.typed);

        await tester.tap(find.text(l10n.commonContinue));
        await tester.pumpAndSettle();
        expect(find.text(l10n.drillCheck), findsOneWidget);
        expect(state.progress.log, hasLength(1));
      });
    }

    for (final judgement in TypoJudgement.values) {
      testWidgets('near miss, ${judgement.name}', (tester) async {
        usePhone(tester);
        final state = await pumpDrill(
          tester,
          DrillRequest.deck(spanish, skill: Skill.production),
          preset: const DrillPreset(target: 'la ventana'),
        );
        final l10n = l10nOf(tester);
        await typeAndCheck(tester, 'la ventna');

        expect(find.text(l10n.feedbackTypo('la ventana')), findsOneWidget);
        expect(find.text(l10n.commonContinue), findsNothing);
        expect(state.progress.log, isEmpty, reason: 'the learner judges it');

        await tester.tap(
          find.text(
            judgement == TypoJudgement.knewIt
                ? l10n.drillKnewIt
                : l10n.drillCountWrong,
          ),
        );
        await tester.pumpAndSettle();
        expect(state.progress.log.single.grade, judgement.toSm2Grade());
        expect(find.text(l10n.drillCheck), findsOneWidget, reason: 'next');
      });
    }

    testWidgets("don't know records 1", (tester) async {
      usePhone(tester);
      final state = await pumpDrill(
        tester,
        DrillRequest.deck(spanish, skill: Skill.production),
        preset: const DrillPreset(target: 'el niño'),
      );
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.drillDontKnow));
      await tester.pumpAndSettle();
      expect(find.text(l10n.feedbackGaveUp), findsOneWidget);
      expect(find.text(l10n.feedbackAnswer('el niño')), findsOneWidget);
      expect(state.progress.log.single.grade, 1);
    });
  });

  testWidgets('script production: keyboard hint, transliteration incoming', (
    tester,
  ) async {
    usePhone(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpDrill(
      tester,
      DrillRequest.deck(hiragana, skill: Skill.production),
      preset: const DrillPreset(target: 'か'),
    );
    final l10n = l10nOf(tester);

    expect(find.text(l10n.drillTypeInScript('Japanese')), findsOneWidget);

    // Below the fold on a phone: the body scrolls, as the design's does.
    await tester.ensureVisible(find.text(l10n.drillGetHeliboard));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.drillGetHeliboard));
    await tester.pumpAndSettle();
    expect(copied, AppLinks.heliboard);
    expect(find.text(l10n.drillHeliboardCopied), findsOneWidget);

    expect(find.text(l10n.incomingBadge), findsOneWidget);
    await tester.ensureVisible(find.byType(IncomingFeature));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(IncomingFeature));
    await tester.pumpAndSettle();
    expect(find.text(l10n.incomingSnackBar), findsOneWidget);
    expect(find.text(l10n.drillTypeInScript('Japanese')), findsOneWidget);
  });

  testWidgets('transliteration, once #47 is on, types Latin letters', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpDrill(
      tester,
      DrillRequest.deck(hiragana, skill: Skill.production),
      state: AppState.test(
        features: const FeatureRegistry.only(<Feature>{
          ...Feature.available,
          Feature.translitInput,
        }),
      ),
      preset: const DrillPreset(target: 'か', inputMode: InputMode.translit),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.incomingBadge), findsNothing);
    expect(find.text(l10n.drillGetHeliboard), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textDirection, TextDirection.ltr);
    // The example is another card's reading (あ), never this card's.
    expect(find.text(l10n.drillTypeLatin('a')), findsOneWidget);

    await typeAndCheck(tester, 'ka');
    expect(find.text(l10n.feedbackCorrect), findsOneWidget);
    expect(
      find.text(l10n.feedbackReadingWithTarget('ka', 'か')),
      findsOneWidget,
    );
    expect(state.progress.log.single.grade, 5);
  });

  testWidgets('listening speaks at the speech rate, and slower', (
    tester,
  ) async {
    usePhone(tester);
    final tts = FixedTtsEngine(<String>{'es'});
    final state = await pumpDrill(
      tester,
      DrillRequest.deck(spanish, skill: Skill.listening),
      state: AppState.test(tts: tts),
    );
    final l10n = l10nOf(tester);
    final card = state.deckById(spanish)!.cards.first;
    expect(find.text(l10n.drillTypeHeard), findsOneWidget);
    expect(find.text(card.target), findsNothing, reason: 'heard, not read');

    await tester.tap(find.byType(PlayButton));
    await tester.pumpAndSettle();
    expect(tts.spoken.single.text, card.target);
    expect(tts.spoken.single.bcp47, 'es-ES');
    expect(tts.spoken.single.rate, state.settings.ttsRate());

    await tester.tap(find.text(l10n.drillSlower(0.7)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PlayButton));
    await tester.pumpAndSettle();
    expect(tts.spoken, hasLength(2));
    expect(tts.spoken.last.rate, state.settings.ttsRate(slower: true));
    expect(tts.spoken.last.rate, lessThan(tts.spoken.first.rate));

    await typeAndCheck(tester, card.target);
    expect(find.text(l10n.feedbackCorrect), findsOneWidget);
    expect(state.progress.log.single.mode, DrillMode.listening);
  });

  testWidgets('an empty queue shows the empty state', (tester) async {
    usePhone(tester);
    // Listening, with no voice on the phone: nothing to drill.
    await pumpDrill(
      tester,
      DrillRequest.deck('ja-hiragana', skill: Skill.listening),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.drillEmptyTitle), findsOneWidget);
    expect(find.text(l10n.drillEmptyBody), findsOneWidget);
    expect(find.byType(DrillFrame), findsNothing);
  });

  testWidgets('the last answer goes to the summary', (tester) async {
    usePhone(tester);
    await pumpDrill(tester, const DrillRequest.learnNew(1));
    final l10n = l10nOf(tester);
    expect(find.text(l10n.drillPositionShort(1, 1)), findsOneWidget);
    await tester.tap(find.text(l10n.drillShowAnswer));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.rateEasy));
    await tester.pumpAndSettle();

    final summary = tester.widget<SummaryPage>(find.byType(SummaryPage));
    expect(summary.result.answers.single.grade, 5);
    expect(summary.result.answers.single.skill, Skill.recognition);
    expect(find.byType(DrillPage), findsNothing);
  });

  testWidgets('closing part-way asks first', (tester) async {
    usePhone(tester);
    final state = AppState.test();
    await pumpScreen(tester, const SizedBox.shrink(), state: state);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => DrillPage(
          request: DrillRequest.deck(spanish, skill: Skill.recognition),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.drillShowAnswer));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.rateHard));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(l10n.drillEndSession));
    await tester.pumpAndSettle();
    expect(find.text(l10n.drillEndTitle), findsOneWidget);
    await tester.tap(find.text(l10n.drillEndKeepGoing));
    await tester.pumpAndSettle();
    expect(find.byType(DrillPage), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.drillEndSession));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, l10n.drillEndSession));
    await tester.pumpAndSettle();
    expect(find.byType(DrillPage), findsNothing);
    expect(state.progress.log.single.grade, 3, reason: 'kept');
  });

  testWidgets('a right-to-left deck types and shows right to left', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpDrill(
      tester,
      DrillRequest.deck(rtlFixtureDeckId, skill: Skill.production),
      state: AppState.test(decks: rtlFixtureDecks()),
      preset: const DrillPreset(target: 'کتاب'),
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textDirection, TextDirection.rtl);

    await typeAndCheck(tester, 'کتاب');
    expect(state.progress.log.single.grade, 5);
    final shown = find.descendant(
      of: find.byType(TargetText),
      matching: find.text('کتاب'),
    );
    expect(tester.widget<Text>(shown).textDirection, TextDirection.rtl);
    expect(find.text(l10nOf(tester).feedbackCorrect), findsOneWidget);
  });

  group('at text scale 2.0 nothing overflows', () {
    final states = <(String, DrillRequest, DrillPreset)>[
      (
        'recognition, revealed',
        DrillRequest.deck(spanish, skill: Skill.recognition),
        const DrillPreset(target: 'la casa', reveal: true),
      ),
      (
        'production, script and keyboard hint',
        DrillRequest.deck(hiragana, skill: Skill.production),
        const DrillPreset(target: 'か'),
      ),
      (
        'production, near miss',
        DrillRequest.deck(spanish, skill: Skill.production),
        const DrillPreset(
          target: 'la ventana',
          typed: 'la ventna',
          check: true,
        ),
      ),
      (
        'listening',
        DrillRequest.deck(spanish, skill: Skill.listening),
        const DrillPreset(),
      ),
      // ser has the longest notes in the bundled decks: they wrap, and the
      // frame must measure them at the width they are laid out at.
      (
        'recognition, revealed, long notes',
        DrillRequest.deck(spanish, skill: Skill.recognition),
        const DrillPreset(target: 'ser', reveal: true),
      ),
      (
        'production, answered, long notes',
        DrillRequest.deck(spanish, skill: Skill.production),
        const DrillPreset(target: 'ser', typed: 'ser', check: true),
      ),
    ];
    for (final (name, request, preset) in states) {
      testWidgets(name, (tester) async {
        usePhone(tester, textScale: 2.0);
        await pumpDrill(
          tester,
          request,
          preset: preset,
          state: AppState.test(tts: FixedTtsEngine(<String>{'es'})),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(DrillFrame), findsOneWidget);
      });
    }
  });

  testWidgets('the dark theme', (tester) async {
    usePhone(tester);
    await pumpDrill(
      tester,
      DrillRequest.deck(spanish, skill: Skill.production),
      preset: const DrillPreset(
        target: 'el niño',
        typed: 'el nino',
        check: true,
      ),
      themeMode: ThemeMode.dark,
    );
    expect(tester.takeException(), isNull);
    final context = tester.element(find.byType(DrillCard));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(find.text(l10nOf(tester).feedbackAccent), findsOneWidget);
  });

  testWidgets('a catalog that failed offers Try again, which starts the '
      'session', (tester) async {
    usePhone(tester);
    await pumpDrill(
      tester,
      DrillRequest.deck(spanish, skill: Skill.recognition),
      state: AppState.test(decks: FailOnceDeckSource()),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.commonDecksFailed), findsOneWidget);
    expect(find.byType(DrillFrame), findsNothing);

    await tester.tap(find.text(l10n.commonRetry));
    await tester.pumpAndSettle();
    expect(find.text(l10n.commonDecksFailed), findsNothing);
    expect(find.byType(DrillFrame), findsOneWidget);
  });

  group('number practice (#54)', () {
    const numbersBig = 'hi-en-numbers-big';

    /// The generated number on screen now.
    NumberCard current(WidgetTester tester) {
      final drill = tester.widget(
        find.byWidgetPredicate((w) => w is RecognitionDrill || w is TypedDrill),
      );
      final session = drill is RecognitionDrill
          ? drill.session
          : (drill as TypedDrill).session;
      return session.item.card as NumberCard;
    }

    testWidgets('recognition, production and listening, none of it recorded', (
      tester,
    ) async {
      usePhone(tester);
      final tts = FixedTtsEngine(<String>{'hi'});
      final state = await pumpDrill(
        tester,
        DrillRequest.numbers(numbersBig),
        state: AppState.test(tts: tts),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.numbersPracticeTitle), findsOneWidget);
      expect(find.text(l10n.drillPositionShort(1, 10)), findsOneWidget);

      // The words, then the digits, rated with no interval: nothing is
      // scheduled.
      var card = current(tester);
      expect(find.text(card.target), findsOneWidget);
      await tester.tap(find.text(l10n.drillShowAnswer));
      await tester.pumpAndSettle();
      expect(find.text(card.native), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.rateGood), findsOneWidget);
      for (final days in <int>[0, 1, 4]) {
        expect(find.text(l10n.rateInterval(days)), findsNothing);
      }
      await tester.tap(find.text(l10n.rateGood));
      await tester.pumpAndSettle();

      // The digits; the words typed, in their other accepted spelling.
      card = current(tester);
      expect(find.text(card.native), findsOneWidget);
      await typeAndCheck(tester, card.altTarget.firstOrNull ?? card.target);
      expect(find.text(l10n.feedbackCorrect), findsOneWidget);
      await tester.tap(find.text(l10n.commonContinue));
      await tester.pumpAndSettle();

      // Heard as words; typed as digits, a comma allowed.
      card = current(tester);
      expect(find.text(l10n.numbersTypeDigits), findsOneWidget);
      await tester.tap(find.byType(PlayButton));
      await tester.pumpAndSettle();
      expect(tts.spoken.single.text, card.target);
      final n = card.number;
      await typeAndCheck(
        tester,
        '${n ~/ 1000},${(n % 1000).toString().padLeft(3, '0')}',
      );
      expect(find.text(l10n.feedbackCorrect), findsOneWidget);

      expect(state.progress.log, isEmpty);
    });

    testWidgets('a heard number one off is wrong, not a near miss', (
      tester,
    ) async {
      usePhone(tester);
      final settings = SettingsNotifier()
        ..setSkillEnabled(Skill.recognition, false)
        ..setSkillEnabled(Skill.production, false);
      await pumpDrill(
        tester,
        DrillRequest.numbers(numbersBig),
        state: AppState.test(
          tts: FixedTtsEngine(<String>{'hi'}),
          settings: settings,
        ),
      );
      final l10n = l10nOf(tester);
      final card = current(tester);
      final off = card.number == 9999 ? 9998 : card.number + 1;
      await typeAndCheck(tester, '$off');
      expect(find.text(l10n.feedbackWrong), findsOneWidget);
      expect(find.text(l10n.feedbackAnswer(card.native)), findsOneWidget);
    });

    testWidgets('without a voice, no number is heard', (tester) async {
      usePhone(tester);
      final state = await pumpDrill(tester, DrillRequest.numbers(numbersBig));
      final deck = state.deckById(numbersBig)!;
      expect(
        state.numberPracticeFor(deck).map((i) => i.mode),
        isNot(contains(DrillMode.listening)),
      );
      expect(find.byType(DrillFrame), findsOneWidget);
    });
  });
}
