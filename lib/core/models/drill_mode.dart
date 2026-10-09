/// The skills Fluenough drills, and the schedules it keeps per word.
///
/// Scheduling state is tracked per `(card, mode)` rather than per card:
/// recognising a word is easier than producing it, which is easier again than
/// recognising it by ear, and one shared interval would over-drill the easy
/// direction while under-drilling the hard one.
///
/// The skill model (ADR-0034) keeps four schedules per word:
/// **Recognition** ([recognition]), **Hear** ([listening]), **Say**
/// ([speaking]) and **Write** ([production]); and grammar's two, understood
/// ([grammarUnderstood]) and produced ([grammar]). The names are stored in
/// the review log, which is never rewritten, so they stay as they were.
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

  /// Grammar understood: shown a form, అమ్మతో (ammatō), choose what it
  /// means among the meanings of the same word's forms: "with mother", "to
  /// mother" (owner, 2026-10-09; B1 format spec 4.7, OPEN-22). Only a rules
  /// table's cells take it. Stored by this name, so its place here does not
  /// matter to the log; it comes before [grammar] so that a session ordered
  /// by [values] asks the meaning before the form, as Recognition comes
  /// before Write. Machine-graded.
  grammarUnderstood,

  /// Grammar produced: shown the meaning to express, give the form. On a
  /// pattern deck's cell, typed; on a rules table's cell, chosen among the
  /// same word's forms while the pair is new or was last missed, then typed
  /// (spec 4.8). Machine-graded. Its name, and what every logged review in
  /// it means, a typed form, is unchanged by [grammarUnderstood].
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
