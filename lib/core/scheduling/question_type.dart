import '../models/drill_mode.dart';
import '../models/reading.dart';
import 'ask.dart';
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
  });

  /// Whether the item, asked as it now is, has enough to choose from.
  final bool Function(SessionItem item) canChoose;

  /// Whether what Hear plays is the form itself, as in script practice.
  final bool Function(SessionItem item)? hearsForm;

  /// Whether a new pair starts typed, the learner's ability being high.
  final bool Function(SessionItem item)? recallsFirst;

  /// Whether an answer can be typed in the card's language.
  final bool Function(SessionItem item)? typed;
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
/// same skill that group several items ([matchPairs]) start from it.
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

/// Shown a rules table's form, choose what it means (DECK-FORMAT.md, Rules
/// decks). Always chosen.
final QuestionType chooseFormMeaningType = QuestionType(
  ask: Ask.chooseFormMeaning,
  skill: DrillMode.grammarUnderstood,
  eligible: (item, context) => true,
);

/// Shown a rules table's word and a meaning, choose its form, while the pair
/// is new or was last missed.
final QuestionType chooseFormType = QuestionType(
  ask: Ask.chooseForm,
  skill: DrillMode.grammar,
  eligible: (item, context) =>
      item.card.choosesForm &&
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
