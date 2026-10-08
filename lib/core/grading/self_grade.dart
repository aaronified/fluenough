/// How well the learner says they knew a self-assessed card.
///
/// Recognition is self-assessed (see `DrillMode.isMachineGraded`): the app
/// shows the meaning and the learner rates their own recall. Four gradations,
/// mapped onto the same 0–5 ladder that `AnswerOutcome.toGrade` uses for
/// machine-graded answers, so that a self-rated "Good" and a typed answer with
/// a missing accent schedule the card the same way. FSRS reads [easy]'s 5 as
/// Easy, and an exact typed answer's 5 as Good (ADR-0033):
///
/// | Rating | Grade | Machine-graded equivalent |
/// | --- | --- | --- |
/// | [again] | 1 | wrong |
/// | [hard] | 3 | closeTypo |
/// | [good] | 4 | closeDiacritics |
/// | [easy] | 5 | exact |
///
/// Grade 2 is deliberately unused: 0–2 are all Again, and a fifth button
/// would ask the learner to draw a line the scheduler ignores.
enum SelfGrade {
  /// Did not remember it. FSRS cuts its stability and brings it back sooner:
  /// the next day for a new card.
  again,

  /// Remembered it, with effort.
  hard,

  /// Remembered it.
  good,

  /// Remembered it at once.
  easy;

  /// The grade (0–5) this rating records.
  int toGrade() => switch (this) {
    SelfGrade.again => 1,
    SelfGrade.hard => 3,
    SelfGrade.good => 4,
    SelfGrade.easy => 5,
  };

  /// Whether this rating counts as remembering the card, in a session's score
  /// and for FSRS alike.
  bool get isCorrect => this != SelfGrade.again;
}

/// The learner's verdict on a near miss.
///
/// `AnswerOutcome.closeTypo` is offered for self-assessment rather than marked
/// wrong outright: a slip of the finger and not knowing the word are different
/// events. The learner decides which one it was.
enum TypoJudgement {
  /// "I knew it": a slip. Recorded as grade 3, as `AnswerOutcome.closeTypo`
  /// itself is.
  knewIt,

  /// "Count it wrong": they did not know it. Recorded as grade 1, as
  /// `AnswerOutcome.wrong` is.
  countWrong;

  /// The grade (0–5) this verdict records.
  int toGrade() => switch (this) {
    TypoJudgement.knewIt => 3,
    TypoJudgement.countWrong => 1,
  };

  bool get isCorrect => this == TypoJudgement.knewIt;
}
