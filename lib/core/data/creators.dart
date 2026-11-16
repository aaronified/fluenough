/// A language's creators file (`decks/creators/<code>.yaml`, `kind: creators`;
/// wiki/Plan-Deck-Kinds-And-Topics.md, D5): the people behind the works, with
/// their names (and readings and IPA), dates, era, bio, legacy and picture
/// credit. Deck-owned and downloaded with the decks, shared across languages
/// in the index's `shared` list.
///
/// Read tolerantly: a creator, era or field that cannot be read costs itself
/// and is named in [CreatorsFile.problems]; `tools/validate_decks.py` is what
/// refuses it on decks-live, so a file it accepted always loads.
library;

import '../models/creator.dart';
import '../models/level.dart';
import 'deck_parser.dart';
import 'kinds_read.dart';

/// The newest schema of a creators file this app reads.
const int supportedCreatorsSchema = 1;

/// The creators in [text]. Throws [DeckParseException] when it is not a
/// creators file, names no language, or is of a later schema.
CreatorsFile parseCreators(String text, {required String source}) {
  final file = readKindsFile(
    text,
    source: source,
    kind: 'creators',
    supportedSchema: supportedCreatorsSchema,
  );
  final code = readLanguageCode(file, source: source);
  final problems = KindsProblems();

  final eras = <CreatorEra>[];
  final eraIds = <String>{};
  final rawEras = file['eras'];
  if (rawEras != null && rawEras is! List) {
    problems.add('eras', 'is not a list, left out');
  } else if (rawEras is List) {
    for (final (i, raw) in rawEras.indexed) {
      final path = 'eras[$i]';
      try {
        final era = _readEra(raw, path, problems);
        if (era == null) continue;
        if (!eraIds.add(era.id)) {
          problems.add(path, '"${era.id}" is listed twice, the first is used');
          continue;
        }
        eras.add(era);
      } on Object catch (e) {
        problems.add(path, 'could not be read ($e), left out');
      }
    }
  }

  final creators = <Creator>[];
  final ids = <String>{};
  final rawCreators = file['creators'];
  if (rawCreators is! List) {
    throw DeckParseException('creators must be a list', source: source);
  }
  for (final (i, raw) in rawCreators.indexed) {
    final path = 'creators[$i]';
    try {
      final creator = _readCreator(raw, path, eraIds, problems);
      if (creator == null) continue;
      if (!ids.add(creator.id)) {
        problems.add(
          path,
          '"${creator.id}" is listed twice, the first is used',
        );
        continue;
      }
      creators.add(creator);
    } on Object catch (e) {
      problems.add(path, 'could not be read ($e), left out');
    }
  }
  return CreatorsFile(
    languageCode: code,
    eras: List<CreatorEra>.unmodifiable(eras),
    creators: List<Creator>.unmodifiable(creators),
    problems: problems.lines,
  );
}

CreatorEra? _readEra(Object? raw, String path, KindsProblems problems) {
  if (raw is! Map) {
    problems.add(path, 'is not a mapping, left out');
    return null;
  }
  final id = raw['id'];
  if (id is! String || !dataIdPattern.hasMatch(id)) {
    problems.add(path, 'has no id of lowercase words, left out');
    return null;
  }
  final from = plainInt(raw['from']);
  if (from == null) {
    problems.add(path, '"$id" has no start year, left out');
    return null;
  }
  final rawTo = raw['to'];
  final to = plainInt(rawTo);
  if (rawTo != null && to == null) {
    problems.add('$path.to', 'is not a year, taken as still running');
  }
  return CreatorEra(
    id: id,
    names: localisedText(raw['name'], '$path.name', problems),
    readings: localisedText(raw['reading'], '$path.reading', problems),
    from: from,
    to: to,
  );
}

CreatorYear? _readYear(Object? raw, String path, KindsProblems problems) {
  if (raw == null) return null;
  final plain = plainInt(raw);
  if (plain != null) return CreatorYear(plain);
  if (raw is Map) {
    final year = plainInt(raw['year']);
    if (year != null) return CreatorYear(year, circa: raw['circa'] == true);
  }
  problems.add(path, 'is not a year, left out');
  return null;
}

CreatorText? _readText(Object? raw) {
  if (raw is! Map) return null;
  final text = plainText(raw['text']);
  if (text == null) return null;
  return CreatorText(
    text: text,
    reading: plainText(raw['reading']),
    ipa: plainText(raw['ipa']),
  );
}

/// A mapping of level to text in the language learned (`bio_target`,
/// `legacy.text_target`).
Map<Level, CreatorText> _readByLevel(
  Object? raw,
  String path,
  KindsProblems problems,
) {
  if (raw == null) return const <Level, CreatorText>{};
  if (raw is! Map) {
    problems.add(path, 'is not a mapping of level to text, left out');
    return const <Level, CreatorText>{};
  }
  final out = <Level, CreatorText>{};
  for (final MapEntry(:key, :value) in raw.entries) {
    final level = Level.tryParse(key);
    final text = _readText(value);
    if (level == null || text == null) {
      problems.add('$path.$key', 'is not a level with text, left out');
    } else {
      out[level] = text;
    }
  }
  return Map<Level, CreatorText>.unmodifiable(out);
}

Creator? _readCreator(
  Object? raw,
  String path,
  Set<String> eraIds,
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
  final names = <String, CreatorText>{};
  final rawNames = raw['name'];
  if (rawNames is Map) {
    for (final MapEntry(:key, :value) in rawNames.entries) {
      final text = value is String
          ? CreatorText(text: value)
          : _readText(value);
      if (key is String && languageCodePattern.hasMatch(key) && text != null) {
        names[key] = text;
      } else {
        problems.add('$path.name.$key', 'is not a name, left out');
      }
    }
  }
  if (names.isEmpty) {
    problems.add(path, '"$id" has no name, left out');
    return null;
  }
  final era = plainText(raw['era']);
  if (era != null && !eraIds.contains(era)) {
    problems.add('$path.era', '"$era" is not an era of the file');
  }
  CreatorImage? image;
  final rawImage = raw['image'];
  if (rawImage != null) {
    final file = rawImage is Map ? plainText(rawImage['file']) : null;
    if (file == null) {
      problems.add('$path.image', 'has no file, left out');
    } else {
      final map = rawImage as Map;
      image = CreatorImage(
        file: file,
        credit: plainText(map['credit']),
        author: plainText(map['author']),
        licence: plainText(map['licence']),
        licenceUrl: plainText(map['licence_url']),
        sourceUrl: plainText(map['source_url']),
        retrieved: plainText(map['retrieved']),
      );
    }
  }
  final related = <CreatorRelation>[];
  final rawRelated = raw['related'];
  if (rawRelated is List) {
    for (final (i, item) in rawRelated.indexed) {
      final creator = item is Map ? plainText(item['creator']) : null;
      final card = item is Map ? plainText(item['card']) : null;
      final relation = item is Map ? plainText(item['relation']) : null;
      if ((creator == null && card == null) || relation == null) {
        problems.add('$path.related[$i]', 'is not a relation, left out');
      } else {
        related.add(
          CreatorRelation(creator: creator, card: card, relation: relation),
        );
      }
    }
  } else if (rawRelated != null) {
    problems.add('$path.related', 'is not a list, left out');
  }
  final died = _readYear(raw['died'], '$path.died', problems);
  return Creator(
    id: id,
    names: Map<String, CreatorText>.unmodifiable(names),
    born: _readYear(raw['born'], '$path.born', problems),
    died: died,
    living: raw['living'] == true && died == null,
    era: era,
    region: plainText(raw['region']),
    bio: localisedText(raw['bio'], '$path.bio', problems),
    bioTarget: _readByLevel(raw['bio_target'], '$path.bio_target', problems),
    image: image,
    legacy: _readLegacy(raw['legacy'], '$path.legacy', problems),
    related: List<CreatorRelation>.unmodifiable(related),
  );
}

Legacy? _readLegacy(Object? raw, String path, KindsProblems problems) {
  if (raw == null) return null;
  if (raw is! Map) {
    problems.add(path, 'is not a mapping, left out');
    return null;
  }
  final items = <LegacyItem>[];
  final rawItems = raw['items'];
  if (rawItems is List) {
    for (final (i, item) in rawItems.indexed) {
      final itemPath = '$path.items[$i]';
      if (item is! Map) {
        problems.add(itemPath, 'is not a mapping, left out');
        continue;
      }
      final texts = localisedText(item['text'], '$itemPath.text', problems);
      if (texts.isEmpty) {
        problems.add(itemPath, 'has no text, left out');
        continue;
      }
      final source = item['source'];
      items.add(
        LegacyItem(
          kind: LegacyKind.parse(item['kind']),
          texts: texts,
          year: plainInt(item['year']),
          sourceUrl: source is Map ? plainText(source['url']) : null,
          sourceWork: source is Map ? plainText(source['work']) : null,
          sourceDate: source is Map
              ? plainText(source['accessed']) ?? plainText(source['date'])
              : null,
        ),
      );
    }
  } else if (rawItems != null) {
    problems.add('$path.items', 'is not a list, left out');
  }
  final text = localisedText(raw['text'], '$path.text', problems);
  if (text.isEmpty && items.isEmpty) return null;
  return Legacy(
    text: text,
    textTarget: _readByLevel(raw['text_target'], '$path.text_target', problems),
    items: List<LegacyItem>.unmodifiable(items),
  );
}
