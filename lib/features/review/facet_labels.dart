import '../../core/review/facets.dart';
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
