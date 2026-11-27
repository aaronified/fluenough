// Fixtures for the achievements tests (#322): a course of plain facts, and an
// in-memory review log whose reviews follow FSRS, so that "known" is the
// app's own rule.

import 'package:fluenough/core/achievements/achievement_facts.dart';
import 'package:fluenough/core/achievements/achievement_set.dart';
import 'package:fluenough/core/data/course_path.dart';
import 'package:fluenough/core/languages/language_skills.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/review_event.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';

/// The four skills of a spoken language with one script.
const List<SkillKey> spokenSkills = <SkillKey>[
  SkillKey(SkillKind.speak),
  SkillKey(SkillKind.hear),
  SkillKey(SkillKind.read, 'devanagari'),
  SkillKey(SkillKind.write, 'devanagari'),
];

/// Card ids of unit [unit], [count] of them: `zz-101`, `zz-102` for unit 1.
List<String> unitCards(int unit, {int count = 2}) => <String>[
  for (var j = 1; j <= count; j++) 'zz-${unit * 100 + j}',
];

/// A course of [units] units whose first unit is the script deck
/// `zz-letters` (six letters) and whose others each teach one deck
/// `zz-u<n>` of two words. Unit 20 also holds the reading deck `zz-read20`
/// (two questions, which no skill asks). The marks are [a1], [a2] and the
/// last unit; [sets] are the chosen sets; every unit is written unless its
/// number is in [unwritten].
AchievementFacts courseFacts({
  int units = 60,
  int a1 = 20,
  int a2 = 40,
  List<SkillKey> skills = spokenSkills,
  Set<SkillKey> leave = const <SkillKey>{},
  List<AchievementSet>? sets,
  Set<int> unwritten = const <int>{},
  Map<Milestone, int>? marks,
  int extraCardsInUnitOne = 0,
}) {
  final unitDecks = <List<String>>[];
  final decks = <String, AchievementDeck>{};
  for (var unit = 1; unit <= units; unit++) {
    final ids = <String>[];
    if (unit == 1) {
      ids.add('zz-letters');
      decks['zz-letters'] = AchievementDeck(
        id: 'zz-letters',
        isScript: true,
        script: 'devanagari',
        cards: <AchievementCard>[
          for (var j = 1; j <= 6 + extraCardsInUnitOne; j++)
            AchievementCard.of('zz-${9000 + j}'),
        ],
      );
    } else {
      ids.add('zz-u$unit');
      final words = <AchievementCard>[
        for (final id in unitCards(unit)) AchievementCard.of(id, isWord: true),
      ];
      decks['zz-u$unit'] = AchievementDeck(id: 'zz-u$unit', cards: words);
    }
    if (unit == 20) {
      ids.add('zz-read20');
      decks['zz-read20'] = const AchievementDeck(
        id: 'zz-read20',
        cards: <AchievementCard>[
          AchievementCard('zz-q1', 0),
          AchievementCard('zz-q2', 0),
        ],
      );
    }
    unitDecks.add(ids);
  }
  final written = <bool>[
    for (var unit = 1; unit <= units; unit++) !unwritten.contains(unit),
  ];
  final marked = Map<Milestone, int>.of(
    marks ?? {Milestone.a1: a1, Milestone.a2: a2, Milestone.b1: units},
  );
  return AchievementFacts(
    language: 'zz',
    unitDecks: unitDecks,
    unitWritten: written,
    marks: marked,
    decks: decks,
    sets: sets ?? defaultSets,
    skills: skills,
    leave: leave,
  );
}

/// A word set of two small decks and a grammar table with its reading deck.
const List<AchievementSet> defaultSets = <AchievementSet>[
  AchievementSet(
    id: 'family',
    grammar: false,
    decks: <String>['zz-u3', 'zz-u4'],
  ),
  AchievementSet(
    id: 'past',
    grammar: true,
    decks: <String>['zz-u20', 'zz-read20'],
  ),
];

/// The ids of the letters of [courseFacts]' script deck.
List<String> letterIds({int count = 6}) => <String>[
  for (var j = 1; j <= count; j++) 'zz-${9000 + j}',
];

/// A log kept in memory: each answer follows FSRS from the pair's last
/// state, so a review a day after a good one leaves its pair known.
class FixtureLog {
  FixtureLog(this.start);

  /// Day 0.
  final DateTime start;
  final List<ReviewEvent> _events = <ReviewEvent>[];
  final Map<String, FsrsState> _states = <String, FsrsState>{};

  /// The log as the app keeps it: oldest first, whatever the order the
  /// answers were added in (each pair's own answers are added in order).
  List<ReviewEvent> get events {
    final indexed = _events.indexed.toList()
      ..sort((a, b) {
        final order = a.$2.at.compareTo(b.$2.at);
        return order != 0 ? order : a.$1.compareTo(b.$1);
      });
    return <ReviewEvent>[for (final entry in indexed) entry.$2];
  }

  /// The moment [day] days after [start], at [hour] o'clock.
  DateTime day(int day, [int hour = 9]) =>
      DateTime.utc(start.year, start.month, start.day + day, hour);

  /// One answer to [card] in [mode] at [at], graded [grade] (4 is right, 0
  /// wrong).
  void answer(
    String card,
    DateTime at, {
    DrillMode mode = DrillMode.recognition,
    int grade = 4,
    String? script,
  }) {
    final key = '$card|${mode.name}';
    final before = _states[key];
    final after = Fsrs.next(before, grade, now: at);
    _states[key] = after;
    _events.add(
      ReviewEvent(
        at: at,
        deckId: 'zz-core',
        cardId: card,
        mode: mode,
        grade: grade,
        elapsed: const Duration(seconds: 3),
        before: before,
        after: after,
        script: script,
      ),
    );
  }

  /// [card] known in [mode] from day [onDay] + 1: answered right that day and
  /// again a day later, which is what the known rule asks.
  void know(
    String card,
    int onDay, {
    DrillMode mode = DrillMode.recognition,
    int hour = 9,
  }) {
    answer(card, day(onDay, hour), mode: mode);
    answer(card, day(onDay + 1, hour), mode: mode);
  }

  /// A placement credit for [card]: grade 5, no time taken, no answer.
  void credit(String card, DateTime at) {
    _events.add(
      ReviewEvent(
        at: at,
        deckId: 'zz-core',
        cardId: card,
        mode: DrillMode.recognition,
        grade: 5,
        elapsed: Duration.zero,
        before: null,
        after: Fsrs.next(null, 5, now: at),
      ),
    );
  }
}
