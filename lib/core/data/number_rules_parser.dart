import 'package:yaml/yaml.dart';

import '../models/deck.dart';
import '../models/number_rules.dart';
import 'deck_parser.dart';

const _fields = {
  'schema',
  'id',
  'name',
  'kind',
  'language',
  'license',
  'description',
  'words',
  'tens_and_units',
  'hundreds',
  'hundreds_before',
  'thousands',
  'thousands_before',
  'join',
};

/// The number rules in [text], a `<code>-numbers.yaml` (#54, ADR-0011).
/// Throws [DeckParseException] for a file that is not one, or is malformed,
/// so that the catalog reports it like a broken deck.
NumberRules parseNumberRules(String text, {required String source}) {
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
  if (root is! YamlMap || root['kind'] != 'numbers') {
    throw bad('a numbers file is a mapping with "kind: numbers"', root);
  }
  final YamlMap doc = root;
  for (final key in doc.nodes.keys.cast<YamlNode>()) {
    if (!_fields.contains(key.value)) {
      throw bad('unknown field "${key.value}" in a numbers file', key);
    }
  }

  String text0(String key) {
    final value = doc[key];
    if (value is! String || value.trim().isEmpty) {
      throw bad('$key is required', doc.nodes[key] ?? doc);
    }
    return value;
  }

  final language = doc.nodes['language'];
  if (language is! YamlMap) throw bad('language is required', doc);
  String langField(String key) {
    final value = language[key];
    if (value is! String || value.trim().isEmpty) {
      throw bad('language.$key is required', language);
    }
    return value;
  }

  final info = LanguageInfo(
    code: langField('code'),
    iso639_3: langField('iso639_3'),
    name: langField('name'),
    script: langField('script'),
    tts: language['tts'] as String?,
  );

  final id = text0('id');
  if (id != '${info.code}-numbers') {
    throw bad('id must be "${info.code}-numbers", got "$id"', doc.nodes['id']);
  }

  /// Keyed by whole numbers from [min] to [max]; each value a spelling or a
  /// list of them, the usual one first.
  Map<int, List<String>> table(
    String key, {
    required int min,
    required int max,
    bool required = true,
    bool complete = false,
  }) {
    final node = doc.nodes[key];
    if (node == null || node.value == null) {
      if (required) throw bad('$key is required', doc);
      return const <int, List<String>>{};
    }
    if (node is! YamlMap || node.nodes.isEmpty) {
      throw bad('$key must map numbers to their words', node);
    }
    final out = <int, List<String>>{};
    for (final entry in node.nodes.entries) {
      final k = (entry.key as YamlNode).value;
      if (k is! int || k < min || k > max) {
        throw bad(
          '$key: keys are whole numbers from $min to $max, got "$k"',
          entry.key as YamlNode,
        );
      }
      final v = entry.value;
      final spellings = <String>[
        if (v.value is String)
          v.value as String
        else if (v is YamlList)
          for (final item in v.nodes)
            if (item.value is String) item.value as String,
      ];
      if (spellings.isEmpty ||
          spellings.any((s) => s.trim().isEmpty) ||
          (v is YamlList && spellings.length != v.nodes.length)) {
        throw bad('$key.$k must be a word or a list of words', v);
      }
      // NFC is the validator's to check, as it is for a card's target.
      out[k] = List<String>.unmodifiable(spellings.map((s) => s.trim()));
    }
    if (complete) {
      for (var k = min; k <= max; k++) {
        if (!out.containsKey(k)) throw bad('$key needs an entry for $k', node);
      }
    }
    return Map<int, List<String>>.unmodifiable(out);
  }

  final tensAndUnits = doc['tens_and_units'] ?? false;
  if (tensAndUnits is! bool) {
    throw bad(
      'tens_and_units must be true or false',
      doc.nodes['tens_and_units'],
    );
  }
  final join = doc['join'] ?? ' ';
  if (join is! String) throw bad('join must be text', doc.nodes['join']);

  return NumberRules(
    id: id,
    language: info,
    words: table('words', min: 1, max: 99),
    tensAndUnits: tensAndUnits,
    hundreds: table('hundreds', min: 1, max: 9, complete: true),
    hundredsBefore: table(
      'hundreds_before',
      min: 1,
      max: 9,
      required: false,
      complete: true,
    ),
    thousands: table('thousands', min: 1, max: 9, complete: true),
    thousandsBefore: table(
      'thousands_before',
      min: 1,
      max: 9,
      required: false,
      complete: true,
    ),
    join: join,
  );
}
