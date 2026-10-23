import '../models/card.dart';

/// The code of the IPA course's language block: the IPA is offered like a
/// language (ADR-0041), though it is a notation (`script: ipa`).
const String ipaLanguageCode = 'ipa';

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
