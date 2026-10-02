import '../core/models/drill_mode.dart';
import 'features.dart';

/// A skill the interface shows: the [DrillMode]s, plus minimal pairs.
///
/// Minimal pairs are drawn in the design (a mode pill, a settings switch, a
/// summary row) but are not a [DrillMode]: the deck format has no pair data
/// yet, and adding the mode needs an ADR (#31). So the interface counts one
/// more skill than the scheduler knows modes. [mode] is null for [pair].
///
/// Icons, labels and colours for a skill are in `lib/ui`: `SkillVisuals` in
/// `lib/ui/skill_visuals.dart` and `ModeColors` in `lib/ui/theme.dart`.
enum Skill {
  recognition(DrillMode.recognition, Feature.drillRecognition),
  production(DrillMode.production, Feature.drillProduction),
  listening(DrillMode.listening, Feature.drillListening),
  speaking(DrillMode.speaking, Feature.drillSpeaking),
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
    DrillMode.speaking => Skill.speaking,
  };

  /// Whether drilling this skill needs a voice for the language.
  bool get needsVoice => this == Skill.listening || this == Skill.pair;

  /// Whether drilling this skill needs the microphone and a speech
  /// recogniser for the language (ADR-0014).
  bool get needsMicrophone => this == Skill.speaking;

  /// Whether the skill can be paused for an hour or switched off per
  /// language: the ones that need sound, out loud or in the ear (#89).
  bool get pausable => this == Skill.listening || this == Skill.speaking;

  /// Whether the skill starts switched on. Speaking starts off: switching it
  /// on asks for the microphone, which the app never does unasked.
  bool get onByDefault => this != Skill.speaking;
}
