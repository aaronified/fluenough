import 'package:yaml/yaml.dart';

import '../models/sound_contrasts.dart';
import 'deck_parser.dart';
import 'yaml_tree.dart';

const _fields = {
  'schema',
  'kind',
  'id',
  'language',
  'description',
  'contrasts',
};
const _contrastFields = {'id', 'name', 'pairs', 'within_word'};
// A core's fields (#498): the names and description are in each layer.
const _coreFields = {'schema', 'kind', 'part', 'id', 'language', 'contrasts'};
const _coreContrastFields = {'id', 'pairs', 'within_word'};

/// The sound contrasts in [text], a `<code>-sounds.yaml` (#89, ADR-0015).
/// Throws [DeckParseException] for a file that is not one, or is malformed,
/// so that the catalog reports it like a broken deck.
SoundContrasts parseSounds(String text, {required String source}) =>
    _parse(text, source: source, core: false);

/// The core of a split sounds file (`part: "core"`, #498): its pairs, with
/// each contrast's name empty until a layer gives it ([mergeSounds]).
SoundContrasts parseSoundsCore(String text, {required String source}) =>
    _parse(text, source: source, core: true);

SoundContrasts _parse(
  String text, {
  required String source,
  required bool core,
}) {
  DeckParseException bad(String message, [YamlNode? at]) => DeckParseException(
    message,
    source: source,
    line: at == null ? null : at.span.start.line + 1,
    column: at == null ? null : at.span.start.column + 1,
  );

  final YamlNode root;
  try {
    root = loadYamlTree(text.startsWith('﻿') ? text.substring(1) : text);
  } on YamlException catch (e) {
    throw bad('not valid YAML: ${e.message}');
  }
  if (root is! YamlMap || root['kind'] != 'sounds') {
    throw bad('a sounds file is a mapping with "kind: sounds"', root);
  }
  if (core != (root['part'] == 'core')) {
    throw bad(
      core
          ? 'a sounds core has part: "core"'
          : 'a sounds file with part: "core" is read as a core',
      root,
    );
  }
  final fields = core ? _coreFields : _fields;
  for (final key in root.nodes.keys.cast<YamlNode>()) {
    if (!fields.contains(key.value)) {
      throw bad('unknown field "${key.value}" in a sounds file', key);
    }
  }
  if (root['schema'] != 1) throw bad('schema must be 1', root);
  final language = root['language'];
  if (language is! String || !RegExp(r'^[a-z]{2,3}$').hasMatch(language)) {
    throw bad('language must be a code such as "bn"', root);
  }
  if (root['id'] != '$language-sounds') {
    throw bad('a sounds file for $language has id "$language-sounds"', root);
  }
  final list = root.nodes['contrasts'];
  if (list is! YamlList || list.isEmpty) {
    throw bad('contrasts must be a non-empty list', list ?? root);
  }
  final ids = <String>{};
  final contrasts = <SoundContrast>[];
  for (final node in list.nodes) {
    if (node is! YamlMap) throw bad('a contrast is a mapping', node);
    for (final key in node.nodes.keys.cast<YamlNode>()) {
      if (!(core ? _coreContrastFields : _contrastFields).contains(key.value)) {
        throw bad('unknown field "${key.value}" in a contrast', key);
      }
    }
    final id = node['id'];
    if (id is! String || !RegExp(r'^[a-z0-9-]+$').hasMatch(id)) {
      throw bad('a contrast needs an id such as "aspiration"', node);
    }
    if (!ids.add(id)) throw bad('contrast "$id" is listed twice', node);
    final name = core ? '' : node['name'];
    if (name is! String || !core && name.trim().isEmpty) {
      throw bad('contrast "$id" needs a name', node);
    }
    final within = node['within_word'] ?? false;
    if (within is! bool) {
      throw bad('within_word is true or false', node.nodes['within_word']);
    }
    final pairsNode = node.nodes['pairs'];
    if (pairsNode is! YamlList || pairsNode.isEmpty) {
      throw bad('contrast "$id" needs a non-empty list of pairs', node);
    }
    final pairs = <(String, String)>[];
    for (final pair in pairsNode.nodes) {
      if (pair is! YamlList ||
          pair.length != 2 ||
          pair.any((p) => p is! String) ||
          pair[0] == pair[1] ||
          (pair[0] as String).isEmpty && (pair[1] as String).isEmpty) {
        throw bad(
          'a pair is two different strings, at most one of them empty',
          pair,
        );
      }
      pairs.add((pair[0] as String, pair[1] as String));
    }
    contrasts.add(
      SoundContrast(id: id, name: name, pairs: pairs, withinWord: within),
    );
  }
  return SoundContrasts(language: language, contrasts: contrasts);
}
