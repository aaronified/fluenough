// The grammar question types are eligible by the card's data: whether the
// card's word has other forms (ADR-0039, #522 step 4).
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/rule.dart';
import 'package:fluenough/core/scheduling/ask.dart';
import 'package:fluenough/core/scheduling/lesson.dart';
import 'package:fluenough/core/scheduling/question_type.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:flutter_test/flutter_test.dart';

Card cell({List<RuleOption> options = const <RuleOption>[]}) => Card(
  id: 'te-cell',
  deckId: 'te-en-grammar',
  target: 'ammalō',
  native: 'in mother',
  modes: const <DrillMode>{DrillMode.grammarUnderstood, DrillMode.grammar},
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

Card word(String id, String target, String native, {String? base}) => Card(
  id: id,
  deckId: 'te-en-words',
  target: target,
  native: native,
  modes: const <DrillMode>{DrillMode.grammar},
  bases: <CardBase>[if (base != null) CardBase(word: target, ref: base)],
);

void siblingTests() {
  final amma = word('te-1', 'ammaki', 'to mother', base: 'te-amma');
  final loc = word('te-2', 'ammalō', 'in mother', base: 'te-amma');
  final same = word('te-3', 'ammaki', 'for mother', base: 'te-amma');
  final other = word('te-4', 'illu', 'house', base: 'te-illu');
  final alone = word('te-5', 'pustakam', 'book');
  final all = <Card>[amma, loc, same, other, alone];
  List<Card> siblingsOf(Card c) => formSiblings(c, all);
  final withSiblings = QuestionContext(canChoose: _yes, siblingsOf: siblingsOf);

  test(
    'siblings are the other cards with a different form of the same base',
    () {
      expect(siblingsOf(amma), [loc]);
      expect(siblingsOf(loc), [amma, same]);
      expect(siblingsOf(other), isEmpty);
      expect(siblingsOf(alone), isEmpty);
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
