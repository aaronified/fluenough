import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/review/deck_review.dart';
import '../decks/path_model.dart' show unitTitle;
import '../decks/unreviewed_notice.dart';
import '../decks/word_sheet.dart' show adultContentOn;
import 'review_words.dart';

/// What is waiting for review, in the reviewer's languages
/// (docs/plans/deck-browser.md, owner, 2026-10-09: "any reviewer should
/// also know what all is pending unreviewed in their chosen languages").
///
/// Per language: the units and decks not yet signed off, with how many
/// cards each has left; the offensive words not yet rated; the sound-alike
/// and look-alike pairs not yet confirmed; and what the reviewer has
/// reviewed but not sent. Read from the decks and the reviews on this
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

/// Whether [card] of [deck] needs nothing more from this reviewer: marked
/// right or with a suggestion, rated if it is rude, and its pair checked
/// if it is like a rude word and [adult] content shows it. A rude word
/// [adult] content hides is never checked: it counts as left.
bool cardChecked(AppState state, DeckEntry deck, Card card, bool adult) {
  final rude = isRudeIn(deck, card);
  if (rude && !adult) return false;
  final review = state.reviewing.reviewOf(deck, card);
  if (review == null) return false;
  // A rude word is rated, not marked right.
  if (rude ? review.rating == null : !review.marked) return false;
  if (adult && rudeAlikesOf(state, card).isNotEmpty && review.alike == null) {
    return false;
  }
  return true;
}

/// A deck waiting for review, and how many of its cards are left to check.
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

  /// Words like a rude one, in decks not yet signed off, whose pair this
  /// reviewer has not confirmed or rejected.
  final List<WaitingCard> unconfirmed;

  /// Its decks this reviewer has reviewed and not sent.
  final List<DeckReview> unsent;

  /// Every deck waiting, in the path's units or not.
  Iterable<WaitingDeck> get allDecks =>
      units.expand((u) => u.decks).followedBy(decks);

  bool get isEmpty =>
      units.isEmpty &&
      decks.isEmpty &&
      unrated.isEmpty &&
      unconfirmed.isEmpty &&
      unsent.isEmpty;
}

/// What waits for review in [language], with adult content on or not as
/// [adult] says (the setting, by default).
WaitingLanguage waitingIn(
  AppState state,
  LanguageInfo language, {
  bool? adult,
}) {
  final shows = adult ?? adultContentOn(state);
  final code = language.code;
  WaitingDeck count(DeckEntry deck) => (
    deck: deck,
    left: deck.cards.where((c) => !cardChecked(state, deck, c, shows)).length,
    total: deck.cards.length,
  );

  final units = <WaitingUnit>[];
  final inCourse = <String>{};
  for (final (i, unit) in state.courseUnits(code).indexed) {
    inCourse.addAll(unit.map((e) => e.id));
    final waiting = <WaitingDeck>[
      for (final deck in unit)
        if (awaitsReview(state, deck)) count(deck),
    ];
    if (waiting.isNotEmpty) {
      units.add((number: i + 1, title: unitTitle(state, unit), decks: waiting));
    }
  }
  final others = <WaitingDeck>[
    for (final deck in state.decks)
      if (deck.language.code == code &&
          !inCourse.contains(deck.id) &&
          awaitsReview(state, deck))
        count(deck),
  ];

  final unrated = <WaitingCard>[];
  final unconfirmed = <WaitingCard>[];
  for (final waiting in <WaitingDeck>[
    for (final unit in units) ...unit.decks,
    ...others,
  ]) {
    final deck = waiting.deck;
    for (final card in deck.cards) {
      final review = state.reviewing.reviewOf(deck, card);
      if (isRudeIn(deck, card) && review?.rating == null) {
        unrated.add((deck: deck, card: card));
      }
      if (review?.alike == null && rudeAlikesOf(state, card).isNotEmpty) {
        unconfirmed.add((deck: deck, card: card));
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
  );
}

/// Whether [unit]'s decks have one waiting for review in a language this
/// reviewer reviews, with reviewing on: the path's "To review" mark.
bool unitToReview(AppState state, List<DeckEntry> unit) {
  final reviewing = state.reviewing;
  if (!reviewing.on || reviewing.code == null || unit.isEmpty) return false;
  final code = unit.first.language.code;
  if (!reviewLanguagesOf(state).any((l) => l.code == code)) return false;
  return unit.any((deck) => awaitsReview(state, deck));
}
