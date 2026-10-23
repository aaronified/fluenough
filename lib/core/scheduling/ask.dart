import '../models/card.dart';
import '../models/drill_mode.dart';
import 'question_type.dart';
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
  /// among the meanings of the same word's other forms (DECK-FORMAT.md, Rules
  /// decks): "with mother" for అమ్మతో (ammatō), beside "to mother" and "in
  /// mother". The question of grammar understood.
  chooseFormMeaning,

  /// Shown a rules table's word and the meaning to express, choose its form
  /// among the same word's forms (DECK-FORMAT.md, Rules decks). Grammar
  /// produced, while the pair is new or was last missed; it is typed once
  /// remembered.
  chooseForm,

  /// Shown the word, its reading and meaning, and played aloud: a lesson
  /// teaching it, before its first question. Records nothing.
  teach,

  /// Shown a set card, or one part of it: a closed group's members
  /// together, before they are drilled (DECK-FORMAT.md, Set cards). Its
  /// item's [SessionItem.setPart] says which. Records nothing.
  showSet;

  /// Whether it only shows something and records nothing: a word taught,
  /// or a set shown.
  bool get onlyShows => this == teach || this == showSet;

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
  /// their meanings, rather than other words (DECK-FORMAT.md, Rules decks).
  bool get choosesAmongForms => this == chooseFormMeaning || this == chooseForm;

  /// What [card] shows as an option of this kind of question: its meaning
  /// for [chooseMeaning], [hearMeaning] and [chooseFormMeaning], else its
  /// target.
  String optionOf(Card card) => choosesMeaning ? card.native : card.target;

  /// The grade a right answer to this kind of question records in [mode]
  /// (ADR-0034, DECK-FORMAT.md, Rules decks): Good (4) for a meaning seen and
  /// chosen, in Recognition or of a rule's form, since choosing what a seen
  /// form means is how understanding is asked; Hard (3) for any other choice,
  /// which counts for less than a right recall.
  int rightChoiceGrade(DrillMode mode) =>
      mode == DrillMode.recognition || this == chooseFormMeaning ? 4 : 3;
}

/// The cards a [ask] question about the rules table's cell [card] offers
/// besides it (DECK-FORMAT.md, Rules decks), from [cells], its deck's cards:
/// the cells of its own row, the same word, that its expansion lists as
/// options, each showing something different from [card] and from the others.
/// Never another word's form, nor a form of a rule its layer leaves out, since
/// such a cell is not among the options. For a card that is not a rules
/// table's cell, its [formSiblings]. Empty for another kind of question.
List<Card> formChoices(Card card, Ask ask, Iterable<Card> cells) {
  if (!ask.choosesAmongForms) return const <Card>[];
  final rule = card.rule;
  if (rule == null) {
    final shown = <String>{ask.optionOf(card)};
    return <Card>[
      for (final other in formSiblings(card, cells))
        if (shown.add(ask.optionOf(other))) other,
    ];
  }
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

/// The other forms of [card]'s word that its `bases` name (#522, step 4;
/// owner, 2026-10-23, "Sibling cards", narrowed the same day to "Same single
/// base"): the cards of [cards], other than [card] itself, that are siblings
/// of it, and whose target differs from [card]'s. Two cards are siblings only
/// when each has exactly one base and that base is the same card, so a
/// sentence of several words that shares one of them is no sibling. Empty for
/// a rules table's cell, which has its row, and for a card with no sibling.
List<Card> formSiblings(Card card, Iterable<Card> cards) =>
    FormSiblings(cards).of(card);

/// [formSiblings] for many cards of the same [cards], with the cards grouped
/// by their single base once.
class FormSiblings {
  FormSiblings(Iterable<Card> cards) {
    for (final card in cards) {
      if (card.rule == null && _singleBaseRef(card) case final ref?) {
        (_byBase[ref] ??= <Card>[]).add(card);
      }
    }
  }

  final Map<String, List<Card>> _byBase = <String, List<Card>>{};

  /// The siblings of [card]: see [formSiblings].
  List<Card> of(Card card) {
    final ref = card.rule == null ? _singleBaseRef(card) : null;
    if (ref == null) return const <Card>[];
    return <Card>[
      for (final other in _byBase[ref] ?? const <Card>[])
        if (other.id != card.id && other.target != card.target) other,
    ];
  }
}

/// The card [card]'s only base refs, or null when it has none or several.
String? _singleBaseRef(Card card) =>
    card.bases.length == 1 ? card.bases.single.ref : null;

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
///   ([Ask.chooseFormMeaning], DECK-FORMAT.md, Rules decks).
/// - **Grammar produced**, on a rules table's cell whose row has another
///   form, is chosen among the forms ([Ask.chooseForm]) while the pair is
///   new or was last missed, and typed once it was last remembered, as Hear
///   is, a new pair starting typed where [recallsFirst] says so. A pattern
///   deck's grammar cell is typed, as before.
///
/// - **Production** of a card whose language is not typed ([typed] says
///   false, as for the IPA, DECK-FORMAT.md, `typed`) is chosen: the word
///   among others ([Ask.chooseWord]), where [canChoose] finds enough to
///   choose from.
///
/// Which type asks an item is the registry's to say ([questionTypes]).
/// Reading questions and every other mode are asked their own way.
List<SessionItem> reviewAsks(
  List<SessionItem> items, {
  required bool Function(SessionItem item) canChoose,
  bool Function(SessionItem item)? hearsForm,
  bool Function(SessionItem item)? recallsFirst,
  bool Function(SessionItem item)? typed,
  List<Card> Function(Card card)? siblingsOf,
}) {
  final context = QuestionContext(
    canChoose: canChoose,
    hearsForm: hearsForm,
    recallsFirst: recallsFirst,
    typed: typed,
    siblingsOf: siblingsOf,
  );
  final recognised = <int>[
    for (final (i, item) in items.indexed)
      if (item.mode == DrillMode.recognition &&
          chooseMeaningType.eligible(item, context))
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
    if (item.mode == DrillMode.recognition) continue;
    final type = questionTypeFor(item, context);
    if (type != null) asked[i] = item.askedAs(type.ask);
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
