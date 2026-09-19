import 'card.dart';

class LanguageInfo {
  const LanguageInfo({
    required this.code,
    required this.name,
    this.script = 'latin',
    this.tts,
    this.rtl = false,
  });

  final String code;
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
  bool get needsReading => !const {'latin', 'cyrillic', 'greek'}.contains(script);

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
    this.description,
    this.tags = const <String>[],
    this.authors = const <String>[],
    this.source,
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

  final String? description;
  final List<String> tags;
  final List<String> authors;
  final String? source;

  int get cardCount => cards.length;

  @override
  String toString() => 'Deck($id, ${cards.length} cards)';
}
