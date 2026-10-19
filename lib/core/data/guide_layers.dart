import 'package:yaml/yaml.dart';

import '../models/script_guide.dart';
import '../models/sound_contrasts.dart';
import 'deck_parser.dart';

/// The layer of a script guide or sounds core (#498): its text in one
/// native language, keyed by the core's feature or contrast ids.
/// `decks/<lang>/<native>/<lang>-<native>-script.yaml` names its core,
/// `<lang>-script` (or `<lang>-<script>-script`, a guide for one of the
/// language's other scripts), in the folder above (DECK-FORMAT.md, Script guides and
/// Sounds files).
class GuideLayer {
  const GuideLayer({
    required this.id,
    required this.core,
    required this.native,
    this.name,
    this.intro,
    this.description,
    this.features = const <String, ({String name, String text})>{},
    this.contrasts = const <String, String>{},
  });

  final String id;

  /// The core's id: `hi-script`, `hi-perso-arabic-script` or `hi-sounds`.
  final String core;

  /// The native language's code, such as `en`.
  final String native;

  /// A script guide's title and intro.
  final String? name;
  final String? intro;

  /// A sounds file's description.
  final String? description;

  /// Each feature's name and text, by its id.
  final Map<String, ({String name, String text})> features;

  /// Each contrast's name, by its id.
  final Map<String, String> contrasts;
}

/// Whether [coreId], a layer's `core`, names a script guide or sounds core
/// rather than a deck's: a deck's core never ends in `-script`, and is never
/// `<lang>-sounds` (DECK-FORMAT.md, Files and ids).
bool isGuideCoreId(String? coreId) =>
    coreId != null && _guideCoreId.hasMatch(coreId);

final _guideCoreId = RegExp(
  r'^[a-z]{2,3}-(?:[a-z]+(?:-[a-z]+)*-script|sounds)$',
);

const _common = {'schema', 'id', 'kind', 'core', 'native'};

/// The guide layer in [text]. Throws [DeckParseException] for a file that
/// is not one.
GuideLayer parseGuideLayer(String text, {required String source}) {
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
  if (root is! YamlMap || root['kind'] != 'layer') {
    throw bad('a layer is a mapping with kind: "layer"', root);
  }
  if (root['schema'] != 1) throw bad('schema must be 1', root);
  final core = root['core'];
  if (core is! String || !isGuideCoreId(core)) {
    throw bad('core must name a script guide or sounds core', root);
  }
  final isScript = core.endsWith('-script');
  final fields = {
    ..._common,
    ...isScript ? {'name', 'intro', 'features'} : {'description', 'contrasts'},
  };
  for (final key in root.nodes.keys.cast<YamlNode>()) {
    if (!fields.contains(key.value)) {
      throw bad('unknown field "${key.value}" in the layer of $core', key);
    }
  }
  final native = root['native'];
  final code = native is YamlMap ? native['code'] : null;
  if (code is! String || !RegExp(r'^[a-z]{2,3}$').hasMatch(code)) {
    throw bad('native must be a language block with a code', root);
  }
  final lang = core.split('-').first;
  // `hi-script` -> `hi-en-script`, `hi-perso-arabic-script` ->
  // `hi-en-perso-arabic-script`.
  final wantId = '$lang-$code${core.substring(lang.length)}';
  final id = root['id'];
  if (id != wantId) {
    throw bad('the $code layer of $core has id "$wantId"', root);
  }
  String textOf(YamlMap map, String key, String what) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw bad('$what needs $key, as text', map.nodes[key] ?? map);
    }
    return value;
  }

  if (isScript) {
    final list = root.nodes['features'];
    if (list is! YamlMap) {
      throw bad('features maps each feature id to its name and text', root);
    }
    final features = <String, ({String name, String text})>{};
    for (final MapEntry(:key, :value) in list.nodes.entries) {
      final fid = (key as YamlNode).value;
      if (fid is! String || value is! YamlMap) {
        throw bad('features maps each feature id to its name and text', key);
      }
      for (final k in value.nodes.keys.cast<YamlNode>()) {
        if (k.value != 'name' && k.value != 'text') {
          throw bad('unknown field "${k.value}" in feature "$fid"', k);
        }
      }
      features[fid] = (
        name: textOf(value, 'name', 'feature "$fid"'),
        text: textOf(value, 'text', 'feature "$fid"'),
      );
    }
    return GuideLayer(
      id: id as String,
      core: core,
      native: code,
      name: textOf(root, 'name', 'a script guide layer'),
      intro: textOf(root, 'intro', 'a script guide layer'),
      features: features,
    );
  }
  final list = root.nodes['contrasts'];
  if (list is! YamlMap) {
    throw bad('contrasts maps each contrast id to its name', root);
  }
  final contrasts = <String, String>{};
  for (final MapEntry(:key, :value) in list.nodes.entries) {
    final cid = (key as YamlNode).value;
    final name = value.value;
    if (cid is! String || name is! String || name.trim().isEmpty) {
      throw bad('contrasts maps each contrast id to its name, as text', key);
    }
    contrasts[cid] = name;
  }
  final description = root['description'];
  if (description != null && description is! String) {
    throw bad('description is text', root.nodes['description']);
  }
  return GuideLayer(
    id: id as String,
    core: core,
    native: code,
    description: description as String?,
    contrasts: contrasts,
  );
}

/// [core], read by `parseScriptGuideCore`, with [layer]'s text. Every
/// feature of the core needs its text, and the layer names no other.
ScriptGuide mergeScriptGuide(
  ScriptGuide core,
  GuideLayer layer, {
  required String source,
}) {
  final ids = {for (final f in core.features) f.id};
  for (final id in layer.features.keys) {
    if (!ids.contains(id)) {
      throw DeckParseException(
        'feature "$id" is not a feature of ${layer.core}',
        source: source,
      );
    }
  }
  return ScriptGuide(
    language: core.language,
    script: core.script,
    name: layer.name ?? '',
    intro: layer.intro ?? '',
    features: <ScriptFeature>[
      for (final f in core.features)
        if (layer.features[f.id] case final texts?)
          ScriptFeature(
            id: f.id,
            name: texts.name,
            term: f.term,
            reading: f.reading,
            ipa: f.ipa,
            example: f.example,
            text: texts.text,
            letters: f.letters,
          )
        else
          throw DeckParseException(
            'gives no text for feature "${f.id}" of ${layer.core}',
            source: source,
          ),
    ],
  );
}

/// [core], read by `parseSoundsCore`, with [layer]'s names. Every contrast
/// of the core needs its name, and the layer names no other.
SoundContrasts mergeSounds(
  SoundContrasts core,
  GuideLayer layer, {
  required String source,
}) {
  final ids = {for (final c in core.contrasts) c.id};
  for (final id in layer.contrasts.keys) {
    if (!ids.contains(id)) {
      throw DeckParseException(
        'contrast "$id" is not a contrast of ${layer.core}',
        source: source,
      );
    }
  }
  return SoundContrasts(
    language: core.language,
    contrasts: <SoundContrast>[
      for (final c in core.contrasts)
        if (layer.contrasts[c.id] case final name?)
          SoundContrast(
            id: c.id,
            name: name,
            pairs: c.pairs,
            withinWord: c.withinWord,
          )
        else
          throw DeckParseException(
            'gives no name for contrast "${c.id}" of ${layer.core}',
            source: source,
          ),
    ],
  );
}
