/// A topic: something a learner would search for in one language, such as a
/// grammar peculiarity, a verb form, a class of words, a script's conjuncts or
/// a profession (wiki/Plan-Deck-Kinds-And-Topics.md, D6). It holds no card
/// text: it names what already exists, and a file of them is
/// `decks/<code>/<code>-topics.yaml`.
library;

import 'level.dart';

/// How a topic is grouped for display; an unknown value is [other].
enum TopicKind {
  grammar,
  verbs,
  words,
  script,
  register,
  profession,
  other;

  /// [value] as a kind; [other] for anything else.
  static TopicKind parse(Object? value) {
    for (final kind in TopicKind.values) {
      if (kind.name == value) return kind;
    }
    return TopicKind.other;
  }
}

/// A letter, sign, conjunct or glyph a script topic lists (`chars`): the
/// list is the data, so it can name glyphs that no card carries yet.
class TopicChar {
  const TopicChar({required this.text, this.reading, this.ipa});

  final String text;

  /// The reading in the Latin alphabet, which a non-Latin text needs.
  final String? reading;
  final String? ipa;

  @override
  String toString() => 'TopicChar($text)';
}

/// The name of the thing in the language learned: は vs が, ser / estar.
class TopicTerm {
  const TopicTerm({required this.text, this.reading});

  final String text;
  final String? reading;
}

class Topic {
  const Topic({
    required this.id,
    required this.names,
    this.summary = const <String, String>{},
    this.term,
    this.kind = TopicKind.other,
    this.level,
    this.decks = const <String>[],
    this.units = const <String>[],
    this.cards = const <String>[],
    this.grammar = const <String>[],
    this.situations = const <String>[],
    this.topics = const <String>[],
    this.scriptUnits = const <String>[],
    this.chars = const <TopicChar>[],
  });

  /// Permanent, `<code>-<slug>`.
  final String id;

  /// The topic's name per UI language; English is always there.
  final Map<String, String> names;
  final Map<String, String> summary;
  final TopicTerm? term;
  final TopicKind kind;

  /// The lowest level the topic suits.
  final Level? level;

  /// Core ids of the language's decks, hidden ones included.
  final List<String> decks;

  /// A path unit, by any core id on it or its planned id.
  final List<String> units;

  /// Card ids of the language.
  final List<String> cards;

  /// Path `grammar:` concept ids and rules-table names.
  final List<String> grammar;

  /// Ids of the language's situation sheets.
  final List<String> situations;

  /// Related topics of the same file.
  final List<String> topics;

  /// Feature ids of the language's script guides.
  final List<String> scriptUnits;
  final List<TopicChar> chars;

  /// Whether the topic names anything at all.
  bool get hasReferences =>
      decks.isNotEmpty ||
      units.isNotEmpty ||
      cards.isNotEmpty ||
      grammar.isNotEmpty ||
      situations.isNotEmpty ||
      topics.isNotEmpty ||
      scriptUnits.isNotEmpty ||
      chars.isNotEmpty;

  /// The name in the first of [spoken] it is written in, else English.
  String nameFor(Iterable<String> spoken) => _pick(names, spoken);

  /// The summary in the first of [spoken] it is written in, else English;
  /// empty when there is none.
  String summaryFor(Iterable<String> spoken) => _pick(summary, spoken);

  @override
  String toString() => 'Topic($id)';
}

String _pick(Map<String, String> byLanguage, Iterable<String> spoken) {
  for (final code in spoken) {
    final text = byLanguage[code];
    if (text != null) return text;
  }
  return byLanguage['en'] ??
      (byLanguage.values.isEmpty ? '' : byLanguage.values.first);
}

/// A language's topics file: its topics, in the file's order.
class TopicsFile {
  const TopicsFile({
    required this.languageCode,
    required this.topics,
    this.problems = const <String>[],
  });

  final String languageCode;
  final List<Topic> topics;

  /// What in the file could not be read and was left out, for the log.
  final List<String> problems;

  /// The topic with [id], or null.
  Topic? byId(String id) {
    for (final topic in topics) {
      if (topic.id == id) return topic;
    }
    return null;
  }
}
