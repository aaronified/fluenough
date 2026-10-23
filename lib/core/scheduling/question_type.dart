import '../models/card.dart';
import '../models/drill_mode.dart';
import '../models/reading.dart';
import 'session_queue.dart';

/// What the app knows about an item that the registry cannot read from its
/// card alone: the wrong options available, and how the learner's deck and
/// ability bear on the question (ADR-0039).
class QuestionContext {
  const QuestionContext({
    required this.canChoose,
    this.hearsForm,
    this.recallsFirst,
    this.typed,
    this.siblingsOf,
  });

  /// Whether the item, asked as it now is, has enough to choose from.
  final bool Function(SessionItem item) canChoose;

  /// Whether what Hear plays is the form itself, as in script practice.
  final bool Function(SessionItem item)? hearsForm;

  /// Whether a new pair starts typed, the learner's ability being high.
  final bool Function(SessionItem item)? recallsFirst;

  /// Whether an answer can be typed in the card's language.
  final bool Function(SessionItem item)? typed;

  /// The other forms of a card's word named by its `bases`: the cards that
  /// are its siblings ([formSiblings]). Null where none are known.
  final List<Card> Function(Card card)? siblingsOf;
}

/// One way of asking (ADR-0039): the [ask] it produces, the skill it asks
/// ([skill], a [DrillMode]), and when it can be asked, [eligible], read from
/// the item's card and the [QuestionContext]. Types are tried in the order of
/// [questionTypes]; the first eligible one for the item's skill is asked.
/// What no type claims is asked its own way ([Ask.own]): typed production
/// and listening, speaking, rated recognition.
class QuestionType {
  const QuestionType({
    required this.ask,
    required this.skill,
    required this.eligible,
    this.groupSize = 1,
  });

  final Ask ask;
  final DrillMode skill;

  /// How many items one question takes: more than one for match pairs.
  final int groupSize;

  /// Whether [item] can be asked as this type.
  final bool Function(SessionItem item, QuestionContext context) eligible;
}

bool _isNew(SessionItem item) => (item.state?.repetitions ?? 0) == 0;

bool _startsTyped(SessionItem item, QuestionContext context) =>
    item.state == null && (context.recallsFirst?.call(item) ?? false);

/// Shown the target, choose its meaning. Recognition, and the types of the
/// same skill that group several items ([matchPairsType]) start from it.
final QuestionType chooseMeaningType = QuestionType(
  ask: Ask.chooseMeaning,
  skill: DrillMode.recognition,
  eligible: (item, context) =>
      item.card is! QuestionCard && context.canChoose(item),
);

/// Match the targets of [matchSize] items with their meanings. Recognition.
/// Whether a group can be matched is the engine's to check: no two of its
/// cards may share a meaning or a target.
final QuestionType matchPairsType = QuestionType(
  ask: Ask.matchPairs,
  skill: DrillMode.recognition,
  groupSize: matchSize,
  eligible: chooseMeaningType.eligible,
);

/// Put the target's words in order. Production of a card that rearranges.
final QuestionType rearrangeType = QuestionType(
  ask: Ask.rearrange,
  skill: DrillMode.production,
  eligible: (item, context) => item.card.rearranges,
);

/// Shown the meaning, choose the word, where the language is not typed.
final QuestionType chooseWordType = QuestionType(
  ask: Ask.chooseWord,
  skill: DrillMode.production,
  eligible: (item, context) =>
      item.card is! QuestionCard &&
      !(context.typed?.call(item) ?? true) &&
      context.canChoose(item.askedAs(Ask.chooseWord)),
);

/// Hear the target, choose its meaning, while the pair is new or was last
/// missed (ADR-0034). Where what is heard is the form, it is typed.
final QuestionType hearMeaningType = QuestionType(
  ask: Ask.hearMeaning,
  skill: DrillMode.listening,
  eligible: (item, context) =>
      item.card is! QuestionCard &&
      !(context.hearsForm?.call(item) ?? false) &&
      _isNew(item) &&
      !_startsTyped(item, context) &&
      context.canChoose(item.askedAs(Ask.hearMeaning)),
);

List<Card> _siblings(SessionItem item, QuestionContext context) =>
    context.siblingsOf?.call(item.card) ?? const <Card>[];

/// Shown a form, choose what it means (DECK-FORMAT.md, Rules decks). Eligible
/// where another form of the card's word means something else: a rules
/// table's other cells ([Card.choosesMeaning]), or a sibling sharing its base.
final QuestionType chooseFormMeaningType = QuestionType(
  ask: Ask.chooseFormMeaning,
  skill: DrillMode.grammarUnderstood,
  eligible: (item, context) =>
      item.card.choosesMeaning ||
      _siblings(item, context).any((s) => s.native != item.card.native),
);

/// Shown a rules table's word and a meaning, choose its form, while the pair
/// is new or was last missed.
final QuestionType chooseFormType = QuestionType(
  ask: Ask.chooseForm,
  skill: DrillMode.grammar,
  eligible: (item, context) =>
      (item.card.hasOtherForms || _siblings(item, context).isNotEmpty) &&
      _isNew(item) &&
      !_startsTyped(item, context) &&
      context.canChoose(item.askedAs(Ask.chooseForm)),
);

/// Every type, in the order they are tried within a skill. Nothing else
/// chooses how an item is asked. Reading questions are never returned: they
/// are exam items, not review (ADR-0039).
final List<QuestionType> questionTypes = <QuestionType>[
  chooseMeaningType,
  matchPairsType,
  rearrangeType,
  chooseWordType,
  hearMeaningType,
  chooseFormMeaningType,
  chooseFormType,
];

/// The questions a lesson asks a card of the grammar skills, in the order
/// the skills are learnt: understood, then produced (ADR-0024). Each skill is
/// asked as its first eligible type, as a new pair; a skill with no eligible
/// type is typed ([Ask.own]), except grammar understood, which is left out.
List<({DrillMode mode, Ask ask})> grammarLessonQuestions(Card card) {
  const context = QuestionContext(canChoose: _always);
  return <({DrillMode mode, Ask ask})>[
    for (final skill in const [DrillMode.grammarUnderstood, DrillMode.grammar])
      if (_lessonTypeFor(card, skill, context) case final type?)
        (mode: skill, ask: type.ask)
      else if (skill == DrillMode.grammar)
        (mode: skill, ask: Ask.own),
  ];
}

bool _always(SessionItem item) => true;

QuestionType? _lessonTypeFor(
  Card card,
  DrillMode skill,
  QuestionContext context,
) {
  final item = SessionItem(card: card, mode: skill, state: null);
  for (final type in questionTypes) {
    if (type.groupSize == 1 &&
        type.skill == skill &&
        type.eligible(item, context)) {
      return type;
    }
  }
  return null;
}

/// The type [item] is asked as, or null where it is asked its own way. Types
/// that group items ([QuestionType.groupSize] above one) are skipped: the
/// engine forms the groups.
QuestionType? questionTypeFor(SessionItem item, QuestionContext context) {
  for (final type in questionTypes) {
    if (type.groupSize == 1 &&
        type.skill == item.mode &&
        type.eligible(item, context)) {
      return type;
    }
  }
  return null;
}
