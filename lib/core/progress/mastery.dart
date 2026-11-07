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
///
/// A pair is EARNED when the learner answered it, and PLACED when placement
/// credited it and the learner has not answered it since (its last review is
/// placement credit, [ReviewEvent.isPlaced]). Placed pairs are counted apart:
/// never as known and never as taught, so the outline stays earned-only; the
/// star draws them as a hatched layer under the solid fill (owner,
/// 2026-11-07). A placed pair the learner then answers is earned from that
/// answer on, known or not (a lapsed one is taught and not known).
class SkillScore {
  const SkillScore({
    required this.known,
    required this.taught,
    required this.total,
    this.placed = 0,
  });

  /// Pairs known in the skill, by the learner's own answers.
  final int known;

  /// Pairs of the skill the learner answered at least once (placed pairs
  /// not answered since are not here).
  final int taught;

  /// Pairs placement credited that the learner has not answered since.
  final int placed;

  /// The pairs the whole B1 plan holds for the skill. Never below [taught]
  /// plus [placed].
  final int total;

  /// Known ÷ B1 total, 0 to 1: the star's solid fill.
  double get fill => total == 0 ? 0 : known / total;

  /// (Known + placed) ÷ B1 total, 0 to 1: the star's hatched layer, which
  /// reaches as far as placement and earning together.
  double get placedFill => total == 0 ? 0 : (known + placed) / total;

  /// Known ÷ taught, 0 to 1, or null where nothing is taught yet: the
  /// star's outline, drawn at the centre. Earned only.
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
  final placed = <MasterySkill, int>{};
  for (final e in last.values) {
    final skill = masterySkillOf(e.mode)!;
    if (e.isPlaced) {
      placed[skill] = (placed[skill] ?? 0) + 1;
      continue;
    }
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
        placed: placed[skill] ?? 0,
        total: _max(
          totals[skill] ?? 0,
          (taught[skill] ?? 0) + (placed[skill] ?? 0),
        ),
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
      placed: all.fold(0, (n, m) => n + m[skill].placed),
      total: all.fold(0, (n, m) => n + m[skill].total),
    ),
});

/// The words counted on Progress: [mastered] of the words [taught], and the
/// words only [placed] (credited by placement, not answered since).
typedef WordCounts = ({int mastered, int taught, int placed});

/// Words taught are the distinct cards the learner answered in a word skill
/// (read, write, hear or say); one is mastered when every one of those skills
/// it has been answered in leaves it known. A card whose every word-skill
/// pair is still placement credit is placed, not taught; a pair of a taught
/// card that is still placement credit is left out of its standing.
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
  final placed = <String>{};
  for (final e in last.values) {
    if (e.isPlaced) {
      placed.add(e.cardId);
      continue;
    }
    cards[e.cardId] =
        (cards[e.cardId] ?? true) &&
        leavesKnown(e, parameters: parametersOf(e.mode));
  }
  return (
    mastered: cards.values.where((known) => known).length,
    taught: cards.length,
    placed: placed.where((id) => !cards.containsKey(id)).length,
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

/// Whether the level [path] has reached is only PLACED: no unit of that
/// milestone (the units after the previous milestone's end, up to its own)
/// has a review the learner earned, that is, one that is not placement credit
/// ([ReviewEvent.isPlaced]). The Level tile then carries a "Placed" mark
/// until a review is earned there (owner, 2026-11-07). False before A1.
bool levelPlaced(
  CoursePath path,
  Milestone? level,
  Iterable<ReviewEvent> reviews,
) {
  if (level == null) return false;
  final end = path.milestoneIndex(level);
  if (end == null) return false;
  var start = 0;
  for (final milestone in Milestone.values) {
    if (milestone == level) break;
    final at = path.milestoneIndex(milestone);
    if (at != null) start = at + 1;
  }
  final decks = <String>{
    for (final unit in path.plan.skip(start).take(end - start + 1))
      ...unit.decks,
  };
  for (final e in reviews.answered) {
    if (decks.contains(e.deckId) && !e.isPlaced) return false;
  }
  return true;
}

/// The day of the first answer in [reviews], or null with none.
DateTime? startedOn(Iterable<ReviewEvent> reviews) {
  DateTime? first;
  for (final e in reviews.answered) {
    if (first == null || e.at.isBefore(first)) first = e.at;
  }
  return first == null ? null : calendarDay(first);
}
