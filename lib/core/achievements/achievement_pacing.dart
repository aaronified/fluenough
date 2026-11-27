/// The pacing rule (#322, decision 9; "Pacing rule" of the approved
/// achievements mockup): where on a language's path each achievement sits, so
/// that unlocks arrive about evenly through the course. A plain,
/// deterministic function of the path's size and marks and of the sets it
/// chooses; no screen shows the timeline.
///
/// Positions are unit numbers: the first unit is 1 and the B1 mark is the
/// last of the plan.
///
/// 1. **Target gap.** One unlock about every 3.5% of the B1 plan, never
///    closer than [kPacingMinGap] units, never farther apart than about 7%
///    ([kPacingMaxGapShare]).
/// 2. **Fixed anchors first.** The levels sit on their marks and are never
///    moved. The other anchors (word counts, Start and Master of each skill)
///    sit at the unit their rule names; if one is closer than the minimum to
///    a placed badge it moves to the nearest free unit, later first.
/// 3. **Sets fill the rest.** Each tenth of the course holds at most
///    [kPacingTenthCapacity] unlocks. A set's natural position is its last
///    unit plus a review lag; if that tenth is full it slides to the nearest
///    tenth with room, later first. Word sets are placed before grammar
///    tables. Sets stop when the course holds its target count; a path that
///    cannot hold all its sets picks fewer, spread along the path.
library;

import 'dart:math' as math;

/// Units between two unlocks, at the least.
const int kPacingMinGap = 2;

/// The target share of the plan between two unlocks.
const double kPacingGapShare = 0.035;

/// The gap a short path aims for: the minimum is a floor, but a path shorter
/// than 74 units would otherwise want a badge every 2 units.
const double kPacingShortGap = 2.6;

/// The farthest apart two unlocks should be, as a share of the plan.
const double kPacingMaxGapShare = 0.07;

/// Unlocks one tenth of the course may hold.
const int kPacingTenthCapacity = 3;

/// How a [PaceItem] is placed.
enum PaceMode {
  /// At its position, never moved: a level on its mark.
  fixed,

  /// Near its position, moved only to keep the minimum gap.
  anchored,

  /// A set: placed by the tenth rule, and dropped when the course is full.
  sliding,
}

/// One badge to place.
class PaceItem {
  const PaceItem(this.id, this.natural, this.mode);

  final String id;

  /// The unit its rule names.
  final int natural;
  final PaceMode mode;
}

/// Rounds half up.
int roundHalfUp(double x) => (x + 0.5).floor();

/// The units between a level's mark and the badge for the skill whose bar
/// ends there: 3.5% of the plan, at least [kPacingMinGap].
int pacingLag(int units) {
  final share = roundHalfUp(kPacingGapShare * units);
  return math.max(kPacingMinGap, share);
}

/// How many unlocks the course holds at most: its plan over the target gap,
/// and one more, so that a plan of about 3.5% gaps keeps every chosen set.
int pacingTarget(int units) {
  final gap = math.max(kPacingShortGap, kPacingGapShare * units);
  return (units / gap).ceil() + 1;
}

/// The tenth of the course unit [position] falls in, 0 to 9.
int pacingTenth(int position, int units) =>
    math.min(9, (position - 1) * 10 ~/ units);

/// The ids of [count] of [sets], spread evenly along the path by their
/// natural unit, for a course that cannot hold them all.
Set<String> _spread(List<PaceItem> sets, int count) {
  final byUnit = List<PaceItem>.of(sets)
    ..sort((a, b) {
      final order = a.natural.compareTo(b.natural);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
  return <String>{
    for (var i = 0; i < count; i++)
      byUnit[(2 * i + 1) * byUnit.length ~/ (2 * count)].id,
  };
}

/// Places [items], in priority order, on a plan of [units] units. Returns the
/// position of each item that has one; a set that finds no room is left out.
Map<String, int> placeOnPath(int units, List<PaceItem> items) {
  final placed = <String, int>{};
  bool free(int c) {
    return placed.values.every((p) => (c - p).abs() >= kPacingMinGap);
  }

  for (final item in items) {
    if (item.mode == PaceMode.fixed) {
      placed[item.id] = item.natural;
    }
  }
  for (final item in items) {
    if (item.mode != PaceMode.anchored) continue;
    for (var d = 0; d <= units; d++) {
      final tries = d == 0
          ? <int>[item.natural]
          : <int>[item.natural + d, item.natural - d];
      final found = tries.where((c) => c >= 1 && c <= units && free(c));
      if (found.isNotEmpty) {
        placed[item.id] = found.first;
        break;
      }
    }
  }

  final tally = List<int>.filled(10, 0);
  for (final p in placed.values) {
    tally[pacingTenth(p, units)]++;
  }
  final target = pacingTarget(units);
  final sets = <PaceItem>[
    for (final item in items)
      if (item.mode == PaceMode.sliding) item,
  ];
  final budget = math.max(0, target - placed.length);
  final keep = sets.length > budget ? _spread(sets, budget) : null;
  for (final item in sets) {
    if (keep != null && !keep.contains(item.id)) continue;
    if (placed.length >= target) break;
    final natural = math.min(math.max(item.natural, 1), units);
    final home = pacingTenth(natural, units);
    final order = <int>[home];
    for (var d = 1; d < 10; d++) {
      if (home + d < 10) order.add(home + d);
      if (home - d >= 0) order.add(home - d);
    }
    for (final tenth in order) {
      if (tally[tenth] >= kPacingTenthCapacity) continue;
      int? best;
      for (var c = 1; c <= units; c++) {
        if (pacingTenth(c, units) != tenth || !free(c)) continue;
        if (best == null) {
          best = c;
          continue;
        }
        final dc = (c - natural).abs();
        final db = (best - natural).abs();
        // The nearest to its natural unit; the later one on a tie.
        if (dc <= db) best = c;
      }
      if (best == null) continue;
      placed[item.id] = best;
      tally[tenth]++;
      break;
    }
  }
  return placed;
}
