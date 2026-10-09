import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/session.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/models/reading.dart' show QuestionCard;
import '../../core/numbers/number_practice.dart' show NumberCard;
import 'word_mastery.dart';

/// What the Decks tab and a unit's screen read out of a course's path, kept
/// apart from the widgets so that it can be tested without pumping
/// anything (docs/plans/path-redesign.md, the owner's design).
///
/// The path is read only through `AppState`'s course and unit API
/// (`courseUnits`, `pathOf`, `isFinished`, `scriptLearned`), so that a
/// change to how paths are written reaches this file through it.

/// The CEFR levels a course's path is marked with, A1 to B1, the level a
/// whole course reaches (`language-paths.md`, "Target level").
enum CefrLevel {
  a1('A1'),
  a2('A2'),
  b1('B1');

  const CefrLevel(this.label);

  /// How the level is written: an international code, the same in every
  /// language, like a language code.
  final String label;
}

/// A unit a course's B1 plan names but that is not written yet: shown on the
/// path as coming, and never opened.
typedef ComingUnit = ({
  String title,
  CefrLevel level,

  /// Its planned size in words, if the plan gives one.
  int? words,
});

/// What a course's B1 plan says beyond its written units: where each level
/// ends, and the units still to be written (`b1-plans.md`).
///
/// No path on this branch marks a level yet: the B1 format adds the marks
/// (`milestone:` on a unit). Until a path has them, [coursePlanOf] gives
/// [CoursePlan.none] and the path shows no level and no level achievement,
/// rather than guessing where A1 ends. Tests and the debug gallery pass a
/// plan of their own.
class CoursePlan {
  const CoursePlan({
    this.levelEnds = const <CefrLevel, String>{},
    this.coming = const <ComingUnit>[],
  });

  /// No levels marked and nothing coming.
  static const CoursePlan none = CoursePlan();

  /// For each level marked, a deck in the unit that ends it.
  final Map<CefrLevel, String> levelEnds;

  /// The units still being written, in order.
  final List<ComingUnit> coming;

  bool get isEmpty => levelEnds.isEmpty && coming.isEmpty;
}

/// The plan of [language]'s course: [CoursePlan.none] until paths mark their
/// levels (see [CoursePlan]). The one place a path's marks will be read.
CoursePlan coursePlanOf(AppState state, String language) => CoursePlan.none;

/// Where a unit stands for the learner.
enum UnitStatus {
  /// Every deck in it finished or placed.
  done,

  /// The first unit not done: where the learner is.
  upNext,

  /// After the unit up next.
  ahead,
}

/// Whether [card] is a sentence or a phrase rather than a single word: a
/// phrase, or anything put in order to produce it (ADR-0024).
bool isSentence(Card card) => card.pos == 'phrase' || card.rearranges;

/// What a unit teaches, as its screen lists it.
class UnitContent {
  UnitContent(this.decks) {
    final seen = <String>{};
    for (final entry in decks) {
      if (entry.deck.pattern != null) {
        rules.add(entry);
        continue;
      }
      if (entry.deck.kind == DeckKind.reading) {
        passages += entry.deck.passages.length;
        continue;
      }
      for (final card in entry.cards) {
        if (card is QuestionCard || card is NumberCard) continue;
        if (!seen.add(card.id)) continue;
        (isSentence(card) ? sentences : words).add(card);
      }
    }
  }

  final List<DeckEntry> decks;

  /// The unit's single words, each once, in order. A script unit's are its
  /// letters.
  final List<Card> words = <Card>[];

  /// Its sentences and phrases, each once, in order.
  final List<Card> sentences = <Card>[];

  /// Its rules: the grammar decks, each one table (ADR-0010).
  final List<DeckEntry> rules = <DeckEntry>[];

  /// How many reading passages it has.
  int passages = 0;

  /// Whether the unit teaches a script: every deck in it is a script deck.
  bool get isScript => decks.every((e) => e.isScript);

  /// Every card the unit drills, each once.
  Iterable<String> get cardIds => <String>{
    for (final entry in decks)
      for (final card in entry.cards) card.id,
  };
}

/// One unit's title: its theme deck's name, or else its first deck's.
String unitTitle(AppState state, List<DeckEntry> decks) {
  for (final entry in decks) {
    if (state.themeOf(entry) != null) return entry.deck.name;
  }
  return decks.first.deck.name;
}

/// One step down a course's path, as the Decks tab draws it.
sealed class PathStep {
  const PathStep();
}

/// A written unit: a node to open.
final class UnitStep extends PathStep {
  UnitStep({
    required this.number,
    required this.title,
    required this.content,
    required this.status,
    required this.due,
    required this.onPath,
    this.level,
  });

  /// Its place in the course, from 1.
  final int number;
  final String title;
  final UnitContent content;
  final UnitStatus status;

  /// Reviews due now in its decks.
  final int due;

  /// Whether its path lists it. A deck the path leaves out follows the path
  /// as a unit of its own, and opens its deck's screen instead.
  final bool onPath;

  /// The level it belongs to, when the path marks levels.
  final CefrLevel? level;

  List<DeckEntry> get decks => content.decks;
}

/// A unit a plan names that is not written yet.
final class ComingStep extends PathStep {
  const ComingStep(this.unit);

  final ComingUnit unit;
}

/// The start of a level: its can-do line and its size.
final class LevelStep extends PathStep {
  const LevelStep({
    required this.level,
    required this.units,
    required this.done,
    required this.words,
    required this.coming,
    required this.current,
  });

  final CefrLevel level;

  /// Its written units, and how many of them are done.
  final int units;
  final int done;

  /// The words its written units teach.
  final int words;

  /// Its units still being written.
  final int coming;

  /// Whether the learner is in it: it holds the unit up next.
  final bool current;
}

/// A level reached, or still to reach, at its end.
final class AchievementStep extends PathStep {
  const AchievementStep({
    required this.level,
    required this.unitsToGo,
    required this.coming,
    this.earnedAt,
  });

  final CefrLevel level;

  /// Its units not done yet, written or coming.
  final int unitsToGo;

  /// How many of those are still being written.
  final int coming;

  /// When the last of its units was finished, if it is reached and the log
  /// says when.
  final DateTime? earnedAt;

  bool get earned => unitsToGo == 0;
}

/// The kinds of milestone on a path (docs/plans/achievements.md, "Basic").
enum MilestoneKind {
  /// Some deck of the course finished.
  firstDeck,

  /// A number of the course's words learned.
  words,

  /// The script units done.
  script,

  /// A number of the course's rules known.
  rules,

  /// A reading passage's questions answered.
  firstPassage,
}

/// The word counts a words milestone is set at: the design's, then the
/// achievements plan's larger ones.
const List<int> wordMilestones = <int>[50, 100, 250, 500, 1000, 2500];

/// The rule counts a rules milestone is set at: the design's 10, then more.
const List<int> ruleMilestones = <int>[10, 25, 50];

/// A milestone on the path, after the unit that reaches it.
final class MilestoneStep extends PathStep {
  const MilestoneStep({
    required this.kind,
    required this.earned,
    required this.toGo,
    this.count = 0,
    this.earnedAt,
  });

  final MilestoneKind kind;

  /// For [MilestoneKind.words] and [MilestoneKind.rules], how many.
  final int count;

  final bool earned;

  /// When it was earned, if the log says.
  final DateTime? earnedAt;

  /// What is left: words for [MilestoneKind.words], rules for
  /// [MilestoneKind.rules], script units for [MilestoneKind.script]; 0 once
  /// earned, and for the first deck and the first passage.
  final int toGo;
}

/// A course's path, with what the learner has done of it.
class CourseView {
  CourseView({
    required this.language,
    required this.native,
    required this.steps,
    required this.otherDecks,
    required this.plan,
  });

  final LanguageInfo language;

  /// The language it is taught from.
  final LanguageInfo native;

  final List<PathStep> steps;

  /// The language's decks its course leaves out: those of other courses,
  /// and those that need an alphabet the learner skips. Each opens its own
  /// screen.
  final List<DeckEntry> otherDecks;

  final CoursePlan plan;

  Iterable<UnitStep> get units => steps.whereType<UnitStep>();

  int get unitCount => units.length;
  int get doneCount => units.where((u) => u.status == UnitStatus.done).length;

  /// The unit the learner is on, or null when every unit is done.
  UnitStep? get upNext {
    for (final unit in units) {
      if (unit.status == UnitStatus.upNext) return unit;
    }
    return null;
  }

  /// The levels the path marks, in order.
  List<CefrLevel> get levels => <CefrLevel>[
    for (final step in steps)
      if (step is LevelStep) step.level,
  ];
}

/// [language]'s course as its path, for the Decks tab: its units in order,
/// each with its status; the milestones, after the unit that reaches each;
/// and, where [plan] marks levels, each level's start, its units still
/// being written and its achievement. Null if no deck teaches [language].
CourseView? courseView(
  AppState state,
  String language, {
  CoursePlan? plan,
  RecentAnswers? answers,
}) {
  final units = state.courseUnits(language);
  if (units.isEmpty) return null;
  final thePlan = plan ?? coursePlanOf(state, language);
  final recent = answers ?? RecentAnswers(state.progress.log);
  final first = units.first.first;

  // Each unit's level: the first level whose end is at or after it.
  final ends = <CefrLevel, int>{
    for (final MapEntry(key: level, value: deckId) in thePlan.levelEnds.entries)
      if (units.indexWhere((u) => u.any((e) => e.id == deckId)) case final i
          when i >= 0)
        level: i,
  };
  CefrLevel? levelOf(int index) {
    for (final level in CefrLevel.values) {
      final end = ends[level];
      if (end != null && index <= end) return level;
    }
    // After the last mark, units belong to the next level a coming unit
    // is planned for, if any.
    for (final level in CefrLevel.values) {
      if (ends[level] == null &&
          thePlan.coming.any((c) => c.level == level) &&
          (ends.isEmpty ||
              ends.keys.every((marked) => marked.index < level.index))) {
        return level;
      }
    }
    return null;
  }

  // Units, with their status.
  final unitSteps = <UnitStep>[];
  var foundNext = false;
  for (final (i, decks) in units.indexed) {
    final done = decks.every(state.isFinished);
    final status = done
        ? UnitStatus.done
        : foundNext
        ? UnitStatus.ahead
        : UnitStatus.upNext;
    if (!done) foundNext = true;
    final ids = <String>{for (final e in decks) e.id};
    unitSteps.add(
      UnitStep(
        number: i + 1,
        title: unitTitle(state, decks),
        content: UnitContent(decks),
        status: status,
        due: state.buildSession(DrillRequest(deckIds: ids)).due.length,
        onPath: state.pathOf(decks.first)?.unitOf(decks.first.id) != null,
        level: levelOf(i),
      ),
    );
  }

  // Milestones, by the unit they follow.
  final after = <int, List<MilestoneStep>>{};
  void place(int unit, MilestoneStep step) =>
      (after[unit] ??= <MilestoneStep>[]).add(step);

  final learned = <String>{
    for (final entry in state.progress.states.entries)
      if (entry.value.repetitions > 0) entry.key.cardId,
  };

  // The first deck finished, after the first unit.
  DateTime? firstFinished;
  var anyFinished = false;
  for (final unit in units) {
    for (final entry in unit) {
      if (!state.canDrill(entry) || !state.isFinished(entry)) continue;
      final ids = entry.cards.map((c) => c.id).toList();
      if (!state.isPlaced(entry) && !ids.any(learned.contains)) continue;
      anyFinished = true;
      final dates = ids.map(recent.firstPassed).nonNulls.toList();
      if (dates.isEmpty) continue;
      final at = dates.reduce((a, b) => a.isAfter(b) ? a : b);
      if (firstFinished == null || at.isBefore(firstFinished)) {
        firstFinished = at;
      }
    }
  }
  place(
    0,
    MilestoneStep(
      kind: MilestoneKind.firstDeck,
      earned: anyFinished,
      earnedAt: firstFinished,
      toGo: 0,
    ),
  );

  // The script, after its units: the first run of units that all need the
  // alphabet, as `AppState.scriptLearned` reads it.
  bool script(List<DeckEntry> unit) => unit.every(state.needsAlphabet);
  final scriptStart = units.indexWhere(script);
  if (scriptStart >= 0) {
    var end = scriptStart;
    while (end + 1 < units.length && script(units[end + 1])) {
      end++;
    }
    final run = unitSteps.sublist(scriptStart, end + 1);
    final toGo = run.where((u) => u.status != UnitStatus.done).length;
    final dates = <DateTime>[
      for (final unit in run)
        ...unit.content.cardIds.map(recent.firstPassed).nonNulls,
    ];
    place(
      end,
      MilestoneStep(
        kind: MilestoneKind.script,
        earned: toGo == 0 && state.scriptLearned(language),
        earnedAt: toGo == 0 && dates.isNotEmpty
            ? dates.reduce((a, b) => a.isAfter(b) ? a : b)
            : null,
        toGo: toGo,
      ),
    );
  }

  // Words learned, after the unit whose words reach each count.
  final words = <String>[];
  final counted = <String>{};
  final reachedAt = <int>[];
  for (final (i, unit) in unitSteps.indexed) {
    for (final card in unit.content.words) {
      if (counted.add(card.id)) {
        words.add(card.id);
        reachedAt.add(i);
      }
    }
  }
  final learnedWords = words.where(learned.contains).toList();
  final wordDates = learnedWords.map(recent.firstPassed).nonNulls.toList()
    ..sort();
  for (final count in wordMilestones) {
    if (count > words.length) break;
    final earned = learnedWords.length >= count;
    place(
      reachedAt[count - 1],
      MilestoneStep(
        kind: MilestoneKind.words,
        count: count,
        earned: earned,
        earnedAt: earned && wordDates.length >= count
            ? wordDates[count - 1]
            : null,
        toGo: earned ? 0 : count - learnedWords.length,
      ),
    );
  }

  // Rules known, after the unit whose rules reach each count. Known is
  // read from recent answers, so a rule forgotten counts again as to go.
  final rules = <({int unit, bool known})>[
    for (final (i, unit) in unitSteps.indexed)
      for (final rule in unit.content.rules)
        (
          unit: i,
          known:
              recent.ofAll(rule.cards.map((c) => c.id)).level ==
              MasteryLevel.known,
        ),
  ];
  final rulesKnown = rules.where((r) => r.known).length;
  for (final count in ruleMilestones) {
    if (count > rules.length) break;
    final earned = rulesKnown >= count;
    place(
      rules[count - 1].unit,
      MilestoneStep(
        kind: MilestoneKind.rules,
        count: count,
        earned: earned,
        toGo: earned ? 0 : count - rulesKnown,
      ),
    );
  }

  // The first passage read, after the first unit with one: earned when any
  // of the course's passages has a question answered.
  final firstReading = unitSteps.indexWhere((u) => u.content.passages > 0);
  if (firstReading >= 0) {
    DateTime? read;
    for (final unit in unitSteps) {
      for (final entry in unit.decks) {
        if (entry.deck.kind != DeckKind.reading) continue;
        for (final card in entry.cards) {
          final at = recent.firstAnswered(card.id);
          if (at != null && (read == null || at.isBefore(read))) read = at;
        }
      }
    }
    place(
      firstReading,
      MilestoneStep(
        kind: MilestoneKind.firstPassage,
        earned: read != null,
        earnedAt: read,
        toGo: 0,
      ),
    );
  }

  // The steps, in order: each level's start, its units, each followed by
  // its milestones, then its units still being written and its
  // achievement.
  final steps = <PathStep>[];
  final upNextLevel = unitSteps
      .where((u) => u.status == UnitStatus.upNext)
      .firstOrNull
      ?.level;
  void startLevel(CefrLevel level) {
    final inLevel = unitSteps.where((u) => u.level == level);
    steps.add(
      LevelStep(
        level: level,
        units: inLevel.length,
        done: inLevel.where((u) => u.status == UnitStatus.done).length,
        words: inLevel.fold(0, (sum, u) => sum + u.content.words.length),
        coming: thePlan.coming.where((c) => c.level == level).length,
        current: upNextLevel == level,
      ),
    );
  }

  void endLevel(CefrLevel level) {
    final coming = thePlan.coming.where((c) => c.level == level).toList();
    steps.addAll(coming.map(ComingStep.new));
    final inLevel = unitSteps.where((u) => u.level == level).toList();
    final toGo =
        inLevel.where((u) => u.status != UnitStatus.done).length +
        coming.length;
    DateTime? at;
    if (toGo == 0) {
      for (final unit in inLevel) {
        for (final id in unit.content.cardIds) {
          final passed = recent.firstPassed(id);
          if (passed != null && (at == null || passed.isAfter(at))) {
            at = passed;
          }
        }
      }
    }
    steps.add(
      AchievementStep(
        level: level,
        unitsToGo: toGo,
        coming: coming.length,
        earnedAt: at,
      ),
    );
  }

  CefrLevel? current;
  for (final (i, unit) in unitSteps.indexed) {
    if (unit.level != current) {
      if (current != null) endLevel(current);
      current = unit.level;
      if (current != null) startLevel(current);
    }
    steps.add(unit);
    steps.addAll(after[i] ?? const <MilestoneStep>[]);
  }
  if (current != null) endLevel(current);
  // Levels planned with no unit written yet.
  for (final level in CefrLevel.values) {
    if (unitSteps.any((u) => u.level == level)) continue;
    if (!thePlan.coming.any((c) => c.level == level)) continue;
    startLevel(level);
    endLevel(level);
  }

  final inCourse = <String>{
    for (final unit in units)
      for (final entry in unit) entry.id,
  };
  return CourseView(
    language: first.language,
    native: first.deck.native,
    steps: steps,
    otherDecks: <DeckEntry>[
      for (final entry in state.decks)
        if (entry.language.code == language && !inCourse.contains(entry.id))
          entry,
    ],
    plan: thePlan,
  );
}

/// The unit holding [deckId] in its language's course, with its number and
/// level, or null if the course leaves the deck out.
({int number, List<DeckEntry> decks, CefrLevel? level})? unitOfDeck(
  AppState state,
  String deckId, {
  CoursePlan? plan,
}) {
  final entry = state.deckById(deckId);
  if (entry == null) return null;
  final language = entry.language.code;
  final units = state.courseUnits(language);
  final index = units.indexWhere((u) => u.any((e) => e.id == deckId));
  if (index < 0) return null;
  final thePlan = plan ?? coursePlanOf(state, language);
  CefrLevel? level;
  for (final candidate in CefrLevel.values) {
    final end = thePlan.levelEnds[candidate];
    if (end == null) continue;
    final at = units.indexWhere((u) => u.any((e) => e.id == end));
    if (at >= index) {
      level = candidate;
      break;
    }
  }
  return (number: index + 1, decks: units[index], level: level);
}

/// Whether [deckId] opens a unit's screen from the path: its path lists it.
/// A deck outside any path opens its own screen, as before.
bool opensUnit(AppState state, String deckId) {
  final entry = state.deckById(deckId);
  if (entry == null) return false;
  return state.pathOf(entry)?.unitOf(deckId) != null &&
      unitOfDeck(state, deckId) != null;
}
