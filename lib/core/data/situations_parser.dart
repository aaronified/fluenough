import 'package:yaml/yaml.dart';

import '../models/situation.dart';
import 'deck_parser.dart';
import 'yaml_tree.dart';

final _id = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
final _code = RegExp(r'^[a-z]{2,3}$');

/// Reads a situations file (`kind: situations`) into its situations, in
/// order (#724).
///
/// Follows `parseFacts`: a malformed file throws a [DeckParseException] with
/// the file and line, so the catalog reports it like a broken deck.
/// `tools/validate_decks.py` holds the full rules, such as the card ids
/// being cards of the language; this checks what the app needs to show a
/// sheet. A card id that is not found is left out when the sheet is drawn.
SituationsFile parseSituations(String text, {required String source}) {
  Never fail(String message, [YamlNode? at]) => throw DeckParseException(
    message,
    source: source,
    line: at == null ? null : at.span.start.line + 1,
    column: at == null ? null : at.span.start.column + 1,
  );

  final YamlNode root;
  try {
    root = loadYamlTree(text.startsWith('﻿') ? text.substring(1) : text);
  } on YamlException catch (e) {
    fail(e.message);
  }
  if (root is! YamlMap || root['kind'] != 'situations') {
    fail('a situations file is a mapping with "kind: situations"', root);
  }
  final language = root.nodes['language'];
  final code = language is YamlMap ? language['code'] : null;
  if (code is! String || !_code.hasMatch(code)) {
    fail('language.code must be a 2-3 letter code', language ?? root);
  }
  final list = root.nodes['situations'];
  if (list is! YamlList || list.nodes.isEmpty) {
    fail('situations must be a non-empty list', list ?? root);
  }

  List<String> cardList(YamlMap node, String key, String id) {
    final value = node.nodes[key];
    if (value == null) return const <String>[];
    if (value is! YamlList || value.nodes.any((n) => n.value is! String)) {
      fail('situation "$id": $key must be a list of card ids', value);
    }
    return List<String>.unmodifiable(value.nodes.map((n) => n.value as String));
  }

  final seen = <String>{};
  final situations = <Situation>[];
  for (final node in list.nodes) {
    if (node is! YamlMap) fail('each situation is a mapping', node);
    final id = node['id'];
    if (id is! String || !_id.hasMatch(id)) {
      fail('situation id must be lowercase words joined by hyphens', node);
    }
    if (!seen.add(id)) fail('situation "$id" is listed twice', node);
    final icon = node['icon'];
    if (icon is! String || icon.isEmpty) {
      fail('situation "$id" needs an icon', node);
    }
    final titleNode = node.nodes['title'];
    if (titleNode is! YamlMap || titleNode.isEmpty) {
      fail('situation "$id" needs a title keyed by language code', node);
    }
    final title = <String, String>{};
    for (final MapEntry(:key, :value) in titleNode.entries) {
      if (key is! String || !_code.hasMatch(key)) {
        fail('situation "$id": title key "$key" is not a language code', node);
      }
      if (value is! String || value.trim().isEmpty) {
        fail('situation "$id": title.$key must be non-empty text', node);
      }
      title[key] = value.trim();
    }
    if (!title.containsKey('en')) {
      fail('situation "$id": the title needs an English entry', titleNode);
    }
    final phrases = cardList(node, 'phrases', id);
    final words = cardList(node, 'words', id);
    if (phrases.isEmpty && words.isEmpty) {
      fail('situation "$id" lists no cards', node);
    }
    situations.add(
      Situation(
        id: id,
        icon: icon,
        title: Map<String, String>.unmodifiable(title),
        phrases: phrases,
        words: words,
      ),
    );
  }
  return SituationsFile(
    languageCode: code,
    situations: List<Situation>.unmodifiable(situations),
  );
}
