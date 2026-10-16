import '../models/card.dart';
import '../models/card_set.dart';

/// One card of a set shown in a lesson (DECK-FORMAT.md, Set cards; #515):
/// a part of at most [setPartSize] of its members, the whole set when it
/// fits on one card.
class SetPart {
  const SetPart({
    required this.set,
    required this.index,
    required this.count,
    required this.members,
    required this.newIds,
    required this.knownIds,
    required this.lessonNew,
    this.next,
  });

  final ResolvedSet set;

  /// Which part this is, from 0, and how many the set has.
  final int index;
  final int count;

  /// The members this part shows, in the set's order.
  final List<Card> members;

  /// The ids of the members the lesson teaches, and drills.
  final Set<String> newIds;

  /// The ids of the members the learner was taught before: marked Known.
  /// Every other member is marked New.
  final Set<String> knownIds;

  /// Every new member of the lesson's sets, in the order they are asked.
  final List<Card> lessonNew;

  /// The set shown straight after this one, on this set's last part; null
  /// on any other part, and after the lesson's last set.
  final ResolvedSet? next;

  bool get isLast => index == count - 1;

  bool get isSplit => count > 1;

  /// Whether [card] is marked Known rather than New.
  bool isKnown(Card card) => knownIds.contains(card.id);

  @override
  String toString() => 'SetPart(${set.set.id} ${index + 1}/$count)';
}

/// The sets a lesson shows and the cards it then teaches (owner,
/// 2026-10-13 and 2026-10-16, #515).
typedef LessonSets = ({
  /// The cards to teach, [picked] with every new member of each set shown,
  /// each card once, in the order it first appears.
  List<Card> cards,

  /// The set parts to show before them, every part of each set in turn.
  List<SetPart> parts,

  /// The ids of the members the sets teach.
  Set<String> members,
});

/// What [picked], a lesson's new cards as `lessonItems` chose them, becomes
/// with [sets], the course's sets, each with its members resolved:
///
/// - A set is shown when one of [picked] is a member and it has a new
///   member; a set with none is not shown, as there is nothing new in it.
/// - **All of its new members are taught in that lesson** ("The cap is for
///   per card, not set. Set can have whatever. And it will be taught
///   together."): a member [isNew] is added where the first member picked
///   is, in the set's order. The lesson's cap holds only outside sets.
/// - Its known members are shown, marked, and not drilled.
/// - **Both sets, then drills**: every set's parts come first, each set of
///   one word across its forms (or of words by ref) before every set of one
///   slot across words, even when a slot's set has a member picked earlier;
///   within each kind, in the order their first member was picked. Each set
///   is divided by [setParts]; a part whose members are all known is still
///   shown.
///
/// [isNew] says whether a member can be taught now: not taught yet, and
/// drillable; [isKnown] whether it was taught before, which marks it Known.
LessonSets lessonSets(
  List<Card> picked, {
  required List<ResolvedSet> sets,
  required bool Function(Card card) isNew,
  required bool Function(Card card) isKnown,
}) {
  final place = <String, int>{
    for (final (i, card) in picked.indexed) card.id: i,
  };
  final shown = <(int, int, int, ResolvedSet)>[];
  for (final (order, set) in sets.indexed) {
    final first = <int>[for (final member in set.members) ?place[member.id]];
    if (first.isEmpty || !set.members.any(isNew)) continue;
    final bySlot = set.set.rule?.fixesRow == false ? 1 : 0;
    shown.add((first.reduce((a, b) => a < b ? a : b), bySlot, order, set));
  }
  shown.sort((a, b) {
    for (final (x, y) in <(int, int)>[
      (a.$2, b.$2),
      (a.$1, b.$1),
      (a.$3, b.$3),
    ]) {
      if (x != y) return x.compareTo(y);
    }
    return 0;
  });
  final ordered = <ResolvedSet>[for (final s in shown) s.$4];

  final cards = <Card>[];
  final ids = <String>{};
  final members = <String>{};
  final expanded = <ResolvedSet>{};
  void add(Card card) {
    if (ids.add(card.id)) cards.add(card);
  }

  for (final card in picked) {
    for (final set in ordered) {
      if (expanded.contains(set) || !set.has(card)) continue;
      expanded.add(set);
      for (final member in set.members) {
        if (!isNew(member)) continue;
        members.add(member.id);
        add(member);
      }
    }
    add(card);
  }

  final lessonNew = <Card>[
    for (final card in cards)
      if (members.contains(card.id)) card,
  ];
  final known = <String>{
    for (final set in ordered)
      for (final member in set.members)
        if (isKnown(member)) member.id,
  };
  final parts = <SetPart>[];
  for (final (i, set) in ordered.indexed) {
    final split = setParts(set.members);
    for (final (j, part) in split.indexed) {
      parts.add(
        SetPart(
          set: set,
          index: j,
          count: split.length,
          members: part,
          newIds: members,
          knownIds: known,
          lessonNew: lessonNew,
          next: j == split.length - 1 && i + 1 < ordered.length
              ? ordered[i + 1]
              : null,
        ),
      );
    }
  }
  return (cards: cards, parts: parts, members: members);
}
