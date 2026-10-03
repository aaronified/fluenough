import 'package:yaml/yaml.dart';

import '../models/romanisation.dart';
import 'deck_parser.dart';

const _fields = {'schema', 'kind', 'id', 'language', 'scheme', 'equivalents'};
final _spelling = RegExp(r"^[a-z]+(?:[ '-][a-z]+)*$");

/// The romanisation in [text], a `<code>-romanisation.yaml` (#47). Throws
/// [DeckParseException] for a file that is not one, or is malformed, so that
/// the catalog reports it like a broken deck.
Romanisation parseRomanisation(String text, {required String source}) {
  DeckParseException bad(String message, [YamlNode? at]) => DeckParseException(
    message,
    source: source,
    line: at == null ? null : at.span.start.line + 1,
    column: at == null ? null : at.span.start.column + 1,
  );

  final YamlNode root;
  try {
    root = loadYamlNode(text.startsWith('﻿') ? text.substring(1) : text);
  } on YamlException catch (e) {
    throw bad('not valid YAML: ${e.message}');
  }
  if (root is! YamlMap || root['kind'] != 'romanisation') {
    throw bad(
      'a romanisation file is a mapping with "kind: romanisation"',
      root,
    );
  }
  for (final key in root.nodes.keys.cast<YamlNode>()) {
    if (!_fields.contains(key.value)) {
      throw bad('unknown field "${key.value}" in a romanisation file', key);
    }
  }
  if (root['schema'] != 1) throw bad('schema must be 1', root);
  final language = root['language'];
  if (language is! String || !RegExp(r'^[a-z]{2,3}$').hasMatch(language)) {
    throw bad('language must be a code such as "hi"', root);
  }
  if (root['id'] != '$language-romanisation') {
    throw bad(
      'a romanisation file for $language has id "$language-romanisation"',
      root,
    );
  }
  final scheme = root['scheme'];
  if (scheme is! String || scheme.trim().isEmpty) {
    throw bad('scheme says how $language is romanised, in a line', root);
  }
  final list = root.nodes['equivalents'];
  if (list is! YamlList) {
    throw bad('equivalents must be a list of groups of spellings', root);
  }
  final seen = <String>{};
  final groups = <List<String>>[];
  for (final node in list.nodes) {
    if (node is! YamlList || node.length < 2) {
      throw bad('a group lists two or more spellings', node);
    }
    final group = <String>[];
    for (final item in node.nodes) {
      final spelling = item.value;
      if (spelling is! String || !_spelling.hasMatch(spelling)) {
        throw bad(
          'a spelling is lowercase ASCII letters, got "$spelling"',
          item,
        );
      }
      if (!seen.add(spelling)) throw bad('"$spelling" is in two groups', item);
      group.add(spelling);
    }
    groups.add(List<String>.unmodifiable(group));
  }
  return Romanisation(
    language: language,
    scheme: scheme,
    equivalents: List<List<String>>.unmodifiable(groups),
  );
}
