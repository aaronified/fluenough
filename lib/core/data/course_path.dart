import 'package:yaml/yaml.dart';

import 'deck_parser.dart';

/// A course's curated path (#117, ADR-0013): its decks in the order they are
/// taught, in units. A course is a language taught from another, such as
/// Hindi from English, and has one path.
///
/// A unit is what is taught together: a theme deck and the grammar that goes
/// with it, or a script. Today takes new cards from the first unfinished
/// unit and the one after it (`AppState.pendingUnits`), and placement passes
/// or places a unit whole (ADR-0013).
///
/// A unit may end in the wildcard `"*"`, which takes the course's decks the
/// path does not list, such as decks a learner adds (#22): those whose theme
/// is the unit's go at its bottom. A last unit of only `"*"` takes the rest,
/// so a deck whose theme no unit takes goes at the end ([placing]).
class CoursePath {
  const CoursePath({
    required this.id,
    required this.language,
    required this.native,
    required this.units,
    this.open = const <int>{},
  });

  /// `<language>-<native>-path`, the file's name.
  final String id;

  /// The code of the language taught, such as `hi`.
  final String language;

  /// The code of the language it is taught from, such as `en`.
  final String native;

  /// Each unit's deck ids, in teaching order, without the wildcard. No deck
  /// is listed twice. Only a unit of the wildcard alone is empty.
  final List<List<String>> units;

  /// The units that end in the wildcard, by index.
  final Set<int> open;

  /// `hi/en`: the key the catalog finds a course's path by.
  String get course => '$language/$native';

  /// Every deck on the path, in order.
  Iterable<String> get deckIds => units.expand((unit) => unit);

  /// The index of the unit holding [deckId], or null if the path has none.
  int? unitOf(String deckId) {
    for (final (i, unit) in units.indexed) {
      if (unit.contains(deckId)) return i;
    }
    return null;
  }

  /// This path with [extra] decks, which it does not list, put where its
  /// wildcards say: each at the bottom of the first open unit that holds a
  /// deck of its theme ([themeOf] gives a listed deck's), else in the open
  /// unit of the wildcard alone. A deck no wildcard takes is left out, and
  /// follows the path as before. The result has no wildcards and no empty
  /// units.
  CoursePath placing(
    Iterable<({String id, String? theme})> extra,
    String? Function(String deckId) themeOf,
  ) {
    final placed = <List<String>>[for (final unit in units) List.of(unit)];
    final rest = <int>[
      for (final i in open)
        if (units[i].isEmpty) i,
    ];
    for (final deck in extra) {
      int? into;
      if (deck.theme != null) {
        for (final i in open.toList()..sort()) {
          if (units[i].any((id) => themeOf(id) == deck.theme)) {
            into = i;
            break;
          }
        }
      }
      into ??= rest.isEmpty ? null : rest.first;
      if (into != null) placed[into].add(deck.id);
    }
    return CoursePath(
      id: id,
      language: language,
      native: native,
      units: List<List<String>>.unmodifiable(<List<String>>[
        for (final unit in placed)
          if (unit.isNotEmpty) List<String>.unmodifiable(unit),
      ]),
    );
  }

  @override
  String toString() => 'CoursePath($id)';
}

/// The wildcard a path's unit may end in.
const String pathWildcard = '*';

final _code = RegExp(r'^[a-z]{2,3}$');
final _deckId = RegExp(r'^[a-z0-9-]+$');

/// The path in [text], a `kind: path` file such as `decks/hi/hi-en-path.yaml`.
/// Throws [DeckParseException] if it is not a path file or is malformed, so
/// the catalog can report it like a broken deck. Whether its decks exist is
/// for the catalog, and the validator, to say.
CoursePath parseCoursePath(String text, {String source = 'path.yaml'}) {
  DeckParseException bad(String message, [YamlNode? at]) => DeckParseException(
    message,
    source: source,
    line: at == null ? null : at.span.start.line + 1,
    column: at == null ? null : at.span.start.column + 1,
  );

  final YamlNode root;
  try {
    root = loadYamlNode(text);
  } on YamlException catch (e) {
    throw bad(e.message);
  }
  if (root is! YamlMap || root['kind'] != 'path') {
    throw bad('a path file is a mapping with "kind: path"', root);
  }
  final language = root['language'];
  final native = root['native'];
  for (final (key, value) in <(String, Object?)>[
    ('language', language),
    ('native', native),
  ]) {
    if (value is! String || !_code.hasMatch(value)) {
      throw bad(
        '$key must be a language code such as "hi", got "$value"',
        root.nodes[key] ?? root,
      );
    }
  }
  final id = root['id'];
  if (id != '$language-$native-path') {
    throw bad(
      'a path for $language from $native has id "$language-$native-path", '
      'got "$id"',
      root.nodes['id'] ?? root,
    );
  }
  final list = root.nodes['units'];
  if (list is! YamlList || list.nodes.isEmpty) {
    throw bad('units must be a non-empty list', list ?? root);
  }
  final seen = <String>{};
  final units = <List<String>>[];
  final open = <int>{};
  for (final (u, item) in list.nodes.indexed) {
    if (item is! YamlList || item.nodes.isEmpty) {
      throw bad('each unit is a non-empty list of deck ids', item);
    }
    final unit = <String>[];
    for (final (i, deck) in item.nodes.indexed) {
      final value = deck.value;
      if (value == pathWildcard) {
        if (i != item.nodes.length - 1) {
          throw bad('"$pathWildcard" can only end a unit', deck);
        }
        if (unit.isEmpty && u != list.nodes.length - 1) {
          throw bad(
            'a unit of "$pathWildcard" alone can only be the last',
            deck,
          );
        }
        open.add(u);
        continue;
      }
      if (value is! String || !_deckId.hasMatch(value)) {
        throw bad('a unit lists deck ids, got "$value"', deck);
      }
      if (!seen.add(value)) throw bad('deck "$value" is listed twice', deck);
      unit.add(value);
    }
    units.add(List<String>.unmodifiable(unit));
  }
  return CoursePath(
    id: id as String,
    language: language as String,
    native: native as String,
    units: List<List<String>>.unmodifiable(units),
    open: Set<int>.unmodifiable(open),
  );
}
