/// Set cards (DECK-FORMAT.md, Set cards; #506, #515): a closed group, such
/// as the three words for "you" or one verb's forms for every person, shown
/// together in a lesson before its members are drilled.
///
/// A set card is taught only: shown once, in its lesson, before its
/// members; never scheduled, asked or logged. Its members are ordinary
/// cards, asked as they are.
library;

import 'card.dart';

/// What a rules table's set fixes (owner, 2026-10-16: "Rule + axis"): a
/// rule, or a whole rules core, and one value of its table. Its members are
/// the table's cells with that value: one verb across the persons
/// (`{ rule: "te-grammar-verb-present", verb: "తాగు" }`), or one person
/// across the verbs (`{ rule: ..., person: "atanu" }`).
class SetRule {
  const SetRule({required this.rule, required this.axis, required this.value});

  /// A rule id, `te-rule-present-third`, or a rules core's id,
  /// `te-grammar-verb-present`, for every rule of its table.
  final String rule;

  /// The key the set fixes: a part of speech of the table's rows, `verb`,
  /// fixing a row; any other key, `person`, fixing a slot.
  final String axis;

  /// A row's word, as its card writes it or by its id, or a slot key.
  final String value;

  /// Whether it fixes a row, one word across the slots, rather than a slot,
  /// one slot across the words: its [axis] is a part of speech.
  bool get fixesRow => rowAxes.contains(axis);
}

/// One set card, as a layer teaches it.
class CardSet {
  const CardSet({
    required this.id,
    required this.deckId,
    required this.name,
    required this.explanation,
    this.members = const <String>[],
    this.rule,
  });

  /// A card id of the language, permanent like every card id.
  final String id;

  /// The deck the set card is written in.
  final String deckId;

  /// The set's name in the learner's language, its layer's `native`: what
  /// the Full list's sheet is titled.
  final String name;

  /// What the set card says about the group, in the learner's language.
  final String explanation;

  /// Its members by card id, in the deck's order; empty for a rules set.
  final List<String> members;

  /// What a rules table's set fixes; null for a set by refs.
  final SetRule? rule;

  @override
  String toString() => 'CardSet($id)';
}

/// The most members one set card shows (owner, 2026-10-16: "do not have
/// more than 3-4 things in one card").
const int setPartSize = 4;

/// [members] divided into the fewest parts of at most [most], as even as
/// they can be, in order (owner, 2026-10-16): 9 as 3 + 3 + 3, since two
/// parts would hold five; 8 as 4 + 4; 6 as 3 + 3; 5 as 3 + 2. A set of
/// [most] or fewer is one part.
List<List<T>> setParts<T>(List<T> members, {int most = setPartSize}) {
  if (members.isEmpty) return <List<T>>[];
  final count = (members.length + most - 1) ~/ most;
  final small = members.length ~/ count;
  final larger = members.length % count;
  final parts = <List<T>>[];
  var start = 0;
  for (var p = 0; p < count; p++) {
    final size = small + (p < larger ? 1 : 0);
    parts.add(List<T>.unmodifiable(members.sublist(start, start + size)));
    start += size;
  }
  return parts;
}

/// One set with its members resolved: the cards a learner from the set's
/// native language is taught, in the set's order.
class ResolvedSet {
  const ResolvedSet({required this.set, required this.members});

  final CardSet set;
  final List<Card> members;

  /// Whether it is shown over more than one card, and so has a Full list
  /// (owner, 2026-10-16: "Split sets only").
  bool get isSplit => members.length > setPartSize;

  /// Whether [card] is one of its members.
  bool has(Card card) => members.any((member) => member.id == card.id);
}

/// The cards [set]'s members are, from [cards], every card a learner from
/// the set's native language is taught in its language: each ref's card,
/// in the set's order; or, for a rules set, each cell of its table that
/// has the fixed value, in the table's order (a row's cells in slot order,
/// a slot's cells in row order).
///
/// [ruleOf] names the rule ids of a rules core by its id, so that a set
/// naming a whole table takes every one of its rules. A member no card is
/// left out.
List<Card> setMembers(
  CardSet set,
  Iterable<Card> cards, {
  Set<String> Function(String coreId)? ruleOf,
}) {
  final rule = set.rule;
  if (rule == null) {
    final byId = <String, Card>{};
    for (final card in cards) {
      byId.putIfAbsent(card.id, () => card);
    }
    return <Card>[for (final id in set.members) ?byId[id]];
  }
  final rules = <String>{rule.rule, ...?ruleOf?.call(rule.rule)};
  final seen = <String>{};
  return <Card>[
    for (final card in cards)
      if (card.rule case final cell?
          when rules.contains(cell.ruleId) &&
              (rule.fixesRow
                  ? cell.word == rule.value || cell.wordTarget == rule.value
                  : cell.slot == rule.value) &&
              seen.add(card.id))
        card,
  ];
}

/// The parts of speech a rules table's rows may be (DECK-FORMAT.md, Rules
/// decks): a set's key that is one of them fixes a row.
const Set<String> rowAxes = <String>{
  'noun',
  'verb',
  'adj',
  'adv',
  'particle',
  'other',
  'pronoun',
};
