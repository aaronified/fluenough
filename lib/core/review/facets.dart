/// The facets of a card a reviewer answers, one by one (ADR-0058, decisions
/// 5 to 7, work package W1). Pure Dart.
///
/// A review used to be one tap per card, "Looks right". It is now one answer
/// per facet: the card's word, its reading, and so on. A facet is answered
/// "right", or flagged with pointer tags and, optionally, a replacement text.
/// A card is reviewed only when every facet that applies to it has an answer
/// ([isComplete]).
library;

import '../models/card.dart';
import 'fix_text.dart';
import 'review_problems.dart';

/// One detail of a card that is checked on its own.
enum Facet {
  /// The word in the language learned (`target`).
  word('word'),
  reading('reading'),
  ipa('ipa'),

  /// The meaning, in the learner's language (`native`).
  meaning('meaning'),
  example('example'),
  note('note'),

  /// Where the card sits in its path unit.
  unitPlacement('unit'),

  /// How offensive a rude word is (the `WordRating`).
  offenceRating('offence'),
  audio('audio');

  const Facet(this.wire);

  /// The name in a review file.
  final String wire;

  static Facet? fromWire(Object? wire) {
    for (final facet in values) {
      if (facet.wire == wire) return facet;
    }
    return null;
  }
}

/// A one-tap reason a facet is not right (decision 5). Several can go on one
/// facet. With no replacement text a tag only points at the problem, and the
/// card goes to the flagged queue for any speaker to resolve.
enum PointerTag {
  meaningWrong('meaning_wrong', <Facet>{Facet.meaning}),
  readingWrong('reading_wrong', <Facet>{Facet.reading}),
  ipaWrong('ipa_wrong', <Facet>{Facet.ipa}),
  spellingWrong('spelling_wrong', <Facet>{Facet.word, Facet.example}),
  unnaturalOrRare('unnatural_or_rare', <Facet>{
    Facet.word,
    Facet.meaning,
    Facet.example,
  }),
  wrongRegister('wrong_register', <Facet>{
    Facet.word,
    Facet.meaning,
    Facet.example,
  }),
  offensive('offensive', <Facet>{
    Facet.word,
    Facet.meaning,
    Facet.example,
    Facet.offenceRating,
  }),
  exampleWrong('example_wrong', <Facet>{Facet.example}),
  noteWrong('note_wrong', <Facet>{Facet.note}),
  wrongUnit('wrong_unit', <Facet>{Facet.unitPlacement}),
  audioWrong('audio_wrong', <Facet>{Facet.audio});

  const PointerTag(this.wire, this.facets);

  /// The name in a review file.
  final String wire;

  /// The facets this tag may be put on. A guess of the build, to be confirmed
  /// by the owner: the tag names its own facet, and the three about the
  /// word's use (unnatural, register, offensive) fit the text facets.
  final Set<Facet> facets;

  static PointerTag? fromWire(Object? wire) {
    for (final tag in values) {
      if (tag.wire == wire) return tag;
    }
    return null;
  }
}

/// What a reviewer said about one facet: right, or flagged.
class FacetAnswer {
  /// "This is right."
  const FacetAnswer.right() : tags = const <PointerTag>{}, replacement = null;

  /// "This is wrong", with at least one of [tags] and, optionally, the
  /// [replacement] text the reviewer proposes.
  FacetAnswer.flagged(Set<PointerTag> tags, {this.replacement})
    : assert(tags.isNotEmpty, 'a flag needs a tag'),
      tags = Set<PointerTag>.unmodifiable(tags);

  /// Empty when the facet is right.
  final Set<PointerTag> tags;

  /// The proposed text, as typed; compare through [sameReplacement].
  final String? replacement;

  bool get isRight => tags.isEmpty;
  bool get isFlagged => tags.isNotEmpty;
  bool get hasReplacement => replacement != null && replacement!.isNotEmpty;

  /// Whether this and [other] propose the same text once both are
  /// normalised ([normalizeFixText]); false if either has none.
  bool sameReplacement(FacetAnswer other) =>
      hasReplacement &&
      other.hasReplacement &&
      sameFixText(replacement!, other.replacement!);

  /// `{"ok": true}`, or `{"tags": [...], "fix": "..."}`.
  Map<String, Object?> toJson() => isRight
      ? const <String, Object?>{'ok': true}
      : <String, Object?>{
          'tags': <String>[for (final t in tags) t.wire],
          if (hasReplacement) 'fix': replacement,
        };

  /// The answer [json] holds for [facet], or null (reported, not thrown)
  /// when it is not one: a flag whose tags are all unknown or do not belong
  /// on [facet] is dropped, never turned into "right". An unknown tag among
  /// good ones is dropped alone.
  static FacetAnswer? fromJson(Facet facet, Object? json) {
    try {
      if (json is! Map) {
        ReviewProblems.report('facet ${facet.wire}: answer is not an object');
        return null;
      }
      final tags = json['tags'];
      if (tags == null) {
        if (json['ok'] == true) return const FacetAnswer.right();
        ReviewProblems.report('facet ${facet.wire}: neither ok nor tags');
        return null;
      }
      if (tags is! List) {
        ReviewProblems.report('facet ${facet.wire}: tags is not a list');
        return null;
      }
      final kept = <PointerTag>{};
      for (final raw in tags) {
        final tag = PointerTag.fromWire(raw);
        if (tag == null || !tag.facets.contains(facet)) {
          ReviewProblems.report(
            'facet ${facet.wire}: tag not usable here: ${_short(raw)}',
          );
        } else {
          kept.add(tag);
        }
      }
      if (kept.isEmpty) return null;
      final fix = json['fix'];
      return FacetAnswer.flagged(kept, replacement: fix is String ? fix : null);
    } on Object catch (e) {
      ReviewProblems.report('facet ${facet.wire}: answer unreadable: $e');
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is FacetAnswer &&
      other.tags.length == tags.length &&
      other.tags.containsAll(tags) &&
      other.replacement == replacement;

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(tags), replacement);
}

String _short(Object? value) {
  final text = '$value';
  return text.length <= 24 ? text : '${text.substring(0, 24)}...';
}

/// The facets "everything looks right" answers in one tap: the plain ones
/// (decision 6).
const Set<Facet> plainFacets = <Facet>{
  Facet.word,
  Facet.meaning,
  Facet.example,
};

/// The facets confirmed separately, never by the shortcut: what a speaker
/// must hear or read closely.
const Set<Facet> separatelyConfirmedFacets = <Facet>{
  Facet.reading,
  Facet.ipa,
  Facet.audio,
};

/// The facets of [card] a reviewer answers, in [Facet]'s order.
///
/// Word and meaning always apply. Reading, IPA, audio, examples and notes
/// apply when the card has them. The offence rating applies to a card whose
/// register is `offensive`. Unit placement applies when the card sits in a
/// path unit ([inUnit], true unless the caller knows it does not; the path
/// is not a part of the card).
Set<Facet> facetsOf(Card card, {bool inUnit = true}) {
  bool has(String? text) => text != null && text.trim().isNotEmpty;
  return <Facet>{
    Facet.word,
    if (has(card.reading)) Facet.reading,
    if (has(card.ipa)) Facet.ipa,
    Facet.meaning,
    if (card.examples.isNotEmpty) Facet.example,
    if (card.notes.isNotEmpty) Facet.note,
    if (inUnit) Facet.unitPlacement,
    if (card.register == 'offensive') Facet.offenceRating,
    if (has(card.audio)) Facet.audio,
  };
}

/// What "everything looks right" gives: a right answer for each of
/// [applicable] that is a plain facet. The others are left for the reviewer.
Map<Facet, FacetAnswer> allGoodAnswers(Set<Facet> applicable) =>
    <Facet, FacetAnswer>{
      for (final facet in Facet.values)
        if (applicable.contains(facet) && plainFacets.contains(facet))
          facet: const FacetAnswer.right(),
    };

/// The facets of [applicable] with no answer in [answers].
Set<Facet> missingFacets(
  Set<Facet> applicable,
  Map<Facet, FacetAnswer> answers,
) => <Facet>{
  for (final facet in applicable)
    if (!answers.containsKey(facet)) facet,
};

/// Whether a card's review is complete: every applicable facet has an
/// answer, flagged or right. An empty [applicable] is never complete.
bool isComplete(Set<Facet> applicable, Map<Facet, FacetAnswer> answers) =>
    applicable.isNotEmpty && missingFacets(applicable, answers).isEmpty;
