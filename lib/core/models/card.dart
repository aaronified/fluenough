import 'drill_mode.dart';

class CardExample {
  const CardExample({required this.target, required this.native});

  final String target;
  final String native;
}

/// One item of content.
///
/// The field set is a deliberate superset, chosen so that the same model serves
/// Latin, syllabic and logographic scripts without per-language branching:
/// [reading] carries romanisation for scripts that need it, [altTarget] and
/// [altNative] carry the alternative answers that make automatic grading
/// tolerable, and [modes] lets a card opt out of drills that make no sense for
/// it.
class Card {
  const Card({
    required this.id,
    required this.deckId,
    required this.target,
    required this.native,
    this.reading,
    this.altTarget = const <String>[],
    this.altNative = const <String>[],
    this.pos,
    this.gender,
    this.tags = const <String>[],
    this.notes,
    this.audio,
    this.examples = const <CardExample>[],
    this.modes = const <DrillMode>{},
  });

  /// Stable for the life of the card. This is the key the user's entire review
  /// history hangs off, so it must never be reused or renumbered.
  final String id;
  final String deckId;

  final String target;
  final String native;

  /// Romanisation or phonetic reading, for non-Latin scripts.
  final String? reading;

  /// Extra answers accepted when the learner is typing the target.
  final List<String> altTarget;

  /// Extra answers accepted when the learner is typing the meaning.
  final List<String> altNative;

  final String? pos;
  final String? gender;
  final List<String> tags;
  final String? notes;

  /// Asset path or URL overriding TTS for this card.
  final String? audio;

  final List<CardExample> examples;

  /// Which drills this card takes part in. Empty means "all applicable",
  /// resolved against the deck by [modesIn].
  final Set<DrillMode> modes;

  /// The drills this card can actually be used for, given whether the device
  /// has a voice for the language, and whether it can recognise speech in it.
  ///
  /// A card that declares no modes gets recognition, production, listening
  /// and speaking, except a phrase (`pos: phrase`), which is not typed: a
  /// whole sentence is too hard to grade fairly (ADR-0010). A phrase can be
  /// spoken, since the recogniser does the writing (ADR-0014).
  Set<DrillMode> modesIn({
    required bool ttsAvailable,
    bool speechAvailable = false,
  }) {
    final declared = modes.isNotEmpty
        ? modes
        : pos == 'phrase'
        ? const {DrillMode.recognition, DrillMode.listening, DrillMode.speaking}
        : const {
            DrillMode.recognition,
            DrillMode.production,
            DrillMode.listening,
            DrillMode.speaking,
          };
    return <DrillMode>{
      for (final mode in declared)
        if ((ttsAvailable || mode != DrillMode.listening) &&
            (speechAvailable || mode != DrillMode.speaking))
          mode,
    };
  }

  /// The accepted answers for [mode], the first being the canonical one.
  List<String> acceptedAnswers(DrillMode mode) => switch (mode) {
    DrillMode.recognition => <String>[native, ...altNative],
    DrillMode.production ||
    DrillMode.listening ||
    DrillMode.grammar ||
    DrillMode.speaking => <String>[target, ...altTarget],
  };

  /// What the learner is shown.
  String promptFor(DrillMode mode) => switch (mode) {
    DrillMode.recognition => target,
    DrillMode.production || DrillMode.grammar || DrillMode.speaking => native,
    // The listening prompt is the audio itself; the text is withheld until
    // the answer is in.
    DrillMode.listening => '',
  };

  @override
  String toString() => 'Card($id: $target = $native)';
}
