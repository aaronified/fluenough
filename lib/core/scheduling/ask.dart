import '../models/card.dart';
import '../models/drill_mode.dart';
import '../models/reading.dart';
import 'session_queue.dart';

/// How a session item is asked (ADR-0024). Whichever way, it records the
/// item's own mode.
enum Ask {
  /// The mode's own way: recognition rated by the learner, production,
  /// listening and grammar typed, speaking said, reading chosen.
  own,

  /// Shown the target, choose its meaning. Recognition.
  chooseMeaning,

  /// Shown the meaning, choose the target. Production.
  chooseWord,

  /// Hear the target, choose it: script practice, where what is heard is
  /// the form. Listening.
  hearAndChoose,

  /// Hear the target, choose its meaning: Hear's choose grade (ADR-0034).
  /// Listening.
  hearMeaning,

  /// Match the targets of a few items with their meanings, by dragging or
  /// tapping. Recognition, for each.
  matchPairs,

  /// Put the target's words in order. Production.
  rearrange,

  /// Shown a rules table's form with its reading, choose what it means
  /// among the meanings of the same word's other forms (spec 4.8): "with
  /// mother" for అమ్మతో (ammatō), beside "to mother" and "in mother". The
  /// question of grammar understood.
  chooseFormMeaning,

  /// Shown a rules table's word and the meaning to express, choose its form
  /// among the same word's forms (spec 4.8). Grammar produced, while the
  /// pair is new or was last missed; it is typed once remembered.
  chooseForm,

  /// Shown the word, its reading and meaning, and played aloud: a lesson
  /// teaching it, before its first question. Records nothing.
  teach;

  /// Whether the learner picks one of the options the session offers.
  bool get chooses =>
      this == chooseMeaning ||
      this == chooseWord ||
      this == hearAndChoose ||
      this == hearMeaning ||
      this == chooseFormMeaning ||
      this == chooseForm;

  /// Whether the options are meanings rather than words.
  bool get choosesMeaning =>
      this == chooseMeaning || this == hearMeaning || this == chooseFormMeaning;

  /// Whether the options are the forms of one word in a rules table, or
  /// their meanings, rather than other words (spec 4.8).
  bool get choosesAmongForms => this == chooseFormMeaning || this == chooseForm;

  /// What [card] shows as an option of this kind of question: its meaning
  /// for [chooseMeaning], [hearMeaning] and [chooseFormMeaning], else its
  /// target.
  String optionOf(Card card) => choosesMeaning ? card.native : card.target;

  /// The grade a right answer to this kind of question records in [mode]
  /// (ADR-0034, spec 4.7): Good (4) for a meaning seen and chosen, in
  /// Recognition or of a rule's form, since choosing what a seen form means
  /// is how understanding is asked; Hard (3) for any other choice, which
  /// counts for less than a right recall.
  int rightChoiceGrade(DrillMode mode) =>
      mode == DrillMode.recognition || this == chooseFormMeaning ? 4 : 3;
}

/// The cards a [ask] question about the rules table's cell [card] offers
/// besides it (spec 4.8), from [cells], its deck's cards: the cells of its
/// own row, the same word, that its expansion lists as options, each
/// showing something different from [card] and from the others. Never
/// another word's form, nor a form of a rule its layer leaves out, since
/// such a cell is not among the options. Empty for a card that is not a
/// rules table's cell, or for another kind of question.
List<Card> formChoices(Card card, Ask ask, Iterable<Card> cells) {
  final rule = card.rule;
  if (rule == null || !ask.choosesAmongForms) return const <Card>[];
  final forms = <String>{for (final option in rule.options) option.form};
  final shown = <String>{ask.optionOf(card)};
  return <Card>[
    for (final other in cells)
      if (other.id != card.id &&
          other.rule?.word == rule.word &&
          other.deckId == card.deckId &&
          forms.contains(other.target) &&
          shown.add(ask.optionOf(other)))
        other,
  ];
}

/// How many items a match pairs question matches.
const int matchSize = 4;

/// [items] as a review asks them (ADR-0024), in the same order.
///
/// - **Recognition** is chosen rather than rated: in fours, in turn, match
///   pairs and then multiple choice, a last four short of four by multiple
///   choice. Four whose meanings or targets are not all different cannot be
///   matched, and are chosen. Where [canChoose] finds too little to choose
///   from, it stays rated.
/// - **Production** of a card that [Card.rearranges] is rearranged.
/// - **Listening** is Hear (ADR-0034): its meaning is chosen while the pair
///   is new or was last missed, and typed once it was last remembered. A
///   new pair starts typed where [recallsFirst] says the learner's ability
///   in Hear is high enough. Where [hearsForm] says what is heard is the
///   form itself, as in script practice, it is typed as heard.
/// - **Grammar understood** is always chosen: the meaning of the form shown
///   ([Ask.chooseFormMeaning], spec 4.8).
/// - **Grammar produced**, on a rules table's cell whose row has another
///   form, is chosen among the forms ([Ask.chooseForm]) while the pair is
///   new or was last missed, and typed once it was last remembered, as Hear
///   is, a new pair starting typed where [recallsFirst] says so. A pattern
///   deck's grammar cell is typed, as before.
///
/// Reading questions and every other mode are asked their own way.
List<SessionItem> reviewAsks(
  List<SessionItem> items, {
  required bool Function(SessionItem item) canChoose,
  bool Function(SessionItem item)? hearsForm,
  bool Function(SessionItem item)? recallsFirst,
}) {
  final recognised = <int>[
    for (final (i, item) in items.indexed)
      if (item.mode == DrillMode.recognition &&
          item.card is! QuestionCard &&
          canChoose(item))
        i,
  ];
  // By index: the item asked another way, or null where a match took it.
  final asked = <int, SessionItem?>{};
  for (var start = 0; start < recognised.length; start += matchSize) {
    final chunk = recognised.skip(start).take(matchSize).toList();
    final group = <SessionItem>[for (final i in chunk) items[i]];
    if ((start ~/ matchSize).isEven &&
        chunk.length == matchSize &&
        _matchable(group)) {
      asked[chunk.first] = group.first.askedAs(Ask.matchPairs, group: group);
      for (final i in chunk.skip(1)) {
        asked[i] = null;
      }
    } else {
      for (final i in chunk) {
        asked[i] = items[i].askedAs(Ask.chooseMeaning);
      }
    }
  }
  for (final (i, item) in items.indexed) {
    if (item.mode == DrillMode.production && item.card.rearranges) {
      asked[i] = item.askedAs(Ask.rearrange);
    }
    if (item.mode == DrillMode.listening &&
        item.card is! QuestionCard &&
        !(hearsForm?.call(item) ?? false) &&
        (item.state?.repetitions ?? 0) == 0 &&
        !(item.state == null && (recallsFirst?.call(item) ?? false)) &&
        canChoose(item.askedAs(Ask.hearMeaning))) {
      asked[i] = item.askedAs(Ask.hearMeaning);
    }
    if (item.mode == DrillMode.grammarUnderstood) {
      asked[i] = item.askedAs(Ask.chooseFormMeaning);
    }
    if (item.mode == DrillMode.grammar &&
        item.card.choosesForm &&
        (item.state?.repetitions ?? 0) == 0 &&
        !(item.state == null && (recallsFirst?.call(item) ?? false)) &&
        canChoose(item.askedAs(Ask.chooseForm))) {
      asked[i] = item.askedAs(Ask.chooseForm);
    }
  }
  return <SessionItem>[
    for (final (i, item) in items.indexed)
      if (!asked.containsKey(i)) item else ?asked[i],
  ];
}

/// Whether [group] can be matched: no two of its cards share a meaning or
/// a target, which would make two matches right.
bool _matchable(List<SessionItem> group) {
  final natives = <String>{for (final item in group) item.card.native};
  final targets = <String>{for (final item in group) item.card.target};
  return natives.length == group.length && targets.length == group.length;
}
