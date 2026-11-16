part of 'deck_parser.dart';

// A script deck's character data (#1226, DECK-FORMAT.md, Character data): the
// deck's `character_scheme` header, which names the kinds of reading and the
// level schemes its characters have, and a card's `character` block, which
// gives that character's readings, levels, strokes and radical. Both are data
// the deck supplies: nothing here names a language or a script. The validator
// judges them against each other; here each is read for its shape.

const _characterFields = {'readings', 'level', 'strokes', 'radical'};
const _characterReadingFields = {'kind', 'text', 'reading'};
const _characterSchemeFields = {'readings', 'levels'};
const _characterKindFields = {'name', 'script'};
const _characterLevelFields = {'name', 'values'};

extension _CharacterReading on _Reader {
  /// A card's `character` block, or null when the card has none.
  CardCharacter? character(YamlNode? node, String path) {
    if (node == null) return null;
    final fields = this.fields(node, path);
    fields.allowOnly(_characterFields);
    final strokes = _characterStrokes(fields, path);
    final radical = fields.optionalString('radical', allowEmpty: false);
    if (radical != null && radical.runes.length != 1) {
      fail(
        fields.require('radical'),
        '$path.radical must be one character, got "$radical"',
      );
    }
    return CardCharacter(
      readings: _characterReadings(fields.node('readings'), '$path.readings'),
      levels: _characterLevels(fields.node('level'), '$path.level'),
      strokes: strokes,
      radical: radical,
    );
  }

  int? _characterStrokes(_Fields fields, String path) {
    final node = fields.node('strokes');
    if (node == null) return null;
    final value = _value(node);
    if (value is! int || value < 1) {
      fail(
        node,
        '$path.strokes must be a whole number from 1, got ${_describe(node)}',
      );
    }
    return value;
  }

  List<CharacterReading> _characterReadings(YamlNode? node, String path) {
    if (node == null) return const <CharacterReading>[];
    return List<CharacterReading>.unmodifiable([
      for (final (i, item) in list(node, path).indexed)
        _characterReading(item, '$path[$i]'),
    ]);
  }

  CharacterReading _characterReading(YamlNode node, String path) {
    final fields = this.fields(node, path);
    fields.allowOnly(_characterReadingFields);
    return CharacterReading(
      kind: fields.string('kind'),
      text: fields.string('text'),
      reading: fields.optionalString('reading', allowEmpty: false),
    );
  }

  /// A level: a mapping of scheme id to its value, a whole number or text.
  Map<String, String> _characterLevels(YamlNode? node, String path) {
    if (node == null) return const <String, String>{};
    if (node is! YamlMap) fail(node, _wrongType(node, path, 'a mapping'));
    if (node.nodes.isEmpty) fail(node, '$path must not be empty');
    final levels = <String, String>{};
    for (final entry in node.nodes.entries) {
      final key = entry.key as YamlNode;
      final id = text(key, '$path key');
      levels[id] = _characterValue(entry.value, '$path.$id');
    }
    return Map<String, String>.unmodifiable(levels);
  }

  /// A whole number or non-blank text, as text.
  String _characterValue(YamlNode node, String path) {
    final value = _value(node);
    if (value is int) return '$value';
    return text(node, path);
  }

  /// The deck's `character_scheme` header, or null when it has none.
  CharacterScheme? characterScheme(_Fields header) {
    final node = header.node('character_scheme');
    if (node == null) return null;
    final fields = this.fields(node, 'character_scheme');
    fields.allowOnly(_characterSchemeFields);
    final readings = fields.node('readings');
    final levels = fields.node('levels');
    if (readings == null && levels == null) {
      fail(node, 'character_scheme names no readings and no levels');
    }
    return CharacterScheme(
      readings: readings == null
          ? const <CharacterReadingKind>[]
          : _characterKinds(readings),
      levels: levels == null
          ? const <CharacterLevelScheme>[]
          : _characterLevelSchemes(levels),
    );
  }

  List<CharacterReadingKind> _characterKinds(YamlNode node) {
    const path = 'character_scheme.readings';
    if (node is! YamlMap) fail(node, _wrongType(node, path, 'a mapping'));
    if (node.nodes.isEmpty) fail(node, '$path must not be empty');
    return List<CharacterReadingKind>.unmodifiable([
      for (final entry in node.nodes.entries)
        _characterKind(text(entry.key as YamlNode, '$path key'), entry.value),
    ]);
  }

  CharacterReadingKind _characterKind(String id, YamlNode node) {
    final path = 'character_scheme.readings.$id';
    final fields = this.fields(node, path);
    fields.allowOnly(_characterKindFields);
    return CharacterReadingKind(
      id: id,
      name: _characterName(fields.require('name'), '$path.name'),
      script: fields.string('script'),
    );
  }

  List<CharacterLevelScheme> _characterLevelSchemes(YamlNode node) {
    const path = 'character_scheme.levels';
    if (node is! YamlMap) fail(node, _wrongType(node, path, 'a mapping'));
    if (node.nodes.isEmpty) fail(node, '$path must not be empty');
    return List<CharacterLevelScheme>.unmodifiable([
      for (final entry in node.nodes.entries)
        _characterLevelScheme(
          text(entry.key as YamlNode, '$path key'),
          entry.value,
        ),
    ]);
  }

  CharacterLevelScheme _characterLevelScheme(String id, YamlNode node) {
    final path = 'character_scheme.levels.$id';
    final fields = this.fields(node, path);
    fields.allowOnly(_characterLevelFields);
    final values = fields.node('values');
    return CharacterLevelScheme(
      id: id,
      name: _characterName(fields.require('name'), '$path.name'),
      values: values == null
          ? const <String>[]
          : List<String>.unmodifiable([
              for (final (i, item) in list(values, '$path.values').indexed)
                _characterValue(item, '$path.values[$i]'),
            ]),
    );
  }

  /// A name by language code; English is required.
  Map<String, String> _characterName(YamlNode node, String path) {
    if (node is! YamlMap) fail(node, _wrongType(node, path, 'a mapping'));
    final names = <String, String>{
      for (final entry in node.nodes.entries)
        text(entry.key as YamlNode, '$path key'): text(
          entry.value,
          '$path.${_value(entry.key as YamlNode)}',
        ),
    };
    if (!names.containsKey('en')) fail(node, '$path needs en');
    return Map<String, String>.unmodifiable(names);
  }
}
