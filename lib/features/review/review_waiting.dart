import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/review/deck_review.dart';
import '../decks/path_model.dart' show unitTitle;
import '../decks/unreviewed_notice.dart';
import 'review_words.dart';

/// What is waiting for review, in the reviewer's languages
/// (docs/plans/deck-browser.md, owner, 2026-10-09: "any reviewer should
/// also know what all is pending unreviewed in their chosen languages").
///
/// Per language: the units and decks not yet signed off, with how many
/// cards each has left, its offensive words aside; the offensive words,
/// which are reviewed apart and only on purpose (owner, 2026-10-10), and
/// how many are not yet rated, and the sound-alike and look-alike pairs
/// not yet confirmed, which that review checks too, since a pair names its
/// rude word; and what the reviewer has reviewed but not sent. Read from the decks and the reviews on this
/// phone, not kept: it changes as the reviewer reviews.

/// The languages [state]'s reviewer reviews, in the catalog's order: those
/// they chose in Settings, or before they chose, the languages they speak
/// that the app teaches.
List<LanguageInfo> reviewLanguagesOf(AppState state) {
  final chosen =
      state.settings.reviewLanguages ?? state.settings.spokenLanguages.toSet();
  return <LanguageInfo>[
    for (final language in state.languages)
      if (chosen.contains(language.code)) language,
  ];
}

/// Whether [deck] waits for a native speaker's sign-off: its file still
/// says no speaker has checked it (`unreviewed`), and this reviewer has not
/// signed it off on this phone.
bool awaitsReview(AppState state, DeckEntry deck) =>
    UnreviewedNotice.appliesTo(deck) &&
    state.reviewing.reviews.of(deck.id)?.signedOff == null;

/// Whether [card] of [deck], a word of the ordinary review, needs nothing
/// more from this reviewer there: marked right or with a suggestion.
///
/// A word like a rude one is checked here like any other: its pair names
/// the rude word, so it is confirmed in the language's Offensive words
/// review, opened on purpose, and never holds up the unit's sign-off
/// (owner, 2026-10-10). A rude word is never in the ordinary review.
bool cardChecked(AppState state, DeckEntry deck, Card card) =>
    !isRudeIn(deck, card) &&
    (state.reviewing.reviewOf(deck, card)?.marked ?? false);

/// A deck waiting for review, and how many of its cards are left to check,
/// its offensive words aside: they are counted in its language's Offensive
/// words review.
typedef WaitingDeck = ({DeckEntry deck, int left, int total});

/// A unit of the course's path with a deck waiting for review.
typedef WaitingUnit = ({int number, String title, List<WaitingDeck> decks});

/// A card waiting for something particular: a rating, or its pair checked.
typedef WaitingCard = ({DeckEntry deck, Card card});

/// What waits for review in one language.
class WaitingLanguage {
  const WaitingLanguage({
    required this.language,
    this.units = const <WaitingUnit>[],
    this.decks = const <WaitingDeck>[],
    this.unrated = const <WaitingCard>[],
    this.unconfirmed = const <WaitingCard>[],
    this.unsent = const <DeckReview>[],
    this.offensive = 0,
    this.pairs = 0,
  });

  final LanguageInfo language;

  /// The units of its course's path with a deck not yet signed off, in
  /// order.
  final List<WaitingUnit> units;

  /// Its decks outside the course's path not yet signed off: those taught
  /// from another language, or that the path leaves out.
  final List<WaitingDeck> decks;

  /// Rude words, in decks not yet signed off, this reviewer has not rated.
  final List<WaitingCard> unrated;

  /// How many offensive words the language has, in all its decks, rated or
  /// not: whether it has an Offensive words review to open.
  final int offensive;

  /// Words like a rude one, in decks not yet signed off, whose pair this
  /// reviewer has not confirmed or rejected: checked in the Offensive words
  /// review, with or without adult content, since that review asks its
  /// own 18+ question. Never among a deck's cards left.
  final List<WaitingCard> unconfirmed;

  /// How many words of the language are like a rude one, checked or not.
  final int pairs;

  /// Whether the language has an Offensive words review to open: a rude
  /// word, or a word like one.
  bool get hasOffensiveReview => offensive > 0 || pairs > 0;

  /// Its decks this reviewer has reviewed and not sent.
  final List<DeckReview> unsent;

  /// Every deck waiting, in the path's units or not.
  Iterable<WaitingDeck> get allDecks =>
      units.expand((u) => u.decks).followedBy(decks);

  /// Whether nothing waits for this reviewer. The Offensive words review
  /// may still be listed beside it, saying none of its words wait: it is
  /// opened on purpose, whether or not anything waits in it.
  bool get isEmpty =>
      units.isEmpty &&
      decks.isEmpty &&
      unrated.isEmpty &&
      unconfirmed.isEmpty &&
      unsent.isEmpty;
}

/// What waits for review in [language]. The adult content setting changes
/// none of it: offensive words and the pairs that name them wait in the
/// Offensive words review, which asks its own 18+ question.
WaitingLanguage waitingIn(AppState state, LanguageInfo language) {
  final code = language.code;
  // The ordinary review's cards: a deck's rude words are reviewed apart.
  WaitingDeck count(DeckEntry deck) {
    final cards = <Card>[
      for (final card in deck.cards)
        if (!isRudeIn(deck, card)) card,
    ];
    return (
      deck: deck,
      left: cards.where((c) => !cardChecked(state, deck, c)).length,
      total: cards.length,
    );
  }

  // A deck of rude words only waits in the Offensive words review alone.
  bool waits(DeckEntry deck) =>
      awaitsReview(state, deck) && hasOrdinaryCards(deck);

  final units = <WaitingUnit>[];
  final inCourse = <String>{};
  for (final (i, unit) in state.courseUnits(code).indexed) {
    inCourse.addAll(unit.map((e) => e.id));
    final waiting = <WaitingDeck>[
      for (final deck in unit)
        if (waits(deck)) count(deck),
    ];
    if (waiting.isNotEmpty) {
      units.add((number: i + 1, title: unitTitle(state, unit), decks: waiting));
    }
  }
  final others = <WaitingDeck>[
    for (final deck in state.decks)
      if (deck.language.code == code &&
          !inCourse.contains(deck.id) &&
          waits(deck))
        count(deck),
  ];

  final unrated = <WaitingCard>[];
  final unconfirmed = <WaitingCard>[];
  var offensive = 0;
  var pairs = 0;
  for (final deck in state.decks) {
    if (deck.language.code != code) continue;
    final waiting = awaitsReview(state, deck);
    for (final card in deck.cards) {
      final review = state.reviewing.reviewOf(deck, card);
      if (isRudeIn(deck, card)) {
        offensive++;
        if (waiting && review?.rating == null) {
          unrated.add((deck: deck, card: card));
        }
      } else if (rudeAlikesOf(state, card).isNotEmpty) {
        pairs++;
        if (waiting && review?.alike == null) {
          unconfirmed.add((deck: deck, card: card));
        }
      }
    }
  }

  return WaitingLanguage(
    language: language,
    units: units,
    decks: others,
    unrated: unrated,
    unconfirmed: unconfirmed,
    unsent: <DeckReview>[
      for (final deck in state.reviewing.unsent)
        if (deck.language == code) deck,
    ],
    offensive: offensive,
    pairs: pairs,
  );
}

/// Whether [unit]'s decks have one waiting for review in a language this
/// reviewer reviews, with reviewing on: the path's "To review" mark. A deck
/// of offensive words only never marks its unit: those words are reviewed
/// only on purpose, from the Offensive words review.
bool unitToReview(AppState state, List<DeckEntry> unit) {
  final reviewing = state.reviewing;
  if (!reviewing.on || reviewing.code == null || unit.isEmpty) return false;
  final code = unit.first.language.code;
  if (!reviewLanguagesOf(state).any((l) => l.code == code)) return false;
  return unit.any(
    (deck) => awaitsReview(state, deck) && hasOrdinaryCards(deck),
  );
}
