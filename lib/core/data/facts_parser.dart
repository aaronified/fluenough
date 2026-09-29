import 'package:yaml/yaml.dart';

import '../models/fact.dart';
import 'deck_parser.dart';

final _id = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
final _code = RegExp(r'^[a-z]{2,3}$');

/// Reads a facts file (`kind: facts`) into its facts, in order (#48).
///
/// Follows `DeckParser`: a malformed file throws a [DeckParseException] with
/// the file and line, so the catalog reports it like a broken deck, and
/// nothing a user file contains can crash it. `tools/validate_decks.py`
/// holds the full rules, such as the 30-fact minimum; this checks what the
/// app needs to show a fact.
FactsFile parseFacts(String text, {required String source}) {
  Never fail(String message, [YamlNode? at]) => throw DeckParseException(
    message,
    source: source,
    line: at == null ? null : at.span.start.line + 1,
    column: at == null ? null : at.span.start.column + 1,
  );

  final YamlNode root;
  try {
    root = loadYamlNode(text.startsWith('﻿') ? text.substring(1) : text);
  } on YamlException catch (e) {
    fail(e.message);
  }
  if (root is! YamlMap || root['kind'] != 'facts') {
    fail('a facts file is a mapping with "kind: facts"', root);
  }
  final language = root.nodes['language'];
  final code = language is YamlMap ? language['code'] : null;
  if (code is! String || !_code.hasMatch(code)) {
    fail('language.code must be a 2-3 letter code', language ?? root);
  }
  final list = root.nodes['facts'];
  if (list is! YamlList || list.nodes.isEmpty) {
    fail('facts must be a non-empty list', list ?? root);
  }

  final seen = <String>{};
  final facts = <Fact>[];
  for (final node in list.nodes) {
    if (node is! YamlMap) fail('each fact is a mapping', node);
    final id = node['id'];
    if (id is! String || !_id.hasMatch(id)) {
      fail('fact id must be lowercase words joined by hyphens', node);
    }
    if (!seen.add(id)) fail('fact "$id" is listed twice', node);
    final textNode = node.nodes['text'];
    if (textNode is! YamlMap || textNode.isEmpty) {
      fail('fact "$id" needs text keyed by language code', textNode ?? node);
    }
    final texts = <String, String>{};
    for (final MapEntry(:key, :value) in textNode.entries) {
      if (key is! String || !_code.hasMatch(key)) {
        fail('fact "$id": text key "$key" is not a language code', textNode);
      }
      if (value is! String || value.trim().isEmpty) {
        fail('fact "$id": text.$key must be non-empty text', textNode);
      }
      texts[key] = value.trim();
    }
    final contrast = node['contrast'];
    if (contrast != null &&
        (contrast is! String || !texts.containsKey(contrast))) {
      fail(
        'fact "$id": contrast must be a language its text is written in',
        node,
      );
    }
    final tags = node['tags'];
    final source = node['source'];
    facts.add(
      Fact(
        id: id,
        text: Map<String, String>.unmodifiable(texts),
        contrast: contrast as String?,
        tags: tags is YamlList
            ? List<String>.unmodifiable(tags.whereType<String>())
            : const <String>[],
        source: source is String ? source : null,
      ),
    );
  }
  return FactsFile(languageCode: code, facts: List<Fact>.unmodifiable(facts));
}
