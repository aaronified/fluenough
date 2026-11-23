import '../core/decks/adult_gate.dart' show isRudeCard;
import 'deck_catalog.dart' show DeckEntry;

/// How many texts a language's summary keeps for the Voices page's Play.
const int voiceSampleCount = 3;

/// What Play says for a language: the target texts of the first cards of its
/// first vocabulary deck, or of a script deck when that is all there is,
/// passing over any rude word (docs/plans/offensive-words.md), up to [count].
/// Empty when no deck of [decks] has a card to say, such as a grammar deck on
/// its own.
List<String> voiceSampleOf(
  Iterable<DeckEntry> decks, {
  int count = voiceSampleCount,
}) {
  final withCards = <DeckEntry>[
    for (final deck in decks)
      if (deck.cards.isNotEmpty) deck,
  ];
  final sample = <String>[];
  for (final deck in <DeckEntry>[
    ...withCards.where((d) => !d.isScript),
    ...withCards.where((d) => d.isScript),
  ]) {
    for (final card in deck.cards) {
      if (isRudeCard(card, deck.deck)) continue;
      sample.add(card.target);
      if (sample.length >= count) return sample;
    }
  }
  return sample;
}
