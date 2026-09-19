/// The four skills Fluenough drills.
///
/// Scheduling state is tracked per `(card, mode)` rather than per card:
/// recognising a word is easier than producing it, which is easier again than
/// recognising it by ear, and one shared interval would over-drill the easy
/// direction while under-drilling the hard one.
enum DrillMode {
  /// Shown the target, recall the meaning. Self-assessed.
  recognition,

  /// Shown the meaning, type the target. Machine-graded.
  production,

  /// Hear the target, type it. Machine-graded, needs a TTS voice.
  listening,

  /// Shown an inflection prompt, type the inflected form. Machine-graded.
  grammar;

  /// Whether the app grades this mode itself.
  ///
  /// Recognition is self-assessed: judging a free-text translation is beyond
  /// what an offline app should attempt.
  bool get isMachineGraded => this != DrillMode.recognition;

  static DrillMode? tryParse(String value) {
    for (final mode in DrillMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }
}
