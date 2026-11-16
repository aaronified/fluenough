/// A recommended work (wiki/Plan-Deck-Kinds-And-Topics.md, D13): a popular
/// book, film, song or play that a learner should find elsewhere, which the
/// app teaches about and never reproduces. It holds no text of the work, only
/// its title, its creators, a briefing and a few comprehension questions.
library;

import 'level.dart';
import 'reading.dart' show ReadingQuestion;

/// What kind of work it is.
enum RecommendationMedium {
  book,
  film,
  series,
  song,
  play,
  podcast,
  comic;

  /// [value] as a medium, or null for another text.
  static RecommendationMedium? tryParse(Object? value) {
    for (final medium in RecommendationMedium.values) {
      if (medium.name == value) return medium;
    }
    return null;
  }
}

/// A legal way to get the work: a library, a publisher, a store, a stream, an
/// archive or a public-domain copy. Never a pirate or unlicensed link.
class LegalRoute {
  const LegalRoute({required this.kind, required this.url, this.notes});

  final String kind;
  final String url;

  /// A note per language, such as "Free: public domain".
  final Map<String, String>? notes;

  String noteFor(Iterable<String> spoken) {
    final notes = this.notes;
    if (notes == null || notes.isEmpty) return '';
    for (final code in spoken) {
      final text = notes[code];
      if (text != null) return text;
    }
    return notes['en'] ?? notes.values.first;
  }
}

class Recommendation {
  const Recommendation({
    required this.id,
    required this.medium,
    required this.title,
    required this.creators,
    this.titleReading,
    this.titleIpa,
    this.year,
    this.level,
    this.script,
    this.briefing = const <String, String>{},
    this.questions = const <ReadingQuestion>[],
    this.legal = const <LegalRoute>[],
    this.quotedIn,
  });

  /// Permanent, `<language>-rec-<slug>`.
  final String id;
  final RecommendationMedium medium;

  /// The title in the language learned.
  final String title;
  final String? titleReading;
  final String? titleIpa;

  /// Ids of the creators file; the work has at least one.
  final List<String> creators;
  final int? year;

  /// A suggestion of the level it suits.
  final Level? level;

  /// For a book, the script it is printed in (`telugu`, `latin`).
  final String? script;

  /// What it is, why it matters, what to expect, per UI language.
  final Map<String, String> briefing;

  /// Authored comprehension questions, 3 to 8, in the reading-deck shape (the
  /// right answer is an index from 0, as `ReadingQuestion` holds it).
  final List<ReadingQuestion> questions;
  final List<LegalRoute> legal;

  /// The culture deck that quotes it, when it is a public-domain work.
  final String? quotedIn;

  bool get isBook => medium == RecommendationMedium.book;

  /// The briefing in the first of [spoken] it is written in, else English.
  String briefingFor(Iterable<String> spoken) {
    for (final code in spoken) {
      final text = briefing[code];
      if (text != null) return text;
    }
    return briefing['en'] ??
        (briefing.values.isEmpty ? '' : briefing.values.first);
  }

  /// The key a question is scheduled and reviewed under: the recommendation's
  /// id and the question's, permanent like a card id.
  String questionKey(ReadingQuestion question) => '$id#${question.id}';

  @override
  String toString() => 'Recommendation($id)';
}

/// A language's recommendations file.
class RecommendationsFile {
  const RecommendationsFile({
    required this.languageCode,
    this.recommendations = const <Recommendation>[],
    this.problems = const <String>[],
  });

  final String languageCode;
  final List<Recommendation> recommendations;

  /// What in the file could not be read and was left out, for the log.
  final List<String> problems;

  Recommendation? byId(String id) {
    for (final recommendation in recommendations) {
      if (recommendation.id == id) return recommendation;
    }
    return null;
  }
}
