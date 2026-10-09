import '../core/models/drill_mode.dart';
import 'features.dart';

/// A skill the interface shows: the [DrillMode]s, plus minimal pairs.
///
/// Minimal pairs are drawn in the design (a mode pill, a settings switch, a
/// summary row) but are not a [DrillMode]: the deck format has no pair data
/// yet, and adding the mode needs an ADR (#31). So the interface counts one
/// more skill than the scheduler knows modes. [mode] is null for [pair].
///
/// Grammar is one skill with two schedules (B1 format spec 4.7, 4.8 item
/// 7): understood ([DrillMode.grammarUnderstood]) and produced
/// ([DrillMode.grammar]) share its tile on Today and its switch in
/// Settings, so [modes] gives both.
///
/// Icons, labels and colours for a skill are in `lib/ui`: `SkillVisuals` in
/// `lib/ui/skill_visuals.dart` and `ModeColors` in `lib/ui/theme.dart`.
enum Skill {
  recognition(DrillMode.recognition, Feature.drillRecognition),
  production(DrillMode.production, Feature.drillProduction),
  listening(DrillMode.listening, Feature.drillListening),
  speaking(DrillMode.speaking, Feature.drillSpeaking),
  grammar(DrillMode.grammar, Feature.drillGrammar),

  /// Passages with questions (#98, ADR-0019). Heard, a passage's questions
  /// are [listening]'s.
  reading(DrillMode.reading, Feature.drillReading),
  pair(null, Feature.drillPair);

  const Skill(this.mode, this.feature);

  /// The scheduler's mode, or null for [pair], which has none yet. For
  /// [grammar], produced; [modes] adds understood.
  final DrillMode? mode;

  /// Every mode this skill's switch, tile and review cover: [mode], and for
  /// [grammar] understood before it, as a lesson asks it first. Empty for
  /// [pair].
  Set<DrillMode> get modes => switch (this) {
    Skill.grammar => const <DrillMode>{
      DrillMode.grammarUnderstood,
      DrillMode.grammar,
    },
    _ => <DrillMode>{?mode},
  };

  /// The feature that switches this skill's drill on.
  final Feature feature;

  static Skill of(DrillMode mode) => switch (mode) {
    DrillMode.recognition => Skill.recognition,
    DrillMode.production => Skill.production,
    DrillMode.reading => Skill.reading,
    DrillMode.listening => Skill.listening,
    // Understood and produced share the grammar tile (skill model,
    // 2026-10-08) and its switch (B1 format spec 4.7, 4.8 item 7).
    DrillMode.grammarUnderstood || DrillMode.grammar => Skill.grammar,
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
