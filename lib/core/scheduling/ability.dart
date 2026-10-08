import 'dart:math' as math;

import '../models/drill_mode.dart';
import 'fsrs.dart';

/// One ability: a language learned, in one schedule.
typedef AbilityKey = ({String language, DrillMode mode});

/// What the app has learned about a learner's strengths (ADR-0034): an Elo
/// rating per language and schedule, and a difficulty per pair, each moved
/// after every answer by how surprising it was (Pelánek 2016).
///
/// Derived from the review log alone, like every scheduling state, so it can
/// always be rebuilt. Recognition, which schedules nothing, is left out.
class Abilities {
  Abilities._(this._ability, this._answers, this._difficulty, this._seen);

  /// Every answer in [reviews], oldest first, played through the model.
  factory Abilities.replay(
    Iterable<({String cardId, DrillMode mode, int grade})> reviews,
  ) {
    final abilities = Abilities._(
      <AbilityKey, double>{},
      <AbilityKey, int>{},
      <String, double>{},
      <String, int>{},
    );
    for (final r in reviews) {
      abilities.add(cardId: r.cardId, mode: r.mode, grade: r.grade);
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

  /// Plays one answer through the model.
  void add({
    required String cardId,
    required DrillMode mode,
    required int grade,
  }) {
    if (!mode.isScheduled) return;
    final key = (language: languageOf(cardId), mode: mode);
    final pair = '$cardId/${mode.name}';
    final ability = _ability[key] ?? 0;
    final difficulty = _difficulty[pair] ?? 0;
    final result = grade >= Fsrs.passingGrade ? 1.0 : 0.0;
    final surprise = result - expected(ability, difficulty);
    final answers = _answers[key] ?? 0;
    final seen = _seen[pair] ?? 0;
    _ability[key] = ability + k(answers) * surprise;
    _difficulty[pair] = difficulty - k(seen) * surprise;
    _answers[key] = answers + 1;
    _seen[pair] = seen + 1;
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

  /// Every language and schedule with at least one answer.
  Iterable<AbilityKey> get keys => _ability.keys;
}
