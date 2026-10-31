import '../data/course_path.dart';
import '../models/drill_mode.dart';
import '../models/review_event.dart';
import '../scheduling/fsrs.dart';
import 'practice_week.dart';

/// The six skills Progress's star shows (#678).
enum MasterySkill { grammar, script, read, write, hear, say }

/// The recall FSRS predicted at a card's last review, at or above which a
/// right answer makes the card known (#680, owner, 2026-10-23).
const double kKnownRecall = 0.85;

/// The skill [mode] counts towards, or null for a mode no axis shows
/// (reading passages and grammar understood, which are not words or forms
/// a learner is taught one at a time).
MasterySkill? masterySkillOf(DrillMode mode) => switch (mode) {
  DrillMode.recognition => MasterySkill.read,
  DrillMode.production => MasterySkill.write,
  DrillMode.listening => MasterySkill.hear,
  DrillMode.speaking => MasterySkill.say,
  DrillMode.grammar => MasterySkill.grammar,
  DrillMode.readScript || DrillMode.writeScript => MasterySkill.script,
  DrillMode.reading || DrillMode.grammarUnderstood => null,
};

/// Whether [e] leaves its pair known: the answer was right and FSRS gave
/// at least [kKnownRecall] chance of recall at that moment. A pair's first
/// review has no recall to measure, so it does not. [parameters] are the
/// ones that schedule the pair's skill (`SkillParameters.of`), so that
/// Progress and the scheduler agree about a card.
bool leavesKnown(ReviewEvent e, {List<double> parameters = Fsrs.w}) =>
    e.passed &&
    e.before != null &&
    Fsrs.retrievability(e.before, e.at, parameters: parameters) >= kKnownRecall;

/// The parameters that schedule a [mode], from the learner's fits.
typedef ParametersOf = List<double> Function(DrillMode mode);

List<double> _defaults(DrillMode mode) => Fsrs.w;

/// What a skill has, and what B1 asks of it.
class SkillScore {
  const SkillScore({
    required this.known,
    required this.taught,
    required this.total,
  });

  /// Pairs known in the skill.
  final int known;

  /// Pairs of the skill answered at least once.
  final int taught;

  /// The pairs the whole B1 plan holds for the skill. Never below [taught].
  final int total;

  /// Known ÷ B1 total, 0 to 1: the star's fill.
  double get fill => total == 0 ? 0 : known / total;

  /// Known ÷ taught, 0 to 1, or null where nothing is taught yet: the
  /// star's outline, drawn at the centre.
  double? get outline => taught == 0 ? null : known / taught;
}

/// The B1 totals per skill.
typedef MasteryTotals = Map<MasterySkill, int>;

/// Every skill's score at one moment.
class Mastery {
  Mastery(this.scores);

  final Map<MasterySkill, SkillScore> scores;

  SkillScore operator [](MasterySkill skill) => scores[skill]!;

  /// Overall mastery, 0 to 1: the share of the star's hexagon the filled
  /// shape covers.
  double get overall {
    const skills = MasterySkill.values;
    var sum = 0.0;
    for (var i = 0; i < skills.length; i++) {
      sum += this[skills[i]].fill * this[skills[(i + 1) % skills.length]].fill;
    }
    return sum / skills.length;
  }
}

/// The pairs' state as of [asOf] (every review when null), from [reviews]
/// oldest first: [reviews] are the log's, and [scriptReviews] the script
/// skills' (`ProgressStore.scriptLog`), of which only those on a card in
/// [scriptCards] count, the letters of the alphabet decks. A pair is known
/// by its last review ([leavesKnown]).
Mastery masteryAt(
  Iterable<ReviewEvent> reviews,
  Iterable<ReviewEvent> scriptReviews, {
  required MasteryTotals totals,
  required Set<String> scriptCards,
  DateTime? asOf,
  ParametersOf parametersOf = _defaults,
}) {
  final last = <String, ReviewEvent>{};
  void take(ReviewEvent e) {
    if (asOf != null && e.at.isAfter(asOf)) return;
    final skill = masterySkillOf(e.mode);
    if (skill == null) return;
    last['${e.mode.name}|${e.cardId}|${e.script ?? ''}'] = e;
  }

  reviews.answered.where((e) => !e.mode.isScript).forEach(take);
  scriptReviews.answered
      .where((e) => scriptCards.contains(e.cardId))
      .forEach(take);

  final known = <MasterySkill, int>{};
  final taught = <MasterySkill, int>{};
  for (final e in last.values) {
    final skill = masterySkillOf(e.mode)!;
    taught[skill] = (taught[skill] ?? 0) + 1;
    if (leavesKnown(e, parameters: parametersOf(e.mode))) {
      known[skill] = (known[skill] ?? 0) + 1;
    }
  }
  return Mastery(<MasterySkill, SkillScore>{
    for (final skill in MasterySkill.values)
      skill: SkillScore(
        known: known[skill] ?? 0,
        taught: taught[skill] ?? 0,
        total: _max(totals[skill] ?? 0, taught[skill] ?? 0),
      ),
  });
}

int _max(int a, int b) => a > b ? a : b;

/// The sum of [all]'s counts, for Progress on All languages.
Mastery sumMastery(Iterable<Mastery> all) => Mastery(<MasterySkill, SkillScore>{
  for (final skill in MasterySkill.values)
    skill: SkillScore(
      known: all.fold(0, (n, m) => n + m[skill].known),
      taught: all.fold(0, (n, m) => n + m[skill].taught),
      total: all.fold(0, (n, m) => n + m[skill].total),
    ),
});

/// The words counted on Progress: [mastered] of the words [taught].
typedef WordCounts = ({int mastered, int taught});

/// Words taught are the distinct cards answered in a word skill (read,
/// write, hear or say); one is mastered when every one of those skills it
/// has been answered in leaves it known.
WordCounts wordCounts(
  Iterable<ReviewEvent> reviews, {
  ParametersOf parametersOf = _defaults,
}) {
  final last = <String, ReviewEvent>{};
  for (final e in reviews.answered) {
    final skill = masterySkillOf(e.mode);
    if (skill == null ||
        skill == MasterySkill.grammar ||
        skill == MasterySkill.script) {
      continue;
    }
    last['${e.cardId}|${e.mode.name}'] = e;
  }
  final cards = <String, bool>{};
  for (final e in last.values) {
    cards[e.cardId] =
        (cards[e.cardId] ?? true) &&
        leavesKnown(e, parameters: parametersOf(e.mode));
  }
  return (
    mastered: cards.values.where((known) => known).length,
    taught: cards.length,
  );
}

/// The highest level [path] has reached, or null before A1: a level is
/// reached when every unit of the plan up to the one that ends it is
/// finished ([isFinished] says so of a deck). A unit still planned or
/// coming is not.
Milestone? levelReached(
  CoursePath path,
  bool Function(String deckId) isFinished,
) {
  Milestone? reached;
  for (final milestone in Milestone.values) {
    final end = path.milestoneIndex(milestone);
    if (end == null) continue;
    final done = path.plan
        .take(end + 1)
        .every((unit) => !unit.isComing && unit.decks.every(isFinished));
    if (!done) break;
    reached = milestone;
  }
  return reached;
}

/// The day of the first answer in [reviews], or null with none.
DateTime? startedOn(Iterable<ReviewEvent> reviews) {
  DateTime? first;
  for (final e in reviews.answered) {
    if (first == null || e.at.isBefore(first)) first = e.at;
  }
  return first == null ? null : calendarDay(first);
}
