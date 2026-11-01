/// The two lists of a card's native side a reviewer adds one item to
/// (ADR-0050): another accepted answer (`alt_native`) and a word that is not
/// a synonym of the card's answer (`not_synonyms`). Pure Dart, so that the
/// rules the review bot applies (`tools/proposals.py`, `value_error`) are
/// tested without a device: a proposal the bot would leave for the owner is
/// stopped on the phone, where the reviewer can fix it.
library;

import '../grading/meaning_rules.dart';
import '../models/card.dart';
import 'deck_review.dart';

/// Why a reviewer's typed item cannot be sent.
enum AddedItemProblem {
  /// Nothing, or only spaces.
  empty,

  /// More than one answer split by `;`: one answer is one proposal.
  severalAnswers,

  /// The card's list already has it, or the reviewer typed it twice.
  alreadyThere,

  /// It is one of the card's own answers: already accepted, so it cannot be
  /// proposed as another one, and never refused.
  ownAnswer,

  /// A word to accept that the card's `not_synonyms` refuses: the owner
  /// decides which of the two stays.
  refusedByCard,

  /// A refused word on a card whose meanings are not English: the synonym
  /// sets are English only.
  notEnglish,
}

/// The item as it is proposed: trimmed, with runs of spaces made one.
String addedItemText(String typed) =>
    typed.trim().replaceAll(RegExp(r'\s+'), ' ');

/// The comparison form of each answer the card accepts outright: its
/// `native`, split by `;` with brackets dropped, and its `alt_native`, each
/// also without a leading article, as the bot reads them.
Set<String> ownAnswerKeys(Card card) {
  return _withoutArticle(<String>[
    for (final text in <String>[card.native, ...card.altNative])
      ...meaningKeys(text),
  ]);
}

Set<String> _withoutArticle(Iterable<String> keys) => <String>{
  for (final key in keys) ...<String>[
    key,
    for (final article in const <String>['a ', 'an ', 'the '])
      if (key.startsWith(article)) key.substring(article.length),
  ],
};

/// The items [card] has in the list [part] adds to.
List<String> itemsOfAddOnly(Card card, CardPart part) => switch (part) {
  CardPart.altNative => card.altNative,
  CardPart.notSynonyms => card.notSynonyms,
  _ => const <String>[],
};

/// Whether there is nothing to add: [card]'s list [part] has [text] already,
/// or an answer that is the same once compared, or [text] is one of the
/// card's own answers (which are accepted already, and never refused).
bool cardHasItem(Card card, CardPart part, String text) {
  final key = meaningKey(text);
  if (key.isEmpty) return false;
  if (itemsOfAddOnly(card, part).any((i) => meaningKey(i) == key)) return true;
  return ownAnswerKeys(card).contains(key);
}

/// Whether the reviewer can propose a word to refuse (`not_synonyms`) on a
/// card taught from the language [nativeCode]: only English meanings have
/// synonym sets.
bool offersNotSynonyms(String nativeCode) => nativeCode == 'en';

/// Why [typed] cannot be added to the list [part] of [card], or null when it
/// can. [alsoAdded] are the other items of the same list that the reviewer
/// has typed, which [typed] must not repeat. [nativeCode] is the language of
/// the card's native side.
AddedItemProblem? checkAddedItem({
  required CardPart part,
  required String typed,
  required Card card,
  required String nativeCode,
  Iterable<String> alsoAdded = const <String>[],
}) {
  assert(part.isAddOnly, '$part is not a list that is only added to');
  final text = addedItemText(typed);
  final key = meaningKey(text);
  if (text.isEmpty || key.isEmpty) return AddedItemProblem.empty;
  final own = ownAnswerKeys(card);
  if (part == CardPart.altNative) {
    if (text.contains(';')) return AddedItemProblem.severalAnswers;
    if (_withoutArticle(meaningKeys(card.native)).contains(key)) {
      return AddedItemProblem.ownAnswer;
    }
    if (own.contains(key)) return AddedItemProblem.alreadyThere;
    final refused = <String>{
      for (final item in card.notSynonyms) meaningKey(item),
    };
    if (refused.intersection(_withoutArticle(<String>[key])).isNotEmpty) {
      return AddedItemProblem.refusedByCard;
    }
  } else {
    if (!offersNotSynonyms(nativeCode)) return AddedItemProblem.notEnglish;
    if (own.contains(key)) return AddedItemProblem.ownAnswer;
    if (itemsOfAddOnly(card, part).any((i) => meaningKey(i) == key)) {
      return AddedItemProblem.alreadyThere;
    }
  }
  if (alsoAdded.any((other) => meaningKey(other) == key)) {
    return AddedItemProblem.alreadyThere;
  }
  return null;
}
