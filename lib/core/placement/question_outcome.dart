import 'placement_questions.dart';

// What the question builder (`question_builder.dart`) says when it cannot turn
// a request into a question, and the note the run controller keeps of it
// (wiki/Plan-Placement-V2.md, "Step 2: question generators"). Kept apart from
// both so that the controller and the builder do not import each other.

/// Why a question could not be built from the learner's data. Each reason is
/// a data gap named in the plan's audit; the run controller maps a reason to
/// the plan's stated fallback ([PlacementRun.markUnavailable]).
enum PlacementUnavailableReason {
  /// The language has no `<lang>-sounds.yaml` and the decks give no pair of
  /// words that differ by one swap (section 8, item 1).
  noSoundsFile,

  /// There is a sounds file, but no two words of the decks differ by exactly
  /// one of its swaps (section 8, item 2).
  noPairFound,

  /// The pair audio is not trusted on this device and the caller asked for
  /// trusted audio only (section 8, item 4).
  pairAudioUntrusted,

  /// No voice: nothing can be played, so a question that needs to be heard is
  /// not asked as one (row j).
  noAudio,

  /// The path has no grammar unit, or no sentence of one has a form to blank
  /// (row l).
  noGrammarFamily,

  /// No sentence of the kind in the decks (a language with no sentences of
  /// three words or more, or an unspaced script whose sentences carry no
  /// `words`).
  noSentences,

  /// No word of the kind in the decks.
  noWords,

  /// The language has no script of its own, or no word spelled in it.
  noScript,

  /// A pick question needs three wrong options of the same kind and the
  /// decks do not give them.
  tooFewDistractors,

  /// Every item of the kind was already asked in this run.
  allAsked,
}

/// One note in a run: [variant], asked after [afterAnswers] answers, could
/// not be built ([PlacementRun.markUnavailable]).
class PlacementUnavailable {
  const PlacementUnavailable({
    required this.afterAnswers,
    required this.variant,
    required this.reason,
  });

  /// How many answers the run had when the note was made.
  final int afterAnswers;

  /// The question that could not be built.
  final PlacementVariant variant;

  final PlacementUnavailableReason reason;
}
