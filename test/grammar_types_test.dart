// The grammar question types are eligible by the card's data: whether the
// card's word has other forms (ADR-0039, #522 step 4).
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/rule.dart';
import 'package:fluenough/core/scheduling/lesson.dart';
import 'package:fluenough/core/scheduling/question_type.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:flutter_test/flutter_test.dart';

Card cell({List<RuleOption> options = const <RuleOption>[]}) => Card(
  id: 'te-cell',
  deckId: 'te-en-grammar',
  target: 'ammalō',
  native: 'in mother',
  modes: DrillMode.vocabulary,
  rule: RuleCell(
    ruleId: 'te-rule-in',
    word: 'te-amma',
    wordTarget: 'amma',
    slot: 'in',
    options: options,
  ),
);

const others = <RuleOption>[
  RuleOption(form: 'ammaki', prompt: 'to mother'),
  RuleOption(form: 'ammatō', prompt: 'with mother'),
];

const context = QuestionContext(canChoose: _yes);
bool _yes(SessionItem item) => true;

SessionItem item(Card card, DrillMode mode) =>
    SessionItem(card: card, mode: mode, state: null);

void main() {
  siblingTests();
  lessonSiblingTests();
  modesTests();
  test(
    'a cell with other forms is asked to choose its form and its meaning',
    () {
      final card = cell(options: others);
      expect(
        questionTypeFor(item(card, DrillMode.grammarUnderstood), context)?.ask,
        Ask.chooseFormMeaning,
      );
      expect(
        questionTypeFor(item(card, DrillMode.grammar), context)?.ask,
        Ask.chooseForm,
      );
    },
  );

  test('a cell with no other forms is asked neither, and is typed', () {
    final card = cell();
    expect(
      questionTypeFor(item(card, DrillMode.grammarUnderstood), context),
      isNull,
    );
    expect(questionTypeFor(item(card, DrillMode.grammar), context), isNull);
    expect(lessonQuestions(card), [(mode: DrillMode.grammar, ask: Ask.own)]);
  });

  test(
    'a form that means what the others mean is produced, not understood',
    () {
      final card = cell(
        options: const <RuleOption>[
          RuleOption(form: 'ammaki', prompt: 'in mother'),
        ],
      );
      expect(lessonQuestions(card), [
        (mode: DrillMode.grammar, ask: Ask.chooseForm),
      ]);
    },
  );

  test('the lesson asks what the registry would, understood then produced', () {
    expect(lessonQuestions(cell(options: others)), [
      (mode: DrillMode.grammarUnderstood, ask: Ask.chooseFormMeaning),
      (mode: DrillMode.grammar, ask: Ask.chooseForm),
    ]);
  });
}

Card word(
  String id,
  String target,
  String native, {
  String? base,
  List<String> bases = const <String>[],
  Set<DrillMode> modes = const <DrillMode>{},
}) => Card(
  id: id,
  deckId: 'te-en-words',
  target: target,
  native: native,
  modes: modes,
  bases: <CardBase>[
    for (final ref in <String>[?base, ...bases])
      CardBase(word: target, ref: ref),
  ],
);

void siblingTests() {
  final amma = word('te-1', 'ammaki', 'to mother', base: 'te-amma');
  final loc = word('te-2', 'ammalō', 'in mother', base: 'te-amma');
  final same = word('te-3', 'ammaki', 'for mother', base: 'te-amma');
  final other = word('te-4', 'illu', 'house', base: 'te-illu');
  final alone = word('te-5', 'pustakam', 'book');
  // A sentence of several words, one of them amma, is no form of amma.
  final sentence = word(
    'te-6',
    'amma illu',
    'mother house',
    bases: ['te-amma', 'te-illu'],
  );
  final sentence2 = word(
    'te-7',
    'amma pustakam',
    'mother book',
    bases: ['te-amma', 'te-pustakam'],
  );
  final all = <Card>[amma, loc, same, other, alone, sentence, sentence2];
  List<Card> siblingsOf(Card c) => formSiblings(c, all);
  final withSiblings = QuestionContext(canChoose: _yes, siblingsOf: siblingsOf);

  test('siblings are single-base cards with another form of the base', () {
    expect(siblingsOf(amma), [loc]);
    expect(siblingsOf(loc), [amma, same]);
    expect(siblingsOf(other), isEmpty);
    expect(siblingsOf(alone), isEmpty);
  });

  test(
    'a multi-base sentence sharing one word is no sibling of either side',
    () {
      expect(siblingsOf(sentence), isEmpty);
      expect(siblingsOf(sentence2), isEmpty);
      expect(siblingsOf(amma), [loc]);
    },
  );

  test(
    'a card with siblings is asked the form questions, one without is not',
    () {
      expect(
        questionTypeFor(item(amma, DrillMode.grammar), withSiblings)?.ask,
        Ask.chooseForm,
      );
      expect(
        questionTypeFor(item(other, DrillMode.grammar), withSiblings),
        isNull,
      );
      expect(
        questionTypeFor(item(alone, DrillMode.grammar), withSiblings),
        isNull,
      );
      expect(questionTypeFor(item(amma, DrillMode.grammar), context), isNull);
    },
  );

  test('a sibling that shows nothing new is no option; a form needs a '
      'different meaning to be understood', () {
    expect(
      questionTypeFor(
        item(amma, DrillMode.grammarUnderstood),
        withSiblings,
      )?.ask,
      Ask.chooseFormMeaning,
    );
    expect(formChoices(loc, Ask.chooseForm, all).map((c) => c.id), ['te-1']);
    expect(formChoices(loc, Ask.chooseFormMeaning, all).map((c) => c.id), [
      'te-1',
      'te-3',
    ]);
    // A sibling with the same form is no other form: not asked.
    final onlySame = <Card>[amma, same];
    expect(
      questionTypeFor(
        item(amma, DrillMode.grammar),
        QuestionContext(
          canChoose: _yes,
          siblingsOf: (c) => formSiblings(c, onlySame),
        ),
      ),
      isNull,
    );
  });
}

const Set<DrillMode> fourSkills = DrillMode.vocabulary;

void modesTests() {
  Card plain({Set<DrillMode> modes = const <DrillMode>{}}) => Card(
    id: 'te-9',
    deckId: 'te-en-words',
    target: 'ammaki',
    native: 'to mother',
    modes: modes,
  );
  final loc = word('te-2', 'ammalō', 'in mother', base: 'te-amma');
  final same = word('te-3', 'ammalō', 'to mother', base: 'te-amma');
  final sentence = word(
    'te-6',
    'amma illu',
    'mother house',
    bases: ['te-amma', 'te-illu'],
  );

  Set<DrillMode> modesOf(Card c, [List<Card> siblings = const <Card>[]]) =>
      c.modesIn(ttsAvailable: true, speechAvailable: true, siblings: siblings);

  test('a card that names no modes takes every vocabulary skill', () {
    expect(modesOf(plain()), fourSkills);
  });

  test('modes are the skills a card is excluded from', () {
    expect(modesOf(plain(modes: {DrillMode.recognition, DrillMode.speaking})), {
      DrillMode.production,
      DrillMode.listening,
    });
  });

  test('a card with siblings is also asked the grammar skills', () {
    final card = word('te-1', 'ammaki', 'to mother', base: 'te-amma');
    expect(modesOf(card, [loc]), {
      ...fourSkills,
      DrillMode.grammar,
      DrillMode.grammarUnderstood,
    });
  });

  test('a sibling that means the same lets the form be produced, not '
      'understood', () {
    final card = word('te-1', 'ammaki', 'to mother', base: 'te-amma');
    expect(modesOf(card, [same]), {...fourSkills, DrillMode.grammar});
  });

  test('a card with no siblings is not asked grammar', () {
    expect(
      modesOf(word('te-1', 'ammaki', 'to mother', base: 'te-amma')),
      fourSkills,
    );
    expect(modesOf(sentence, const <Card>[]), fourSkills);
  });

  test('excluding grammar excludes both grammar skills', () {
    final card = word(
      'te-1',
      'ammaki',
      'to mother',
      base: 'te-amma',
      modes: {DrillMode.grammar},
    );
    expect(modesOf(card, [loc]), fourSkills);
  });

  test('a card that excludes the four vocabulary skills is a grammar cell', () {
    final cell = plain(modes: fourSkills);
    expect(cell.isGrammarCell, isTrue);
    expect(modesOf(cell), {DrillMode.grammar});
  });

  test('a rules cell is asked grammar alone, understood where it means '
      'something else', () {
    expect(modesOf(cell(options: others)), {
      DrillMode.grammarUnderstood,
      DrillMode.grammar,
    });
    expect(modesOf(cell()), {DrillMode.grammar});
  });

  test('without a voice or a recogniser those skills are left out', () {
    expect(plain().modesIn(ttsAvailable: false), {
      DrillMode.recognition,
      DrillMode.production,
    });
  });

  test('a session offers a card with siblings a new grammar pair', () {
    final a = word('te-1', 'ammaki', 'to mother', base: 'te-amma');
    final cards = <Card>[a, loc, sentence];
    final queue = SessionQueue.build(
      cards: cards,
      stateOf: (card, mode) => null,
      hasVoice: (card) => false,
      now: DateTime(2026, 10, 23),
      newCardLimit: 10,
      modes: {DrillMode.grammar},
      siblingsOf: (card) => formSiblings(card, cards),
    );
    expect(queue.items.map((i) => '${i.card.id}:${i.mode.name}').toSet(), {
      'te-1:grammar',
      'te-2:grammar',
    });
  });
}

void lessonSiblingTests() {
  final amma = word('te-1', 'ammaki', 'to mother', base: 'te-amma');
  final loc = word('te-2', 'ammalō', 'in mother', base: 'te-amma');
  // Four letters: an easy card (eight, as in 'pustakam', is medium).
  final alone = word('te-5', 'puvvu', 'flower');

  test('a lesson asks a card with siblings its word, then its forms', () {
    expect(lessonQuestions(amma, siblings: [loc]), [
      (mode: DrillMode.recognition, ask: Ask.chooseMeaning),
      (mode: DrillMode.speaking, ask: Ask.own),
      (mode: DrillMode.listening, ask: Ask.hearMeaning),
      (mode: DrillMode.production, ask: Ask.chooseWord),
      (mode: DrillMode.grammarUnderstood, ask: Ask.chooseFormMeaning),
      (mode: DrillMode.grammar, ask: Ask.chooseForm),
    ]);
  });

  test('a card with no sibling is asked only its word, and none is typed', () {
    final questions = lessonQuestions(alone);
    expect(questions, [
      (mode: DrillMode.recognition, ask: Ask.chooseMeaning),
      (mode: DrillMode.speaking, ask: Ask.own),
      (mode: DrillMode.listening, ask: Ask.hearMeaning),
      (mode: DrillMode.production, ask: Ask.chooseWord),
    ]);
    expect(lessonQuestions(alone, siblings: const <Card>[]), questions);
  });

  // Pins the lesson's asks for cards without siblings, by difficulty and by
  // whether the language is typed (ADR-0024), so a change to the registry
  // that moves one fails here.
  final asked = <({String name, Card card, bool typed, List<Ask> asks})>[
    (
      name: 'easy, typed language: production is chosen',
      card: alone,
      typed: true,
      asks: [Ask.chooseMeaning, Ask.own, Ask.hearMeaning, Ask.chooseWord],
    ),
    (
      name: 'easy, untyped language',
      card: alone,
      typed: false,
      asks: [Ask.chooseMeaning, Ask.own, Ask.hearMeaning, Ask.chooseWord],
    ),
    (
      name: 'medium (two words), typed: recognition is matched',
      card: word('te-11', 'illu pustakam', 'house book'),
      typed: true,
      asks: [Ask.hearMeaning, Ask.matchPairs, Ask.chooseWord, Ask.own],
    ),
    (
      name: 'medium (long word), untyped: recognition is matched',
      card: word('te-12', 'pustakamulu', 'books'),
      typed: false,
      asks: [Ask.hearMeaning, Ask.matchPairs, Ask.chooseWord, Ask.own],
    ),
    (
      name: 'hard (three words), typed: rearranged',
      card: word('te-9', 'amma illu pustakam', 'mother house book'),
      typed: true,
      asks: [Ask.rearrange, Ask.own, Ask.hearMeaning, Ask.chooseMeaning],
    ),
    (
      name: 'hard (three words), untyped: still rearranged',
      card: word('te-9', 'amma illu pustakam', 'mother house book'),
      typed: false,
      asks: [Ask.rearrange, Ask.own, Ask.hearMeaning, Ask.chooseMeaning],
    ),
    (
      name: 'hard (one-word phrase), typed: the answer is typed',
      card: const Card(
        id: 'te-10',
        deckId: 'te-en-words',
        target: 'namaste',
        native: 'hello',
        pos: 'phrase',
      ),
      typed: true,
      asks: [Ask.own, Ask.own, Ask.hearMeaning, Ask.chooseMeaning],
    ),
    (
      name: 'hard (one-word phrase), untyped: the word is chosen',
      card: const Card(
        id: 'te-10',
        deckId: 'te-en-words',
        target: 'namaste',
        native: 'hello',
        pos: 'phrase',
      ),
      typed: false,
      asks: [Ask.chooseWord, Ask.own, Ask.hearMeaning, Ask.chooseMeaning],
    ),
  ];
  for (final row in asked) {
    test('a lesson asks a card without siblings: ${row.name}', () {
      final questions = lessonQuestions(row.card, typed: row.typed);
      expect(questions.map((q) => q.ask), row.asks);
      // Only the word's own four skills: no grammar without siblings.
      expect(questions.map((q) => q.mode).toSet(), {
        DrillMode.recognition,
        DrillMode.speaking,
        DrillMode.listening,
        DrillMode.production,
      });
    });
  }

  test('a lesson reaches the forms of a card whose word skills are off', () {
    final card = word(
      'te-1',
      'ammaki',
      'to mother',
      base: 'te-amma',
      modes: {DrillMode.recognition, DrillMode.listening, DrillMode.speaking},
    );
    final plan = lessonPlan(
      [card],
      modesOf: (c) => c.modesIn(ttsAvailable: true, siblings: [loc]),
      canChoose: (_, _) => true,
      siblingsOf: (_) => [loc],
    );
    expect(plan.map((i) => (i.mode, i.ask)), [
      (DrillMode.production, Ask.teach),
      (DrillMode.production, Ask.chooseWord),
      (DrillMode.grammarUnderstood, Ask.chooseFormMeaning),
    ]);
  });

  test('a hard card is typed only in a typed language', () {
    final phrase = word('te-9', 'amma illu pustakam', 'mother house book');
    expect(lessonQuestions(phrase, typed: false).first, (
      mode: DrillMode.production,
      ask: Ask.rearrange,
    ));
    final one = const Card(
      id: 'te-10',
      deckId: 'te-en-words',
      target: 'namaste',
      native: 'hello',
      pos: 'phrase',
    );
    expect(lessonQuestions(one).first.ask, Ask.own);
    expect(lessonQuestions(one, typed: false).first.ask, Ask.chooseWord);
  });
}
