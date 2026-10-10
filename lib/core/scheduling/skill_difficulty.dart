import '../models/drill_mode.dart';
import 'fsrs.dart';

/// How hard a card is for this learner in one skill: FSRS's difficulty D
/// of the pair, read from its state (docs/plans/difficulty-by-skill.md).
///
/// There is no other measure. A pair has no D until its first answer in
/// that skill, so a skill never answered has no [SkillDifficulty] at all,
/// and new words are still picked by `Difficulty.of(card)`. Reviews and
/// quick revision do not read it (owner, 2026-10-10); Inspect shows it.
///
/// Pure: nothing here imports Flutter.
class SkillDifficulty {
  const SkillDifficulty(this.mode, this.difficulty);

  /// The skill, as the scheduler keys it.
  final DrillMode mode;

  /// FSRS's D, from 1 (easiest) to 10 (hardest).
  final double difficulty;

  /// D rounded to a whole number from 1 to 10, as it is shown.
  int get shown => difficulty.round().clamp(1, 10);

  /// Which way D leans: [DifficultyLean.easier] up to 4, [harder] from 7,
  /// otherwise [middling]. A first answer of Good gives about 2, a first
  /// miss about 6.4; each further miss raises D and each right answer
  /// lowers it, so the ends are reached by answers, not by one guess.
  DifficultyLean get lean => switch (shown) {
    <= 4 => DifficultyLean.easier,
    >= 7 => DifficultyLean.harder,
    _ => DifficultyLean.middling,
  };

  /// The D of each skill [cardId] has been answered in, in the order of
  /// [DrillMode.values]; none for a skill it has not. [stateOf] is the
  /// pair's state, or null before its first answer.
  static List<SkillDifficulty> of(
    String cardId,
    FsrsState? Function(String cardId, DrillMode mode) stateOf,
  ) => <SkillDifficulty>[
    for (final mode in DrillMode.values)
      if (stateOf(cardId, mode) case final state?)
        SkillDifficulty(mode, state.difficulty),
  ];

  @override
  bool operator ==(Object other) =>
      other is SkillDifficulty &&
      other.mode == mode &&
      other.difficulty == difficulty;

  @override
  int get hashCode => Object.hash(mode, difficulty);

  @override
  String toString() => 'SkillDifficulty(${mode.name}, D: $difficulty)';
}

/// Which way a [SkillDifficulty] leans, for wording it plainly.
enum DifficultyLean { easier, middling, harder }
