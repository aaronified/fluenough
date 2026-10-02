/// The skills Fluenough drills.
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

  /// Read a passage, answer questions about it by choosing. Machine-graded
  /// (#98, ADR-0019). Before listening, so that a new question is read
  /// before it is heard.
  reading,

  /// Hear the target, type it. Machine-graded, needs a TTS voice. For a
  /// reading question, the passage is read aloud and its text is hidden
  /// until the question is answered.
  listening,

  /// Shown an inflection prompt, type the inflected form. Machine-graded.
  grammar,

  /// Shown the meaning, say the target. Graded from what the phone's speech
  /// recogniser heard, so it needs one for the language (#89, ADR-0014).
  speaking;

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
