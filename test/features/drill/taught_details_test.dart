import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/scheduling/ask.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/choice_drill.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/taught_details.dart';
import 'package:fluenough/features/drill/typed_drill.dart';
import 'package:fluenough/ui/widgets/drill_frame.dart';
import 'package:fluenough/ui/widgets/feedback_banner.dart';

import '../../support/harness.dart';

/// What a word's lesson showed of it (its note and its example) comes back
/// once a review question about it is answered, never before.

const String spanish = 'es-fixture-details';
const String hindi = 'hi-fixture-details';
const String urdu = 'ur-fixture-details';

/// Three small decks, in memory, so that each card has the note and the
/// example a test needs, or none.
MemoryDeckSource fixtureDecks() => MemoryDeckSource(const <String, String>{
  'decks/es/$spanish.yaml': _spanish,
  'decks/hi/$hindi.yaml': _hindi,
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

/// A widget test with the semantics tree built, so that what a screen reader
/// is told can be found.
void semanticsTest(
  String name,
  Future<void> Function(WidgetTester tester) body,
) => testWidgets(name, (tester) async {
  final handle = tester.ensureSemantics();
  try {
    await body(tester);
  } finally {
    handle.dispose();
  }
});

/// A drill on screen, with its engines.
class Rig {
  Rig(this.state, this.speech);

  final AppState state;
  final FixedSpeechEngine speech;

  Card card(String deck, String target) =>
      state.deckById(deck)!.cards.firstWhere((c) => c.target == target);
}

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
    decks: fixtureDecks(),
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

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The example, named for a screen reader: its label, then the sentence and
/// its translation it holds.
Finder exampleNamed(WidgetTester tester) => find.bySemanticsLabel(
  RegExp('^${RegExp.escape(l10nOf(tester).drillExample)}'),
);

/// [finder] on the drill's card.
Finder inCard(Finder finder) =>
    find.descendant(of: find.byType(DrillCard), matching: finder);

enum Outcome { right, wrong }

typedef Answer = Future<void> Function(
  WidgetTester tester,
  Rig rig,
  Card card,
  Outcome outcome,
);

Future<void> typed(WidgetTester tester, Rig rig, Card card, Outcome o) async {
  // Hear types the meaning of what was heard (ADR-0034); the rest, the word.
  final session = tester.widget<TypedDrill>(find.byType(TypedDrill)).session;
  await tester.enterText(
    find.byType(TextField),
    o == Outcome.wrong
        ? 'zzzz'
        : session.hearsMeaning
        ? card.native
        : card.target,
  );
  await tester.pump();
  await tester.tap(find.text(l10nOf(tester).drillCheck));
  await tester.pumpAndSettle();
}

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

Future<void> revealed(
  WidgetTester tester,
  Rig rig,
  Card card,
  Outcome o,
) async {
  await tapText(tester, l10nOf(tester).drillShowAnswer);
}

/// One way of asking a question about one word, and what it shows before
/// the answer.
class Question {
  const Question(
    this.name,
    this.skill,
    this.ask,
    this.answer, {
    required this.showsWord,
    required this.showsMeaning,
    this.phrase = false,
  });

  final String name;
  final Skill skill;
  final Ask ask;
  final Answer answer;

  /// Whether the word is on the card before the answer.
  final bool showsWord;

  /// Whether the meaning is on the card before the answer.
  final bool showsMeaning;

  /// Whether it asks a phrase, which is rearranged.
  final bool phrase;

  /// The target of the card with a note and an example, and of the one
  /// with neither, in [deck].
  String rich(String deck) => switch ((deck, phrase)) {
    (spanish, false) => 'la casa',
    (spanish, true) => 'buenos días a todos',
    (hindi, false) => 'किताब',
    (hindi, true) => 'यह मेरी किताब है',
    _ => 'کتاب',
  };

  String plain(String deck) => switch ((deck, phrase)) {
    (spanish, false) => 'el perro',
    (spanish, true) => 'buenas noches a todos',
    (hindi, _) => 'घर',
    _ => 'گھر',
  };

  @override
  String toString() => name;
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

const Question recognition = Question(
  'recognition',
  Skill.recognition,
  Ask.own,
  revealed,
  showsWord: true,
  showsMeaning: false,
);

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
  group('after the answer, a review of one word shows what its lesson did', () {
    for (final question in <Question>[...answered, recognition]) {
      for (final outcome
          in question == recognition
              ? <Outcome>[Outcome.right]
              : Outcome.values) {
        semanticsTest('${question.name}, answered ${outcome.name}', (
          tester,
        ) async {
          usePhone(tester);
          final rig = await pumpRig(
            tester,
            deck: spanish,
            skill: question.skill,
            target: question.rich(spanish),
            ask: question.ask,
          );
          final card = rig.card(spanish, question.rich(spanish));
          final l10n = l10nOf(tester);
          expect(find.byType(DrillCard), findsOneWidget);

          // Nothing is given away beforehand.
          expectDetails(tester, card, shown: false);
          expect(
            inCard(find.text(card.target)),
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
          expect(inCard(find.text(card.target)), findsOneWidget);
          expect(inCard(find.text(card.native)), findsOneWidget);
          // On the card, which scrolls, not in the frame's fixed foot.
          expect(inCard(find.text(card.notes.first.text)), findsOneWidget);
          expect(find.byType(TaughtDetails), findsOneWidget);
        });
      }
    }
  });

  group('a card with no note and no example shows none', () {
    for (final question in <Question>[...answered, recognition]) {
      semanticsTest(question.name, (tester) async {
        usePhone(tester);
        final rig = await pumpRig(
          tester,
          deck: spanish,
          skill: question.skill,
          target: question.plain(spanish),
          ask: question.ask,
        );
        final card = rig.card(spanish, question.plain(spanish));
        final rich = rig.card(spanish, question.rich(spanish));
        await question.answer(tester, rig, card, Outcome.wrong);
        expect(tester.takeException(), isNull);
        // The word is there; the example and the note are not.
        expect(inCard(find.text(card.target)), findsOneWidget);
        expect(exampleNamed(tester), findsNothing);
        expect(find.text(rich.notes.first.text), findsNothing);
        expect(find.text(rich.examples.first.target), findsNothing);
        // Nothing but the answer's own texts: no text of a note's kind.
        final details = tester.widget<TaughtDetails>(
          find.byType(TaughtDetails),
        );
        expect(details.card.notes, isEmpty);
        expect(details.card.examples, isEmpty);
      });
    }
  });

  group('a note and an example each show on their own', () {
    semanticsTest('a note and no example', (tester) async {
      usePhone(tester);
      final rig = await pumpRig(
        tester,
        deck: spanish,
        skill: Skill.production,
        target: 'el gato',
      );
      await typed(tester, rig, rig.card(spanish, 'el gato'), Outcome.right);
      expect(find.text('A note and no example.'), findsOneWidget);
      expect(exampleNamed(tester), findsNothing);
    });

    semanticsTest('an example and no note', (tester) async {
      usePhone(tester);
      final rig = await pumpRig(
        tester,
        deck: spanish,
        skill: Skill.production,
        target: 'la mesa',
      );
      await typed(tester, rig, rig.card(spanish, 'la mesa'), Outcome.right);
      expect(find.text('La mesa es de madera.'), findsOneWidget);
      expect(find.text('The table is wooden.'), findsOneWidget);
      expect(exampleNamed(tester), findsOneWidget);
    });

    semanticsTest('only the first of several examples', (tester) async {
      usePhone(tester);
      final rig = await pumpRig(
        tester,
        deck: spanish,
        skill: Skill.production,
        target: 'la casa',
      );
      final card = rig.card(spanish, 'la casa');
      await typed(tester, rig, card, Outcome.right);
      expect(exampleNamed(tester), findsOneWidget);
    });
  });

  group('the lesson\'s teach card still shows them', () {
    semanticsTest('the word, meaning, note and example', (tester) async {
      usePhone(tester);
      final rig = await pumpRig(
        tester,
        deck: spanish,
        skill: Skill.production,
        target: 'la casa',
        ask: Ask.teach,
      );
      final card = rig.card(spanish, 'la casa');
      expect(find.text(l10nOf(tester).drillTeachTitle), findsOneWidget);
      expect(inCard(find.text(card.target)), findsOneWidget);
      expect(inCard(find.text(card.native)), findsOneWidget);
      expectDetails(tester, card, shown: true);
    });

    semanticsTest('a card with neither shows neither', (tester) async {
      usePhone(tester);
      final rig = await pumpRig(
        tester,
        deck: spanish,
        skill: Skill.production,
        target: 'el perro',
        ask: Ask.teach,
      );
      final card = rig.card(spanish, 'el perro');
      expect(inCard(find.text(card.native)), findsOneWidget);
      expect(exampleNamed(tester), findsNothing);
    });

    semanticsTest('a word with a reading shows it under the word', (
      tester,
    ) async {
      usePhone(tester);
      final rig = await pumpRig(
        tester,
        deck: hindi,
        skill: Skill.production,
        target: 'किताब',
        ask: Ask.teach,
      );
      final card = rig.card(hindi, 'किताब');
      expectDetails(tester, card, shown: true);
      expect(
        tester.getTopLeft(find.text(card.target)).dy,
        lessThan(tester.getTopLeft(find.text(card.reading!)).dy),
      );
    });
  });

  group('the reading follows Show romanisation and the alphabet choice', () {
    // Not rearranging: it has its own phrase, below.
    final asked = answered.where((q) => !q.phrase).toList();

    for (final question in asked) {
      semanticsTest('${question.name}: under the word while it is on', (
        tester,
      ) async {
        usePhone(tester);
        final rig = await pumpRig(
          tester,
          deck: hindi,
          skill: question.skill,
          target: 'किताब',
          ask: question.ask,
        );
        final card = rig.card(hindi, 'किताब');
        // The question that shows the word shows its reading from the start.
        expect(
          inCard(find.text(card.reading!)),
          question.showsWord ? findsOneWidget : findsNothing,
        );
        await question.answer(tester, rig, card, Outcome.wrong);
        expect(inCard(find.text(card.reading!)), findsOneWidget);
        // The script first, the reading under it.
        expect(
          tester.getTopLeft(inCard(find.text(card.target))).dy,
          lessThan(tester.getTopLeft(inCard(find.text(card.reading!))).dy),
        );
        expectDetails(tester, card, shown: true);
      });

      // A question that shows the word shows its reading from the start, as
      // it always has, whatever Show romanisation says: what is left out here
      // is what the answer adds.
      if (!question.showsWord) {
        semanticsTest('${question.name}: left out while it is off', (
          tester,
        ) async {
          usePhone(tester);
          final rig = await pumpRig(
            tester,
            deck: hindi,
            skill: question.skill,
            target: 'किताब',
            ask: question.ask,
            romanisation: false,
          );
          final card = rig.card(hindi, 'किताब');
          await question.answer(tester, rig, card, Outcome.wrong);
          expect(inCard(find.text(card.reading!)), findsNothing);
          expect(inCard(find.text(card.target)), findsOneWidget);
          // The rest is shown all the same.
          expectDetails(tester, card, shown: true);
        });
      }

      semanticsTest('${question.name}: first, big, without the alphabet', (
        tester,
      ) async {
        usePhone(tester);
        final rig = await pumpRig(
          tester,
          deck: hindi,
          skill: question.skill,
          target: 'किताब',
          ask: question.ask,
          // Whatever Show romanisation says.
          romanisation: false,
          noAlphabet: const <String>{'hi'},
        );
        final card = rig.card(hindi, 'किताब');
        await question.answer(tester, rig, card, Outcome.wrong);
        final reading = inCard(find.text(card.reading!));
        final script = inCard(find.text(card.target));
        expect(reading, findsOneWidget);
        expect(script, findsOneWidget);
        expect(
          tester.getTopLeft(reading).dy,
          lessThan(tester.getTopLeft(script).dy),
        );
        expect(
          tester.widget<Text>(reading).style!.fontSize!,
          greaterThan(tester.widget<Text>(script).style!.fontSize!),
        );
        expectDetails(tester, card, shown: true);
      });
    }

    semanticsTest('rearranging: under the word while it is on, and not off', (
      tester,
    ) async {
      for (final on in <bool>[true, false]) {
        usePhone(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        final rig = await pumpRig(
          tester,
          deck: hindi,
          skill: Skill.production,
          target: 'यह मेरी किताब है',
          ask: Ask.rearrange,
          romanisation: on,
        );
        final card = rig.card(hindi, 'यह मेरी किताब है');
        await arranged(tester, rig, card, Outcome.right);
        expect(
          inCard(find.text(card.reading!)),
          on ? findsOneWidget : findsNothing,
        );
        expectDetails(tester, card, shown: true);
      }
    });
  });

  group('a right-to-left script', () {
    final rtl = <Question>[answered[0], answered[3], answered[5]];
    for (final question in rtl) {
      semanticsTest('${question.name}: the word and the example read right to '
          'left', (tester) async {
        usePhone(tester);
        final rig = await pumpRig(
          tester,
          deck: urdu,
          skill: question.skill,
          target: 'کتاب',
          ask: question.ask,
        );
        final card = rig.card(urdu, 'کتاب');
        await question.answer(tester, rig, card, Outcome.wrong);
        expectDetails(tester, card, shown: true);
        for (final text in <String>[card.target, card.examples.first.target]) {
          final shown = tester.widget<Text>(inCard(find.text(text)));
          expect(shown.textDirection, TextDirection.rtl, reason: text);
          expect(shown.locale, const Locale('ur'), reason: text);
        }
        // The note is the interface's own language, left to right.
        expect(
          tester.widget<Text>(find.text(card.notes.first.text)).textDirection,
          isNull,
        );
      });
    }
  });

  group('at text scale 2.0, with a long note and a long example', () {
    // Each of the details is reached by scrolling the card, clear of the
    // fixed foot, which keeps the feedback and the button in view.
    for (final question in <Question>[...answered, recognition]) {
      for (final cardScale in <double>[
        1.0,
        SettingsNotifier.maxCardTextScale,
      ]) {
        semanticsTest('${question.name}, card text at $cardScale', (
          tester,
        ) async {
          usePhone(tester, textScale: 2.0);
          final target = question.phrase
              ? 'la ventana de mi cuarto da al jardín'
              : 'la ventana';
          final rig = await pumpRig(
            tester,
            deck: spanish,
            skill: question.skill,
            target: target,
            ask: question.ask,
            cardTextScale: cardScale,
          );
          final card = rig.card(spanish, target);
          await question.answer(tester, rig, card, Outcome.wrong);
          expect(tester.takeException(), isNull);

          final viewport = tester.getRect(find.byType(CustomScrollView));
          double footTop() => question == recognition
              ? tester.getTopLeft(find.text(l10nOf(tester).drillRatePrompt)).dy
              : tester.getTopLeft(find.byType(FeedbackBanner)).dy;
          final foot = footTop();
          // The scrolling body ends where the fixed foot begins: nothing on
          // the card can be covered by it.
          expect(viewport.bottom, lessThanOrEqualTo(foot + 0.5));
          for (final text in <String>[
            card.notes.first.text,
            card.examples.first.target,
            card.examples.first.native,
          ]) {
            final finder = find.text(text);
            await tester.ensureVisible(finder);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final rect = tester.getRect(finder);
            expect(rect.bottom, greaterThan(viewport.top), reason: text);
            expect(rect.top, lessThan(viewport.bottom), reason: text);
            // What fits the body is all in view once scrolled to.
            if (rect.height <= viewport.height) {
              expect(rect.top, greaterThanOrEqualTo(viewport.top - 0.5));
              expect(rect.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));
            }
          }
          // The foot stayed where it was while the card scrolled.
          expect(footTop(), foot);
        });
      }
    }
  });

  group('themes', () {
    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      semanticsTest('${mode.name}: the example and the note take its colours', (
        tester,
      ) async {
        usePhone(tester);
        final rig = await pumpRig(
          tester,
          deck: spanish,
          skill: Skill.production,
          target: 'la casa',
          themeMode: mode,
        );
        final card = rig.card(spanish, 'la casa');
        await typed(tester, rig, card, Outcome.right);
        expect(tester.takeException(), isNull);
        final scheme = Theme.of(tester.element(find.byType(DrillCard)))
            .colorScheme;
        expect(
          scheme.brightness,
          mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        );
        final box = tester.widget<Container>(
          find
              .ancestor(
                of: find.text(card.examples.first.target),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(
          (box.decoration! as BoxDecoration).color,
          scheme.surfaceContainerLowest,
        );
        expect(
          tester.widget<Text>(find.text(card.notes.first.text)).style!.color,
          scheme.onSurfaceVariant,
        );
      });
    }
  });

  group('TaughtDetails', () {
    semanticsTest('with nothing to show, takes no room', (tester) async {
      usePhone(tester);
      final rig = await pumpRig(
        tester,
        deck: spanish,
        skill: Skill.production,
        target: 'el perro',
      );
      final card = rig.card(spanish, 'el perro');
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpScreen(
        tester,
        Scaffold(
          body: Center(
            child: TaughtDetails(
              card: card,
              language: rig.state.deckById(spanish)!.language,
              reading: TaughtReading.first,
              word: false,
              meaning: false,
            ),
          ),
        ),
        state: rig.state,
      );
      expect(tester.getSize(find.byType(TaughtDetails)), Size.zero);
    });

    semanticsTest('lays out as the teach card does: 12 apart, centred', (
      tester,
    ) async {
      usePhone(tester);
      final rig = await pumpRig(
        tester,
        deck: spanish,
        skill: Skill.production,
        target: 'la casa',
      );
      final card = rig.card(spanish, 'la casa');
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpScreen(
        tester,
        Scaffold(
          body: Center(
            child: TaughtDetails(
              card: card,
              language: rig.state.deckById(spanish)!.language,
              reading: TaughtReading.first,
            ),
          ),
        ),
        state: rig.state,
      );
      final meaning = tester.getRect(find.text(card.native));
      final note = tester.getRect(find.text(card.notes.first.text));
      final example = tester.getRect(
        find
            .ancestor(
              of: find.text(card.examples.first.target),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(note.top - meaning.bottom, closeTo(12, 1));
      expect(example.top - note.bottom, closeTo(12, 1));
      expect(meaning.center.dx, closeTo(195, 1));
      expect(example.center.dx, closeTo(195, 1));
    });
  });
}
