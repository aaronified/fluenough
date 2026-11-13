/// The level model (wiki/Plan-Deck-Kinds-And-Topics.md, D2): the level of a
/// path unit and the level a learner has reached in a language, from the
/// units of the language's path. The levels themselves and the gate every
/// levelled item passes are in `lib/core/models/level.dart`, exported here.
/// Pure functions over data; free of Flutter, so that it is tested in
/// milliseconds.
library;

import '../data/course_path.dart' show Milestone, PlanUnit;
import '../models/level.dart';

export '../models/level.dart';

/// The level a path's [milestone] marks.
Level levelOfMilestone(Milestone milestone) => switch (milestone) {
  Milestone.a1 => Level.a1,
  Milestone.a2 => Level.a2,
  Milestone.b1 => Level.b1,
};

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
    last = levelOfMilestone(milestone);
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
