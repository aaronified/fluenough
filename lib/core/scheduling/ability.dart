import 'dart:math' as math;

import '../models/drill_mode.dart';
import 'fsrs.dart';
import 'skill_map.dart';

/// One ability: a language learned, in one schedule.
typedef AbilityKey = ({String language, DrillMode mode});

/// What the app has learned about a learner's strengths (ADR-0034): an Elo
/// rating per language and schedule, and a difficulty per pair, each moved
/// after every answer by how surprising it was (Pelánek 2016). One answer
/// can judge several skills (a Q-matrix, as in multi-skill Elo: Park et al.
/// 2019): a right answer also moves the skills it implies ([SkillMap]), by
/// their share. A miss moves its own skill alone.
///
/// Derived from the review log alone, like every scheduling state, so it can
/// always be rebuilt.
class Abilities {
  Abilities._(this._ability, this._answers, this._difficulty, this._seen);

  /// Every answer in [reviews], oldest first, played through the model.
  factory Abilities.replay(
    Iterable<({String cardId, String deckId, DrillMode mode, int grade})>
    reviews, {
    SkillMap skills = const SkillMap(),
  }) {
    final abilities = Abilities._(
      <AbilityKey, double>{},
      <AbilityKey, int>{},
      <String, double>{},
      <String, int>{},
    );
    for (final r in reviews) {
      abilities.add(
        cardId: r.cardId,
        deckId: r.deckId,
        mode: r.mode,
        grade: r.grade,
        skills: skills,
      );
    }
    return abilities;
  }

  final Map<AbilityKey, double> _ability;
  final Map<AbilityKey, int> _answers;
  final Map<String, double> _difficulty;
  final Map<String, int> _seen;

  /// The language a card id names: `te` for `te-0053` (ADR-0018).
  static String languageOf(String cardId) {
    final dash = cardId.indexOf('-');
    return dash < 0 ? cardId : cardId.substring(0, dash);
  }

  /// How far one answer moves an estimate made from [n] answers before it:
  /// large at first, smaller as answers add up (Pelánek 2016, α 1, β 0.05).
  static double k(int n) => 1 / (1 + 0.05 * n);

  /// The chance of a right answer for [ability] against [difficulty].
  static double expected(double ability, double difficulty) =>
      1 / (1 + math.exp(difficulty - ability));

  /// Plays one answer through the model: in its own skill, and, if right,
  /// in each skill [skills] says it implies, by that skill's own surprise
  /// times its share.
  void add({
    required String cardId,
    required DrillMode mode,
    required int grade,
    String deckId = '',
    SkillMap skills = const SkillMap(),
  }) {
    final right = grade >= Fsrs.passingGrade;
    _move(cardId, mode, right ? 1.0 : 0.0, 1);
    if (!right) return;
    for (final MapEntry(key: other, value: share)
        in skills.impliedBy(mode, deckId).entries) {
      _move(cardId, other, 1.0, share, counted: false);
    }
  }

  /// Moves the ability in [mode] and the pair's difficulty by [share] of
  /// how surprising [result] was. Only an answer in the skill itself is
  /// [counted] toward how many answers an estimate rests on.
  void _move(
    String cardId,
    DrillMode mode,
    double result,
    double share, {
    bool counted = true,
  }) {
    final key = (language: languageOf(cardId), mode: mode);
    final pair = '$cardId/${mode.name}';
    final ability = _ability[key] ?? 0;
    final difficulty = _difficulty[pair] ?? 0;
    final surprise = result - expected(ability, difficulty);
    _ability[key] = ability + share * k(_answers[key] ?? 0) * surprise;
    _difficulty[pair] = difficulty - share * k(_seen[pair] ?? 0) * surprise;
    if (!counted) return;
    _answers[key] = (_answers[key] ?? 0) + 1;
    _seen[pair] = (_seen[pair] ?? 0) + 1;
  }

  /// The learner's ability in [mode] in [language], 0 before any answer.
  double of(String language, DrillMode mode) =>
      _ability[(language: language, mode: mode)] ?? 0;

  /// How many answers [of] rests on.
  int answersIn(String language, DrillMode mode) =>
      _answers[(language: language, mode: mode)] ?? 0;

  /// The chance, from 0 to 1, that the learner answers a pair of average
  /// difficulty right in [mode] in [language]: the strength shown on
  /// Progress.
  double strength(String language, DrillMode mode) =>
      expected(of(language, mode), 0);

  /// Every language and schedule with at least one answer of its own.
  Iterable<AbilityKey> get keys => _answers.keys;
}
