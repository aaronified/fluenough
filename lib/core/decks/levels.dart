/// The level model (wiki/Plan-Deck-Kinds-And-Topics.md, D2): the levels a deck
/// or a card may carry, the level a learner has reached in a language, and the
/// one gate every levelled item passes before it reaches the learner. Pure
/// functions over data; free of Flutter, so that it is tested in milliseconds.
library;

import '../data/course_path.dart' show Milestone, PlanUnit;

/// A CEFR-style level, in order: `A1 < A2 < B1 < B2 < C1 < C2`. The paths
/// reach B1, so a learner's level tops out at B1 today; B2 and above are valid
/// data that nobody sees until a path grows.
enum Level {
  a1,
  a2,
  b1,
  b2,
  c1,
  c2;

  /// `A1`, `B2`: how a deck writes it and a learner reads it.
  String get label => name.toUpperCase();

  /// Whether this level is [other] or above it.
  bool isAtLeast(Level other) => index >= other.index;

  /// [value] as a level, or null when it is not one: `A1` to `C2`, in capitals
  /// as the decks write them. Anything else, including a number, is no level,
  /// so that a deck with a bad value is read as one without a level rather
  /// than refused (the validator is what refuses it).
  static Level? tryParse(Object? value) {
    if (value is! String) return null;
    for (final level in Level.values) {
      if (level.label == value) return level;
    }
    return null;
  }

  /// The level a path's milestone marks.
  static Level ofMilestone(Milestone milestone) => switch (milestone) {
    Milestone.a1 => Level.a1,
    Milestone.a2 => Level.a2,
    Milestone.b1 => Level.b1,
  };
}

/// The level of the unit at [index] of [plan]: the first milestone at or after
/// it, and the last milestone's level for a unit after the final one (after the
/// B1 mark, B1). Null where the path has no milestone at all, as a notation
/// course has none, or [index] is not a unit.
Level? levelOfUnit(List<PlanUnit> plan, int index) {
  if (index < 0 || index >= plan.length) return null;
  Level? last;
  for (final (i, unit) in plan.indexed) {
    final milestone = unit.milestone;
    if (milestone == null) continue;
    last = Level.ofMilestone(milestone);
    if (i >= index) return last;
  }
  return last;
}

/// The learner's level in a language: the level of its furthest unit
/// ([furthestUnit], an index of [plan]), null where the path has no levels.
Level? learnerLevel(List<PlanUnit> plan, int furthestUnit) =>
    levelOfUnit(plan, furthestUnit);

/// For each card id, the index of the first unit of [plan] whose cores hold it:
/// [cardsOfCore] gives each core's card ids. A card counts for the first unit
/// that holds it, so that a word a later deck shares with an earlier one does
/// not make the later unit reached. A core [cardsOfCore] does not know holds
/// nothing.
Map<String, int> firstUnitOfCards(
  List<PlanUnit> plan,
  Map<String, Iterable<String>> cardsOfCore,
) {
  final first = <String, int>{};
  for (final (i, unit) in plan.indexed) {
    for (final core in unit.decks) {
      for (final id in cardsOfCore[core] ?? const <String>[]) {
        first.putIfAbsent(id, () => i);
      }
    }
  }
  return first;
}

/// The index of the furthest unit of [plan] the learner has reached: the unit
/// of a card they have studied ([studied], the ids of cards with a review or a
/// schedule; [firstUnit] from [firstUnitOfCards]), or the unit after one whose
/// decks are all placed ([placed], core ids; placement passed it whole), never
/// past the last unit; 0 for a learner who has begun nothing. A planned unit
/// (no decks) is never reached on its own, only passed over.
int furthestUnit(
  List<PlanUnit> plan, {
  required Map<String, int> firstUnit,
  required Iterable<String> studied,
  required Set<String> placed,
}) {
  var furthest = 0;
  for (final id in studied) {
    final unit = firstUnit[id];
    if (unit != null && unit > furthest) furthest = unit;
  }
  for (final (i, unit) in plan.indexed) {
    if (unit.decks.isEmpty || !unit.decks.every(placed.contains)) continue;
    final next = i + 1 < plan.length ? i + 1 : i;
    if (next > furthest) furthest = next;
  }
  return furthest;
}

/// The one gate a levelled item passes (D2): an item above the learner's level
/// is never drilled, never shown as content and never put in a result with its
/// text. Every place a levelled item reaches the learner calls it.
abstract final class LevelGate {
  /// Whether an item of level [item] may reach a learner at [learner]. An item
  /// with no level is open to everyone, and so are those of a learner at or
  /// above it. A language with no levels ([learner] null) offers no levelled
  /// item at all.
  static bool allows(Level? item, Level? learner) {
    if (item == null) return true;
    if (learner == null) return false;
    return learner.isAtLeast(item);
  }

  /// Whether [item] is above [learner]: the opposite of [allows], for the
  /// places that list such an item marked with its level (search).
  static bool isAbove(Level? item, Level? learner) => !allows(item, learner);

  /// The items of [items] a learner at [learner] may be given, in order.
  static List<T> filter<T>(
    Iterable<T> items,
    Level? learner,
    Level? Function(T item) levelOf,
  ) => <T>[
    for (final item in items)
      if (allows(levelOf(item), learner)) item,
  ];
}
