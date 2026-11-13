/// A language's topics file (`decks/<code>/<code>-topics.yaml`,
/// `kind: topics`; wiki/Plan-Deck-Kinds-And-Topics.md, D6).
///
/// Read tolerantly: a topic that cannot be read costs itself and is named in
/// [TopicsFile.problems]; the rest is used. The references (decks, units,
/// cards, concepts, situations, script units) are not checked here, since they
/// resolve against the other files of the language, which `topic_resolver.dart`
/// does; `tools/validate_decks.py` is what refuses an unresolved one.
library;

import '../models/level.dart';
import '../models/topic.dart';
import 'deck_parser.dart';
import 'kinds_read.dart';

/// The newest schema of a topics file this app reads.
const int supportedTopicsSchema = 1;

/// The most code points a `chars` entry may have (a letter with its signs, or
/// a conjunct).
const int maxTopicCharLength = 12;

/// The topics in [text]. Throws [DeckParseException] when it is not a topics
/// file, names no language, or is of a later schema.
TopicsFile parseTopics(String text, {required String source}) {
  final file = readKindsFile(
    text,
    source: source,
    kind: 'topics',
    supportedSchema: supportedTopicsSchema,
  );
  final code = readLanguageCode(file, source: source);
  final problems = KindsProblems();
  final list = file['topics'];
  if (list is! List) {
    throw DeckParseException('topics must be a list', source: source);
  }
  final seen = <String>{};
  final topics = <Topic>[];
  for (final (i, item) in list.indexed) {
    final path = 'topics[$i]';
    try {
      final topic = _readTopic(item, path, code, problems);
      if (topic == null) continue;
      if (!seen.add(topic.id)) {
        problems.add(path, '"${topic.id}" is listed twice, the first is used');
        continue;
      }
      topics.add(topic);
    } on Object catch (e) {
      problems.add(path, 'could not be read ($e), left out');
    }
  }
  return TopicsFile(
    languageCode: code,
    topics: List<Topic>.unmodifiable(topics),
    problems: problems.lines,
  );
}

Topic? _readTopic(
  Object? item,
  String path,
  String code,
  KindsProblems problems,
) {
  if (item is! Map) {
    problems.add(path, 'is not a mapping, left out');
    return null;
  }
  final id = item['id'];
  if (id is! String || !dataIdPattern.hasMatch(id)) {
    problems.add(path, 'has no id of lowercase words, left out');
    return null;
  }
  if (!id.startsWith('$code-')) {
    problems.add(path, '"$id" does not start with "$code-"');
  }
  final names = localisedText(item['name'], '$path.name', problems);
  if (!names.containsKey('en')) {
    problems.add(path, '"$id" has no English name, left out');
    return null;
  }
  var level = Level.tryParse(item['level']);
  if (item['level'] != null && level == null) {
    problems.add('$path.level', 'is not a level (A1 to C2), left out');
    level = null;
  }
  TopicTerm? term;
  final rawTerm = item['term'];
  if (rawTerm != null) {
    final termText = rawTerm is Map ? plainText(rawTerm['text']) : null;
    if (termText == null) {
      problems.add('$path.term', 'has no text, left out');
    } else {
      term = TopicTerm(
        text: termText,
        reading: plainText((rawTerm as Map)['reading']),
      );
    }
  }
  final chars = <TopicChar>[];
  final rawChars = item['chars'];
  if (rawChars != null && rawChars is! List) {
    problems.add('$path.chars', 'is not a list, left out');
  } else if (rawChars is List) {
    final seenChars = <String>{};
    for (final (i, raw) in rawChars.indexed) {
      final c = _readChar(raw);
      if (c == null) {
        problems.add('$path.chars[$i]', 'is not a character, left out');
      } else if (!seenChars.add(c.text)) {
        problems.add('$path.chars[$i]', '"${c.text}" is listed twice');
      } else {
        chars.add(c);
      }
    }
  }
  final topic = Topic(
    id: id,
    names: names,
    summary: localisedText(item['summary'], '$path.summary', problems),
    term: term,
    kind: TopicKind.parse(item['kind']),
    level: level,
    decks: textList(item['decks'], '$path.decks', problems),
    units: textList(item['units'], '$path.units', problems),
    cards: textList(item['cards'], '$path.cards', problems),
    grammar: textList(item['grammar'], '$path.grammar', problems),
    situations: textList(item['situations'], '$path.situations', problems),
    topics: textList(item['topics'], '$path.topics', problems),
    scriptUnits: textList(item['script_units'], '$path.script_units', problems),
    chars: List<TopicChar>.unmodifiable(chars),
  );
  if (!topic.hasReferences) {
    problems.add(path, '"$id" names nothing, left out');
    return null;
  }
  return topic;
}

/// A `chars` entry: text of at most [maxTopicCharLength] code points with no
/// space, or a mapping with that as `text` and an optional reading and IPA.
TopicChar? _readChar(Object? raw) {
  final text = raw is Map ? plainText(raw['text']) : plainText(raw);
  if (text == null ||
      text.runes.length > maxTopicCharLength ||
      text.contains(RegExp(r'\s'))) {
    return null;
  }
  if (raw is Map) {
    return TopicChar(
      text: text,
      reading: plainText(raw['reading']),
      ipa: plainText(raw['ipa']),
    );
  }
  return TopicChar(text: text);
}
