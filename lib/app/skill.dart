import '../core/models/drill_mode.dart';
import 'features.dart';

/// A skill the interface shows: the four [DrillMode]s, plus minimal pairs.
///
/// Minimal pairs are drawn in the design (a mode pill, a settings switch, a
/// summary row) but are not a [DrillMode]: the deck format has no pair data
/// yet, and adding the mode needs an ADR (#31). So the interface counts five
/// skills while the scheduler knows four. [mode] is null for [pair].
///
/// Icons, labels and colours for a skill are in `lib/ui`: `SkillVisuals` in
/// `lib/ui/skill_visuals.dart` and `ModeColors` in `lib/ui/theme.dart`.
enum Skill {
  recognition(DrillMode.recognition, Feature.drillRecognition),
  production(DrillMode.production, Feature.drillProduction),
  listening(DrillMode.listening, Feature.drillListening),
  grammar(DrillMode.grammar, Feature.drillGrammar),
  pair(null, Feature.drillPair);

  const Skill(this.mode, this.feature);

  /// The scheduler's mode, or null for [pair], which has none yet.
  final DrillMode? mode;

  /// The feature that switches this skill's drill on.
  final Feature feature;

  static Skill of(DrillMode mode) => switch (mode) {
    DrillMode.recognition => Skill.recognition,
    DrillMode.production => Skill.production,
    DrillMode.listening => Skill.listening,
    DrillMode.grammar => Skill.grammar,
  };

  /// Whether drilling this skill needs a voice for the language.
  bool get needsVoice => this == Skill.listening || this == Skill.pair;
}
