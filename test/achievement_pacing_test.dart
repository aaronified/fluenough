// The pacing rule of the achievements (#322, decision 9): one unlock about
// every 3.5% of the B1 plan, never closer than 2 units, never farther apart
// than about 7%, with the levels on their marks. Checked on the two course
// shapes the approved mockup uses: Hindustani (114 units, marks 43, 71, 114)
// and Bengali (187 units, marks 60, 109, 187).

import 'package:fluenough/core/achievements/achievement.dart';
import 'package:fluenough/core/achievements/achievement_catalogue.dart';
import 'package:fluenough/core/achievements/achievement_facts.dart';
import 'package:fluenough/core/achievements/achievement_pacing.dart';
import 'package:fluenough/core/achievements/achievement_set.dart';
import 'package:fluenough/core/data/course_path.dart';
import 'package:fluenough/core/languages/language_skills.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/achievement_fixture.dart';

/// A course of [units] units, each one deck of one card, with the chosen
/// sets ending at the units [words] and [grammar] name.
AchievementFacts _shape(
  int units,
  int a1,
  int a2, {
  required Map<String, int> words,
  required Map<String, int> grammar,
  List<SkillKey> skills = spokenSkills,
  Set<int> unwritten = const <int>{},
  bool marked = true,
}) {
  final decks = <String, AchievementDeck>{
    for (var i = 1; i <= units; i++)
      'zz-u$i': AchievementDeck(
        id: 'zz-u$i',
        cards: <AchievementCard>[AchievementCard.of('zz-$i')],
      ),
  };
  final marks = <Milestone, int>{};
  if (marked) {
    marks[Milestone.a1] = a1;
    marks[Milestone.a2] = a2;
    marks[Milestone.b1] = units;
  }
  return AchievementFacts(
    language: 'zz',
    unitDecks: <List<String>>[
      for (var i = 1; i <= units; i++) <String>['zz-u$i'],
    ],
    unitWritten: <bool>[
      for (var i = 1; i <= units; i++) !unwritten.contains(i),
    ],
    marks: marks,
    decks: decks,
    sets: <AchievementSet>[
      for (final e in words.entries) _set(e.key, e.value, grammar: false),
      // Given out of path order: the rule places grammar tables in path order.
      for (final e in grammar.entries.toList().reversed)
        _set(e.key, e.value, grammar: true),
    ],
    skills: skills,
  );
}

/// A set that ends at unit [last].
AchievementSet _set(String id, int last, {required bool grammar}) =>
    AchievementSet(id: id, grammar: grammar, decks: <String>['zz-u$last']);

/// The unit numbers of every badge on the path.
Map<String, int> _placed(AchievementFacts facts) => <String, int>{
  for (final def in courseAchievementDefs(facts))
    if (def.position != null) def.id: def.position!,
};

const Map<String, int> _hindustaniWords = <String, int>{
  'pron': 8,
  'fam': 11,
  'num': 15,
  'food': 31,
  'fest': 61,
};
const Map<String, int> _hindustaniGrammar = <String, int>{
  'post': 35,
  'past': 54,
  'fut': 64,
  'rel': 75,
  'cond': 84,
  'purp': 86,
  'caus': 91,
  'indef': 95,
  'pass': 104,
};
const Map<String, int> _bengaliWords = <String, int>{
  'pron': 15,
  'fam': 20,
  'num': 43,
};
const Map<String, int> _bengaliGrammar = <String, int>{
  'past': 75,
  'comp': 81,
  'compar': 91,
  'imper': 96,
  'rel': 116,
  'cond': 131,
  'purp': 137,
  'beaf': 141,
  'caus': 147,
  'conc': 153,
  'pass': 168,
  'rep': 174,
};

AchievementFacts _hindustani() =>
    _shape(114, 43, 71, words: _hindustaniWords, grammar: _hindustaniGrammar);
AchievementFacts _bengali() =>
    _shape(187, 60, 109, words: _bengaliWords, grammar: _bengaliGrammar);

/// The positions, sorted.
List<int> _sorted(Map<String, int> placed) => placed.values.toList()..sort();

void main() {
  group('the pacing rule on the two course shapes', () {
    final shapes = <String, ({AchievementFacts facts, int units})>{
      'Hindustani': (facts: _hindustani(), units: 114),
      'Bengali': (facts: _bengali(), units: 187),
    };
    for (final MapEntry(key: name, value: shape) in shapes.entries) {
      group(name, () {
        final placed = _placed(shape.facts);
        final positions = _sorted(placed);
        final units = shape.units;

        test('the levels sit on their marks', () {
          expect(placed['level-a1'], shape.facts.marks[Milestone.a1]);
          expect(placed['level-a2'], shape.facts.marks[Milestone.a2]);
          expect(placed['level-b1'], units);
        });

        test('never closer than 2 units', () {
          for (var i = 1; i < positions.length; i++) {
            expect(
              positions[i] - positions[i - 1],
              greaterThanOrEqualTo(kPacingMinGap),
              reason: 'unit ${positions[i - 1]} and ${positions[i]}',
            );
          }
        });

        test('never farther apart than about 7% of the plan', () {
          final limit = (kPacingMaxGapShare * units).ceil();
          for (var i = 1; i < positions.length; i++) {
            expect(
              positions[i] - positions[i - 1],
              lessThanOrEqualTo(limit),
              reason: 'unit ${positions[i - 1]} and ${positions[i]}',
            );
          }
          // From the first unit to the first unlock too.
          expect(positions.first, lessThanOrEqualTo(limit));
        });

        test('one unlock about every 3.5% of the plan, about 30 a course', () {
          final target = pacingTarget(units);
          expect(positions.length, inInclusiveRange(target - 2, target));
          final gap = units / positions.length;
          expect(gap, closeTo(kPacingGapShare * units, 0.01 * units));
        });

        test('each tenth of the course holds at most 3 unlocks', () {
          final tenths = List<int>.filled(10, 0);
          for (final p in positions) {
            tenths[pacingTenth(p, units)]++;
          }
          for (final (i, count) in tenths.indexed) {
            expect(
              count,
              lessThanOrEqualTo(kPacingTenthCapacity),
              reason: 'tenth $i',
            );
          }
          // Nothing bunches at the start or the end.
          expect(tenths.first, greaterThanOrEqualTo(2));
          expect(tenths.last, greaterThanOrEqualTo(2));
        });

        test('placing it again gives the same positions', () {
          expect(_placed(shape.facts), placed);
        });
      });
    }

    test('Hindustani is placed unit by unit as the rule says', () {
      expect(_placed(_hindustani()), <String, int>{
        'skill-hear-start': 4,
        'words-100': 6,
        'skill-read-devanagari-start': 9,
        'set-pron': 13,
        'set-fam': 15,
        'set-num': 19,
        'skill-speak-start': 24,
        'skill-write-devanagari-start': 26,
        'words-500': 31,
        'set-food': 36,
        'set-post': 39,
        'level-a1': 43,
        'skill-read-devanagari-master': 47,
        'skill-write-devanagari-master': 50,
        'words-1000': 52,
        'set-past': 58,
        'set-fest': 65,
        'set-fut': 68,
        'level-a2': 71,
        'skill-hear-master': 75,
        'skill-speak-master': 79,
        'set-rel': 81,
        'set-cond': 88,
        'set-purp': 90,
        'set-caus': 95,
        'set-indef': 99,
        'words-2500': 103,
        'set-pass': 108,
        'level-b1': 114,
      });
    });

    test('Bengali is placed unit by unit as the rule says', () {
      expect(_placed(_bengali()), <String, int>{
        'skill-hear-start': 6,
        'words-100': 9,
        'skill-read-devanagari-start': 12,
        'set-pron': 22,
        'skill-speak-start': 33,
        'skill-write-devanagari-start': 36,
        'set-fam': 39,
        'words-500': 50,
        'set-num': 52,
        'level-a1': 60,
        'skill-read-devanagari-master': 67,
        'skill-write-devanagari-master': 74,
        'set-past': 82,
        'words-1000': 86,
        'set-comp': 88,
        'set-compar': 98,
        'set-imper': 103,
        'level-a2': 109,
        'skill-hear-master': 116,
        'skill-speak-master': 123,
        'set-rel': 125,
        'set-cond': 138,
        'set-purp': 144,
        'set-beaf': 148,
        'set-caus': 154,
        'set-conc': 160,
        'words-2500': 168,
        'set-pass': 175,
        'set-rep': 181,
        'level-b1': 187,
      });
    });
  });

  group('the pacing rule on other paths', () {
    test('a short path keeps every anchor and picks fewer sets', () {
      final facts = _shape(
        45,
        15,
        30,
        words: const <String, int>{'pron': 4, 'fam': 6, 'num': 9, 'food': 12},
        grammar: const <String, int>{
          'past': 20,
          'rel': 27,
          'cond': 33,
          'pass': 38,
        },
      );
      final placed = _placed(facts);
      final positions = _sorted(placed);
      for (var i = 1; i < positions.length; i++) {
        expect(positions[i] - positions[i - 1], greaterThanOrEqualTo(2));
      }
      expect(positions.length, lessThanOrEqualTo(pacingTarget(45)));
      for (final id in <String>[
        'level-a1',
        'level-a2',
        'level-b1',
        'words-100',
        'words-500',
        'words-1000',
        'words-2500',
        'skill-hear-start',
        'skill-speak-start',
        'skill-read-devanagari-start',
        'skill-write-devanagari-start',
        'skill-hear-master',
        'skill-speak-master',
        'skill-read-devanagari-master',
        'skill-write-devanagari-master',
      ]) {
        expect(placed, contains(id));
      }
      final sets = placed.keys.where((id) => id.startsWith('set-')).length;
      expect(sets, lessThan(8));
      expect(sets, greaterThan(0));
    });

    test('a path with only A1 built places only that part', () {
      final unwritten = <int>{for (var i = 44; i <= 114; i++) i};
      final facts = _shape(
        114,
        43,
        71,
        words: _hindustaniWords,
        grammar: _hindustaniGrammar,
        unwritten: unwritten,
      );
      final placed = _placed(facts);
      expect(placed, contains('level-a1'));
      expect(placed, isNot(contains('level-a2')));
      expect(placed, isNot(contains('level-b1')));
      expect(placed, isNot(contains('words-2500')));
      expect(placed, isNot(contains('skill-hear-master')));
      for (final entry in placed.entries) {
        expect(entry.value, lessThanOrEqualTo(43), reason: entry.key);
      }
    });

    test('a path with no B1 plan has no timeline, level or master', () {
      final facts = _shape(
        30,
        0,
        0,
        words: const <String, int>{'family': 4},
        grammar: const <String, int>{},
        marked: false,
      );
      final defs = courseAchievementDefs(facts);
      expect(defs.where((d) => d.position != null), isEmpty);
      final ids = defs.map((d) => d.id).toSet();
      expect(ids, containsAll(<String>['words-100', 'set-family']));
      expect(ids, contains('skill-hear-start'));
      expect(ids, contains('other-first-lesson'));
      expect(ids.where((id) => id.startsWith('level-')), isEmpty);
      expect(ids.where((id) => id.endsWith('-master')), isEmpty);
    });

    test('a language with no sets has an empty Sets category', () {
      final facts = _shape(
        114,
        43,
        71,
        words: const <String, int>{},
        grammar: const <String, int>{},
      );
      final defs = courseAchievementDefs(facts);
      expect(defs.where((d) => d.kind == AchievementKind.deckSet), isEmpty);
      expect(defs.where((d) => d.kind == AchievementKind.level), hasLength(3));
    });

    test('a sign language has one pair of skill badges, Gestures', () {
      final facts = _shape(
        114,
        43,
        71,
        words: const <String, int>{},
        grammar: const <String, int>{},
        skills: const <SkillKey>[SkillKey(SkillKind.gesture)],
      );
      final skills = courseAchievementDefs(facts)
          .where((d) => d.skill != null)
          .map((d) => d.id)
          .toList();
      const expected = <String>['skill-gesture-start', 'skill-gesture-master'];
      expect(skills, unorderedEquals(expected));
    });

    test('every badge id of a course is distinct', () {
      final defs = courseAchievementDefs(_hindustani());
      final ids = defs.map((d) => d.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });
  });

  group('placing items by hand', () {
    test('a fixed item never moves; an anchor next to it moves to the nearest '
        'free unit, later first', () {
      final placed = placeOnPath(100, const <PaceItem>[
        PaceItem('level', 10, PaceMode.fixed),
        PaceItem('anchor', 10, PaceMode.anchored),
      ]);
      expect(placed['level'], 10);
      expect(placed['anchor'], 12);
    });

    test('a set slides to the nearest later tenth when its own is full', () {
      final placed = placeOnPath(100, const <PaceItem>[
        PaceItem('a', 2, PaceMode.fixed),
        PaceItem('b', 5, PaceMode.fixed),
        PaceItem('c', 8, PaceMode.fixed),
        PaceItem('set', 6, PaceMode.sliding),
      ]);
      expect(placed['set'], 11);
    });

    test('the lag and the target follow the size of the plan', () {
      expect(pacingLag(114), 4);
      expect(pacingLag(187), 7);
      expect(pacingLag(45), 2);
      expect(pacingTarget(114), 30);
      expect(pacingTarget(187), 30);
      expect(pacingTarget(45), 19);
    });
  });
}
