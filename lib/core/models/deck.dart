import 'author.dart';
import 'card.dart';
import 'card_set.dart';
import 'grammar_pattern.dart';
import 'proposal.dart';
import 'reading.dart';
import 'rule.dart';

class LanguageInfo {
  const LanguageInfo({
    required this.code,
    required this.iso639_3,
    required this.name,
    this.script = 'latin',
    this.scripts = const <String>[],
    this.tts,
    this.rtl = false,
    this.icon,
    this.typed = true,
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

  /// For a language written in several scripts, all of them, [script]
  /// first (`scripts`, #623): `devanagari` and `perso_arabic` for
  /// Hindustani. Empty where the deck names one, so use [allScripts].
  final List<String> scripts;

  /// Every script the language is written in, [script] first.
  List<String> get allScripts => scripts.isEmpty ? <String>[script] : scripts;

  final bool rtl;

  /// Whether this text runs right to left: the deck says so ([rtl]), or its
  /// [script] does, as Hindustani's Perso-Arabic does though its deck is
  /// not marked right to left (it is first a Devanagari course).
  bool get rightToLeft => rtl || rtlScripts.contains(script);

  /// BCP-47 voice tag from the deck, if it declared one.
  final String? tts;

  /// What the language's chip shows: the first letter of its own name, as
  /// हि for Hindi (ADR-0027). Null for a deck that gives none.
  final String? icon;

  /// Whether an answer in this language can be typed. False for the IPA
  /// (`script: ipa`), which has no keyboard: production is asked by
  /// choosing (ADR-0041). Braille is typed, on the app's own keyboard
  /// ([keyboard], ADR-0043).
  final bool typed;

  /// This language written in [other], one of its [allScripts] (#623):
  /// the same language in that script's direction, for text drawn in it.
  LanguageInfo inScript(String other) => other == script
      ? this
      : LanguageInfo(
          code: code,
          iso639_3: iso639_3,
          name: name,
          script: other,
          scripts: scripts,
          tts: tts,
          rtl: rtlScripts.contains(other),
          icon: icon,
          typed: typed,
        );

  /// The scripts that run right to left.
  static const Set<String> rtlScripts = <String>{
    'arabic',
    'perso_arabic',
    'shahmukhi',
    'hebrew',
    'thaana',
    'syriac',
    'nko',
    'adlam',
  };

  /// Whether this is the IPA, a notation taught like a language
  /// (ADR-0041): its cards' examples are in other languages.
  bool get isIpa => script == 'ipa';

  /// Whether this is braille, a script taught as a course of its own
  /// (ADR-0043): English Braille, Unified English Braille.
  bool get isBraille => script == 'braille';

  /// Whether this is a notation taught like a language: the IPA
  /// (ADR-0041) or braille (ADR-0043). It has no voice, is learned only
  /// when chosen, is placed by nothing, and is complete once its path is
  /// written.
  bool get isNotation => isIpa || isBraille;

  /// The app's own keyboard that answers in this language are typed on,
  /// in place of the phone's, or null for the phone's: braille's six dots
  /// (ADR-0043). Named by the script, so that a deck needs no new field.
  ScriptKeyboard? get keyboard => isBraille ? ScriptKeyboard.braille : null;

  /// The tag handed to the TTS engine. Falls back to the bare language code,
  /// which leaves the regional accent to the device — acceptable, but decks
  /// for languages with major regional variation should set it explicitly.
  String get ttsTag => tts ?? code;

  /// Whether this script needs a romanisation shown alongside the target.
  /// Not the notations: an IPA symbol or a braille cell is read as written,
  /// and its print equivalent is its meaning (ADR-0043).
  bool get needsReading =>
      !const {'latin', 'cyrillic', 'greek', 'ipa', 'braille'}.contains(script);

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

/// A keyboard the app draws for a script the phone has none for
/// ([LanguageInfo.keyboard], ADR-0043).
enum ScriptKeyboard {
  /// Six dots in the Perkins layout, entered a cell at a time.
  braille,
}

/// What a deck holds: cards, a pattern table that expands into cards,
/// passages with questions, which are its cards (#98, ADR-0019), or a rules
/// table, whose cells are its cards (DECK-FORMAT.md, Rules decks).
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
    this.proposals = const <String, List<Proposal>>{},
    this.checkedBy = const <String, List<String>>{},
    this.verified = const <String, List<String>>{},
    this.sets = const <CardSet>[],
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

  /// What reviewers have proposed for its cards, by card id, waiting for
  /// agreement (ADR-0038). Only reviewer mode shows them.
  final Map<String, List<Proposal>> proposals;

  /// The rater codes of the reviewers who signed each card off, by card id
  /// (#449): its `checked_by`, which the review bot writes. A card no one
  /// has checked is not in it.
  final Map<String, List<String>> checkedBy;

  /// The data points of each card the reviewers have settled with agreeing
  /// "yes" answers, by card id (#519): its `verified`, which the review bot
  /// writes. Each is `meaning`, `example:<8 hex>`, `confusable:<id>` or
  /// `sound`. The daily questions do not ask about them again.
  final Map<String, List<String>> verified;

  /// Its set cards (DECK-FORMAT.md, Set cards), in order: taught only,
  /// never in [cards], so never scheduled, asked or logged.
  final List<CardSet> sets;

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
    proposals: proposals,
    checkedBy: checkedBy,
    verified: verified,
    sets: sets,
  );

  @override
  String toString() => 'Deck($id, ${cards.length} cards)';
}

/// Whether [card], in a deck of [kind], counts as a word (DECK-FORMAT.md, The
/// B1 plan): the words a unit plans and a course teaches. True for a card of a
/// vocab deck that is not a phrasebook chunk nor a phrase, and is one word by
/// its `words`, where the deck gives them, else by [wordsForBases], or a
/// noun, verb, adjective, adverb or pronoun of several words. Grammar and
/// rules cells and reading questions are not words.
bool countsAsWord(Card card, DeckKind kind) =>
    kind == DeckKind.vocab &&
    !card.phrasebook &&
    card.pos != 'phrase' &&
    ((card.words?.length ?? wordsForBases(card.target).length) == 1 ||
        const {'noun', 'verb', 'adj', 'adv', 'pronoun'}.contains(card.pos));
