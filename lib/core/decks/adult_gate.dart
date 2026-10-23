import '../models/card.dart';
import '../models/deck.dart';

/// The tag that marks a deck of offensive words, and a rude card inside an
/// ordinary deck (#96, #628, docs/plans/offensive-words.md).
const String adultTag = 'offensive';

/// Whether [deck] is an adult deck: tagged [adultTag].
bool isAdultDeck(Deck deck) => deck.tags.contains(adultTag);

/// Whether [card] is rude: tagged [adultTag] or registered `offensive`, or in
/// [deck], when it is one, an adult deck.
bool isRudeCard(Card card, Deck? deck) =>
    card.tags.contains(adultTag) ||
    card.register == adultTag ||
    (deck != null && isAdultDeck(deck));

/// [deck] as a learner with adult content [adult] sees it: with it on, the
/// deck as it is. Off, null for an adult deck or one left with no card, and
/// otherwise the deck without its rude cards (#628: "Hidden everywhere").
Deck? deckForAdult(Deck deck, {required bool adult}) {
  if (adult) return deck;
  if (isAdultDeck(deck)) return null;
  final cards = <Card>[
    for (final card in deck.cards)
      if (!isRudeCard(card, deck)) card,
  ];
  if (cards.length == deck.cards.length) return deck;
  return cards.isEmpty ? null : deck.withCards(cards);
}
