/// The people behind the works (wiki/Plan-Deck-Kinds-And-Topics.md, D5, D5b):
/// a creator appears once in a language's creators file, however many cards
/// and decks cite them. Free of Flutter.
library;

import 'level.dart';

/// A year, negative for BCE, possibly uncertain (`{ year: 1750, circa: true }`).
class CreatorYear {
  const CreatorYear(this.year, {this.circa = false});

  final int year;
  final bool circa;

  @override
  bool operator ==(Object other) =>
      other is CreatorYear && other.year == year && other.circa == circa;

  @override
  int get hashCode => Object.hash(year, circa);

  @override
  String toString() => circa ? 'c. $year' : '$year';
}

/// A name or a short text in the language learned, with its reading and IPA.
class CreatorText {
  const CreatorText({required this.text, this.reading, this.ipa});

  final String text;
  final String? reading;
  final String? ipa;
}

/// An era of the language's own tradition: the axis band of the timeline.
class CreatorEra {
  const CreatorEra({
    required this.id,
    required this.names,
    required this.from,
    this.to,
    this.readings = const <String, String>{},
  });

  final String id;
  final Map<String, String> names;

  /// Readings of the names, per language code, for a non-Latin name.
  final Map<String, String> readings;
  final int from;

  /// Null: the era is still running, the timeline's "today".
  final int? to;

  String nameFor(Iterable<String> spoken) => _pick(names, spoken);
}

/// A creator's picture and where it comes from; the app shows [credit] under
/// it. Absent: the app draws a placeholder.
class CreatorImage {
  const CreatorImage({
    required this.file,
    this.credit,
    this.author,
    this.licence,
    this.licenceUrl,
    this.sourceUrl,
    this.retrieved,
  });

  /// Its path in the repository, `decks/creators/images/te-gurajada.jpg`.
  final String file;
  final String? credit;
  final String? author;

  /// `public-domain`, `CC0-1.0`, `CC-BY-4.0` or `CC-BY-SA-4.0`.
  final String? licence;
  final String? licenceUrl;
  final String? sourceUrl;
  final String? retrieved;
}

/// What a legacy item is.
enum LegacyKind {
  curriculum,
  festival,
  film,
  music,
  saying,
  commemoration,
  adaptation,
  place,
  other;

  static LegacyKind parse(Object? value) {
    for (final kind in LegacyKind.values) {
      if (kind.name == value) return kind;
    }
    return LegacyKind.other;
  }
}

/// One concrete, checkable example of how a person or work still shapes the
/// culture.
class LegacyItem {
  const LegacyItem({
    required this.kind,
    required this.texts,
    this.year,
    this.sourceUrl,
    this.sourceWork,
    this.sourceDate,
  });

  final LegacyKind kind;
  final Map<String, String> texts;

  /// Places the item on the timeline's "today" end.
  final int? year;
  final String? sourceUrl;
  final String? sourceWork;

  /// The source's `accessed` or `date`, as the file writes it.
  final String? sourceDate;

  String textFor(Iterable<String> spoken) => _pick(texts, spoken);
}

/// What a creator's legacy shows a learner at a level: the summary in their
/// spoken language, the summary in the language learned at the highest level
/// at or below theirs (when the file has one), and the items.
class LegacyView {
  const LegacyView({required this.text, required this.items, this.target});

  final String text;
  final CreatorText? target;
  final List<LegacyItem> items;
}

/// How a creator relates to another creator or to a card.
class CreatorRelation {
  const CreatorRelation({this.creator, this.card, required this.relation});

  final String? creator;
  final String? card;

  /// `adaptation`, `influence`, `response` or `echo`.
  final String relation;
}

class Legacy {
  const Legacy({
    this.text = const <String, String>{},
    this.textTarget = const <Level, CreatorText>{},
    this.items = const <LegacyItem>[],
  });

  final Map<String, String> text;
  final Map<Level, CreatorText> textTarget;
  final List<LegacyItem> items;
}

class Creator {
  const Creator({
    required this.id,
    required this.names,
    this.born,
    this.died,
    this.living = false,
    this.era,
    this.region,
    this.bio = const <String, String>{},
    this.bioTarget = const <Level, CreatorText>{},
    this.image,
    this.legacy,
    this.related = const <CreatorRelation>[],
  });

  /// Permanent, `<language>-<slug>`.
  final String id;

  /// The name per language code (the language learned, and `en`).
  final Map<String, CreatorText> names;
  final CreatorYear? born;
  final CreatorYear? died;

  /// Still alive: there is no [died], and the lifespan runs to today.
  final bool living;

  /// An id in the file's eras.
  final String? era;
  final String? region;
  final Map<String, String> bio;
  final Map<Level, CreatorText> bioTarget;
  final CreatorImage? image;
  final Legacy? legacy;
  final List<CreatorRelation> related;

  /// The name in the first of [spoken] (then the language learned, [target],
  /// then English, then any) it is written in.
  CreatorText nameFor(Iterable<String> spoken, {String? target}) {
    for (final code in <String>[...spoken, ?target, 'en']) {
      final name = names[code];
      if (name != null) return name;
    }
    return names.values.isEmpty ? CreatorText(text: id) : names.values.first;
  }

  /// The bio in the first of [spoken] it is written in, else English; empty
  /// when there is none.
  String bioFor(Iterable<String> spoken) => _pick(bio, spoken);

  /// The bio in the language learned at the highest level at or below
  /// [level], or null: for a learner with no level ([level] null), or a file
  /// with none at or below it.
  CreatorText? bioTargetFor(Level? level) => _atOrBelow(bioTarget, level);

  /// The legacy a learner at [level] sees, with the summary in [spoken]; null
  /// when the creator has none.
  LegacyView? legacyFor(Level? level, Iterable<String> spoken) {
    final legacy = this.legacy;
    if (legacy == null) return null;
    return LegacyView(
      text: _pick(legacy.text, spoken),
      target: _atOrBelow(legacy.textTarget, level),
      items: legacy.items,
    );
  }

  @override
  String toString() => 'Creator($id)';
}

CreatorText? _atOrBelow(Map<Level, CreatorText> byLevel, Level? level) {
  if (level == null) return null;
  CreatorText? best;
  Level? bestLevel;
  for (final MapEntry(:key, :value) in byLevel.entries) {
    if (!level.isAtLeast(key)) continue;
    if (bestLevel == null || key.index > bestLevel.index) {
      best = value;
      bestLevel = key;
    }
  }
  return best;
}

String _pick(Map<String, String> byLanguage, Iterable<String> spoken) {
  for (final code in spoken) {
    final text = byLanguage[code];
    if (text != null) return text;
  }
  return byLanguage['en'] ??
      (byLanguage.values.isEmpty ? '' : byLanguage.values.first);
}

/// A language's creators file.
class CreatorsFile {
  const CreatorsFile({
    required this.languageCode,
    this.eras = const <CreatorEra>[],
    this.creators = const <Creator>[],
    this.problems = const <String>[],
  });

  final String languageCode;
  final List<CreatorEra> eras;
  final List<Creator> creators;

  /// What in the file could not be read and was left out, for the log.
  final List<String> problems;

  Creator? byId(String id) {
    for (final creator in creators) {
      if (creator.id == id) return creator;
    }
    return null;
  }

  CreatorEra? eraById(String? id) {
    if (id == null) return null;
    for (final era in eras) {
      if (era.id == id) return era;
    }
    return null;
  }
}
