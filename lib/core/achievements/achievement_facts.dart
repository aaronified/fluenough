/// What the achievements need to know of a language's decks, as plain data
/// (#322): the path's units, marks and chosen sets, and each deck's cards
/// with the skills they are asked in. It holds no card text and needs no
/// catalog, so that it can be built once, kept, and sent to an isolate.
library;

import '../data/course_path.dart' show Milestone;
import '../languages/language_skills.dart';
import '../models/drill_mode.dart';
import 'achievement_set.dart';

/// One card, as the achievements see it.
class AchievementCard {
  const AchievementCard(this.id, this.modeMask, {this.isWord = false});

  /// A card asked in [modes] (the four vocabulary skills it may be drilled
  /// in; none for a card that is only read, such as a passage's question).
  factory AchievementCard.of(
    String id, {
    Set<DrillMode> modes = DrillMode.vocabulary,
    bool isWord = false,
  }) => AchievementCard(id, maskOf(modes), isWord: isWord);

  /// The bit of each mode in [modeMask].
  static int maskOf(Iterable<DrillMode> modes) =>
      modes.fold(0, (mask, mode) => mask | (1 << mode.index));

  final String id;

  /// The modes the card is asked in, a bit each ([maskOf]).
  final int modeMask;

  /// Whether it counts as a word of a level (`countsAsWord`): a root, not a
  /// phrase, a grammar cell or a question.
  final bool isWord;

  /// Whether the card is asked in [mode].
  bool asks(DrillMode mode) => modeMask & (1 << mode.index) != 0;
}

/// One deck of a course's path.
class AchievementDeck {
  const AchievementDeck({
    required this.id,
    required this.cards,
    this.isScript = false,
    this.script,
  });

  /// The deck's id in the course.
  final String id;
  final List<AchievementCard> cards;

  /// Whether the deck teaches a script's letters (it is on the path's
  /// `alphabet`): what a Read or Write Start counts.
  final bool isScript;

  /// The script a script deck teaches, as decks name it; null when it is not
  /// told, and then the deck counts for every script of the language.
  final String? script;
}

/// What one language's achievements are worked out from.
class AchievementFacts {
  const AchievementFacts({
    required this.language,
    required this.unitDecks,
    required this.unitWritten,
    required this.marks,
    required this.decks,
    this.sets = const <AchievementSet>[],
    this.skills = const <SkillKey>[],
    this.leave = const <SkillKey>{},
  });

  /// The language's code, such as `hi`.
  final String language;

  /// For each unit of the path's plan, in order, the course's deck ids it
  /// teaches; empty for a planned unit or one with no deck in this course.
  final List<List<String>> unitDecks;

  /// For each unit, whether it is written (it has decks in this course).
  /// Parallel to [unitDecks].
  final List<bool> unitWritten;

  /// The unit number (the first unit is 1) at which each level ends. A path
  /// with no B1 plan has none.
  final Map<Milestone, int> marks;

  /// The decks of the path by id.
  final Map<String, AchievementDeck> decks;

  /// The sets the path chooses, by the course's deck ids.
  final List<AchievementSet> sets;

  /// The skills the language has (`skillsOfLanguage`): Speak, Hear and Read
  /// and Write for each script, or the one Gestures skill of a sign
  /// language.
  final List<SkillKey> skills;

  /// The skills the learner marked Leave: shown dimmed, never earned
  /// (decision 11).
  final Set<SkillKey> leave;

  /// These facts with [left] marked Leave: the same decks and path.
  AchievementFacts withLeave(Set<SkillKey> left) => AchievementFacts(
    language: language,
    unitDecks: unitDecks,
    unitWritten: unitWritten,
    marks: marks,
    decks: decks,
    sets: sets,
    skills: skills,
    leave: left,
  );

  /// How many units the path has.
  int get units => unitDecks.length;

  /// Whether the path marks B1, so that the pacing rule has a timeline.
  bool get hasPlan => marks.containsKey(Milestone.b1);

  /// The ids of the cards of the decks of the first [units] units.
  Set<String> cardIdsUpTo(int units) {
    final ids = <String>{};
    for (final deckId in decksUpTo(units)) {
      for (final card in decks[deckId]?.cards ?? const <AchievementCard>[]) {
        ids.add(card.id);
      }
    }
    return ids;
  }

  /// The decks of the first [units] units, in order, each once.
  Iterable<String> decksUpTo(int units) sync* {
    final seen = <String>{};
    for (final (i, unit) in unitDecks.indexed) {
      if (i >= units) return;
      for (final id in unit) {
        if (seen.add(id)) yield id;
      }
    }
  }

  /// The number of the last unit that teaches any deck of [setDecks], or
  /// null when none does.
  int? lastUnitOf(Iterable<String> setDecks) {
    final wanted = setDecks.toSet();
    int? last;
    for (final (i, unit) in unitDecks.indexed) {
      if (unit.any(wanted.contains)) last = i + 1;
    }
    return last;
  }

  /// Whether every unit up to and including unit number [position] is
  /// written: nothing is promised past a unit still to be written.
  bool isBuiltTo(int position) {
    for (var i = 0; i < position && i < unitWritten.length; i++) {
      if (!unitWritten[i]) return false;
    }
    return true;
  }
}
