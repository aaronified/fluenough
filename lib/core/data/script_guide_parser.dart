import 'package:yaml/yaml.dart';

import '../models/script_guide.dart';
import 'deck_parser.dart';

const _fields = {
  'schema',
  'kind',
  'id',
  'language',
  'name',
  'intro',
  'features',
};
// A core's fields (#498): the text is in each layer.
const _coreFields = {'schema', 'kind', 'part', 'id', 'language', 'features'};
const _coreFeatureFields = {
  'id',
  'term',
  'reading',
  'ipa',
  'example',
  'letters',
};
const _featureFields = {
  'id',
  'name',
  'term',
  'reading',
  'ipa',
  'example',
  'text',
  'letters',
};

/// The script guide in [text], a `<code>-script.yaml` (#30, ADR-0016).
/// Throws [DeckParseException] for a file that is not one, or is malformed,
/// so that the catalog reports it like a broken deck.
ScriptGuide parseScriptGuide(String text, {required String source}) =>
    _parse(text, source: source, core: false);

/// The core of a split script guide (`part: "core"`, #498): its letters,
/// with no text. Its name, intro and each feature's name and text are
/// empty until a layer gives them ([mergeScriptGuide]).
ScriptGuide parseScriptGuideCore(String text, {required String source}) =>
    _parse(text, source: source, core: true);

ScriptGuide _parse(String text, {required String source, required bool core}) {
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
  if (root is! YamlMap || root['kind'] != 'script') {
    throw bad('a script guide is a mapping with "kind: script"', root);
  }
  if (core != (root['part'] == 'core')) {
    throw bad(
      core
          ? 'a script guide core has part: "core"'
          : 'a script guide with part: "core" is read as a core',
      root,
    );
  }
  final fields = core ? _coreFields : _fields;
  for (final key in root.nodes.keys.cast<YamlNode>()) {
    if (!fields.contains(key.value)) {
      throw bad('unknown field "${key.value}" in a script guide', key);
    }
  }
  if (root['schema'] != 1) throw bad('schema must be 1', root);
  final language = root['language'];
  if (language is! String || !RegExp(r'^[a-z]{2,3}$').hasMatch(language)) {
    throw bad('language must be a code such as "bn"', root);
  }
  // `hi-script`, or for another script of the language `hi-perso-arabic-script`
  // (ADR-0016): the script, hyphenated, between the code and `-script`.
  final id = root['id'];
  final idPattern = RegExp('^$language-(?:([a-z]+(?:-[a-z]+)*)-)?script\$');
  final match = id is String ? idPattern.firstMatch(id) : null;
  if (match == null) {
    throw bad(
      'a script guide for $language has id "$language-script", or '
      '"$language-<script>-script" for another script of the language',
      root,
    );
  }
  final script = match.group(1)?.replaceAll('-', '_');
  String required(YamlMap map, String key, String what) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw bad('$what needs $key', map.nodes[key] ?? map);
    }
    return value;
  }

  final name = core ? '' : required(root, 'name', 'a script guide');
  final intro = core ? '' : required(root, 'intro', 'a script guide');
  final featureFields = core ? _coreFeatureFields : _featureFields;
  final list = root.nodes['features'];
  if (list is! YamlList || list.isEmpty) {
    throw bad('features must be a non-empty list', list ?? root);
  }
  final ids = <String>{};
  final features = <ScriptFeature>[];
  for (final node in list.nodes) {
    if (node is! YamlMap) throw bad('a feature is a mapping', node);
    for (final key in node.nodes.keys.cast<YamlNode>()) {
      if (!featureFields.contains(key.value)) {
        throw bad('unknown field "${key.value}" in a feature', key);
      }
    }
    final id = node['id'];
    if (id is! String || !RegExp(r'^[a-z0-9-]+$').hasMatch(id)) {
      throw bad('a feature needs an id such as "headline"', node);
    }
    if (!ids.add(id)) throw bad('feature "$id" is listed twice', node);
    final term = node['term'];
    if (term != null && (term is! String || term.trim().isEmpty)) {
      throw bad('feature "$id": term is text, or left out', node);
    }
    final reading = node['reading'];
    if (reading != null &&
        (term == null || reading is! String || reading.trim().isEmpty)) {
      throw bad('feature "$id": reading is the term\'s, as text', node);
    }
    final ipa = node['ipa'];
    if (ipa != null && (term == null || ipa is! String || ipa.trim().isEmpty)) {
      throw bad('feature "$id": ipa is the term\'s, as text', node);
    }
    final lettersNode = node.nodes['letters'];
    final letters = <String>[];
    if (lettersNode != null) {
      if (lettersNode is! YamlList) {
        throw bad('feature "$id": letters is a list', lettersNode);
      }
      for (final letter in lettersNode.nodes) {
        if (letter.value is! String || (letter.value as String).isEmpty) {
          throw bad('feature "$id": each letter is quoted text', letter);
        }
        letters.add(letter.value as String);
      }
    }
    features.add(
      ScriptFeature(
        id: id,
        name: core ? '' : required(node, 'name', 'feature "$id"'),
        term: term as String?,
        reading: reading as String?,
        ipa: ipa as String?,
        example: required(node, 'example', 'feature "$id"'),
        text: core ? '' : required(node, 'text', 'feature "$id"'),
        letters: letters,
      ),
    );
  }
  return ScriptGuide(
    language: language,
    script: script,
    name: name,
    intro: intro,
    features: features,
  );
}
