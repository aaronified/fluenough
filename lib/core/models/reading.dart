import 'card.dart';
import 'drill_mode.dart';

/// One sentence of a passage, as the deck gives it (#98, ADR-0019).
class PassageSentence {
  const PassageSentence({required this.text, this.reading});

  /// The sentence in the language learned, exactly as written in the deck:
  /// never trimmed, normalised or tidied, since a passage may quote a book
  /// letter for letter.
  final String text;

  /// Its romanisation, shown when Show romanisation is on.
  final String? reading;
}

/// An older or unusual word in a passage, with today's form of it: Sahaj
/// Path's লয় is নেয় now. Older Bengali reads differently from the language
/// the decks teach, sadhu and chalit alike.
class GlossEntry {
  const GlossEntry({
    required this.word,
    required this.modern,
    required this.meaning,
    this.reading,
    this.note = const <String, String>{},
  });

  /// The word exactly as the passage writes it, which it occurs in letter
  /// for letter.
  final String word;

  /// Today's standard colloquial form.
  final String modern;

  /// [modern] in the Latin alphabet, shown when Show romanisation is on.
  final String? reading;

  /// What it means, by language code; English always.
  final Map<String, String> meaning;

  /// More about it, by language code, or empty: "older colloquial; the
  /// apostrophe marks a dropped ই".
  final Map<String, String> note;
}

/// Which of [written], the languages some text is written in, to show it
/// in: the first of [spoken], best known first, that it has, else English,
/// else any (#53).
String bestLanguage(Iterable<String> written, List<String> spoken) {
  final have = written.toSet();
  for (final code in spoken) {
    if (have.contains(code)) return code;
  }
  return have.contains('en') ? 'en' : have.first;
}

/// A question about a passage: multiple choice, or true or false.
///
/// Its [prompt] and [options] are written in one or more of the languages a
/// learner can say they speak, keyed by code as a fact's text is: English
/// always, Bengali and Hindi if the deck has them.
class ReadingQuestion {
  const ReadingQuestion({
    required this.id,
    required this.prompt,
    required this.answer,
    this.options = const <Map<String, String>>[],
  });

  /// Permanent, like a card id: it keys the question's review history.
  final String id;

  /// The question, or for true or false the statement, by language code.
  final Map<String, String> prompt;

  /// The choices, each by language code, in the order shown. Empty for a
  /// true-or-false question, whose choices are True and False.
  final List<Map<String, String>> options;

  /// The right choice, from 0: an index into [options], or for true or false
  /// 0 for true and 1 for false.
  final int answer;

  /// The grade a right choice records. A choice can be guessed, so a right
  /// one is Good, not Easy (`SelfGrade.good`).
  static const int rightGrade = 4;

  /// The grade a wrong choice records, as for a wrong typed answer.
  static const int wrongGrade = 1;

  bool get isTrueFalse => options.isEmpty;

  /// How many choices are shown: two for true or false.
  int get choiceCount => isTrueFalse ? 2 : options.length;

  bool isRight(int choice) => choice == answer;

  /// The SM-2 grade for [choice].
  int gradeFor(int choice) => isRight(choice) ? rightGrade : wrongGrade;

  /// [choice] as the deck numbers it, for the review log: the option's
  /// number from 1, or `true` or `false`.
  String logged(int choice) =>
      isTrueFalse ? (choice == 0 ? 'true' : 'false') : '${choice + 1}';

  /// The languages the whole question is written in: its prompt's, where
  /// every option has them too.
  Set<String> get languages => <String>{
    for (final code in prompt.keys)
      if (options.every((o) => o.containsKey(code))) code,
  };

  /// The language to show the question in: the first of [spoken], best known
  /// first, that it is written in, else English, else any it has.
  String languageFor(List<String> spoken) => bestLanguage(languages, spoken);
}

/// A short text to read, or hear, and its questions (#98, ADR-0019).
class Passage {
  const Passage({
    required this.id,
    required this.title,
    required this.sentences,
    required this.questions,
    this.source,
    this.theme,
    this.glossary = const <GlossEntry>[],
  });

  /// Permanent, like a card id.
  final String id;

  /// The passage's name, in the language the deck is taught from.
  final String title;

  final List<PassageSentence> sentences;

  /// Where the passage comes from, shown with it. Null to use the deck's.
  final String? source;

  /// The theme whose words it uses, by its id in `decks/themes.yaml`.
  final String? theme;

  final List<ReadingQuestion> questions;

  /// The words in it a learner of today's language may not know, in the
  /// order the deck gives them. Often empty.
  final List<GlossEntry> glossary;
}

/// A reading question as a card, so that it is scheduled, recorded and
/// counted like any other: its own SM-2 state per mode, keyed by the
/// question's id, a card id of the language (ADR-0018).
///
/// It is read in [DrillMode.reading], and heard in [DrillMode.listening]
/// where the phone has a voice. Its [target] and [reading] are the passage's
/// first sentence, so that a list of cards, such as the leeches, shows which
/// passage it is; its [native] is the question in English.
class QuestionCard extends Card {
  QuestionCard({
    required super.deckId,
    required this.passage,
    required this.question,
    this.source,
  }) : super(
         id: question.id,
         target: passage.sentences.first.text,
         reading: passage.sentences.first.reading,
         native: question.prompt['en'] ?? question.prompt.values.first,
         modes: const <DrillMode>{DrillMode.reading, DrillMode.listening},
       );

  final Passage passage;
  final ReadingQuestion question;

  /// Where the passage comes from: its own source, or else its deck's.
  final String? source;

  /// Whether [other] asks about the same passage, in the same deck.
  bool sharesPassage(Card other) =>
      other is QuestionCard &&
      other.deckId == deckId &&
      other.passage.id == passage.id;
}
