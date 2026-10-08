/// The skills Fluenough drills, and the schedules it keeps per word.
///
/// Scheduling state is tracked per `(card, mode)` rather than per card:
/// recognising a word is easier than producing it, which is easier again than
/// recognising it by ear, and one shared interval would over-drill the easy
/// direction while under-drilling the hard one.
///
/// The skill model (ADR-0034) keeps three schedules per word: **Hear**
/// ([listening]), **Say** ([speaking]) and **Write** ([production]), and
/// grammar's. The names are stored in the review log, which is never
/// rewritten, so they stay as they were.
enum DrillMode {
  /// Shown the target, choose or recall the meaning. A lesson step only,
  /// not scheduled ([isScheduled]): understanding in writing is taken from
  /// Write (ADR-0034).
  recognition,

  /// Write: shown the meaning, give the word, typed, chosen or put in order.
  /// Machine-graded.
  production,

  /// Read a passage, answer questions about it by choosing. Machine-graded
  /// (#98, ADR-0019). Before listening, so that a new question is read
  /// before it is heard.
  reading,

  /// Hear: the target is played; choose or type its meaning. In script
  /// practice, and for a generated number, what was heard is typed instead.
  /// Machine-graded, needs a TTS voice. For a reading question, the passage
  /// is read aloud and its text is hidden until the question is answered.
  listening,

  /// Shown an inflection prompt, type the inflected form. Machine-graded.
  grammar,

  /// Say: shown the meaning, say the target. Graded from what the phone's
  /// speech recogniser heard, so it needs one for the language (#89,
  /// ADR-0014).
  speaking;

  /// Whether this mode is a schedule: due in reviews, and introduced as a
  /// new pair. Recognition is asked in lessons and logged, but schedules
  /// nothing (ADR-0034).
  bool get isScheduled => this != DrillMode.recognition;

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
