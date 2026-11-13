// The level model (wiki/Plan-Deck-Kinds-And-Topics.md, D2): the order of the
// levels, the level of a path unit, the level a learner has reached, and the
// one gate every levelled item passes.

import 'package:fluenough/core/data/course_path.dart';
import 'package:fluenough/core/decks/levels.dart';
import 'package:flutter_test/flutter_test.dart';

PlanUnit _unit(List<String> decks, {Milestone? milestone}) =>
    PlanUnit(decks: decks, milestone: milestone);

/// Six units: the A1 mark on the second, the A2 mark on the fourth, the B1
/// mark on the fifth, one unit after it, and a planned one last.
List<PlanUnit> _plan() => <PlanUnit>[
  _unit(<String>['xx-a']),
  _unit(<String>['xx-b'], milestone: Milestone.a1),
  _unit(<String>['xx-c']),
  _unit(<String>['xx-d'], milestone: Milestone.a2),
  _unit(<String>['xx-e'], milestone: Milestone.b1),
  _unit(<String>['xx-f']),
  const PlanUnit(planned: PlannedDeck(id: 'xx-g')),
];

void main() {
  group('Level', () {
    test('is ordered A1 < A2 < B1 < B2 < C1 < C2', () {
      expect(Level.values.map((l) => l.label), <String>[
        'A1',
        'A2',
        'B1',
        'B2',
        'C1',
        'C2',
      ]);
      expect(Level.b1.isAtLeast(Level.a2), isTrue);
      expect(Level.a2.isAtLeast(Level.b1), isFalse);
      expect(Level.c2.isAtLeast(Level.c2), isTrue);
    });

    test('is read as the decks write it, and nothing else is a level', () {
      expect(Level.tryParse('A1'), Level.a1);
      expect(Level.tryParse('C2'), Level.c2);
      expect(Level.tryParse('a1'), isNull);
      expect(Level.tryParse('D1'), isNull);
      expect(Level.tryParse(1), isNull);
      expect(Level.tryParse(null), isNull);
    });

    test('has one for each milestone of a path', () {
      expect(levelOfMilestone(Milestone.a1), Level.a1);
      expect(levelOfMilestone(Milestone.a2), Level.a2);
      expect(levelOfMilestone(Milestone.b1), Level.b1);
    });
  });

  group('levelOfUnit', () {
    test('is the first milestone at or after the unit', () {
      final plan = _plan();
      expect(levelOfUnit(plan, 0), Level.a1);
      expect(levelOfUnit(plan, 1), Level.a1);
      expect(levelOfUnit(plan, 2), Level.a2);
      expect(levelOfUnit(plan, 3), Level.a2);
      expect(levelOfUnit(plan, 4), Level.b1);
    });

    test('is B1 for a unit after the B1 mark', () {
      final plan = _plan();
      expect(levelOfUnit(plan, 5), Level.b1);
      expect(levelOfUnit(plan, 6), Level.b1);
    });

    test('is none for a path with no milestones', () {
      final plan = <PlanUnit>[
        _unit(<String>['xx-a']),
        _unit(<String>['xx-b']),
      ];
      expect(levelOfUnit(plan, 0), isNull);
      expect(levelOfUnit(plan, 1), isNull);
    });

    test('is none for a unit the path does not have', () {
      expect(levelOfUnit(_plan(), -1), isNull);
      expect(levelOfUnit(_plan(), 7), isNull);
      expect(levelOfUnit(const <PlanUnit>[], 0), isNull);
    });
  });

  group('the unit a learner has reached', () {
    final cards = <String, List<String>>{
      'xx-a': <String>['xx-1', 'xx-2'],
      'xx-b': <String>['xx-2', 'xx-3'],
      'xx-c': <String>['xx-3', 'xx-4'],
    };

    test('counts a card for the first unit that holds it', () {
      final first = firstUnitOfCards(_plan(), cards);
      expect(first, <String, int>{'xx-1': 0, 'xx-2': 0, 'xx-3': 1, 'xx-4': 2});
    });

    test('knows nothing of a core it is not given', () {
      expect(
        firstUnitOfCards(_plan(), const <String, List<String>>{}),
        isEmpty,
      );
    });

    test('is the first unit for a learner who has begun nothing', () {
      expect(
        furthestUnit(
          _plan(),
          firstUnit: firstUnitOfCards(_plan(), cards),
          studied: const <String>[],
          placed: <String>{},
        ),
        0,
      );
    });

    test('is the unit of the furthest card studied', () {
      final first = firstUnitOfCards(_plan(), cards);
      int reached(List<String> studied) => furthestUnit(
        _plan(),
        firstUnit: first,
        studied: studied,
        placed: <String>{},
      );
      expect(reached(<String>['xx-1']), 0);
      // xx-2 is in the first two cores: it reaches the first only.
      expect(reached(<String>['xx-2']), 0);
      expect(reached(<String>['xx-3']), 1);
      expect(reached(<String>['xx-1', 'xx-4']), 2);
      // A card no deck holds reaches nothing.
      expect(reached(<String>['xx-99']), 0);
    });

    test('is the unit after one placement passed whole', () {
      final plan = _plan();
      int reached(Set<String> placed) => furthestUnit(
        plan,
        firstUnit: const <String, int>{},
        studied: const <String>[],
        placed: placed,
      );
      expect(reached(<String>{'xx-b'}), 2);
      // The last written unit placed: the reach stops at the unit after it,
      // here the planned one.
      expect(reached(<String>{'xx-f'}), 6);
    });

    test('does not take a unit placed in part for passed', () {
      final plan = <PlanUnit>[
        _unit(<String>['xx-a', 'xx-b'], milestone: Milestone.a1),
        _unit(<String>['xx-c'], milestone: Milestone.a2),
      ];
      expect(
        furthestUnit(
          plan,
          firstUnit: const <String, int>{},
          studied: const <String>[],
          placed: <String>{'xx-a'},
        ),
        0,
      );
    });

    test('gives the learner the level of that unit', () {
      final plan = _plan();
      expect(learnerLevel(plan, 0), Level.a1);
      expect(learnerLevel(plan, 2), Level.a2);
      expect(learnerLevel(plan, 5), Level.b1);
    });
  });

  group('LevelGate', () {
    test('refuses an item above the learner', () {
      expect(LevelGate.allows(Level.a2, Level.a1), isFalse);
      expect(LevelGate.allows(Level.b2, Level.b1), isFalse);
      expect(LevelGate.isAbove(Level.a2, Level.a1), isTrue);
    });

    test('allows an item at or below the learner', () {
      expect(LevelGate.allows(Level.a1, Level.a1), isTrue);
      expect(LevelGate.allows(Level.a1, Level.b1), isTrue);
      expect(LevelGate.isAbove(Level.a1, Level.b1), isFalse);
    });

    test('allows an item with no level to everyone', () {
      expect(LevelGate.allows(null, Level.a1), isTrue);
      expect(LevelGate.allows(null, null), isTrue);
    });

    test('offers no levelled item in a language with no levels', () {
      expect(LevelGate.allows(Level.a1, null), isFalse);
    });

    test('never shows a B2 item to a learner whose path ends at B1', () {
      expect(LevelGate.allows(Level.b2, Level.b1), isFalse);
    });

    test('filters a list in its order', () {
      final items = <(String, Level?)>[
        ('a', Level.a1),
        ('b', Level.b1),
        ('c', null),
        ('d', Level.a2),
      ];
      expect(
        LevelGate.filter(items, Level.a2, (i) => i.$2).map((i) => i.$1),
        <String>['a', 'c', 'd'],
      );
    });
  });
}
