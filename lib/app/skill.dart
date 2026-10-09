import '../core/models/drill_mode.dart';
import 'features.dart';

/// A skill the interface shows: the [DrillMode]s, plus minimal pairs. One
/// switch in Settings each (ADR-0034: one switch per skill).
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

  /// Grammar understood: a rules table's form shown, its meaning chosen
  /// (B1 format spec 4.7). A skill of its own, with its own schedule and
  /// switch, sharing [grammar]'s tile on Today ([tile]) and its colour.
  /// Before [grammar], as understood comes before produced.
  grammarUnderstood(DrillMode.grammarUnderstood, Feature.drillGrammar),

  /// Grammar produced: the form chosen or typed. Its tile on Today is
  /// grammar understood's too.
  grammar(DrillMode.grammar, Feature.drillGrammar),

  /// Passages with questions (#98, ADR-0019). Heard, a passage's questions
  /// are [listening]'s.
  reading(DrillMode.reading, Feature.drillReading),
  pair(null, Feature.drillPair);

  const Skill(this.mode, this.feature);

  /// The scheduler's mode, or null for [pair], which has none yet.
  final DrillMode? mode;

  /// The feature that switches this skill's drill on.
  final Feature feature;

  static Skill of(DrillMode mode) => switch (mode) {
    DrillMode.recognition => Skill.recognition,
    DrillMode.production => Skill.production,
    DrillMode.reading => Skill.reading,
    DrillMode.listening => Skill.listening,
    DrillMode.grammarUnderstood => Skill.grammarUnderstood,
    DrillMode.grammar => Skill.grammar,
    DrillMode.speaking => Skill.speaking,
  };

  /// The skill whose tile on Today counts and starts this one: grammar
  /// understood shares grammar's, as understood and produced share one tile
  /// (ADR-0034, decided 2026-10-08). Every other skill is its own.
  Skill get tile => this == Skill.grammarUnderstood ? Skill.grammar : this;

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
