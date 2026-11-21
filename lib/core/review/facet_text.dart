/// What a card says for each text facet, the tags a facet offers, and the
/// help the fix field gets (ADR-0058, decisions 5 and 13, work package W4).
/// Pure Dart.
library;

import '../models/card.dart';
import 'facets.dart';
import 'fix_text.dart';

/// The pointer tag that names [facet] itself, offered first on its sheet.
PointerTag ownTagOf(Facet facet) => switch (facet) {
  Facet.word => PointerTag.spellingWrong,
  Facet.reading => PointerTag.readingWrong,
  Facet.ipa => PointerTag.ipaWrong,
  Facet.meaning => PointerTag.meaningWrong,
  Facet.example => PointerTag.exampleWrong,
  Facet.note => PointerTag.noteWrong,
  Facet.unitPlacement => PointerTag.wrongUnit,
  Facet.offenceRating => PointerTag.offensive,
  Facet.audio => PointerTag.audioWrong,
};

/// The tags that may go on [facet] ([PointerTag.facets]; a tag outside it
/// would be dropped when the answer is read back), the facet's own first
/// and the rest in [PointerTag]'s order.
List<PointerTag> tagsFor(Facet facet) {
  final own = ownTagOf(facet);
  return <PointerTag>[
    own,
    for (final tag in PointerTag.values)
      if (tag != own && tag.facets.contains(facet)) tag,
  ];
}

/// Whether a flag on [facet] can carry replacement text: the facets that
/// are text. Unit, offence rating and audio are only pointed at.
bool isTextFacet(Facet facet) => switch (facet) {
  Facet.word ||
  Facet.reading ||
  Facet.ipa ||
  Facet.meaning ||
  Facet.example ||
  Facet.note => true,
  _ => false,
};

/// What [card] says for [facet], the text a reviewer sees and a fix
/// replaces; null when the card has none or the facet is not text. An
/// example or a note is its first.
String? facetTextOf(Card card, Facet facet) => switch (facet) {
  Facet.word => card.target,
  Facet.reading => card.reading,
  Facet.ipa => card.ipa,
  Facet.meaning => card.native,
  Facet.example => card.examples.firstOrNull?.target,
  Facet.note => card.notes.firstOrNull?.text,
  _ => null,
};

/// What a receipt hashes for [facet] of [card] (`ReviewReceipt`): the text of
/// a text facet, and for the others what the reviewer saw: the deck the card
/// sits in for its unit, the card's register for the offence rating, and the
/// audio file's name for its audio. Empty when the card has none.
String seenTextOf(Card card, Facet facet) =>
    facetTextOf(card, facet) ??
    switch (facet) {
      Facet.unitPlacement => card.deckId,
      Facet.offenceRating => card.register,
      Facet.audio => card.audio,
      _ => null,
    } ??
    '';

/// The reading to show beside the field of [facet], for the facets whose
/// text a reviewer may have to type in a script they read from a
/// romanisation: the word's, or the first example's. Null otherwise.
String? readingBesideOf(Card card, Facet facet) {
  final reading = switch (facet) {
    Facet.word => card.reading,
    Facet.example => card.examples.firstOrNull?.reading,
    _ => null,
  };
  return reading != null && reading.trim().isNotEmpty ? reading : null;
}

/// The candidate texts the card already holds for [facet], to offer as
/// chips: the other readings of a reading, the other written forms of a
/// word, the other accepted answers of a meaning. Never invented: a facet
/// with no such list, and the IPA, give none. The current text is left
/// out, and two spellings of one text count once ([sameFixText]).
///
/// There is no engine source yet: the on-device recogniser hears a
/// recording, and no recording is part of this sheet.
List<String> candidatesFor(Card card, Facet facet) {
  final source = switch (facet) {
    Facet.reading => card.altReading,
    Facet.word => card.altTarget,
    Facet.meaning => card.altNative,
    _ => const <String>[],
  };
  final seen = <String>[facetTextOf(card, facet) ?? ''];
  final out = <String>[];
  for (final text in source) {
    if (text.trim().isEmpty) continue;
    if (seen.any((s) => sameFixText(s, text))) continue;
    seen.add(text);
    out.add(text);
  }
  return out;
}

/// Whether [text] is written in a script a phone's plain Latin keyboard
/// does not type, so that the sheet hints at enabling the script's
/// keyboard in the phone's settings. Latin with marks, and the IPA, are
/// typed on a Latin keyboard.
bool needsScriptKeyboard(String text) {
  for (final rune in text.runes) {
    if ((rune >= 0x0370 && rune <= 0x1DFF) ||
        (rune >= 0x2C00 && rune <= 0x2DFF) ||
        (rune >= 0x3040 && rune <= 0xD7FF) ||
        (rune >= 0xF900 && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF)) {
      return true;
    }
  }
  return false;
}
