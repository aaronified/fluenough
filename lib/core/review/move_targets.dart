/// Where a reviewer may suggest a card belongs (#477, docs/plans/
/// reviewing-scope.md, rule 4): the units of the course's B1 plan, and
/// nothing else. Adding a theme or a unit the plan does not have needs a
/// direct change to the deck, by pull request, so it is never offered here.
library;

import '../data/course_path.dart';

/// A unit of the course's B1 plan a card can be moved to, or shown as not
/// yet possible.
class MoveTarget {
  const MoveTarget({
    required this.deckId,
    required this.unit,
    required this.name,
    this.planned = false,
  });

  /// The course's deck the card would be moved to, such as `hi-en-family`.
  /// For a [planned] unit, the core id its deck will have.
  final String deckId;

  /// The unit's number in the plan, from 1.
  final int unit;

  /// The deck's name; for a planned unit, its theme.
  final String name;

  /// Whether the unit has no deck yet. It is shown, never offered: there is
  /// no deck file to move the card into.
  final bool planned;
}

/// The units of [path], in order, a card of the deck [from] may be moved to:
/// each written unit's vocabulary decks other than [from] (and not a script
/// deck), and each planned unit marked [MoveTarget.planned]. [nameOf] gives a
/// deck's name, or null when the deck is not on the phone; [isVocab] says
/// whether a deck teaches words, the only decks a card can be moved into.
List<MoveTarget> moveTargets(
  CoursePath path, {
  required String from,
  required String? Function(String deckId) nameOf,
  required bool Function(String deckId) isVocab,
}) {
  final out = <MoveTarget>[];
  for (final (i, unit) in path.plan.indexed) {
    if (unit.isPlanned) {
      final planned = unit.planned!;
      out.add(
        MoveTarget(
          deckId: planned.id,
          unit: i + 1,
          name: planned.theme ?? planned.id,
          planned: true,
        ),
      );
      continue;
    }
    for (final deck in unit.decks) {
      final name = nameOf(deck);
      if (deck == from ||
          name == null ||
          path.alphabet.contains(deck) ||
          !isVocab(deck)) {
        continue;
      }
      out.add(MoveTarget(deckId: deck, unit: i + 1, name: name));
    }
  }
  return out;
}

/// The unit number of [path] that holds [deckId], from 1, or null.
int? unitNumberOf(CoursePath path, String deckId) {
  for (final (i, unit) in path.plan.indexed) {
    if (unit.decks.contains(deckId)) return i + 1;
  }
  return null;
}
