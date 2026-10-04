import 'drill_mode.dart';

class CardExample {
  const CardExample({
    required this.target,
    required this.native,
    this.language,
    this.reading,
    this.ipa,
  });

  final String target;
  final String native;

  /// The language [target] is in, by code, where it is not the deck's: the
  /// IPA course's example words are Hindi, Telugu or Spanish, and are played
  /// in that language's voice.
  final String? language;

  /// [target] romanised, for an example in a script that needs it.
  final String? reading;

  /// [target] in the IPA, broad, without slashes.
  final String? ipa;
}

/// A card written in another deck, listed in this one by its id (ADR-0018).
///
/// A card id names a word of the language learned, not a deck or a course,
/// so a word met again in another deck, or from another native language, is
/// the same card with one schedule. The ref may give the native-side fields
/// this deck wants; the card's target, its alternatives and its part of
/// speech stay the card's own.
class CardRef {
  const CardRef({
    required this.id,
    required this.position,
    this.native,
    this.reading,
    this.ipa,
    this.altNative,
    this.tags,
    this.notes,
    this.examples,
    this.modes,
  });

  final String id;

  /// Where the ref sits in its deck's `cards`, from 0, written cards
  /// counted, so that the deck keeps its order once the ref is resolved.
  final int position;

  // Each null when the ref does not give it.
  final String? native;
  final String? reading;
  final String? ipa;
  final List<String>? altNative;
  final List<String>? tags;
  final String? notes;
  final List<CardExample>? examples;
  final Set<DrillMode>? modes;

  /// [written] as this ref lists it in [deckId]. A deck taught from the
  /// language [written] was written for takes the card's own native-side
  /// fields where the ref gives none. A deck taught from another language
  /// takes none of its notes, tags, alternative meanings or examples, and is
  /// null when the ref gives no [native]. The card's [reading], [ipa] and
  /// [modes], which belong to the word, come across either way unless the
  /// ref gives its own.
  Card? resolve(
    Card written, {
    required String deckId,
    required bool sameNative,
  }) {
    final native = this.native ?? (sameNative ? written.native : null);
    if (native == null) return null;
    return Card(
      id: id,
      deckId: deckId,
      target: written.target,
      native: native,
      reading: reading ?? written.reading,
      altReading: reading == null ? written.altReading : const <String>[],
      ipa: ipa ?? written.ipa,
      altTarget: written.altTarget,
      altNative:
          altNative ?? (sameNative ? written.altNative : const <String>[]),
      pos: written.pos,
      gender: written.gender,
      tags: tags ?? (sameNative ? written.tags : const <String>[]),
      notes: notes ?? (sameNative ? written.notes : null),
      audio: written.audio,
      examples:
          examples ?? (sameNative ? written.examples : const <CardExample>[]),
      modes: modes ?? written.modes,
    );
  }
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
    this.ipa,
    this.altReading = const <String>[],
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
  /// history hangs off, so it must never be reused or renumbered. It names
  /// the language learned and a number, such as `bn-0042`, and is the same in
  /// every deck that lists the card (ADR-0018).
  final String id;

  /// The deck this card is listed in. A card in two decks is two [Card]s
  /// with one [id], and one schedule.
  final String deckId;

  final String target;
  final String native;

  /// Romanisation, for non-Latin scripts: ISO 15919 letters for the Indic
  /// languages, spelled as the word is said (ADR-0025).
  final String? reading;

  /// How the word is said, in the IPA: broad, without the slashes, as
  /// `paːlu` (ADR-0025).
  final String? ipa;

  /// The readings of [altTarget], for a grammar cell that lists several
  /// forms: accepted too when the answer is typed in Latin letters (#47).
  final List<String> altReading;

  /// Every reading a romanised answer is compared with, [reading] first.
  /// Empty for a card with none.
  List<String> get readings => <String>[?reading, ...altReading];

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
  /// and speaking, except that a phrase (`pos: phrase`) is not typed: a
  /// whole sentence is too hard to grade fairly (ADR-0010). A phrase of two
  /// words or more is produced by putting its words in order instead
  /// ([rearranges], ADR-0024). A phrase can be spoken, since the recogniser
  /// does the writing (ADR-0014).
  Set<DrillMode> modesIn({
    required bool ttsAvailable,
    bool speechAvailable = false,
  }) {
    final declared = modes.isNotEmpty
        ? modes
        : pos == 'phrase' && !rearranges
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

  /// Whether producing this card is asked by putting its words in order
  /// rather than typing it (ADR-0024): a sentence of three words or more,
  /// or a phrase of two or more.
  bool get rearranges {
    final words = wordsOf(target).length;
    return words >= 3 || (pos == 'phrase' && words >= 2);
  }

  /// The accepted answers for [mode], the first being the canonical one.
  List<String> acceptedAnswers(DrillMode mode) => switch (mode) {
    DrillMode.recognition ||
    DrillMode.reading => <String>[native, ...altNative],
    DrillMode.production ||
    DrillMode.listening ||
    DrillMode.grammar ||
    DrillMode.speaking => <String>[target, ...altTarget],
  };

  /// What the learner is shown.
  String promptFor(DrillMode mode) => switch (mode) {
    DrillMode.recognition || DrillMode.reading => target,
    DrillMode.production || DrillMode.grammar || DrillMode.speaking => native,
    // The listening prompt is the audio itself; the text is withheld until
    // the answer is in.
    DrillMode.listening => '',
  };

  @override
  String toString() => 'Card($id: $target = $native)';
}

/// The words of [text], split at spaces, without what holds no letter, such
/// as a dash standing alone. Punctuation stays with its word.
List<String> wordsOf(String text) => <String>[
  for (final word in text.trim().split(_space))
    if (_letter.hasMatch(word)) word,
];

final RegExp _letter = RegExp(r'\p{L}', unicode: true);
final RegExp _space = RegExp(r'\s+');
