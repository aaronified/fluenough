import 'author.dart';
import 'card.dart';
import 'grammar_pattern.dart';

class LanguageInfo {
  const LanguageInfo({
    required this.code,
    required this.iso639_3,
    required this.name,
    this.script = 'latin',
    this.tts,
    this.rtl = false,
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

enum DeckKind { vocab, grammar }

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
    this.description,
    this.tags = const <String>[],
    this.authors = const <Author>[],
    this.source,
    this.theme,
    this.refs = const <CardRef>[],
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
    description: description,
    tags: tags,
    authors: authors,
    source: source,
    theme: theme,
  );

  @override
  String toString() => 'Deck($id, ${cards.length} cards)';
}
