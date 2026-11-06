import '../models/card.dart';
import '../models/sound_contrasts.dart';

// What the question builder reads of one learner's language: plain data,
// handed in by the caller (the feature layer maps the catalog, the path and
// the script check's decks to it). Nothing here loads a file or touches
// Flutter (wiki/Plan-Placement-V2.md, "Step 2: question generators").

/// One word deck of the path, in path order.
class PlacementDeck {
  const PlacementDeck({
    required this.id,
    required this.cards,
    this.grammarFamilies = const <String>[],
  });

  final String id;

  /// The deck's cards, in deck order. A card is read as the app reads it:
  /// its `native` is in the learner's native language.
  final List<Card> cards;

  /// The concept families the path's unit holding this deck teaches (the
  /// `grammar:` topics of its `PlanUnit`, such as `plural` or `postpositions`);
  /// empty for a deck of a unit that teaches no grammar. A deck with families
  /// is a **grammar unit** for topic 3.
  final List<String> grammarFamilies;

  bool get isGrammar => grammarFamilies.isNotEmpty;
}

/// A word of the course spelled in a script, as the script check reads it
/// (`ScriptWord` in `lib/app/placement.dart`): [card], and [spelling] in the
/// script.
class PlacementScriptWord {
  const PlacementScriptWord({required this.card, required this.spelling});

  final Card card;
  final String spelling;
}

/// One script of the course that a script check asks about, as the script
/// check reads its decks: the cards of the decks that teach letters, those
/// that teach joined forms (vowel signs, conjuncts), and the course's words
/// spelled in it.
class PlacementScriptData {
  const PlacementScriptData({
    required this.script,
    this.letters = const <Card>[],
    this.joined = const <Card>[],
    this.words = const <PlacementScriptWord>[],
  });

  /// The script's own code, such as `bengali`.
  final String script;

  final List<Card> letters;
  final List<Card> joined;
  final List<PlacementScriptWord> words;
}

/// Everything the builder needs of one learner's language.
class PlacementLanguageData {
  PlacementLanguageData({
    required this.language,
    required List<PlacementDeck> decks,
    this.scripts = const <PlacementScriptData>[],
    this.sounds,
    this.levelMarkDecks = const <int>[],
    this.stableCardIds = const <String>{},
    this.pairAudioTrusted = false,
    this.pairsFromDecks = true,
    this.deckPairSwaps,
  }) : decks = List<PlacementDeck>.unmodifiable(decks) {
    for (final (i, deck) in this.decks.indexed) {
      for (final card in deck.cards) {
        _deckOf.putIfAbsent(card.id, () => i);
        _byId.putIfAbsent(card.id, () => card);
      }
    }
  }

  /// The language's code, such as `bn`.
  final String language;

  /// The word decks of the path in order, as `walkDecks` gives them: index 0
  /// is the first, the last is B1's end.
  final List<PlacementDeck> decks;

  /// The scripts the course checks, in path order; empty for a language
  /// written in Latin letters.
  final List<PlacementScriptData> scripts;

  /// `decks/<lang>/<lang>-sounds.yaml`; null where the language has none.
  final SoundContrasts? sounds;

  /// The deck indexes where A1, A2 and B1 end (the path's level marks); only
  /// the ones the path marks. Used to say which level an item belongs to.
  final List<int> levelMarkDecks;

  /// Cards the learner reviews with high stability: a stable card says
  /// "learned in the app", not "known before", so it is never asked
  /// (section 2.2).
  final Set<String> stableCardIds;

  /// Whether the voice's pair audio has been checked on this device for the
  /// language (section 8, item 4). Nothing checks it yet, so it defaults to
  /// false and every pair question is marked untrusted.
  final bool pairAudioTrusted;

  /// Whether a language with no sounds file may get its minimal pairs from
  /// the decks (plan section 8, item 1: Spanish). False for Toki Pona, whose
  /// stated fallback is complex words. On, a pair is two words of the decks
  /// that differ in one letter, and only where that swap is in
  /// [deckPairSwaps] (or the built-in list of the language): a swap of two
  /// letters that are not two phonemes of the language (an accent, a silent
  /// letter, a spelling variant) is never a pair.
  final bool pairsFromDecks;

  /// The letter swaps that are real, distinct sounds of this language, as
  /// letter pairs, for the pairs taken from the decks where there is no
  /// sounds file. Null takes [deckPairSwapsByLanguage] for [language]; empty
  /// (or no entry) means no deck pair can be built.
  final List<(String, String)>? deckPairSwaps;

  /// The swaps a deck-derived pair may differ by: [deckPairSwaps], else the
  /// built-in ones of [language], and none when [pairsFromDecks] is off.
  List<(String, String)> get effectiveDeckPairSwaps => !pairsFromDecks
      ? const <(String, String)>[]
      : (deckPairSwaps ??
            deckPairSwapsByLanguage[language] ??
            const <(String, String)>[]);

  final Map<String, int> _deckOf = <String, int>{};
  final Map<String, Card> _byId = <String, Card>{};

  /// The number of decks, the `N` of the plan.
  int get deckCount => decks.length;

  /// The index of the deck holding the card [id], or null.
  int? deckIndexOf(String id) => _deckOf[id];

  /// The card [id] of the course, or null.
  Card? cardById(String id) => _byId[id];

  /// The level a deck belongs to, 1 for A1, 2 for A2, 3 for B1, 0 for a deck
  /// the path marks no level for.
  int levelOfDeck(int index) {
    for (final (i, mark) in levelMarkDecks.indexed) {
      if (index <= mark) return i + 1;
    }
    return 0;
  }
}

/// The built-in letter swaps that tell two sounds apart, for the languages
/// with no sounds file whose minimal pairs come from the decks. Only swaps of
/// letters that are two phonemes of the language belong here: Spanish `si` and
/// `sí` (an accent), `ola` and `hola` (a silent h) and `b` and `v` (one
/// sound) are not contrasts and are left out on purpose.
const Map<String, List<(String, String)>> deckPairSwapsByLanguage =
    <String, List<(String, String)>>{
      'es': <(String, String)>[
        ('p', 'b'),
        ('t', 'd'),
        ('p', 't'),
        ('b', 'd'),
        ('m', 'n'),
        ('n', 'ñ'),
        ('l', 'r'),
        ('a', 'e'),
        ('a', 'i'),
        ('a', 'o'),
        ('a', 'u'),
        ('e', 'i'),
        ('e', 'o'),
        ('e', 'u'),
        ('i', 'o'),
        ('i', 'u'),
        ('o', 'u'),
      ],
    };
