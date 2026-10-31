/// The daily questions of reviewer mode (#519): short questions the app
/// writes from a card's data, one data point at a time, answered with a tap
/// and sent by mail like a review. Pure Dart, so that the questions and the
/// rules are tested without a device.
library;

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
  image;

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
  };
}

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
  });

  /// The course's language, by code.
  final String language;

  /// The card's id.
  final String card;

  final QuestionKind kind;

  /// Names the data point on the card, permanent: `meaning`,
  /// `example:<8 hex>`, `confusable:<item id>`, `sound`, `image:<File>`.
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

  /// How weak the data is: 0 is unverified (written by Claude, or from no
  /// source), 1 semi-verified (taken from Wiktionary or Tatoeba, or signed
  /// off by one reviewer). The weakest comes first (owner, 2026-10-13).
  final int weakness;

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
