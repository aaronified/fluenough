import '../models/card.dart';
import '../models/creator.dart' show CreatorImage;
import '../models/deck.dart' show Deck;
import 'adult_gate.dart' show isAdultDeck, isRudeCard, isUnratedAdultDeck;
import 'language_summary.dart';

// The credits the Sources page lists, found from a language's decks: pure
// Dart, so that the unit job of a language can put them in its summary and
// the page can list every language's from the directory (ADR-0062,
// Plan-Lazy-Language-Loading, P-C5).

/// A project whose data the decks may use, credited on the Sources page
/// when a deck names it (ADR-0040).
enum ContentCredit {
  /// Word data, CC BY-SA 4.0 (#518).
  wiktionary(<String>['wiktionary']),

  /// Recordings and images, each under its own licence and credit (#518,
  /// #523).
  commons(<String>['wikimedia commons', 'commons.wikimedia.org']),

  /// Drawings of what words mean, CC BY-SA 4.0 (#523).
  openmoji(<String>['openmoji']),

  /// Frequency, counted from each language's Wikipedia, CC BY-SA (#516).
  wikipedia(<String>['wikipedia']),

  /// Sentences, CC BY 2.0 FR.
  tatoeba(<String>['tatoeba']),

  /// Signs written in SignWriting, pictures drawn with the Sutton fonts under
  /// SIL OFL 1.1.
  signwriting(<String>['signwriting']);

  const ContentCredit(this.marks);

  /// How a source names the project, in lower case: its name or its host.
  final List<String> marks;

  /// Whether [source] names this project.
  bool namedIn(String source) {
    final text = source.toLowerCase();
    return marks.any(text.contains);
  }
}

/// The sources [card]'s data names, item by item (#506, #518): its
/// examples', its items' and senses', its frequency's, and its recording's.
Iterable<String> cardSources(Card card) sync* {
  for (final example in card.examples) {
    if (example.source case final source?) yield source;
  }
  for (final items in <List<CardItem>>[
    card.synonyms,
    card.antonyms,
    card.collocations,
    card.confusables,
    card.forms,
  ]) {
    for (final item in items) {
      if (item.source case final source?) yield source;
    }
  }
  for (final sense in card.senses) {
    if (sense.source case final source?) yield source;
  }
  if (card.frequency case final frequency?) yield frequency.source;
  if (card.audioCredit case final credit?) yield credit.source;
  if (card.imageCredit case final credit?) yield credit.source;
}

/// One credit of a language's recordings and pictures: whom, and the
/// licence.
typedef MediaCreditLine = ({String credit, String license});

/// The credits of [card]'s own files: its recording's and its image's.
List<MediaCredit> mediaCredits(Card card) => <MediaCredit>[
  ?card.audioCredit,
  ?card.imageCredit,
];

/// What [decks], the decks of one language, credit, for its summary: each
/// deck's own `source` with the deck's kind, each recording's and image's
/// credit and licence, the projects whose data any of them names, and the
/// credits of [images], the portraits and posters of the language's people
/// and works. Every line is once, in the order the decks come, and tells
/// whether only adult decks and rude cards gave it, so that the page leaves
/// it out while Adult content is off. An adult deck no native speaker has
/// rated is no learner's, and credits nothing.
SummaryCredits creditsOfDecks(
  Iterable<Deck> decks,
  Iterable<CreatorImage> images,
) {
  final named = <String, ({String kind, bool adult})>{};
  final media = <MediaCreditLine, bool>{};
  final content = <ContentCredit, bool>{};
  for (final deck in decks) {
    if (isUnratedAdultDeck(deck)) continue;
    final plain = <String>{};
    final rude = <String>{};
    if (deck.source case final book?) {
      final adult = isAdultDeck(deck);
      (adult ? rude : plain).add(book);
      final kept = named[book];
      named[book] = (
        kind: kept?.kind ?? deck.kind.name,
        adult: (kept?.adult ?? true) && adult,
      );
    }
    for (final card in deck.cards) {
      final isRude = isRudeCard(card, deck);
      (isRude ? rude : plain).addAll(cardSources(card));
      for (final credit in mediaCredits(card)) {
        final line = (credit: credit.credit, license: credit.license);
        media[line] = (media[line] ?? true) && isRude;
      }
    }
    for (final project in ContentCredit.values) {
      final given = plain.any(project.namedIn);
      if (given || rude.any(project.namedIn)) {
        content[project] = (content[project] ?? true) && !given;
      }
    }
  }
  final pictures = <MediaCreditLine>{};
  for (final image in images) {
    final credit = image.author ?? image.credit;
    final licence = image.licence;
    if (credit == null || licence == null) continue;
    pictures.add((credit: credit, license: licence));
  }
  return SummaryCredits(
    sources: <SummaryCreditLine>[
      for (final MapEntry(key: book, value: found) in named.entries)
        SummaryCreditLine(text: book, extra: found.kind, adult: found.adult),
    ],
    media: <SummaryCreditLine>[
      for (final MapEntry(key: line, value: adult) in media.entries)
        SummaryCreditLine(text: line.credit, extra: line.license, adult: adult),
    ],
    pictures: <SummaryCreditLine>[
      for (final line in pictures)
        SummaryCreditLine(text: line.credit, extra: line.license),
    ],
    content: <SummaryCreditLine>[
      for (final MapEntry(key: project, value: adult) in content.entries)
        SummaryCreditLine(text: project.name, adult: adult),
    ],
  );
}
