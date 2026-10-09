import 'drill_mode.dart';
import 'rule.dart';

class CardExample {
  const CardExample({
    required this.target,
    required this.native,
    this.reading,
    this.ipa,
    this.bases = const <CardBase>[],
  });

  final String target;
  final String native;

  /// [target] romanised, for an example in a script that needs it.
  final String? reading;

  /// [target] in the IPA, broad, without slashes.
  final String? ipa;

  /// The base words of [target]'s inflected or derived words.
  final List<CardBase> bases;
}

/// What a note is about (B1 format, spec 6).
enum NoteKind {
  /// A word that sounds almost the same: the minimal-pair partner.
  pair,

  /// A custom, a habit or a fact about the culture, with its source.
  culture,

  /// How the word is used: register, a fixed phrase, a false friend.
  usage,

  /// How the word behaves: its stem, its plural, its irregular forms.
  behaviour,

  /// Anything else, and every note written as plain text.
  note,
}

/// One note on a card.
class CardNote {
  const CardNote({
    required this.id,
    required this.kind,
    required this.text,
    this.ref,
    this.source,
    this.regions = const <String>[],
  });

  /// The note's id, or its 1-based position for a note written without one.
  /// The app remembers which notes it has shown by card id and note id.
  final String id;

  final NoteKind kind;

  /// The note, in the learner's language, its placeholders filled.
  final String text;

  /// A pair note's partner, by card id.
  final String? ref;

  /// Where a culture note's claim can be checked.
  final String? source;

  /// A region note's regions (ADR-0036): ids of regions of the language's
  /// path, where the word is used or heard as the note says. Empty for a
  /// note about every region.
  final List<String> regions;
}

/// The base word of an inflected or derived word in a card's target or in
/// one of its examples: by the card that teaches it ([ref]), or written in
/// full ([base]) with its reading and meaning.
class CardBase {
  const CardBase({
    required this.word,
    this.ref,
    this.base,
    this.reading,
    this.ipa,
    this.meaning,
    this.wiktionary = false,
  });

  /// The word as it stands in the text.
  final String word;

  /// The card teaching the base; null for a base written in full.
  final String? ref;

  /// The base written in full; null for a base given by [ref].
  final String? base;

  /// [base] romanised.
  final String? reading;

  /// [base] in the IPA.
  final String? ipa;

  /// [base]'s meaning in the learner's language.
  final String? meaning;

  /// Whether Wiktionary in the learner's language has an entry for [base].
  final bool wiktionary;
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
    this.wiktionary,
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
  final List<CardNote>? notes;
  final List<CardExample>? examples;
  final Set<DrillMode>? modes;

  /// Whether Wiktionary has an entry for the word, in this deck's native
  /// language; null when the ref does not say, and the written card's mark
  /// is taken as its notes are.
  final bool? wiktionary;

  /// [written] as this ref lists it in [deckId]. A deck taught from the
  /// language [written] was written for takes the card's own native-side
  /// fields where the ref gives none. A deck taught from another language
  /// takes none of its notes, tags, alternative meanings, examples or
  /// Wiktionary mark, and is null when the ref gives no [native]. The card's
  /// [reading], [ipa] and [modes], which belong to the word, come across
  /// either way unless the ref gives its own, and so do its phrasebook mark,
  /// bases, rules and rule cell, which a ref cannot give.
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
      notes: notes ?? (sameNative ? written.notes : const <CardNote>[]),
      audio: written.audio,
      examples:
          examples ?? (sameNative ? written.examples : const <CardExample>[]),
      modes: modes ?? written.modes,
      pair: written.pair,
      picture: written.picture,
      phrasebook: written.phrasebook,
      bases: written.bases,
      rules: written.rules,
      wiktionary: wiktionary ?? (sameNative && written.wiktionary),
      rule: written.rule,
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
    this.notes = const <CardNote>[],
    this.audio,
    this.examples = const <CardExample>[],
    this.modes = const <DrillMode>{},
    this.pair,
    this.picture,
    this.phrasebook = false,
    this.bases = const <CardBase>[],
    this.rules = const <String>[],
    this.wiktionary = false,
    this.rule,
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

  /// Its notes, in order. A note written as plain text is one note of kind
  /// [NoteKind.note].
  final List<CardNote> notes;

  /// Asset path or URL overriding TTS for this card.
  final String? audio;

  final List<CardExample> examples;

  /// Which drills this card takes part in. Empty means "all applicable",
  /// resolved against the deck by [modesIn].
  final Set<DrillMode> modes;

  /// The id of a word that sounds almost the same, its minimal-pair partner,
  /// such as కాలం (time) for కలం (pen). Hear offers its meaning among the
  /// options, so that a learner who confuses the two is caught (ADR-0034).
  final String? pair;

  /// A picture of what the word means, for a concrete word: one emoji, drawn
  /// from Noto Emoji ([picturePath]). A cue beside the meaning in Write, and
  /// beside each meaning Hear offers (ADR-0034).
  final String? picture;

  /// Whether the card is one of the course's phrasebook chunks: taught whole
  /// in the first lessons, never held back, its words not counted as taught
  /// by it.
  final bool phrasebook;

  /// The base words of the target's inflected or derived words.
  final List<CardBase> bases;

  /// The rules the sentence uses, by rule id, such as `te-rule-ki`.
  final List<String> rules;

  /// Whether Wiktionary in the learner's language has an entry for the
  /// target. The link is built from the target, not stored.
  final bool wiktionary;

  /// For a rules table's cell, its rule and word; null for any other card.
  final RuleCell? rule;

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
            (speechAvailable || mode != DrillMode.speaking) &&
            // Removed by the choose question (spec 4.8).
            mode != DrillMode.grammarUnderstood)
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

  /// The first part of [native], split as [meanings] splits it, or all of
  /// it: the meaning a rule cell's prompt expresses ("mother").
  String get firstMeaning {
    final parts = _parts(native);
    return parts.isEmpty ? native : parts.first;
  }

  /// Every meaning a typed meaning is graded against (ADR-0034): [native]
  /// whole, then each part of it between `/`, `;` and `,` outside brackets,
  /// then [altNative], each once. `to go, to leave` accepts `to go`.
  List<String> get meanings {
    final seen = <String>{};
    return <String>[
      for (final m in <String>[native, ..._parts(native), ...altNative])
        if (m.isNotEmpty && seen.add(m)) m,
    ];
  }

  static List<String> _parts(String text) {
    final parts = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == '(' || c == '[') depth++;
      if ((c == ')' || c == ']') && depth > 0) depth--;
      if (depth == 0 && (c == '/' || c == ';' || c == ',')) {
        parts.add(text.substring(start, i).trim());
        start = i + 1;
      }
    }
    if (parts.isEmpty) return const <String>[];
    return parts..add(text.substring(start).trim());
  }

  /// The accepted answers for [mode], the first being the canonical one.
  List<String> acceptedAnswers(DrillMode mode) => switch (mode) {
    DrillMode.recognition ||
    DrillMode.reading => <String>[native, ...altNative],
    DrillMode.production ||
    DrillMode.listening ||
    DrillMode.grammarUnderstood ||
    DrillMode.grammar ||
    DrillMode.speaking => <String>[target, ...altTarget],
  };

  /// What the learner is shown. A rules table's cell typed as
  /// [DrillMode.grammar] shows its word, with its reading, before the
  /// meaning to express, so that only the rule is tested:
  /// "అమ్మ (amma): with mother".
  String promptFor(DrillMode mode) => switch (mode) {
    DrillMode.recognition || DrillMode.reading => target,
    DrillMode.grammar when rule != null => switch (rule!.wordReading) {
      final reading? => '${rule!.wordTarget} ($reading): $native',
      null => '${rule!.wordTarget}: $native',
    },
    DrillMode.production ||
    DrillMode.grammarUnderstood ||
    DrillMode.grammar ||
    DrillMode.speaking => native,
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

/// The words of [text] as the validator's `_words` splits them, for
/// comparing a text's words with its `bases` and with the words a course
/// teaches (spec 8.3): split at white space; within each piece, every
/// punctuation mark, symbol or separator except `’` and `'` splits it too;
/// `’` and `'` are stripped from each end; and what is left empty or is all
/// digits is dropped. Unlike the validator, this does not NFC-normalise
/// (#28).
List<String> wordsForBases(String text) => <String>[
  for (final chunk in text.split(_pySpace))
    for (final piece in chunk.replaceAll(_baseBreak, ' ').split(_pySpace))
      if (piece.replaceAll(_edgeApostrophes, '') case final word
          when word.isNotEmpty && !_allDigits.hasMatch(word))
        word,
];

/// A punctuation mark, symbol or separator other than an apostrophe.
final RegExp _baseBreak = RegExp(r"(?!['’])[\p{P}\p{S}\p{Z}]", unicode: true);
final RegExp _edgeApostrophes = RegExp(r"^['’]+|['’]+$");
final RegExp _allDigits = RegExp(r'^\p{Nd}+$', unicode: true);

/// White space as Python's `str.split()` sees it.
final RegExp _pySpace = RegExp(
  r'[\t-\r\x1C-\x20\x85\xA0  - '
  r'    　]+',
);

/// The tiles of [text] to put in order (#347): its [wordsOf] in lowercase,
/// without the marks at their edges, which are tiles of their own, so that
/// neither a capital nor a mark shows where a word goes. An apostrophe or a
/// hyphen inside a word stays in it.
List<String> tilesOf(String text) {
  final tiles = <String>[];
  for (final word in wordsOf(text)) {
    final parts = _edges.firstMatch(word)!;
    tiles
      ..addAll(_characters(parts[1]!))
      ..add(parts[2]!.toLowerCase())
      ..addAll(_characters(parts[3]!));
  }
  return <String>[
    for (final tile in tiles)
      if (tile.isNotEmpty) tile,
  ];
}

Iterable<String> _characters(String text) =>
    text.runes.map(String.fromCharCode);

final RegExp _edges = RegExp(
  r'^([^\p{L}\p{M}\p{N}]*)(.*?)([^\p{L}\p{M}\p{N}]*)$',
  unicode: true,
  dotAll: true,
);

final RegExp _letter = RegExp(r'\p{L}', unicode: true);
final RegExp _space = RegExp(r'\s+');

/// The bundled image of [emoji], a card's [Card.picture]: Noto Emoji's
/// picture of it, named by its code points in hex of at least four digits,
/// joined by `_`, without the variation selector U+FE0F
/// (`tools/pictures.py` copies it under this name).
String picturePath(String emoji) {
  final points = <String>[
    for (final rune in emoji.runes)
      if (rune != 0xfe0f) rune.toRadixString(16).padLeft(4, '0'),
  ];
  return 'assets/pictures/emoji_u${points.join('_')}.png';
}
