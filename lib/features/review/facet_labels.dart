import '../../core/review/facets.dart';
import '../../core/review/review_question.dart' show builderSomethingElse;
import '../../l10n/app_localizations.dart';

/// The name of [facet] a screen shows: the title of its tags sheet, and the
/// reason of a contested row. The word is named by its spelling, as the
/// approved mockup does.
String facetTitle(AppLocalizations l10n, Facet facet) => switch (facet) {
  Facet.word => l10n.reviewFacetSpelling,
  Facet.reading => l10n.reviewFacetReading,
  Facet.ipa => l10n.reviewFacetIpa,
  Facet.meaning => l10n.reviewFacetMeaning,
  Facet.example => l10n.reviewFacetExample,
  Facet.note => l10n.reviewFacetNote,
  Facet.unitPlacement => l10n.reviewFacetUnit,
  Facet.offenceRating => l10n.reviewFacetOffence,
  Facet.audio => l10n.reviewFacetAudio,
};

/// The label of the pointer [tag].
String pointerTagLabel(AppLocalizations l10n, PointerTag tag) => switch (tag) {
  PointerTag.meaningWrong => l10n.reviewTagMeaningWrong,
  PointerTag.readingWrong => l10n.reviewTagReadingWrong,
  PointerTag.ipaWrong => l10n.reviewTagIpaWrong,
  PointerTag.spellingWrong => l10n.reviewTagSpellingWrong,
  PointerTag.unnaturalOrRare => l10n.reviewTagUnnaturalOrRare,
  PointerTag.wrongRegister => l10n.reviewTagWrongRegister,
  PointerTag.offensive => l10n.reviewTagOffensive,
  PointerTag.exampleWrong => l10n.reviewTagExampleWrong,
  PointerTag.noteWrong => l10n.reviewTagNoteWrong,
  PointerTag.wrongUnit => l10n.reviewTagWrongUnit,
  PointerTag.audioWrong => l10n.reviewTagAudioWrong,
};

/// The one fixed question of a builder question about [facet]: "Is the
/// `<facet>` on this card correct?" (wiki Plan-Builder-Questions-V2). Words of
/// the app only, never any text of a card or a queue; empty for no facet.
String builderAskText(AppLocalizations l10n, Facet? facet) => switch (facet) {
  Facet.word => l10n.builderAskWord,
  Facet.reading => l10n.builderAskReading,
  Facet.ipa => l10n.builderAskIpa,
  Facet.meaning => l10n.builderAskMeaning,
  Facet.example => l10n.builderAskExample,
  Facet.note => l10n.builderAskNote,
  Facet.unitPlacement => l10n.builderAskUnit,
  Facet.offenceRating => l10n.builderAskOffence,
  Facet.audio => l10n.builderAskAudio,
  null => '',
};

/// The label of the [key] option of a builder question about [facet]: the
/// pointer tag's label, "Something else" for the last. The offence facet
/// shows its `offensive` option as "The rating does not fit": the rating, not
/// the word, is in doubt (display only, the key is unchanged).
String builderOptionLabel(AppLocalizations l10n, Facet facet, String key) {
  if (key == builderSomethingElse) return l10n.builderAskSomethingElse;
  if (facet == Facet.offenceRating && key == PointerTag.offensive.wire) {
    return l10n.builderAskOffenceOption;
  }
  final tag = PointerTag.fromWire(key);
  return tag == null ? key : pointerTagLabel(l10n, tag);
}
