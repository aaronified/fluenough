import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/language_skills.dart' show LanguageSkillsOnState;
import '../../app/reviewing.dart' show Reviewing;
import '../../core/decks/deck_index.dart' show IndexLanguage;
import '../../core/decks/language_summary.dart' show SummaryCourse;
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/models/proposal.dart';
import '../../core/review/added_item.dart' show cardHasItem;
import '../../core/review/deck_review.dart';
import '../../core/review/sent_state.dart';
import '../../core/review/review_pairs.dart';
import '../decks/path_model.dart' show unitTitle;
import '../decks/unreviewed_notice.dart';
import 'proposal_card.dart' show partOf;
import 'review_sheets.dart' show partText;
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
/// rude word. Read from the decks and the reviews on this phone, not kept:
/// it changes as the reviewer reviews.
///
/// What the reviewer has reviewed, sent or not, is not per language: it is
/// the "Your reviews" group above them (#471), read by [sentSuggestionsOf]
/// and the reviews' own `unsent`.

/// What [state]'s reviewer has said about themselves (#462): the languages
/// they know, and whether they read each one's script.
ReviewerLanguages reviewerOf(AppState state) => state.reviewerLanguages();

/// The courses with decks on the phone, a language and the one its decks
/// are taught from. Read one language at a time (ADR-0062), from the
/// language directory, so that no unit has to be loaded to know them; read
/// whole, from the decks.
Set<ReviewPair> pairsOnPhone(AppState state) {
  if (!state.readsPerLanguage) {
    return <ReviewPair>{for (final deck in state.decks) pairOf(deck)};
  }
  return <ReviewPair>{
    for (final language in state.languages)
      for (final course in _coursesOf(state, language.code))
        ReviewPair(language.code, course.native),
  };
}

List<SummaryCourse> _coursesOf(AppState state, String code) =>
    state.summaryOf(code)?.courses ?? const <SummaryCourse>[];

/// Every course a reviewer could review (#462), a language and the one its
/// decks are taught from: each in the deck index, downloaded or not, then
/// any other on the phone.
List<ReviewPair> offeredPairs(AppState state) => <ReviewPair>{
  for (final language
      in state.deckDownloads?.index?.languages ?? const <IndexLanguage>[])
    for (final native in language.natives)
      ReviewPair(language.code, native.code),
  ...pairsOnPhone(state),
}.toList();

/// The courses [state]'s reviewer reviews: those they ticked in Languages
/// you review, or the languages they chose before courses (#462). With none
/// ticked, none (owner, 2026-11-05). Only those they can review: both
/// languages known, both scripts read.
///
/// A good signed reviewer key (ADR-0058, W7) adds the courses it names, with
/// no tick and whatever languages or scripts the reviewer said they know: the
/// key replaces the self-declared ticks for those courses.
Set<ReviewPair> reviewPairsOf(AppState state) => <ReviewPair>{
  ...reviewedPairs(
    chosenPairs: state.settings.reviewPairs,
    chosenLanguages: state.settings.reviewLanguages,
    offered: pairsOnPhone(state),
    reviewer: reviewerOf(state),
  ),
  ...keyPairsOf(state),
};

/// The courses [state]'s reviewer key unlocks: the offered and downloaded
/// courses it names, or whose language it names. None without a good key.
Set<ReviewPair> keyPairsOf(AppState state) {
  final key = state.reviewing.key;
  if (key == null) return <ReviewPair>{};
  return <ReviewPair>{
    for (final pair in <ReviewPair>[
      ...offeredPairs(state),
      ...pairsOnPhone(state),
    ])
      if (key.unlocks(pair)) pair,
  };
}

/// The languages [state]'s reviewer reviews in one course or more, in the
/// catalog's order.
List<LanguageInfo> reviewLanguagesOf(AppState state) {
  final targets = <String>{for (final p in reviewPairsOf(state)) p.target};
  return <LanguageInfo>[
    for (final language in state.languages)
      if (targets.contains(language.code)) language,
  ];
}

/// Every language's English name the phone knows, by code: from the deck
/// index, its natives included, and from the decks on the phone.
Map<String, String> languageNamesOf(AppState state) => <String, String>{
  for (final language
      in state.deckDownloads?.index?.languages ??
          const <IndexLanguage>[]) ...<String, String>{
    language.code: language.name,
    for (final native in language.natives) native.code: native.name,
  },
  ..._namesOnPhone(state),
};

/// The names of the languages with decks on the phone, and of the ones they
/// are taught from, by code: from the language directory when the catalog
/// is read one language at a time, else from the decks.
Map<String, String> _namesOnPhone(AppState state) {
  if (!state.readsPerLanguage) {
    return <String, String>{
      for (final deck in state.decks) ...<String, String>{
        deck.language.code: deck.language.name,
        deck.deck.native.code: deck.deck.native.name,
      },
    };
  }
  return <String, String>{
    for (final language in state.languages) ...<String, String>{
      language.code: language.name,
      for (final course in _coursesOf(state, language.code))
        course.native: course.nativeName,
    },
  };
}

/// The course [deck] belongs to, for review.
ReviewPair pairOf(DeckEntry deck) =>
    ReviewPair(deck.language.code, deck.deck.native.code);

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
    this.offensive = 0,
    this.pairs = 0,
    this.reading = false,
  });

  final LanguageInfo language;

  /// Whether the language's decks are still being read (one language at a
  /// time, ADR-0062): nothing is known of what waits in it yet, so it is
  /// drawn as loading and not as empty.
  final bool reading;

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

  /// Every deck waiting, in the path's units or not.
  Iterable<WaitingDeck> get allDecks =>
      units.expand((u) => u.decks).followedBy(decks);

  /// Whether nothing waits for this reviewer. The Offensive words review
  /// may still be listed beside it, saying none of its words wait: it is
  /// opened on purpose, whether or not anything waits in it.
  bool get isEmpty =>
      units.isEmpty && decks.isEmpty && unrated.isEmpty && unconfirmed.isEmpty;
}

/// What waits for review in [language]. The adult content setting changes
/// none of it: offensive words and the pairs that name them wait in the
/// Offensive words review, which asks its own 18+ question.
WaitingLanguage waitingIn(AppState state, LanguageInfo language) {
  final code = language.code;
  if (state.isLanguageReading(code)) {
    return WaitingLanguage(language: language, reading: true);
  }
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

  // A deck of rude words only waits in the Offensive words review alone,
  // and a deck of a course not reviewed does not wait for this reviewer.
  final reviewed = reviewPairsOf(state);
  bool waits(DeckEntry deck) =>
      reviewed.contains(pairOf(deck)) &&
      awaitsReview(state, deck) &&
      hasOrdinaryCards(deck);

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
    for (final deck in state.decksOf(code))
      if (!inCourse.contains(deck.id) && waits(deck)) count(deck),
  ];

  final unrated = <WaitingCard>[];
  final unconfirmed = <WaitingCard>[];
  var offensive = 0;
  var pairs = 0;
  for (final deck in state.reviewDecksOf(code)) {
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
  final pairs = reviewPairsOf(state);
  return unit.any(
    (deck) =>
        pairs.contains(pairOf(deck)) &&
        awaitsReview(state, deck) &&
        hasOrdinaryCards(deck),
  );
}

/// A suggestion the reviewer sent, with where it stands.
typedef SentSuggestion = ({
  DeckReview review,
  DeckEntry? deck,
  String cardId,
  Card? card,
  Suggestion suggestion,
  SentState state,
});

/// Every suggestion this reviewer has sent, deck by deck in the order the
/// decks were first reviewed, and each deck's cards in review order, with
/// its state worked out from the deck files on the phone (#471). A deck or
/// card gone from the phone is kept, its state not known.
List<SentSuggestion> sentSuggestionsOf(AppState state) {
  final code = '${state.reviewing.code ?? ''}';
  final out = <SentSuggestion>[];
  for (final review in state.reviewing.reviews.decks.values) {
    if (review.sent == null) continue;
    final deck = state.reviewDeckById(review.deckId);
    for (final MapEntry(key: cardId, value: cardReview)
        in review.sentCards.entries) {
      final card = deck?.cards.where((c) => c.id == cardId).firstOrNull;
      for (final s in cardReview.suggestions) {
        final field = proposalFieldOf(s.part);
        // An item added to a list (ADR-0050) has no field text: it is in the
        // deck once the card's list has it.
        final current = card == null || field == null
            ? null
            : field.isAdd
            ? (cardHasItem(card, partOf(field), s.text) ? s.text : '')
            : partText(card, partOf(field)) ?? '';
        out.add((
          review: review,
          deck: deck,
          cardId: cardId,
          card: card,
          suggestion: s,
          state: sentStateOf(
            suggestion: s,
            current: current,
            proposals: card == null || deck == null
                ? const <Proposal>[]
                : <Proposal>[
                    for (final d in state.decksOf(deck.language.code))
                      ...?d.deck.proposals[card.id],
                  ],
            code: code.isEmpty ? null : code,
            agreementsNeeded: Reviewing.agreementsNeeded,
          ),
        ));
      }
    }
  }
  return out;
}
