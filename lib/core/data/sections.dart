import 'package:yaml/yaml.dart';

import '../models/deck.dart';
import 'deck_parser.dart';
import 'yaml_tree.dart';

/// The Decks tab's sections, the deck genres, the professions and the search
/// kinds, as data (`decks/sections.yaml`, wiki/Plan-Deck-Kinds-And-Topics.md,
/// D8): deck-owned, downloaded from decks-live with the decks, with the copy
/// bundled in the app as the fallback. A new genre, profession or search kind
/// that reuses a row template is a row in the file and no app release.
///
/// Everything here is read tolerantly: an entry that cannot be read costs
/// itself, is named in [DeckSections.problems], and the rest is used. Only a
/// file that is not a sections file at all, or is of a newer schema, is
/// refused whole, so that the copy the app already has stays in use.

/// The newest schema of a sections file this app reads.
const int supportedSectionsSchema = 1;

/// The row templates a search kind may use (D10). A new template is code, so a
/// kind naming another is left out.
const Set<String> searchRowTemplates = <String>{
  'scene',
  'topic',
  'deck',
  'concept',
  'card',
  'unit',
};

/// The section a deck is in when it names no other and has no genre.
const String pathSectionId = 'path';

/// The section of a deck whose genre or section the file does not list.
const String beyondBasicsSectionId = 'beyond-basics';

final _dataId = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

/// A name keyed by language code, `en` always present where the file gave it.
typedef Names = Map<String, String>;

/// [names] in the first of [spoken] that has one, else English, else any.
String nameIn(Names names, List<String> spoken) {
  for (final code in spoken) {
    final name = names[code];
    if (name != null) return name;
  }
  return names['en'] ?? (names.values.isEmpty ? '' : names.values.first);
}

/// One list the Decks tab shows its decks under.
class SectionInfo {
  const SectionInfo({
    required this.id,
    required this.names,
    required this.listed,
  });

  final String id;
  final Names names;

  /// Whether the Decks tab shows it (`professional` is not: hidden decks).
  final bool listed;
}

/// One deck genre: where its decks are listed, and what search calls them.
class GenreInfo {
  const GenreInfo({
    required this.id,
    required this.names,
    required this.section,
    required this.searchKind,
    required this.weave,
  });

  final String id;
  final Names names;

  /// The section its decks are under, unless a deck says another.
  final String? section;

  /// The search kind (tab) its cards are found under.
  final String? searchKind;

  /// The default of a deck's `weave`.
  final bool weave;
}

/// A profession a professional deck can be for.
class ProfessionInfo {
  const ProfessionInfo({required this.id, required this.names});

  final String id;
  final Names names;
}

/// One search tab: its name, the row template it is drawn with, and its place.
class SearchKindInfo {
  const SearchKindInfo({
    required this.id,
    required this.names,
    required this.row,
    required this.order,
  });

  final String id;
  final Names names;

  /// One of [searchRowTemplates].
  final String row;
  final int order;
}

/// The sections file as the app reads it.
class DeckSections {
  const DeckSections({
    this.sections = const <SectionInfo>[],
    this.genres = const <GenreInfo>[],
    this.professions = const <ProfessionInfo>[],
    this.searchKinds = const <SearchKindInfo>[],
    this.problems = const <String>[],
  });

  /// What a catalog has before it has read a file: no section, genre,
  /// profession or search kind, so every deck is on the path and a genre the
  /// file does not list is "Beyond the basics".
  static const DeckSections empty = DeckSections();

  final List<SectionInfo> sections;
  final List<GenreInfo> genres;
  final List<ProfessionInfo> professions;

  /// In their `order`.
  final List<SearchKindInfo> searchKinds;

  /// What in the file could not be read and was left out, one line each, for
  /// the log.
  final List<String> problems;

  SectionInfo? section(String? id) {
    for (final section in sections) {
      if (section.id == id) return section;
    }
    return null;
  }

  GenreInfo? genre(String? id) {
    if (id == null) return null;
    for (final genre in genres) {
      if (genre.id == id) return genre;
    }
    return null;
  }

  ProfessionInfo? profession(String? id) {
    if (id == null) return null;
    for (final profession in professions) {
      if (profession.id == id) return profession;
    }
    return null;
  }

  SearchKindInfo? searchKind(String? id) {
    if (id == null) return null;
    for (final kind in searchKinds) {
      if (kind.id == id) return kind;
    }
    return null;
  }

  /// The id of the section [deck] is listed under (D7): its own `section`,
  /// else its genre's, else `path` for a deck with no genre. A genre the file
  /// does not list, and a section it does not list, put the deck under
  /// "Beyond the basics".
  String sectionIdOf(Deck deck) {
    final own = deck.section ?? genre(deck.genre)?.section;
    if (own == null) {
      return deck.genre == null ? pathSectionId : beyondBasicsSectionId;
    }
    return section(own) == null ? beyondBasicsSectionId : own;
  }

  /// Whether [deck] may be woven into the course: its own `weave`, else its
  /// genre's, else no.
  bool weaves(Deck deck) => deck.weave ?? genre(deck.genre)?.weave ?? false;

  /// The search kind the cards of [deck] are found under, or null for a deck
  /// with no genre (its cards are plain words) or a genre with none.
  String? searchKindOf(Deck deck) => genre(deck.genre)?.searchKind;
}

/// The sections file in [text]. Throws [DeckParseException] when it is not a
/// sections file or of a later schema, so the catalog can report it like a
/// broken deck and the downloader keeps the bundled copy; reads every entry
/// tolerantly otherwise.
DeckSections parseSections(String text, {String source = 'sections.yaml'}) {
  DeckParseException bad(String message, [YamlNode? at]) => DeckParseException(
    message,
    source: source,
    line: at == null ? null : at.span.start.line + 1,
    column: at == null ? null : at.span.start.column + 1,
  );

  final YamlNode root;
  try {
    root = loadYamlTree(withoutBom(text));
  } on YamlException catch (e) {
    throw bad(e.message);
  }
  if (root is! YamlMap || root['kind'] != 'sections') {
    throw bad('a sections file is a mapping with "kind: sections"', root);
  }
  final schema = root['schema'];
  if (schema is int && schema > supportedSectionsSchema) {
    throw bad(
      'sections schema $schema is newer than this app reads '
      '($supportedSectionsSchema)',
      root,
    );
  }
  final YamlMap file = root;
  final problems = <String>[];

  /// The mapping items of [key], each as plain Dart; one that is not a mapping
  /// costs itself.
  List<Map<Object?, Object?>> items(String key) {
    final node = file.nodes[key];
    if (node == null || node.value == null) return const [];
    if (node is! YamlList) {
      problems.add('$key is not a list, left out');
      return const [];
    }
    final out = <Map<Object?, Object?>>[];
    for (final (i, item) in node.nodes.indexed) {
      try {
        final tree = plainTree(item);
        if (tree is Map) {
          out.add(tree);
        } else {
          problems.add('$key[$i] is not a mapping, left out');
        }
      } on Object catch (e) {
        problems.add('$key[$i] could not be read ($e), left out');
      }
    }
    return out;
  }

  /// The id of [item], or null (and a problem) when it has none or it was
  /// taken already.
  String? idOf(
    String key,
    int i,
    Map<Object?, Object?> item,
    Set<String> seen,
  ) {
    final id = item['id'];
    if (id is! String || !_dataId.hasMatch(id)) {
      problems.add('$key[$i] has no id of lowercase words, left out');
      return null;
    }
    if (!seen.add(id)) {
      problems.add('$key[$i]: "$id" is listed twice, the first is used');
      return null;
    }
    return id;
  }

  Names namesOf(String key, String id, Map<Object?, Object?> item) {
    final raw = item['name'];
    final names = <String, String>{
      if (raw is Map)
        for (final MapEntry(:key, :value) in raw.entries)
          if (key is String && value is String && value.trim().isNotEmpty)
            key: value.trim(),
    };
    if (!names.containsKey('en')) {
      problems.add('$key "$id" has no English name');
    }
    return Names.unmodifiable(names);
  }

  String? optionalId(Object? value) =>
      value is String && _dataId.hasMatch(value) ? value : null;

  final sectionIds = <String>{};
  final sections = <SectionInfo>[
    for (final (i, item) in items('sections').indexed)
      if (idOf('sections', i, item, sectionIds) case final id?)
        SectionInfo(
          id: id,
          names: namesOf('section', id, item),
          listed: item['listed'] != false,
        ),
  ];
  final genreIds = <String>{};
  final genres = <GenreInfo>[
    for (final (i, item) in items('genres').indexed)
      if (idOf('genres', i, item, genreIds) case final id?)
        GenreInfo(
          id: id,
          names: namesOf('genre', id, item),
          section: optionalId(item['section']),
          searchKind: optionalId(item['search_kind']),
          weave: item['weave'] == true,
        ),
  ];
  final professionIds = <String>{};
  final professions = <ProfessionInfo>[
    for (final (i, item) in items('professions').indexed)
      if (idOf('professions', i, item, professionIds) case final id?)
        ProfessionInfo(id: id, names: namesOf('profession', id, item)),
  ];
  final kindIds = <String>{};
  final kinds = <SearchKindInfo>[];
  for (final (i, item) in items('search_kinds').indexed) {
    final id = idOf('search_kinds', i, item, kindIds);
    if (id == null) continue;
    final row = item['row'];
    if (row is! String || !searchRowTemplates.contains(row)) {
      problems.add(
        'search kind "$id" has a row template this app does not '
        'draw, left out',
      );
      continue;
    }
    final order = item['order'];
    kinds.add(
      SearchKindInfo(
        id: id,
        names: namesOf('search kind', id, item),
        row: row,
        order: order is int ? order : 1000 + i,
      ),
    );
  }
  kinds.sort((a, b) => a.order.compareTo(b.order));
  return DeckSections(
    sections: List<SectionInfo>.unmodifiable(sections),
    genres: List<GenreInfo>.unmodifiable(genres),
    professions: List<ProfessionInfo>.unmodifiable(professions),
    searchKinds: List<SearchKindInfo>.unmodifiable(kinds),
    problems: List<String>.unmodifiable(problems),
  );
}
