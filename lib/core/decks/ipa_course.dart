import '../models/card.dart';
import '../models/deck.dart';

/// The code of the IPA course's language block: the IPA is offered like a
/// language (ADR-0041), though it is a notation (`script: ipa`).
const String ipaLanguageCode = 'ipa';

/// The tag of an IPA card that every learner needs, whatever they learn.
const String ipaCoreTag = 'core';

/// Which of the IPA course's cards a learner has: the whole chart, or only
/// the symbols the languages they learn use. The course is offered twice in
/// the list of languages, "IPA: my languages" and "IPA: whole chart", with
/// one progress between them (ADR-0041).
enum IpaScope {
  /// Only the cards tagged [ipaCoreTag] or with a language the learner
  /// learns.
  mine,

  /// Every card.
  whole;

  /// The scope named [name], or null.
  static IpaScope? tryParse(String? name) {
    for (final scope in values) {
      if (scope.name == name) return scope;
    }
    return null;
  }
}

/// Whether [card] of the IPA course is in [scope], when the learner learns
/// [learned], the codes of their languages: the one place cards are
/// filtered by their tags against them, so that counts, lessons, finished
/// decks and Inspect agree (ADR-0041).
///
/// A card in [kept], such as one the learner has answered, is always in.
bool ipaCardInScope(
  Card card,
  IpaScope scope,
  Set<String> learned, {
  Set<String> kept = const <String>{},
}) =>
    scope == IpaScope.whole ||
    kept.contains(card.id) ||
    card.tags.any((tag) => tag == ipaCoreTag || learned.contains(tag));

/// [deck] as the learner has it, for [scope] and the languages [learned]: a
/// deck of the IPA course with only its cards in scope, or the deck as it
/// is; null for an IPA deck with none left, which is not on offer.
Deck? ipaDeckInScope(
  Deck deck,
  IpaScope scope,
  Set<String> learned, {
  Set<String> kept = const <String>{},
}) {
  if (!deck.language.isIpa || scope == IpaScope.whole) return deck;
  final cards = <Card>[
    for (final card in deck.cards)
      if (ipaCardInScope(card, scope, learned, kept: kept)) card,
  ];
  if (cards.isEmpty) return null;
  return cards.length == deck.cards.length ? deck : deck.withCards(cards);
}

/// The cards of [ipaCards] whose symbols occur in [ipa], a word's
/// transcription, in the order given: the "sounds of this word". A card's
/// symbol is its target, such as `ɒ`, `pʰ` or `ː`; the marks that stand for
/// no sound, `/ /`, `[ ]` and `.`, are never one. A transcription written
/// between slashes or brackets is read as it is.
List<Card> ipaCardsFor(String ipa, Iterable<Card> ipaCards) {
  final text = ipa.replaceAll(RegExp(r'[/\[\]\s.]'), '');
  if (text.isEmpty) return const <Card>[];
  return <Card>[
    for (final card in ipaCards)
      if (_isSymbol(card.target) && text.contains(card.target)) card,
  ];
}

bool _isSymbol(String target) =>
    target.trim().isNotEmpty && !RegExp(r'[/\[\]\s.]').hasMatch(target);
