import 'dart:ui' show LocaleStringAttribute;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/reading.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/reading_drill.dart';
import 'package:fluenough/features/drill/reading_fixture.dart';
import 'package:fluenough/features/summary/summary_page.dart';
import 'package:fluenough/ui/widgets/play_button.dart';
import 'package:fluenough/ui/widgets/target_text.dart';

import '../../support/harness.dart';

/// The reading drill (#98, ADR-0019): a passage, then its questions, read or
/// heard, each choice recorded at once.

final DateTime noon = DateTime(2026, 9, 28, 12);

final DrillRequest read = DrillRequest.untaught(
  readingFixtureDeckId,
  skill: Skill.reading,
);
final DrillRequest heard = DrillRequest.untaught(
  readingFixtureDeckId,
  skill: Skill.listening,
);

const List<String> shop = <String>[
  'নমস্কার। কত দাম?',
  'পঞ্চাশ টাকা।',
  'একটু কম করুন।',
  'আচ্ছা। ধন্যবাদ।',
];
const String home = 'সে কাজ ক’রে বাড়ি যায়।';

AppState readingApp({
  FixedTtsEngine? tts,
  SettingsNotifier? settings,
  MemoryProgress? progress,
}) => AppState.test(
  decks: readingFixtureDecks(),
  tts: tts ?? FixedTtsEngine(<String>{'bn'}),
  settings: settings,
  progress: progress,
  now: noon,
);

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

/// Whether [finder] is drawn inside the phone's screen, not scrolled off it.
void expectOnScreen(WidgetTester tester, Finder finder) {
  expect(finder, findsWidgets);
  final rect = tester.getRect(finder.first);
  expect(
    rect.top >= 0 && rect.bottom <= 844 && rect.left >= 0 && rect.right <= 390,
    isTrue,
    reason: '$finder is at $rect, off the screen',
  );
}

Future<void> meetsEveryGuideline(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  group('read', () {
    testWidgets('the passage shows on its own, with its readings, a button '
        'per sentence and its source', (tester) async {
      usePhone(tester);
      final tts = FixedTtsEngine(<String>{'bn'});
      final state = readingApp(tts: tts);
      await pumpScreen(tester, DrillPage(request: read), state: state);
      final l10n = l10nOf(tester);
      expect(find.byType(ReadingDrill), findsOneWidget);
      expect(find.text('At the shop'), findsOneWidget);
      expect(find.text(l10n.readingIntro(3)), findsOneWidget);
      for (final sentence in shop) {
        expect(find.text(sentence), findsOneWidget);
      }
      expect(find.text('nomoshkar. koto dam?'), findsOneWidget);
      expectOnScreen(
        tester,
        find.text(l10n.readingSource(readingFixtureSource)),
      );
      expect(find.byTooltip(l10n.readingPlaySentence), findsNWidgets(4));
      // No question yet.
      expect(find.text('What does the buyer ask first?'), findsNothing);

      await tester.tap(find.byTooltip(l10n.readingPlaySentence).at(1));
      await tester.pumpAndSettle();
      expect(tts.spoken.single.text, shop[1]);
      expect(tts.spoken.single.bcp47, 'bn-IN');

      state.settings.showRomanisation = false;
      await tester.pumpAndSettle();
      expect(find.text('nomoshkar. koto dam?'), findsNothing);

      await tapText(tester, l10n.readingToQuestions);
      expect(find.text('What does the buyer ask first?'), findsOneWidget);
      for (final choice in ['The price', 'The way', 'The time']) {
        expect(find.text(choice), findsOneWidget);
      }
      // The passage is under the choices, to look back at.
      expect(find.text(l10n.readingPassage), findsOneWidget);
      expect(find.text(shop.first), findsOneWidget);
      expect(state.progress.log, isEmpty);
    });

    testWidgets('the options are shuffled (#148), and the one tapped is the '
        'one recorded', (tester) async {
      usePhone(tester);
      final state = readingApp();
      await pumpScreen(tester, DrillPage(request: read), state: state);
      await tapText(tester, l10nOf(tester).readingToQuestions);
      // The test app's chance is seeded, so this order is always the same,
      // and it is not the deck's: The price is not first.
      final shown = <String>['The price', 'The way', 'The time']
        ..sort(
          (a, b) => tester
              .getTopLeft(find.text(a))
              .dy
              .compareTo(tester.getTopLeft(find.text(b)).dy),
        );
      expect(shown.first, isNot('The price'));
      await tapText(tester, 'The price');
      expect(state.progress.log.single.answerGiven, '1');
      expect(state.progress.log.single.grade, ReadingQuestion.rightGrade);
    });

    testWidgets('a choice is recorded at once, right or wrong, with the right '
        'answer shown', (tester) async {
      usePhone(tester);
      final state = readingApp();
      await pumpScreen(tester, DrillPage(request: read), state: state);
      final l10n = l10nOf(tester);
      await tapText(tester, l10n.readingToQuestions);

      await tapText(tester, 'The price');
      final right = state.progress.log.single;
      expect(right.deckId, readingFixtureDeckId);
      expect(right.cardId, 'bn-en-fixture-reading-shop-q1');
      expect(right.mode, DrillMode.reading);
      expect(right.grade, ReadingQuestion.rightGrade);
      expect(right.answerGiven, '1');
      expect(find.text(l10n.feedbackCorrect), findsOneWidget);
      expect(find.text(l10n.feedbackAnswer('The price')), findsOneWidget);
      // Choosing again changes nothing.
      await tester.tap(find.text('The way'));
      await tester.pumpAndSettle();
      expect(state.progress.log, hasLength(1));

      // The next question about the same passage follows at once.
      await tapText(tester, l10n.commonContinue);
      expect(find.text(l10n.readingToQuestions), findsNothing);
      expect(find.text(l10n.readingTrueOrFalse), findsOneWidget);
      expect(find.text('The buyer asks for a lower price.'), findsOneWidget);
      await tapText(tester, l10n.readingFalse);
      final wrong = state.progress.log.last;
      expect(wrong.cardId, 'bn-en-fixture-reading-shop-q2');
      expect(wrong.grade, ReadingQuestion.wrongGrade);
      expect(wrong.answerGiven, 'false');
      expect(find.text(l10n.feedbackWrong), findsOneWidget);
      expect(find.text(l10n.feedbackAnswer(l10n.readingTrue)), findsOneWidget);

      await tapText(tester, l10n.commonContinue);
      await tapText(tester, 'Fifty taka');
      await tapText(tester, l10n.commonContinue);
      // The next passage shows on its own first.
      expect(find.text('Going home'), findsOneWidget);
      expect(find.text(l10n.readingToQuestions), findsOneWidget);
      expect(find.text(home), findsOneWidget);
    });

    for (final (name, request) in <(String, DrillRequest)>[
      ('read', read),
      ('heard', heard),
    ]) {
      testWidgets('the source shows on every screen of a passage and its '
          'questions, $name', (tester) async {
        usePhone(tester);
        final state = readingApp();
        await pumpScreen(tester, DrillPage(request: request), state: state);
        final l10n = l10nOf(tester);
        final sources = <String>[
          for (var i = 0; i < 3; i++) readingFixtureSource,
          for (var i = 0; i < 2; i++) readingFixtureDeckSource,
        ];
        for (final (i, source) in sources.indexed) {
          final line = find.text(l10n.readingSource(source));
          final session = tester
              .widget<ReadingDrill>(find.byType(ReadingDrill))
              .session;
          if (session.showsPassage) {
            expectOnScreen(tester, line);
            await tapText(tester, l10n.readingToQuestions);
          }
          expectOnScreen(tester, line);
          final question = session.question!.question;
          await tapText(
            tester,
            question.isTrueFalse
                ? l10n.readingTrue
                : question.options.first['en']!,
          );
          expectOnScreen(tester, line);
          expect(state.progress.log, hasLength(i + 1));
          await tapText(tester, l10n.commonContinue);
        }
        expect(find.byType(SummaryPage), findsOneWidget);
      });
    }

    testWidgets('a question is shown in the best language the learner speaks '
        'that it is written in, and read in it', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      final settings = SettingsNotifier(
        spokenLanguages: const <String>['bn', 'hi', 'en'],
        learningChosen: true,
      );
      await pumpScreen(
        tester,
        DrillPage(request: read, preset: const DrillPreset(questions: true)),
        state: readingApp(settings: settings),
      );
      const prompt = 'ग्राहक पहले क्या पूछता है?';
      expect(find.text(prompt), findsOneWidget);
      expect(find.text('दाम'), findsOneWidget);
      expect(find.text('What does the buyer ask first?'), findsNothing);
      final label = tester.getSemantics(find.text(prompt)).attributedLabel;
      expect(
        label.attributes.whereType<LocaleStringAttribute>().single.locale,
        const Locale('hi'),
      );
      // The second question has no Hindi, so it is in English.
      await tapText(tester, 'दाम');
      await tapText(tester, l10nOf(tester).commonContinue);
      expect(find.text('The buyer asks for a lower price.'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('screen readers read the passage in Bengali, and the question '
        'in the interface\'s language', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      await pumpScreen(tester, DrillPage(request: read), state: readingApp());
      for (final sentence in shop) {
        final label = tester.getSemantics(find.text(sentence)).attributedLabel;
        final bengali = <String>[
          for (final a in label.attributes.whereType<LocaleStringAttribute>())
            if (a.locale == const Locale('bn'))
              label.string.substring(a.range.start, a.range.end),
        ];
        expect(bengali, <String>[sentence]);
      }
      await tapText(tester, l10nOf(tester).readingToQuestions);
      for (final text in <String>[
        'What does the buyer ask first?',
        'The way',
      ]) {
        final label = tester.getSemantics(find.text(text)).attributedLabel;
        expect(label.string, contains(text));
        expect(label.attributes.whereType<LocaleStringAttribute>(), isEmpty);
      }
      semantics.dispose();
    });

    testWidgets('Show romanisation on the passage hides and shows its '
        'readings, before and with the questions', (tester) async {
      usePhone(tester);
      final state = readingApp();
      await pumpScreen(tester, DrillPage(request: read), state: state);
      final l10n = l10nOf(tester);
      final toggle = find.widgetWithText(FilterChip, l10n.settingsRomanisation);
      expect(toggle, findsOneWidget);
      expect(find.text('nomoshkar. koto dam?'), findsOneWidget);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(state.settings.showRomanisation, isFalse);
      expect(find.text('nomoshkar. koto dam?'), findsNothing);

      await tapText(tester, l10n.readingToQuestions);
      expect(
        toggle,
        findsOneWidget,
        reason: 'with the passage under the choices',
      );
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(state.settings.showRomanisation, isTrue);
      expect(find.text('nomoshkar. koto dam?'), findsOneWidget);
    });

    testWidgets('Words opens the glossary: the word as written, today\'s '
        'form, its reading with romanisation on, and its meaning', (
      tester,
    ) async {
      usePhone(tester);
      final state = readingApp();
      await pumpScreen(
        tester,
        DrillPage(
          request: read,
          preset: const DrillPreset(target: home),
        ),
        state: state,
      );
      final l10n = l10nOf(tester);
      expect(find.text(home), findsOneWidget);
      await tapText(tester, l10n.readingWords);
      expect(find.text(l10n.readingWordsTitle), findsOneWidget);
      final glossary = find.byType(Glossary);
      for (final text in <String>['ক’রে', 'করে']) {
        final shown = find.descendant(of: glossary, matching: find.text(text));
        expect(shown, findsOneWidget);
        expect(
          find.ancestor(of: shown, matching: find.byType(TargetText)),
          findsOneWidget,
        );
      }
      expect(find.text('kore'), findsOneWidget);
      expect(find.text('having done'), findsOneWidget);
      // A word written the same today shows once, with no arrow to itself.
      expect(
        find.descendant(of: glossary, matching: find.text('বাড়িতে')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: glossary,
          matching: find.byIcon(Icons.arrow_forward),
        ),
        findsOneWidget,
      );
      expect(
        find.text('older spelling; the apostrophe marks a dropped ই'),
        findsOneWidget,
      );
      state.settings.showRomanisation = false;
      await tester.pumpAndSettle();
      expect(find.text('kore'), findsNothing);
      // Behind the sheet, Words stays by the passage, to open it again.
      expect(
        find.descendant(
          of: find.byType(ReadingDrill),
          matching: find.text(l10n.readingWords),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a passage without a glossary has no Words', (tester) async {
      usePhone(tester);
      await pumpScreen(tester, DrillPage(request: read), state: readingApp());
      expect(find.text(l10nOf(tester).readingWords), findsNothing);
    });
  });

  group('heard', () {
    testWidgets('the passage is read aloud, its text hidden until the '
        'question is answered', (tester) async {
      usePhone(tester);
      final tts = FixedTtsEngine(<String>{'bn'});
      final state = readingApp(tts: tts);
      await pumpScreen(tester, DrillPage(request: heard), state: state);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.readingListenIntro(3)), findsOneWidget);
      expect(find.text(l10n.readingTextHidden), findsOneWidget);
      for (final sentence in shop) {
        expect(find.text(sentence), findsNothing);
      }
      expect(find.text('nomoshkar. koto dam?'), findsNothing);
      expect(find.text(l10n.drillCantListen), findsOneWidget);

      await tester.tap(find.byType(PlayButton));
      await tester.pumpAndSettle();
      expect(tts.spoken.map((s) => s.text), shop);

      await tapText(tester, l10n.readingToQuestions);
      expect(find.byType(PlayButton), findsOneWidget);
      for (final sentence in shop) {
        expect(find.text(sentence), findsNothing);
      }
      await tapText(tester, 'The price');
      expect(state.progress.log.single.mode, DrillMode.listening);
      for (final sentence in shop) {
        expect(find.text(sentence), findsOneWidget);
      }
      expect(find.text(l10n.readingTextHidden), findsNothing);

      // Hidden again for the next question.
      await tapText(tester, l10n.commonContinue);
      for (final sentence in shop) {
        expect(find.text(sentence), findsNothing);
      }
    });

    testWidgets('the glossary waits for the text', (tester) async {
      usePhone(tester);
      await pumpScreen(
        tester,
        DrillPage(
          request: heard,
          preset: const DrillPreset(target: home),
        ),
        state: readingApp(),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.readingWords), findsNothing);
      await tapText(tester, l10n.readingToQuestions);
      expect(find.text(l10n.readingWords), findsNothing);
      await tapText(tester, l10n.readingTrue);
      expect(find.text(l10n.readingWords), findsOneWidget);
    });

    test(
      'only with a voice, and the listening skill on, for Bengali',
      () async {
        Future<int> heardItems(AppState state) async {
          await state.load();
          return state.buildSession(heard).items.length;
        }

        expect(await heardItems(readingApp()), 5);
        expect(await heardItems(readingApp(tts: FixedTtsEngine(const {}))), 0);
        final off = SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningChosen: true,
        )..setOffFor(Skill.listening, 'bn', true);
        expect(await heardItems(readingApp(settings: off)), 0);
        final allOff = SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningChosen: true,
        )..setSkillEnabled(Skill.listening, false);
        final today = readingApp(settings: allOff);
        await today.load();
        expect(
          today
              .buildSession(DrillRequest.untaught(readingFixtureDeckId))
              .items
              .map((i) => i.mode)
              .toSet(),
          {DrillMode.reading},
        );
      },
    );

    testWidgets('Can\'t listen now pauses listening and skips what is heard, '
        'and the questions read go on', (tester) async {
      usePhone(tester);
      final progress = MemoryProgress();
      // The first question is read already, so it is heard next; the rest
      // are new, and read.
      progress.record(
        deckId: readingFixtureDeckId,
        cardId: 'bn-en-fixture-reading-shop-q1',
        mode: DrillMode.reading,
        grade: 4,
        now: noon.subtract(const Duration(hours: 1)),
      );
      final state = readingApp(progress: progress);
      await pumpScreen(
        tester,
        DrillPage(request: DrillRequest.untaught(readingFixtureDeckId)),
        state: state,
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.readingListenIntro(1)), findsOneWidget);
      await tapText(tester, l10n.drillCantListen);
      await tapText(tester, l10n.cantNowPause);
      expect(state.settings.isPaused(Skill.listening, noon), isTrue);
      expect(state.progress.log, hasLength(1), reason: 'nothing new recorded');
      // The same passage again, read this time, for its other questions.
      expect(find.text(l10n.readingIntro(2)), findsOneWidget);
      for (final sentence in shop) {
        expect(find.text(sentence), findsOneWidget);
      }
    });
  });

  group('accessibility', () {
    final states = <(String, DrillRequest, DrillPreset?)>[
      ('the passage', read, null),
      ('a question', read, const DrillPreset(questions: true)),
      ('answered right', read, const DrillPreset(choice: 0)),
      ('answered wrong', read, const DrillPreset(choice: 2)),
      (
        'true or false, with Words',
        read,
        const DrillPreset(target: home, questions: true),
      ),
      ('heard', heard, null),
      ('heard, a question', heard, const DrillPreset(questions: true)),
      ('heard and answered', heard, const DrillPreset(choice: 1)),
    ];

    for (final themeMode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      for (final (name, request, preset) in states) {
        testWidgets('${themeMode.name} theme: $name', (tester) async {
          usePhone(tester);
          final semantics = tester.ensureSemantics();
          await pumpScreen(
            tester,
            DrillPage(request: request, preset: preset),
            state: readingApp(),
            themeMode: themeMode,
          );
          await meetsEveryGuideline(tester);
          semantics.dispose();
        });
      }
    }

    for (final (name, request, preset) in states) {
      testWidgets('at the largest font size, 2.0: $name, nothing clipped and '
          'targets still big enough', (tester) async {
        usePhone(tester, textScale: 2.0);
        final semantics = tester.ensureSemantics();
        await pumpScreen(
          tester,
          DrillPage(request: request, preset: preset),
          state: readingApp(),
        );
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }

    testWidgets('the glossary meets the guidelines', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      await pumpScreen(
        tester,
        DrillPage(
          request: read,
          preset: const DrillPreset(target: home),
        ),
        state: readingApp(),
      );
      await tapText(tester, l10nOf(tester).readingWords);
      await meetsEveryGuideline(tester);
      semantics.dispose();
    });
  });
}
