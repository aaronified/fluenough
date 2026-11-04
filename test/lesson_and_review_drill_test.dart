// Split out of lesson_and_review_test.dart so that CI can spread it over its shards;
// the tests and their names are unchanged. This file holds: the drill, choice, match and rearrange, confusables, the braille keyboard, taught details.

import 'dart:math';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/grading/answer_grader.dart';
import 'package:fluenough/core/grading/self_grade.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/choice_drill.dart';
import 'package:fluenough/features/drill/choice_tile.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/drill/match_drill.dart';
import 'package:fluenough/features/drill/rearrange_drill.dart';
import 'package:fluenough/features/drill/recognition_drill.dart';
import 'package:fluenough/features/drill/rtl_fixture.dart';
import 'package:fluenough/features/drill/taught_details.dart';
import 'package:fluenough/features/drill/typed_drill.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/widgets/braille_keyboard.dart';
import 'package:fluenough/ui/widgets/drill_frame.dart';
import 'package:fluenough/ui/widgets/play_button.dart';
import 'package:fluenough/ui/widgets/target_text.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/braille_course.dart';
import 'support/harness.dart';
import 'support/lesson_and_review_shared.dart';

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

Future<AppState> pumpAsked(
  WidgetTester tester, {
  required String deck,
  required Skill skill,
  required String target,
  required Ask ask,
  AppState? state,
}) => pumpScreen(
  tester,
  DrillPage(
    request: DrillRequest.untaught(deck, skill: skill),
    preset: DrillPreset(target: target, ask: ask),
  ),
  state: state,
);

Card cardOf(AppState state, String deck, String target) =>
    state.deckById(deck)!.cards.firstWhere((c) => c.target == target);

/// A match pairs question of [target] and the next words of [deck] with
/// other meanings, in recognition, as a lesson asks it (ADR-0034). The
/// match shows until it is answered and continued.
Future<(AppState, DrillSession)> pumpMatch(
  WidgetTester tester, {
  required String deck,
  required String target,
}) async {
  final state = AppState.test();
  await state.load();
  final cards = state.deckById(deck)!.cards;
  final first = cards.firstWhere((c) => c.target == target);
  final group = <SessionItem>[
    SessionItem(card: first, mode: DrillMode.recognition, state: null),
  ];
  for (final card in cards) {
    if (group.length == matchSize) break;
    if (group.every(
      (g) => g.card.native != card.native && g.card.target != card.target,
    )) {
      group.add(
        SessionItem(card: card, mode: DrillMode.recognition, state: null),
      );
    }
  }
  final session = DrillSession(
    state: state,
    items: <SessionItem>[group.first.askedAs(Ask.matchPairs, group: group)],
  );
  addTearDown(session.dispose);
  await pumpScreen(
    tester,
    ListenableBuilder(
      listenable: session,
      builder: (context, _) => session.finished
          ? const SizedBox.shrink()
          : MatchDrill(session: session, onClose: () {}),
    ),
    state: state,
  );
  return (state, session);
}

// From braille_keyboard_test.dart.
Finder dot(int n) => find.byKey(ValueKey<String>('braille-dot-$n'));
const String urdu = 'ur-fixture-details';

/// Three small decks, in memory, so that each card has the note and the
/// example a test needs, or none.
MemoryDeckSource fixtureDecksTaughtDetails() =>
    MemoryDeckSource(const <String, String>{
      'decks/es/$spanishTaughtDetails.yaml': _spanish,
      'decks/hi/$hindiTaughtDetails.yaml': _hindi,
      'decks/ur/$urdu.yaml': _urdu,
    });

const String _spanish = '''
schema: 1
id: es-fixture-details
name: "Spanish (details fixture)"
kind: vocab
language: { code: es, iso639_3: spa, name: Spanish, script: latin, tts: es-ES }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: es-fixture-0001
    target: "la casa"
    native: "the house"
    notes: "A feminine noun: la casa, las casas."
    examples:
      - target: "La casa es grande."
        native: "The house is big."
  - id: es-fixture-0002
    target: "el perro"
    native: "the dog"
  - id: es-fixture-0003
    target: "el gato"
    native: "the cat"
    notes: "A note and no example."
  - id: es-fixture-0004
    target: "la mesa"
    native: "the table"
    examples:
      - target: "La mesa es de madera."
        native: "The table is wooden."
  - id: es-fixture-0005
    target: "el libro"
    native: "the book"
  - id: es-fixture-0006
    target: "la silla"
    native: "the chair"
  - id: es-fixture-0007
    target: "buenos días a todos"
    native: "good morning, everyone"
    pos: phrase
    notes: "Said to a group, as a class begins."
    examples:
      - target: "Buenos días a todos, empecemos."
        native: "Good morning, everyone, let us begin."
  - id: es-fixture-0008
    target: "buenas noches a todos"
    native: "good night, everyone"
    pos: phrase
  - id: es-fixture-0009
    target: "la ventana"
    native: "the window"
    notes: "Spanish has two words for a window of a house and a window of a vehicle or a bank: ventana is the first, ventanilla the second. A small ventana can be a ventanita, and the diminutive is common in speech."
    examples:
      - target: "La ventana de mi habitación da al jardín y por la mañana entra mucha luz."
        native: "My bedroom window looks out on the garden, and a lot of light comes in through it in the morning."
  - id: es-fixture-0010
    target: "la ventana de mi cuarto da al jardín"
    native: "the window of my room looks out on the garden"
    pos: phrase
    notes: "Spanish has two words for a window of a house and a window of a vehicle or a bank: ventana is the first, ventanilla the second. A small ventana can be a ventanita, and the diminutive is common in speech."
    examples:
      - target: "La ventana de mi habitación da al jardín y por la mañana entra mucha luz."
        native: "My bedroom window looks out on the garden, and a lot of light comes in through it in the morning."
''';

const String _hindi = '''
schema: 1
id: hi-fixture-details
name: "Hindi (details fixture)"
kind: vocab
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari, tts: hi-IN }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: hi-fixture-0001
    target: "किताब"
    native: "book"
    reading: "kitāb"
    notes: "Borrowed from Arabic through Persian."
    examples:
      - target: "यह मेरी किताब है।"
        native: "This is my book."
  - id: hi-fixture-0002
    target: "घर"
    native: "house"
    reading: "ghar"
  - id: hi-fixture-0003
    target: "पानी"
    native: "water"
    reading: "pānī"
  - id: hi-fixture-0004
    target: "दूध"
    native: "milk"
    reading: "dūdh"
  - id: hi-fixture-0005
    target: "रोटी"
    native: "bread"
    reading: "rōṭī"
  - id: hi-fixture-0006
    target: "चाय"
    native: "tea"
    reading: "cāy"
  - id: hi-fixture-0007
    target: "यह मेरी किताब है"
    native: "this is my book"
    reading: "yah mērī kitāb hai"
    pos: phrase
    notes: "Said as you hold it up."
    examples:
      - target: "यह मेरी किताब है, वह तुम्हारी।"
        native: "This is my book, that one is yours."
''';

const String _urdu = '''
schema: 1
id: ur-fixture-details
name: "Urdu (details fixture)"
kind: vocab
language: { code: ur, iso639_3: urd, name: Urdu, script: arabic, rtl: true, tts: ur-PK }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - id: ur-fixture-0001
    target: "کتاب"
    native: "book"
    reading: "kitaab"
    notes: "Borrowed from Arabic."
    examples:
      - target: "یہ میری کتاب ہے۔"
        native: "This is my book."
  - id: ur-fixture-0002
    target: "گھر"
    native: "house"
    reading: "ghar"
  - id: ur-fixture-0003
    target: "پانی"
    native: "water"
    reading: "paani"
  - id: ur-fixture-0004
    target: "دودھ"
    native: "milk"
    reading: "doodh"
  - id: ur-fixture-0005
    target: "روٹی"
    native: "bread"
    reading: "roti"
  - id: ur-fixture-0006
    target: "چائے"
    native: "tea"
    reading: "chai"
''';

/// [target] of [deck], asked [ask] as [skill], on a phone with a voice and a
/// recogniser for each fixture language.
Future<Rig> pumpRig(
  WidgetTester tester, {
  required String deck,
  required Skill skill,
  required String target,
  Ask ask = Ask.own,
  Set<String> noAlphabet = const <String>{},
  bool romanisation = true,
  double cardTextScale = 1.0,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  final speech = FixedSpeechEngine(onDevice: <String>{'es', 'hi', 'ur'});
  final state = AppState.test(
    decks: fixtureDecksTaughtDetails(),
    tts: FixedTtsEngine(<String>{'es', 'hi', 'ur'}),
    speech: speech,
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningChosen: true,
      enabledSkills: Skill.values.toSet(),
      noAlphabet: noAlphabet,
      showRomanisation: romanisation,
      cardTextScale: cardTextScale,
    ),
  );
  addTearDown(state.dispose);
  await state.load();
  await state.startSpeech();
  await pumpScreen(
    tester,
    DrillPage(
      request: DrillRequest.untaught(deck, skill: skill),
      preset: DrillPreset(target: target, ask: ask),
    ),
    state: state,
    themeMode: themeMode,
  );
  return Rig(state, speech);
}

/// The example, named for a screen reader: its label, then the sentence and
/// its translation it holds.
Finder exampleNamed(WidgetTester tester) => find.bySemanticsLabel(
  RegExp('^${RegExp.escape(l10nOf(tester).drillExample)}'),
);

/// [finder] on the drill's card.
Finder inCard(Finder finder) =>
    find.descendant(of: find.byType(DrillCard), matching: finder);

Future<void> chosen(WidgetTester tester, Rig rig, Card card, Outcome o) async {
  final session = tester.widget<ChoiceDrill>(find.byType(ChoiceDrill)).session;
  final option = o == Outcome.right
      ? card
      : session.options.firstWhere((c) => c.id != card.id);
  await tapText(
    tester,
    session.ask.choosesMeaning ? option.native : option.target,
  );
}

Future<void> said(WidgetTester tester, Rig rig, Card card, Outcome o) async {
  rig.speech.next = <SpeechAlternative>[
    SpeechAlternative(o == Outcome.right ? card.target : 'zzzz'),
  ];
  final mic = find.bySemanticsLabel(l10nOf(tester).drillSpeak);
  await tester.ensureVisible(mic);
  await tester.pumpAndSettle();
  await tester.tap(mic);
  await tester.pumpAndSettle();
}

Future<void> arranged(
  WidgetTester tester,
  Rig rig,
  Card card,
  Outcome o,
) async {
  final words = tilesOf(card.target);
  for (final word in o == Outcome.right ? words : words.reversed) {
    await tapText(tester, word);
  }
  await tapText(tester, l10nOf(tester).drillCheck);
}

const List<Question> answered = <Question>[
  Question(
    'production',
    Skill.production,
    Ask.own,
    typed,
    showsWord: false,
    showsMeaning: true,
  ),
  Question(
    'listening',
    Skill.listening,
    Ask.own,
    typed,
    showsWord: false,
    showsMeaning: false,
  ),
  Question(
    'multiple choice of the meaning',
    Skill.recognition,
    Ask.chooseMeaning,
    chosen,
    showsWord: true,
    showsMeaning: false,
  ),
  Question(
    'multiple choice of the word',
    Skill.production,
    Ask.chooseWord,
    chosen,
    showsWord: false,
    showsMeaning: true,
  ),
  Question(
    'hearing and choosing',
    Skill.listening,
    Ask.hearAndChoose,
    chosen,
    showsWord: false,
    showsMeaning: false,
  ),
  Question(
    'speaking',
    Skill.speaking,
    Ask.own,
    said,
    showsWord: false,
    showsMeaning: true,
  ),
  Question(
    'rearranging',
    Skill.production,
    Ask.rearrange,
    arranged,
    showsWord: false,
    showsMeaning: true,
    phrase: true,
  ),
  Question(
    'hearing and choosing the meaning',
    Skill.listening,
    Ask.hearMeaning,
    chosen,
    showsWord: false,
    showsMeaning: false,
  ),
];

/// Where the details are on screen: the note, the example's sentence and
/// its translation, and the example itself, named for a screen reader.
void expectDetails(WidgetTester tester, Card card, {required bool shown}) {
  final example = card.examples.first;
  final matcher = shown ? findsOneWidget : findsNothing;
  expect(find.text(card.notes.first.text), matcher, reason: 'the note');
  expect(find.text(example.target), matcher, reason: 'the example');
  expect(find.text(example.native), matcher, reason: 'its translation');
  expect(exampleNamed(tester), matcher, reason: 'the example, named');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the drill', () {
    testWidgets('recognition: reveal, rate with the previewed interval, '
        'recorded', (tester) async {
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
      // Rated, as recognition is where it cannot be chosen (ADR-0024): a
      // preset keeps each card asked its own way. Recognition is scheduled
      // (ADR-0034): the card is due, and the new words follow it.
      final state = await pumpDrill(
        tester,
        DrillRequest.untaught(spanish, skill: Skill.recognition),
        state: AppState.test(progress: progress),
        preset: DrillPreset(target: card.target),
      );
      final l10n = l10nOf(tester);
      final total = state
          .buildSession(
            DrillRequest.untaught(spanish, skill: Skill.recognition),
          )
          .length;
      expect(total, greaterThan(1));

      expect(find.text(card.target), findsOneWidget);
      expect(find.text(card.native), findsNothing);
      await tester.tap(find.text(l10n.drillShowAnswer));
      await tester.pumpAndSettle();
      expect(find.text(card.native), findsOneWidget);
      expect(find.text(l10n.drillRatePrompt), findsOneWidget);

      for (final grade in SelfGrade.values) {
        final days = progress
            .preview(card.id, DrillMode.recognition, grade.toGrade(), now: now)
            .intervalDays;
        expect(find.text(l10n.rateInterval(days)), findsWidgets);
      }
      final goodDays = progress
          .preview(card.id, DrillMode.recognition, 4, now: now)
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
      // The next card of the review, rated in its turn.
      expect(progress.log.last.mode, DrillMode.recognition);
      expect(find.text(l10n.drillShowAnswer), findsOneWidget);
      expect(find.text(l10n.drillPositionShort(2, total)), findsOneWidget);
    });

    testWidgets('recognition: the four ratings are one row at large text, and '
        'a swipe on the answer records Good', (tester) async {
      usePhone(tester, textScale: 1.4);
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
      await pumpDrill(
        tester,
        DrillRequest.untaught(spanish, skill: Skill.recognition),
        state: AppState.test(progress: progress),
        preset: DrillPreset(target: card.target),
      );
      final l10n = l10nOf(tester);

      // A swipe before the answer is shown goes nowhere.
      final before = progress.log.length;
      await tester.fling(
        find.byType(Scaffold).first,
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(progress.log, hasLength(before));
      await tester.tap(find.text(l10n.drillShowAnswer));
      await tester.pumpAndSettle();

      final labels = <String>[
        l10n.rateAgain,
        l10n.rateHard,
        l10n.rateGood,
        l10n.rateEasy,
      ];
      final tops = <double>{
        for (final label in labels) tester.getTopLeft(find.text(label)).dy,
      };
      expect(tops, hasLength(1), reason: 'one row');

      await tester.tap(find.text(l10n.rateHard));
      await tester.pumpAndSettle();
      expect(progress.log.last.grade, SelfGrade.hard.toGrade());

      // The next card: a swipe toward the start edge is the same as Good.
      await tester.tap(find.text(l10n.drillShowAnswer));
      await tester.pumpAndSettle();
      final count = progress.log.length;
      await tester.fling(
        find.byType(Scaffold).first,
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(progress.log, hasLength(count + 1));
      expect(progress.log.last.grade, SelfGrade.good.toGrade());
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

      testWidgets(
        'production records its grade on Check; a near miss waits for the '
        'learner to judge it',
        (tester) async {
          for (final c in cases) {
            usePhone(tester);
            final state = await pumpDrill(
              tester,
              DrillRequest.untaught(spanish, skill: Skill.production),
              preset: const DrillPreset(target: 'el niño'),
            );
            final l10n = l10nOf(tester);
            await typeAndCheck(tester, c.typed);

            expect(find.text(c.title(l10n)), findsOneWidget);
            final log = state.progress.log;
            expect(log, hasLength(1), reason: 'recorded before going on');
            expect(log.single.grade, c.grade);
            expect(log.single.mode, DrillMode.production);
            expect(log.single.answerGiven, c.typed);

            await nextCard(tester);
            expect(find.text(l10n.drillCheck), findsOneWidget);
            expect(state.progress.log, hasLength(1));
          }

          {
            for (final judgement in TypoJudgement.values) {
              usePhone(tester);
              final state = await pumpDrill(
                tester,
                DrillRequest.untaught(spanish, skill: Skill.production),
                preset: const DrillPreset(target: 'la ventana'),
              );
              final l10n = l10nOf(tester);
              await typeAndCheck(tester, 'la ventna');

              expect(
                find.text(l10n.feedbackTypo('la ventana')),
                findsOneWidget,
              );
              expect(find.text(l10n.commonContinue), findsNothing);
              expect(
                state.progress.log,
                isEmpty,
                reason: 'the learner judges it',
              );

              await tester.tap(
                find.text(
                  judgement == TypoJudgement.knewIt
                      ? l10n.drillKnewIt
                      : l10n.drillCountWrong,
                ),
              );
              await tester.pumpAndSettle();
              expect(state.progress.log.single.grade, judgement.toGrade());
              expect(
                find.text(l10n.drillCheck),
                findsOneWidget,
                reason: 'next',
              );
            }
          }
        },
      );
    });

    testWidgets('listening speaks at the speech rate, and slower, and its '
        'meaning is typed once remembered (ADR-0034)', (tester) async {
      usePhone(tester);
      final tts = FixedTtsEngine(<String>{'es'});
      // Heard and remembered: due, so Hear asks for the meaning to be typed.
      final base = AppState.test();
      await base.load();
      final card = base.deckById(spanish)!.cards.first;
      final progress = MemoryProgress()
        ..record(
          deckId: spanish,
          cardId: card.id,
          mode: DrillMode.listening,
          grade: 4,
          now: base.now().subtract(const Duration(days: 8)),
        );
      final state = await pumpDrill(
        tester,
        DrillRequest.deck(spanish, skill: Skill.listening),
        state: AppState.test(tts: tts, progress: progress),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.drillTypeMeaning), findsOneWidget);
      expect(find.text(l10n.drillTypeHeard), findsNothing);
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

      // The word typed as heard is not its meaning.
      final before = state.progress.log.length;
      await typeAndCheck(tester, card.native);
      expect(find.text(l10n.feedbackCorrect), findsOneWidget);
      expect(state.progress.log, hasLength(before + 1));
      expect(state.progress.log.last.mode, DrillMode.listening);
      expect(state.progress.log.last.answerGiven, card.native);
      expect(state.progress.log.last.grade, 5);
    });

    testWidgets(
      'closing part-way asks first; a right-to-left deck types and shows '
      'right to left',
      (tester) async {
        usePhone(tester);
        final state = AppState.test();
        await pumpScreen(tester, const SizedBox.shrink(), state: state);
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => DrillPage(
              request: DrillRequest.untaught(spanish, skill: Skill.production),
              preset: const DrillPreset(target: 'el niño'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = l10nOf(tester);
        await typeAndCheck(tester, 'el nino');
        await nextCard(tester);

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
        expect(state.progress.log.single.grade, 4, reason: 'kept');

        {
          usePhone(tester);
          final state = await pumpDrill(
            tester,
            DrillRequest.untaught(rtlFixtureDeckId, skill: Skill.production),
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
        }
      },
    );

    group('number practice (#54)', () {
      const numbersBig = 'hi-en-numbers-big';

      /// The generated number on screen now.
      Card current(WidgetTester tester) {
        final drill = tester.widget(
          find.byWidgetPredicate(
            (w) => w is RecognitionDrill || w is TypedDrill,
          ),
        );
        final session = drill is RecognitionDrill
            ? drill.session
            : (drill as TypedDrill).session;
        return session.item.card;
      }

      testWidgets(
        'recognition, production and listening, none of it recorded',
        (tester) async {
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
          await nextCard(tester);

          // Heard as words; typed as digits, a comma allowed.
          card = current(tester);
          expect(find.text(l10n.numbersTypeDigits), findsOneWidget);
          await tester.tap(find.byType(PlayButton));
          await tester.pumpAndSettle();
          expect(tts.spoken.single.text, card.target);
          final n = int.parse(card.native);
          await typeAndCheck(
            tester,
            '${n ~/ 1000},${(n % 1000).toString().padLeft(3, '0')}',
          );
          expect(find.text(l10n.feedbackCorrect), findsOneWidget);

          expect(state.progress.log, isEmpty);
        },
      );
    });
  });

  group('choice, match and rearrange', () {
    group('multiple choice', () {
      testWidgets(
        'the right meaning records 4; a wrong one records 1 and shows the '
        'answer',
        (tester) async {
          usePhone(tester);
          final state = await pumpAsked(
            tester,
            deck: spanish,
            skill: Skill.recognition,
            target: 'la casa',
            ask: Ask.chooseMeaning,
          );
          final l10n = l10nOf(tester);
          final card = cardOf(state, spanish, 'la casa');
          expect(find.byType(ChoiceDrill), findsOneWidget);
          expect(find.text(l10n.drillChooseMeaning), findsOneWidget);
          // Four options, each a different meaning, the card's among them.
          final options = find.descendant(
            of: find.bySemanticsLabel(l10n.drillOptionsGroup),
            matching: find.byType(InkWell),
          );
          expect(options, findsNWidgets(4));

          await tapText(tester, card.native);
          final event = state.progress.log.single;
          expect(event.cardId, card.id);
          expect(event.mode, DrillMode.recognition);
          expect(event.grade, 4);
          expect(find.text(l10n.feedbackCorrect), findsOneWidget);
          // Answered right: only the right option is left, and there is no
          // Continue button, only the swipe and the chevron (#509).
          expect(options, findsOneWidget);
          expect(find.text(l10n.commonContinue), findsNothing);
          await nextCard(tester);
          expect(find.byType(ChoiceDrill), findsNothing);

          {
            usePhone(tester);
            final state = await pumpAsked(
              tester,
              deck: spanish,
              skill: Skill.recognition,
              target: 'la casa',
              ask: Ask.chooseMeaning,
            );
            final l10n = l10nOf(tester);
            final card = cardOf(state, spanish, 'la casa');
            final session = tester.widget<ChoiceDrill>(
              find.byType(ChoiceDrill),
            );
            final wrong = session.session.options.firstWhere(
              (o) => o.id != card.id,
            );
            await tapText(tester, wrong.native);
            expect(state.progress.log.single.grade, 1);
            expect(find.text(l10n.feedbackWrong), findsOneWidget);
            expect(find.text(l10n.feedbackAnswer(card.native)), findsOneWidget);
            // Answered wrong: the right option and the one chosen, no others.
            expect(find.byType(ChoiceTile), findsNWidgets(2));
          }
        },
      );
    });

    group('match pairs', () {
      testWidgets('a word is matched to its meaning by a tap, or by dragging', (
        tester,
      ) async {
        usePhone(tester);
        final (state, _) = await pumpMatch(
          tester,
          deck: spanish,
          target: 'la casa',
        );
        final l10n = l10nOf(tester);
        final drill = tester.widget<MatchDrill>(find.byType(MatchDrill));
        final group = drill.session.item.group;
        expect(group, hasLength(matchSize));
        expect(find.text(l10n.drillMatchPrompt), findsOneWidget);

        // A wrong pair first: nothing recorded, the word marked missed.
        await tapText(tester, group[0].card.target);
        await tapText(tester, group[1].card.native);
        expect(state.progress.log, isEmpty);
        expect(drill.session.wasMissed(group[0]), isTrue);

        // Meaning first, then word, works too.
        for (final entry in group) {
          await tapText(tester, entry.card.native);
          await tapText(tester, entry.card.target);
        }
        final grades = <String, int>{
          for (final e in state.progress.log) e.cardId: e.grade,
        };
        expect(state.progress.log, hasLength(matchSize));
        expect(state.progress.log.map((e) => e.mode).toSet(), <DrillMode>{
          DrillMode.recognition,
        });
        expect(grades[group[0].card.id], 1);
        for (final entry in group.skip(1)) {
          expect(grades[entry.card.id], 4);
        }
        expect(find.text(l10n.drillMatchAgain(1)), findsOneWidget);
        await nextCard(tester);
        expect(find.byType(MatchDrill), findsNothing);

        {
          usePhone(tester);
          final (state, _) = await pumpMatch(
            tester,
            deck: spanish,
            target: 'la casa',
          );
          final card = cardOf(state, spanish, 'la casa');
          final word = find.text(card.target);
          final meaning = find.text(card.native);
          await tester.ensureVisible(word);
          await tester.pumpAndSettle();
          final gesture = await tester.startGesture(tester.getCenter(word));
          await tester.pump();
          await gesture.moveTo(tester.getCenter(meaning));
          await tester.pump();
          await gesture.up();
          await tester.pumpAndSettle();
          final event = state.progress.log.single;
          expect(event.cardId, card.id);
          expect(event.grade, 4);
        }
      });
    });

    group('rearrange', () {
      testWidgets('the words put in order record 5; the wrong order records 1', (
        tester,
      ) async {
        usePhone(tester);
        final state = await pumpAsked(
          tester,
          deck: hindi,
          skill: Skill.production,
          target: 'आप कैसे हैं?',
          ask: Ask.rearrange,
        );
        final l10n = l10nOf(tester);
        final card = cardOf(state, hindi, 'आप कैसे हैं?');
        expect(find.byType(RearrangeDrill), findsOneWidget);
        expect(find.text(card.native), findsOneWidget);
        // Before the script units, the words come in Latin letters.
        final words = tilesOf(card.reading!);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, l10n.drillCheck),
              )
              .onPressed,
          isNull,
        );
        for (final word in words) {
          await tapText(tester, word);
        }
        await tapText(tester, l10n.drillCheck);
        final event = state.progress.log.single;
        expect(event.mode, DrillMode.production);
        expect(event.grade, 5);
        expect(find.text(l10n.feedbackCorrect), findsOneWidget);

        {
          usePhone(tester);
          final state = await pumpAsked(
            tester,
            deck: spanish,
            skill: Skill.production,
            target: 'la casa',
            ask: Ask.rearrange,
          );
          final l10n = l10nOf(tester);
          Finder placed(String word) => find.descendant(
            of: find.byWidgetPredicate(
              (w) =>
                  w is Semantics &&
                  w.properties.label == l10n.drillRearrangeAnswer,
            ),
            matching: find.text(word),
          );
          await tapText(tester, 'la');
          expect(placed('la'), findsOneWidget);
          // Its place among the words to place is kept, so the others stay put.
          expect(find.text('la'), findsNWidgets(2));
          await tester.tap(placed('la'));
          await tester.pumpAndSettle();
          expect(placed('la'), findsNothing);
          await tapText(tester, 'casa');
          await tapText(tester, 'la');
          await tapText(tester, l10n.drillCheck);
          expect(state.progress.log.single.grade, 1);
          expect(find.text(l10n.feedbackAnswer('la casa')), findsOneWidget);
        }
      });
    });
  });

  group('confusables', () {
    test('a card whose confusables name three cards is offered exactly those '
        'as wrong options', () async {
      final state = AppState.test(
        decks: MemoryDeckSource(const <String, String>{
          'decks/zz/zz-curated.yaml': core,
          'decks/zz/en/zz-en-curated.yaml': layer,
        }),
      );
      addTearDown(state.dispose);
      await state.load();
      final card = state
          .deckById('zz-en-curated')!
          .cards
          .firstWhere((c) => c.id == 'zz-8001');
      // The pool alone would also offer the cat and the dog.
      expect(state.choicePool(card, Ask.chooseMeaning), hasLength(5));
      for (var seed = 0; seed < 8; seed++) {
        final session = DrillSession(
          state: state,
          items: <SessionItem>[
            SessionItem(
              card: card,
              mode: DrillMode.recognition,
              state: null,
              ask: Ask.chooseMeaning,
            ),
          ],
          random: Random(seed),
        );
        addTearDown(session.dispose);
        expect(session.options, hasLength(DrillSession.optionCount));
        expect(
          session.options.map((c) => c.id),
          unorderedEquals(<String>['zz-8001', 'zz-8002', 'zz-8003', 'zz-8004']),
        );
      }
    });
  });

  group('the braille keyboard', () {
    testWidgets('the braille course\'s production is typed on it, in place of '
        'the phone\'s keyboard, and graded as typed', (tester) async {
      usePhone(tester);
      final state = brailleApp(<String>['qbe']);
      addTearDown(state.dispose);
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(
            'qbe-en-letters',
            skill: Skill.production,
          ),
          preset: const DrillPreset(target: '⠃'),
        ),
        state: state,
      );
      final l10n = l10nOf(tester);
      expect(find.byType(TypedDrill), findsOneWidget);
      expect(find.byType(BrailleKeyboard), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.readOnly,
        isTrue,
        reason: 'the phone\'s keyboard stays shut',
      );
      expect(field.keyboardType, TextInputType.none);
      // Owner, 2026-10-20: "Make sure that the fields which need the keyboard
      // will not trigger the normal keyboard": not as it appears, nor on a tap.
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.testTextInput.hasAnyClients, isFalse);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.testTextInput.hasAnyClients, isFalse);

      await tester.tap(dot(1));
      await tester.tap(dot(2));
      await tester.pump();
      await tester.tap(find.text(l10n.brailleEnterCell));
      await tester.pumpAndSettle();
      expect(field.controller!.text, '⠃');
      await tester.tap(find.text(l10n.drillCheck));
      await tester.pumpAndSettle();
      final session = tester
          .widget<TypedDrill>(find.byType(TypedDrill))
          .session;
      expect(session.answer!.graded!.outcome, AnswerOutcome.exact);
      // With the answer in, the keyboard goes with the field.
      expect(find.byType(BrailleKeyboard), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);

      // The next card's field does not ask for the phone's keyboard either.
      await nextCard(tester);
      if (find.byType(BrailleKeyboard).evaluate().isNotEmpty) {
        await tester.tap(find.byType(TextField));
        await tester.pump();
      }
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.testTextInput.hasAnyClients, isFalse);
    });

    testWidgets('another language keeps the phone\'s keyboard', (tester) async {
      usePhone(tester);
      final state = brailleApp(<String>['es']);
      addTearDown(state.dispose);
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.untaught(
            'es-en-words',
            skill: Skill.production,
          ),
          preset: const DrillPreset(target: 'hola'),
        ),
        state: state,
      );
      expect(find.byType(TypedDrill), findsOneWidget);
      expect(find.byType(BrailleKeyboard), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.readOnly, isFalse);
      expect(field.keyboardType, isNot(TextInputType.none));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
    });
  });

  group('taught details', () {
    testWidgets('after the answer, a reviewed word shows its note and '
        'example, which nothing gives away before it', (tester) async {
      final handle = tester.ensureSemantics();
      for (final question in <Question>[...answered, recognition]) {
        const outcome = Outcome.right;

        usePhone(tester);
        final rig = await pumpRig(
          tester,
          deck: spanishTaughtDetails,
          skill: question.skill,
          target: question.rich(spanishTaughtDetails),
          ask: question.ask,
        );
        final card = rig.card(
          spanishTaughtDetails,
          question.rich(spanishTaughtDetails),
        );
        final l10n = l10nOf(tester);
        expect(find.byType(DrillCard), findsOneWidget);

        // Nothing is given away beforehand.
        expectDetails(tester, card, shown: false);
        expect(
          inCard(findTarget(card.target)),
          question.showsWord ? findsOneWidget : findsNothing,
          reason: 'the word, before the answer',
        );
        expect(
          inCard(find.text(card.native)),
          question.showsMeaning ? findsOneWidget : findsNothing,
          reason: 'the meaning, before the answer',
        );

        await question.answer(tester, rig, card, outcome);
        expect(tester.takeException(), isNull);
        if (question != recognition) {
          expect(
            find.text(
              outcome == Outcome.right
                  ? l10n.feedbackCorrect
                  : l10n.feedbackWrong,
            ),
            findsOneWidget,
            reason: 'the answer was taken as ${outcome.name}',
          );
        }

        // Now: the word, the meaning, the note and the example.
        expectDetails(tester, card, shown: true);
        expect(inCard(findTarget(card.target)), findsOneWidget);
        expect(inCard(find.text(card.native)), findsOneWidget);
        // On the card, which scrolls, not in the frame's fixed foot.
        expect(inCard(find.text(card.notes.first.text)), findsOneWidget);
        expect(find.byType(TaughtDetails), findsOneWidget);
      }
      handle.dispose();
    });
  });
}
