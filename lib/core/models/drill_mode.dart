/// The skills Fluenough drills, and the schedules it keeps per word.
///
/// Scheduling state is tracked per `(card, mode)` rather than per card:
/// recognising a word is easier than producing it, which is easier again than
/// recognising it by ear, and one shared interval would over-drill the easy
/// direction while under-drilling the hard one.
///
/// The skill model (ADR-0034) keeps four schedules per word:
/// **Recognition** ([recognition]), **Hear** ([listening]), **Say**
/// ([speaking]) and **Write** ([production]), and grammar's. The names are stored in the review log, which is never
/// rewritten, so they stay as they were.
enum DrillMode {
  /// Recognition: shown the target, choose or recall the meaning. A skill
  /// of its own, scheduled like the others (ADR-0034).
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

  /// Grammar understood: shown the meaning to express ("with mother"),
  /// choose its form among the forms of the same word. Only a rules
  /// table's cells take it (B1 format, spec 4.7). Stored by this name, so
  /// its place here does not matter to the log; it comes before [grammar]
  /// so that a session ordered by [values] asks the choice before the typed
  /// form. Machine-graded.
  grammarUnderstood,

  /// Grammar produced: shown an inflection prompt, type the inflected form.
  /// Machine-graded. Its name, and what every logged review in it means, is
  /// unchanged by [grammarUnderstood].
  grammar,

  /// Say: shown the meaning, say the target. Graded from what the phone's
  /// speech recogniser heard, so it needs one for the language (#89,
  /// ADR-0014).
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
