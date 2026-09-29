import 'package:yaml/yaml.dart';

import 'deck_parser.dart';

/// One theme on the shared path that vocabulary is taught along (ADR-0010).
class DeckTheme {
  const DeckTheme({required this.id, required this.name});

  /// Permanent, like a card id: decks name their theme by it.
  final String id;

  /// In English, the language every beta deck is taught from.
  final String name;

  @override
  String toString() => 'DeckTheme($id)';
}

final _themeId = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

/// The themes in [text], the shared `decks/themes.yaml`, in the order the
/// path teaches them. Throws [DeckParseException] if it is not a themes file
/// or a theme is malformed, so the catalog can report it like a broken deck.
List<DeckTheme> parseThemes(String text, {String source = 'themes.yaml'}) {
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
  if (root is! YamlMap || root['kind'] != 'themes') {
    throw bad('a themes file is a mapping with "kind: themes"', root);
  }
  final list = root.nodes['themes'];
  if (list is! YamlList || list.nodes.isEmpty) {
    throw bad('themes must be a non-empty list', list ?? root);
  }
  final seen = <String>{};
  final themes = <DeckTheme>[];
  for (final item in list.nodes) {
    if (item is! YamlMap) {
      throw bad('each theme is a mapping with an id and a name', item);
    }
    final id = item['id'];
    final name = item['name'];
    if (id is! String || !_themeId.hasMatch(id)) {
      throw bad(
        'theme id must be lowercase words joined by hyphens, got "$id"',
        item,
      );
    }
    if (name is! String || name.trim().isEmpty) {
      throw bad('theme "$id" needs a name', item);
    }
    if (!seen.add(id)) throw bad('theme "$id" is listed twice', item);
    themes.add(DeckTheme(id: id, name: name.trim()));
  }
  return themes;
}
