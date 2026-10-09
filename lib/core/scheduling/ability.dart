import 'dart:math' as math;

import '../models/drill_mode.dart';
import 'fsrs.dart';

/// One ability: a language learned, in one schedule.
typedef AbilityKey = ({String language, DrillMode mode});

/// What the app has learned about a learner's strengths (ADR-0034): an Elo
/// rating per language and schedule, and a difficulty per pair, each moved
/// after every answer by how surprising it was (Pelánek 2016). The skills of
/// a word share what is learned, weighted by [relatedness]; each keeps its
/// own schedule.
///
/// Derived from the review log alone, like every scheduling state, so it can
/// always be rebuilt.
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

  /// The skills of a word, which inform each other: an answer in one moves
  /// the learner's ability and the word's difficulty in the others too.
  /// Grammar and reading are asked of their own cards, and stay apart.
  static const Set<DrillMode> wordSkills = <DrillMode>{
    DrillMode.recognition,
    DrillMode.production,
    DrillMode.listening,
    DrillMode.speaking,
  };

  /// How much an answer in one skill of a word moves the others, against
  /// its own: the correlation between knowing words by ear and in writing,
  /// about .68 (Milton & Hopkins 2006). The research gives no figure per
  /// pair of skills, so one is used for all.
  static const double relatedness = 0.68;

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
    final language = languageOf(cardId);
    final key = (language: language, mode: mode);
    final pair = '$cardId/${mode.name}';
    final result = grade >= Fsrs.passingGrade ? 1.0 : 0.0;
    final surprise =
        result - expected(_ability[key] ?? 0, _difficulty[pair] ?? 0);
    // The skills are related but separable (ADR-0034): an answer moves the
    // other skills of a word too, by [relatedness] of what it moves its own.
    for (final other in wordSkills.contains(mode) ? wordSkills : {mode}) {
      final weight = other == mode ? 1.0 : relatedness;
      final otherKey = (language: language, mode: other);
      final otherPair = '$cardId/${other.name}';
      _ability[otherKey] =
          (_ability[otherKey] ?? 0) +
          weight * k(_answers[otherKey] ?? 0) * surprise;
      _difficulty[otherPair] =
          (_difficulty[otherPair] ?? 0) -
          weight * k(_seen[otherPair] ?? 0) * surprise;
    }
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
