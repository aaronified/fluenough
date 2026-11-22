/// The daily questions of reviewer mode (#519): short questions the app
/// writes from a card's data, one data point at a time, answered with a tap
/// and sent by mail like a review. Pure Dart, so that the questions and the
/// rules are tested without a device.
library;

import 'facets.dart';

/// What a question is about.
enum QuestionKind {
  /// "Is this the right meaning of तुम (tum)?"
  meaning,

  /// "Is this example natural?"
  example,

  /// "Is this a real confusable for खाना (khānā)?"
  confusable,

  /// "Is this recording correct and by a native speaker?" There is no
  /// recording option: a reviewer can only flag a bad one, and the card then
  /// uses text-to-speech.
  sound,

  /// "Is this the right picture for it?" A proposal from the Wiktionary
  /// import (#523). The answer pins the exact file (the point is
  /// `image:<File>`), so two answers agree only on the same file.
  image,

  /// A doubt the deck's builder raised about one facet of a card, put to the
  /// reviewer as a step of its own (builder questions v2, owner, 2026-11-22;
  /// wiki Plan-Builder-Questions-V2): the question is the app's one fixed
  /// "Is the `<facet>` on this card correct?", the card is shown in full, and
  /// the answer is Yes, or No with one of the facet's options. The point is
  /// `builder:<facet>`; no text of the card or the queue is ever the
  /// question.
  builder;

  /// How it is written in the mail's files. Permanent.
  String get wire => name;

  static QuestionKind? parse(Object? wire) {
    for (final kind in values) {
      if (kind.wire == wire) return kind;
    }
    return null;
  }

  /// The answers a reviewer can give. A sound has no No: it is flagged.
  List<QuestionAnswer> get answers => this == sound
      ? const <QuestionAnswer>[QuestionAnswer.yes, QuestionAnswer.flag]
      : const <QuestionAnswer>[QuestionAnswer.yes, QuestionAnswer.no];

  /// Why an answer that is not Yes may be given, one reason or none, in the
  /// order they are offered. The reasons are fixed keys (never text), so the
  /// bot can count them without reading anything a reviewer wrote.
  List<String> get reasons => switch (this) {
    meaning => const <String>['wrong', 'awkward'],
    example => const <String>['unnatural', 'wrong'],
    confusable => const <String>['not_real', 'wrong_word'],
    sound => const <String>['noisy', 'wrong_word', 'not_native'],
    image => const <String>['not_the_word', 'unclear', 'not_fit'],
    // The reasons of a builder question depend on its facet: see
    // [reasonsFor].
    builder => const <String>[],
  };

  /// The reasons an answer to the question with [point] may carry. The same
  /// as [reasons], except for a builder question, whose options are those
  /// of its facet (`builder:<facet>`); a point that names no facet, such as
  /// the old `builder:<8 hex>`, has none.
  List<String> reasonsFor(String point) {
    if (this != builder) return reasons;
    final facet = builderFacetOf(point);
    return facet == null ? const <String>[] : builderOptions(facet);
  }
}

/// The option that ends every facet's list of a builder question.
const String builderSomethingElse = 'something_else';

/// The start of a builder question's point: `builder:<facet wire>`.
const String builderPointPrefix = 'builder:';

/// The point of the builder question about [facet] of a card.
String builderPoint(Facet facet) => '$builderPointPrefix${facet.wire}';

/// The facet a builder question's [point] names, or null.
Facet? builderFacetOf(String point) => point.startsWith(builderPointPrefix)
    ? Facet.fromWire(point.substring(builderPointPrefix.length))
    : null;

/// The options of a builder question about [facet], as keys in the order they
/// are offered: the pointer tags that may go on that facet, in
/// [PointerTag]'s order, then [builderSomethingElse].
/// `tools/question_answers.py` `BUILDER_OPTIONS` holds the same lists, and a
/// test keeps them equal.
List<String> builderOptions(Facet facet) => <String>[
  for (final tag in PointerTag.values)
    if (tag.facets.contains(facet)) tag.wire,
  builderSomethingElse,
];

/// What a reviewer answers.
enum QuestionAnswer {
  /// It is right.
  yes,

  /// It is wrong.
  no,

  /// A bad recording, for a sound: it is replaced by text-to-speech.
  flag;

  /// How it is written in the mail's files. Permanent.
  String get wire => name;

  static QuestionAnswer? parse(Object? wire) {
    for (final answer in values) {
      if (answer.wire == wire) return answer;
    }
    return null;
  }
}

/// An example sentence of a card, shown whole to a reviewer.
class QuestionExample {
  const QuestionExample({required this.target, this.reading, this.native});

  /// The sentence in the language, its reading and its translation.
  final String target;
  final String? reading;
  final String? native;
}

/// One question about one data point of one card.
class ReviewQuestion {
  const ReviewQuestion({
    required this.language,
    required this.card,
    required this.kind,
    required this.point,
    required this.word,
    required this.weakness,
    this.reading,
    this.shown,
    this.shownReading,
    this.shownMeaning,
    this.meaning,
    this.deckId,
    this.facet,
    this.ref,
    this.concern,
    this.ipa,
    this.notes = const <String>[],
    this.hasAudio = false,
    this.offensive = false,
    this.examples = const <QuestionExample>[],
  });

  /// The course's language, by code.
  final String language;

  /// The card's id.
  final String card;

  final QuestionKind kind;

  /// Names the data point on the card, permanent: `meaning`,
  /// `example:<8 hex>`, `confusable:<item id>`, `sound`, `image:<File>`,
  /// `builder:<facet>`.
  final String point;

  /// The card's word, in the language's script, and its reading.
  final String word;
  final String? reading;

  /// The card's meaning, in the learner's language.
  final String? meaning;

  /// What the question asks about, where it is text: the example's
  /// sentence, or the confusable's word, with its reading and meaning.
  final String? shown;
  final String? shownReading;
  final String? shownMeaning;

  /// The deck the card was found in, for the screen's sake.
  final String? deckId;

  /// The facet a [QuestionKind.builder] question asks about; the question
  /// itself is the app's fixed one for it, never any text of the card.
  final Facet? facet;

  /// For an example facet, the 8 hex ([pointHash]) of the one example the
  /// builder doubts, or null for the examples as a whole.
  final String? ref;

  /// What the builder was unsure of, shown only as context under the
  /// question, plain: never the question and never parsed.
  final String? concern;

  /// The card's IPA and notes, whether it has a recording and whether its
  /// register is offensive, for a [QuestionKind.builder] question, so that
  /// the reviewer sees whatever facet is asked about.
  final String? ipa;
  final List<String> notes;
  final bool hasAudio;
  final bool offensive;

  /// Every example the card has, for a [QuestionKind.builder] question, so
  /// that the reviewer can look at whatever the builder asks about.
  final List<QuestionExample> examples;

  /// How weak the data is: 0 is unverified (written by Claude, or from no
  /// source), 1 semi-verified (taken from Wiktionary or Tatoeba, or signed
  /// off by one reviewer). The weakest comes first (owner, 2026-10-13).
  final int weakness;

  /// The reasons an answer to this question may carry.
  List<String> get reasons => kind.reasonsFor(point);

  /// `<card>|<point>`: the same data point always has the same id, so a
  /// reviewer is never asked twice and the bot counts answers by it.
  String get id => '$card|$point';
}

/// A short, stable hash of [text], 8 lowercase hex digits (FNV-1a over the
/// UTF-16 code units, after trimming): what names an example on its card,
/// since examples have no id of their own.
///
/// The multiplication by the FNV prime 0x01000193 is split so that no
/// product passes 2^53: the web build computes ints as doubles.
String pointHash(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.trim().codeUnits) {
    hash ^= unit;
    hash = ((hash & 0xff) * 0x1000000 + hash * 0x193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
