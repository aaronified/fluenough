import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/models/reading.dart' show QuestionCard;
import '../../core/review/flagged_queue.dart';
import '../../core/review/review_pairs.dart';
import '../../core/review/review_session.dart';
import '../decks/path_model.dart' show unitTitle;
import 'review_waiting.dart';
import 'review_words.dart' show isRudeIn;

/// The cards of [deck] a reviewer is asked about in the queue: not a grammar
/// table's or a rules deck's cells (forms of words taught elsewhere), not a
/// reading passage, no question card or practice-only card, and no rude
/// word, which is reviewed apart, on purpose (docs/plans/deck-browser.md).
List<Card> queueCardsOf(DeckEntry deck) {
  if (deck.deck.pattern != null ||
      deck.deck.kind == DeckKind.rules ||
      deck.deck.kind == DeckKind.reading) {
    return const <Card>[];
  }
  return <Card>[
    for (final card in deck.cards)
      if (card is! QuestionCard && !card.practiceOnly && !isRudeIn(deck, card))
        card,
  ];
}

/// The queue's view of [pair]'s course: its units, as the Decks tab numbers
/// them, each with the decks that hold cards to review.
ReviewSource reviewSourceOf(AppState state, ReviewPair pair) {
  final units = state.courseUnits(pair.target, native: pair.native);
  return ReviewSource(
    pair: pair,
    units: <QueueUnit>[
      for (final (i, decks) in units.indexed)
        if (decks.isNotEmpty)
          QueueUnit(
            number: i + 1,
            title: unitTitle(state, decks),
            decks: <FlaggedSourceDeck>[
              for (final deck in decks)
                if (queueCardsOf(deck) case final cards when cards.isNotEmpty)
                  FlaggedSourceDeck(
                    deckId: deck.id,
                    pair: pairOf(deck),
                    cards: cards,
                  ),
            ],
          ),
    ],
  );
}

/// The courses the reviewer may review that have a card to review, in the
/// order the courses are offered, each with its [ReviewSource].
List<ReviewSource> reviewSourcesOf(AppState state) {
  final reviewing = state.reviewing;
  if (!reviewing.on || reviewing.code == null) return const <ReviewSource>[];
  final allowed = reviewPairsOf(state);
  return <ReviewSource>[
    for (final pair in offeredPairs(state))
      if (allowed.contains(pair))
        if (reviewSourceOf(state, pair) case final source
            when source.allCards.isNotEmpty)
          source,
  ];
}

/// Whether the reviewer may review [deck]'s cards from the deck view: they
/// review the deck's course and its cards are in the queue.
bool mayReviewDeck(AppState state, DeckEntry deck) {
  final reviewing = state.reviewing;
  if (!reviewing.on || reviewing.code == null) return false;
  return reviewPairsOf(state).contains(pairOf(deck)) &&
      queueCardsOf(deck).isNotEmpty;
}

/// Whether the reviewer may review [card] of [deck] from the deck view.
bool mayReviewCard(AppState state, DeckEntry? deck, Card card) =>
    deck != null &&
    mayReviewDeck(state, deck) &&
    queueCardsOf(deck).any((c) => c.id == card.id);
