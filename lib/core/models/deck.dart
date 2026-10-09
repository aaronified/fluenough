import 'author.dart';
import 'card.dart';
import 'grammar_pattern.dart';
import 'reading.dart';
import 'rule.dart';

class LanguageInfo {
  const LanguageInfo({
    required this.code,
    required this.iso639_3,
    required this.name,
    this.script = 'latin',
    this.tts,
    this.rtl = false,
    this.icon,
  });

  /// BCP-47 primary subtag, e.g. `hi`: the tag voices and the article table
  /// key on.
  final String code;

  /// Three-letter ISO 639-3 code, e.g. `hin`. Names the language
  /// unambiguously, including languages with no two-letter code, beside
  /// [code] rather than instead of it.
  final String iso639_3;

  final String name;
  final String script;
  final bool rtl;

  /// BCP-47 voice tag from the deck, if it declared one.
  final String? tts;

  /// What the language's chip shows: the first letter of its own name, as
  /// हि for Hindi (ADR-0027). Null for a deck that gives none.
  final String? icon;

  /// The tag handed to the TTS engine. Falls back to the bare language code,
  /// which leaves the regional accent to the device — acceptable, but decks
  /// for languages with major regional variation should set it explicitly.
  String get ttsTag => tts ?? code;

  /// Whether this script needs a romanisation shown alongside the target.
  bool get needsReading =>
      !const {'latin', 'cyrillic', 'greek'}.contains(script);

  /// Leading articles ignored when grading typed answers.
  ///
  /// Deliberately data rather than code: a language without articles returns an
  /// empty list and the grading pass becomes a no-op.
  List<String> get articles => switch (code) {
    'es' => const ['el', 'la', 'los', 'las', 'un', 'una'],
    'fr' => const ['le', 'la', 'les', 'un', 'une', "l'"],
    'de' => const ['der', 'die', 'das', 'ein', 'eine'],
    'it' => const ['il', 'lo', 'la', 'i', 'gli', 'le', 'un', 'una'],
    'pt' => const ['o', 'a', 'os', 'as', 'um', 'uma'],
    'nl' => const ['de', 'het', 'een'],
    'en' => const ['the', 'a', 'an'],
    _ => const <String>[],
  };
}

/// What a deck holds: cards, a pattern table that expands into cards,
/// passages with questions, which are its cards (#98, ADR-0019), or a rules
/// table, whose cells are its cards (B1 format, spec 4).
enum DeckKind { vocab, grammar, reading, rules }

class Deck {
  const Deck({
    required this.id,
    required this.name,
    required this.kind,
    required this.language,
    required this.native,
    required this.license,
    required this.cards,
    this.pattern,
    this.passages = const <Passage>[],
    this.description,
    this.tags = const <String>[],
    this.authors = const <Author>[],
    this.source,
    this.theme,
    this.refs = const <CardRef>[],
    this.table,
    this.rules = const <Rule>[],
  });

  final String id;
  final String name;
  final DeckKind kind;
  final LanguageInfo language;
  final LanguageInfo native;

  /// SPDX identifier for the *content*, independent of the app's licence.
  final String license;

  /// For a grammar deck these are the expanded pattern cells, so the rest of
  /// the app never needs to know which kind of deck it came from.
  final List<Card> cards;

  /// A grammar deck's pattern table; null for a vocab deck. A parsed grammar
  /// deck has this set and [cards] empty until the expander fills them.
  final GrammarPattern? pattern;

  /// A reading deck's passages, in order; empty for any other deck. Their
  /// questions are its [cards], as `QuestionCard`s.
  final List<Passage> passages;

  final String? description;
  final List<String> tags;
  final List<Author> authors;
  final String? source;

  /// The theme this deck teaches, by its id in `decks/themes.yaml`, such as
  /// `market`. Null for a deck outside the theme path (ADR-0010).
  final String? theme;

  /// Cards written in other decks, listed here by id: unresolved until the
  /// catalog has every deck, and then folded into [cards] (ADR-0018).
  final List<CardRef> refs;

  /// A rules deck's table; null for any other deck. A merged rules deck has
  /// this set and [cards] empty until its cells are expanded.
  final RuleTable? table;

  /// A rules deck's rules that its layer gives, for the lesson's teach step:
  /// a rule its layer leaves out is not taught, and its cells are not asked.
  final List<Rule> rules;

  int get cardCount => cards.length;

  /// This deck with [cards] in place of its own, and no refs left: a grammar
  /// deck once its pattern is expanded, or a deck once its refs are resolved.
  Deck withCards(List<Card> cards) => Deck(
    id: id,
    name: name,
    kind: kind,
    language: language,
    native: native,
    license: license,
    cards: cards,
    pattern: pattern,
    passages: passages,
    description: description,
    tags: tags,
    authors: authors,
    source: source,
    theme: theme,
    table: table,
    rules: rules,
  );

  @override
  String toString() => 'Deck($id, ${cards.length} cards)';
}

/// Whether [card], in a deck of [kind], counts as a word (spec 8.5): the
/// words a unit plans and a course teaches. True for a card of a vocab deck
/// that is not a phrasebook chunk nor a phrase, and is one word by
/// [wordsForBases] or a noun, verb, adjective, adverb or pronoun of several
/// words. Grammar and rules cells and reading questions are not words.
bool countsAsWord(Card card, DeckKind kind) =>
    kind == DeckKind.vocab &&
    !card.phrasebook &&
    card.pos != 'phrase' &&
    (wordsForBases(card.target).length == 1 ||
        const {'noun', 'verb', 'adj', 'adv', 'pronoun'}.contains(card.pos));
