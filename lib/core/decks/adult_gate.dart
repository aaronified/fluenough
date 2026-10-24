import '../models/card.dart';
import '../models/deck.dart';

/// The tag that marks a deck of offensive words, and a rude card inside an
/// ordinary deck (#96, #628, docs/plans/offensive-words.md).
const String adultTag = 'offensive';

/// The tag a deck of offensive words gains once native speakers have rated
/// its words (#630, owner, 2026-10-24: "Merge, reviewer-only until rated").
/// It is an ordinary tag, so an app that does not know it reads the deck as
/// before. A deck has it only once its raters' median has set each band.
const String ratedTag = 'rated';

/// Whether [deck] is an adult deck: tagged [adultTag].
bool isAdultDeck(Deck deck) => deck.tags.contains(adultTag);

/// Whether [deck] is an adult deck whose words no native speaker has rated:
/// tagged [adultTag] and not [ratedTag]. No learner ever sees it, with Adult
/// content on or off; only the Offensive words review lists it.
bool isUnratedAdultDeck(Deck deck) =>
    isAdultDeck(deck) && !deck.tags.contains(ratedTag);

/// Whether [card] is rude: tagged [adultTag] or registered `offensive`, or in
/// [deck], when it is one, an adult deck.
bool isRudeCard(Card card, Deck? deck) =>
    card.tags.contains(adultTag) ||
    card.register == adultTag ||
    (deck != null && isAdultDeck(deck));

/// [deck] as a learner with adult content [adult] sees it: null for an
/// unrated adult deck whatever the setting (#630). With it on, otherwise the
/// deck as it is. Off, null for an adult deck or one left with no card, and
/// otherwise the deck without its rude cards (#628: "Hidden everywhere").
Deck? deckForAdult(Deck deck, {required bool adult}) {
  if (isUnratedAdultDeck(deck)) return null;
  if (adult) return deck;
  if (isAdultDeck(deck)) return null;
  final cards = <Card>[
    for (final card in deck.cards)
      if (!isRudeCard(card, deck)) card,
  ];
  if (cards.length == deck.cards.length) return deck;
  return cards.isEmpty ? null : deck.withCards(cards);
}
