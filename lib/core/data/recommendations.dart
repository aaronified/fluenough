/// A language's recommendations file (`decks/recommendations/<code>.yaml`,
/// `kind: recommendations`; wiki/Plan-Deck-Kinds-And-Topics.md, D13): popular
/// works to find elsewhere, with a briefing, comprehension questions and a
/// legal route. Deck-owned and downloaded with the decks, in the index's
/// `shared` list.
///
/// Read tolerantly: a recommendation or a question that cannot be read costs
/// itself and is named in [RecommendationsFile.problems]. `tools/validate_decks.py`
/// holds the rules (3 to 8 questions, a legal https route, the creators
/// resolve); the app only needs to show what it has.
library;

import '../models/level.dart';
import '../models/reading.dart' show ReadingQuestion;
import '../models/recommendation.dart';
import 'deck_parser.dart';
import 'kinds_read.dart';

/// The newest schema of a recommendations file this app reads.
const int supportedRecommendationsSchema = 1;

/// The recommendations in [text]. Throws [DeckParseException] when it is not
/// a recommendations file, names no language, or is of a later schema.
RecommendationsFile parseRecommendations(
  String text, {
  required String source,
}) {
  final file = readKindsFile(
    text,
    source: source,
    kind: 'recommendations',
    supportedSchema: supportedRecommendationsSchema,
  );
  final code = readLanguageCode(file, source: source);
  final list = file['recommendations'];
  if (list is! List) {
    throw DeckParseException('recommendations must be a list', source: source);
  }
  final problems = KindsProblems();
  final seen = <String>{};
  final out = <Recommendation>[];
  for (final (i, raw) in list.indexed) {
    final path = 'recommendations[$i]';
    try {
      final recommendation = _readRecommendation(raw, path, code, problems);
      if (recommendation == null) continue;
      if (!seen.add(recommendation.id)) {
        problems.add(
          path,
          '"${recommendation.id}" is listed twice, the first is used',
        );
        continue;
      }
      out.add(recommendation);
    } on Object catch (e) {
      problems.add(path, 'could not be read ($e), left out');
    }
  }
  return RecommendationsFile(
    languageCode: code,
    recommendations: List<Recommendation>.unmodifiable(out),
    problems: problems.lines,
  );
}

Recommendation? _readRecommendation(
  Object? raw,
  String path,
  String code,
  KindsProblems problems,
) {
  if (raw is! Map) {
    problems.add(path, 'is not a mapping, left out');
    return null;
  }
  final id = raw['id'];
  if (id is! String || !dataIdPattern.hasMatch(id)) {
    problems.add(path, 'has no id of lowercase words, left out');
    return null;
  }
  final medium = RecommendationMedium.tryParse(raw['medium']);
  if (medium == null) {
    problems.add(path, '"$id" has a medium this app does not know, left out');
    return null;
  }
  final rawTitle = raw['title'];
  final title = rawTitle is Map
      ? plainText(rawTitle['text'])
      : plainText(rawTitle);
  if (title == null) {
    problems.add(path, '"$id" has no title, left out');
    return null;
  }
  final creators = raw['creator'] is String
      ? <String>[raw['creator'] as String]
      : textList(raw['creator'], '$path.creator', problems);
  if (creators.isEmpty) {
    problems.add(path, '"$id" names no creator, left out');
    return null;
  }
  var level = Level.tryParse(raw['level']);
  if (raw['level'] != null && level == null) {
    problems.add('$path.level', 'is not a level (A1 to C2), left out');
    level = null;
  }
  final questions = <ReadingQuestion>[];
  final rawQuestions = raw['questions'];
  if (rawQuestions is List) {
    final ids = <String>{};
    for (final (i, item) in rawQuestions.indexed) {
      final question = _readQuestion(item, '$path.questions[$i]', problems);
      if (question == null) continue;
      if (!ids.add(question.id)) {
        problems.add(
          '$path.questions[$i]',
          '"${question.id}" is listed twice, left out',
        );
        continue;
      }
      questions.add(question);
    }
  } else if (rawQuestions != null) {
    problems.add('$path.questions', 'is not a list, left out');
  }
  final legal = <LegalRoute>[];
  final rawLegal = raw['legal'];
  if (rawLegal is List) {
    for (final (i, item) in rawLegal.indexed) {
      final kind = item is Map ? plainText(item['kind']) : null;
      final url = item is Map ? plainText(item['url']) : null;
      if (kind == null || url == null || !url.startsWith('https://')) {
        problems.add('$path.legal[$i]', 'is not an https route, left out');
        continue;
      }
      final notes = localisedText(
        (item as Map)['note'],
        '$path.legal[$i].note',
        problems,
      );
      legal.add(
        LegalRoute(kind: kind, url: url, notes: notes.isEmpty ? null : notes),
      );
    }
  } else if (rawLegal != null) {
    problems.add('$path.legal', 'is not a list, left out');
  }
  return Recommendation(
    id: id,
    medium: medium,
    title: title,
    titleReading: rawTitle is Map ? plainText(rawTitle['reading']) : null,
    titleIpa: rawTitle is Map ? plainText(rawTitle['ipa']) : null,
    creators: List<String>.unmodifiable(creators),
    year: plainInt(raw['year']),
    level: level,
    script: plainText(raw['script']),
    briefing: localisedText(raw['briefing'], '$path.briefing', problems),
    questions: List<ReadingQuestion>.unmodifiable(questions),
    legal: List<LegalRoute>.unmodifiable(legal),
    quotedIn: plainText(raw['quoted_in']),
  );
}

/// A question in the reading-deck shape, as a [ReadingQuestion]. `options` is
/// a mapping of language to its list of options (`{ en: [a, b] }`) or a list
/// of per-language options as a reading deck writes them; the file's `answer`
/// counts from 1, the model's from 0. A question without options is true or
/// false (`answer: true`).
ReadingQuestion? _readQuestion(
  Object? raw,
  String path,
  KindsProblems problems,
) {
  if (raw is! Map) {
    problems.add(path, 'is not a mapping, left out');
    return null;
  }
  final id = plainText(raw['id']);
  final prompt = localisedText(raw['prompt'], '$path.prompt', problems);
  if (id == null || prompt.isEmpty) {
    problems.add(path, 'has no id or no prompt, left out');
    return null;
  }
  final rawOptions = raw['options'];
  final answer = raw['answer'];
  if (rawOptions == null) {
    if (answer is! bool) {
      problems.add(path, 'has no options and no true or false answer');
      return null;
    }
    return ReadingQuestion(id: id, prompt: prompt, answer: answer ? 0 : 1);
  }
  final options = <Map<String, String>>[];
  if (rawOptions is Map) {
    // { en: [a, b, c], bn: [...] }: option k is the k-th of every language.
    final byLanguage = <String, List<String>>{
      for (final MapEntry(:key, :value) in rawOptions.entries)
        if (key is String) key: textList(value, '$path.options.$key', problems),
    };
    final count = byLanguage.values.fold<int>(
      0,
      (most, list) => list.length > most ? list.length : most,
    );
    for (var k = 0; k < count; k++) {
      options.add(<String, String>{
        for (final MapEntry(:key, :value) in byLanguage.entries)
          if (k < value.length) key: value[k],
      });
    }
  } else if (rawOptions is List) {
    for (final (k, item) in rawOptions.indexed) {
      options.add(localisedText(item, '$path.options[$k]', problems));
    }
  } else {
    problems.add('$path.options', 'is not a list, left out');
    return null;
  }
  if (options.length < 2 || options.any((o) => o.isEmpty)) {
    problems.add(path, 'has fewer than two options, left out');
    return null;
  }
  if (answer is! int || answer < 1 || answer > options.length) {
    problems.add(path, 'has an answer that is no option, left out');
    return null;
  }
  return ReadingQuestion(
    id: id,
    prompt: prompt,
    options: List<Map<String, String>>.unmodifiable(options),
    answer: answer - 1,
  );
}
