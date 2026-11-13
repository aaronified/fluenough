/// Writing a private language package out as a `.fnzip`, and turning a
/// built-in course into one the learner can change (#1017, Plan-Private-
/// Languages tasks 19 and 20). Pure Dart, no Flutter.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:yaml/yaml.dart';

import '../backup/zip_files.dart';
import '../models/deck.dart';
import 'private_ids.dart';
import 'private_package.dart';

/// The oldest app that reads a package this app exports: the one that
/// introduced private languages.
const String privatePackageMinApp = '0.9.0';

/// What [PrivateExport.fromBuiltIn] made of a course.
class PrivateExportResult {
  const PrivateExportResult({
    required this.files,
    required this.decks,
    required this.cards,
    required this.skipped,
  });

  /// The package's files, by path in the package, manifest first.
  final Map<String, String> files;

  /// The decks (cores) the package holds copies of.
  final int decks;

  /// The cards in those decks.
  final int cards;

  /// Files of the course left out: facts, sounds, scripts and the like belong
  /// to the app, and a deck that could not be rewritten safely is left out
  /// whole with its layers. The names are never logged, only the count.
  final int skipped;
}

/// A `.fnzip` and the copy of a built-in course a learner changes.
abstract final class PrivateExport {
  /// The file name the learner is offered for the package [id] at
  /// [revision]: `fnpd-qaa-rev1.fnzip`.
  static String fileName(String id, int revision) =>
      '$id-rev$revision.$privateExtension';

  /// The file extension of a package, without its dot.
  static const String privateExtension = 'fnzip';

  /// The bytes of a `.fnzip` holding [files], keyed by path in the package:
  /// the manifest first and the rest by name, each entry deflated when that
  /// makes it smaller. The same files always give the same bytes, and
  /// `ZipFiles.decode` of the result gives the same files back, so a package
  /// exported and imported again is unchanged.
  static Uint8List archive(Map<String, String> files) {
    final names = files.keys.toList()
      ..sort((a, b) {
        if (a == privateManifestFile) return b == privateManifestFile ? 0 : -1;
        if (b == privateManifestFile) return 1;
        return a.compareTo(b);
      });
    return ZipFiles.encode(<String, List<int>>{
      for (final name in names) name: utf8.encode(files[name]!),
    }, deflate: true);
  }

  /// The package that lets a learner change the built-in course of
  /// [language] (Download a course to change): copies of its vocabulary and
  /// grammar decks and their layers, every id rewritten to `fnpd-<code>-`,
  /// and the course's path file as it is.
  ///
  /// [files] are the course's own files, by their path on the phone to their
  /// text. The path still names the built-in decks, so an unchanged export
  /// teaches what the course did and keeps every card's progress; a learner
  /// who changes a deck's copy puts its `fnpd-` id in the path in place of
  /// the built-in one (a changed card is a new card to the app, and starts
  /// fresh). Facts, sounds, scripts, romanisation and themes belong to the
  /// app and are not copied.
  ///
  /// A deck is rewritten as text, so that its layout, notes and comments stay
  /// as written, and then checked: if any id of the language is left without
  /// the prefix, the deck and its layers are left out and counted in
  /// [PrivateExportResult.skipped], so that what is exported always imports.
  ///
  /// [basedOn] says which course revision the learner started from, such as
  /// `te-0.10.0`.
  static PrivateExportResult fromBuiltIn({
    required LanguageInfo language,
    required Map<String, String> files,
    required String basedOn,
    String minApp = privatePackageMinApp,
  }) {
    final code = language.code;
    final cores = <String, ({String id, String text, YamlMap root})>{};
    final layers =
        <
          String,
          ({String id, String core, String native, String text, YamlMap root})
        >{};
    String? pathText;
    var skipped = 0;
    for (final text in files.values) {
      final root = _load(text);
      if (root == null) {
        skipped++;
        continue;
      }
      final kind = root['kind'] ?? 'vocab';
      final id = root['id'];
      final taught = root['language'];
      if (kind == 'path') {
        if (taught == code && pathText == null) {
          pathText = text;
        } else {
          skipped++;
        }
      } else if (kind == 'layer') {
        final core = root['core'];
        final native = root['native'];
        final nativeCode = native is YamlMap ? native['code'] : null;
        if (id is String &&
            core is String &&
            nativeCode is String &&
            id.startsWith('$code-')) {
          layers[id] = (
            id: id,
            core: core,
            native: nativeCode,
            text: text,
            root: root,
          );
        } else {
          skipped++;
        }
      } else if (root['part'] == 'core' &&
          (kind == 'vocab' || kind == 'grammar') &&
          id is String &&
          id.startsWith('$code-') &&
          taught is YamlMap &&
          taught['code'] == code) {
        cores[id] = (id: id, text: text, root: root);
      } else {
        skipped++;
      }
    }

    // Every id the language's decks write: their own, their layers', each
    // card's, and any nested `id`, plus the keys a layer gives translations
    // under (a generated card's id is only ever written there).
    final own = <String>{};
    void collect(Object? node, {required bool keys}) {
      if (node is YamlMap) {
        for (final MapEntry(key: key, value: value) in node.entries) {
          if (key == 'id' && value is String && value.startsWith('$code-')) {
            own.add(value);
          }
          if (keys && key is String && key.startsWith('$code-')) own.add(key);
          collect(value, keys: false);
        }
      } else if (node is YamlList) {
        for (final item in node) {
          collect(item, keys: false);
        }
      }
    }

    for (final core in cores.values) {
      collect(core.root, keys: false);
    }
    for (final layer in layers.values) {
      collect(layer.root, keys: false);
      final cards = layer.root['cards'];
      if (cards is YamlMap) {
        for (final key in cards.keys) {
          if (key is String && key.startsWith('$code-')) own.add(key);
        }
      }
    }

    final quoted = RegExp(
      '(["\'])(${RegExp.escape(code)}-[a-z0-9]+(?:-[a-z0-9]+)*)\\1',
    );
    String rewrite(String text) => text.replaceAllMapped(quoted, (m) {
      final id = m[2]!;
      return own.contains(id) ? '${m[1]}$privateIdMarker$id${m[1]}' : m[0]!;
    });

    // Whether [text], once rewritten, writes no id of the language that
    // still lacks the prefix.
    bool clean(String text) {
      try {
        var ok = true;
        void walk(Object? node, {required bool keys}) {
          if (node is YamlMap) {
            for (final MapEntry(key: key, value: value) in node.entries) {
              if (key == 'id' &&
                  value is String &&
                  value.startsWith('$code-')) {
                ok = false;
              }
              if (keys && key is String && key.startsWith('$code-')) {
                ok = false;
              }
              walk(value, keys: false);
            }
          } else if (node is YamlList) {
            for (final item in node) {
              walk(item, keys: false);
            }
          }
        }

        final root = _load(text);
        if (root == null) return false;
        walk(root, keys: false);
        final cards = root['cards'];
        if (root['kind'] == 'layer' && cards is YamlMap) {
          walk(cards, keys: true);
        }
        return ok;
      } on YamlException {
        return false;
      }
    }

    final out = <String, String>{};
    var decks = 0;
    var cardCount = 0;
    final exportedCores = <String>{};
    for (final core in cores.values) {
      final plain = _withoutAliases(core.text);
      final text = plain == null ? '' : rewrite(plain);
      if (plain == null || !clean(text)) {
        skipped++;
        continue;
      }
      final id = '$privateIdMarker${core.id}';
      out['$code/$id.yaml'] = text;
      exportedCores.add(core.id);
      decks++;
      final cards = core.root['cards'];
      if (cards is YamlList) cardCount += cards.length;
    }
    for (final layer in layers.values) {
      if (!exportedCores.contains(layer.core)) {
        skipped++;
        continue;
      }
      final plain = _withoutAliases(layer.text);
      final text = plain == null ? '' : rewrite(plain);
      if (plain == null || !clean(text)) {
        skipped++;
        continue;
      }
      out['$code/${layer.native}/$privateIdMarker${layer.id}.yaml'] = text;
    }
    if (pathText != null) out['$code-path.yaml'] = pathText;

    return PrivateExportResult(
      files: <String, String>{
        privateManifestFile: manifestText(
          language: language,
          kind: 'modified-language',
          revision: 1,
          basedOn: basedOn,
          minApp: minApp,
        ),
        ...out,
      },
      decks: decks,
      cards: cardCount,
      skipped: skipped,
    );
  }

  /// [text] as it is, or, when it uses YAML anchors and aliases (some of the
  /// course's own files do, from the tool that wrote them), the same data
  /// written out in full: an import refuses an alias, so a package never
  /// holds one. Null when it cannot be read or reads in a loop.
  static String? _withoutAliases(String text) {
    try {
      final root = loadYamlNode(text);
      final visited = Set<Object>.identity();
      bool alias(Object? node) {
        if (node is YamlMap || node is YamlList) {
          if (!visited.add(node!)) return true;
        }
        if (node is YamlMap) {
          for (final MapEntry(:key, :value) in node.nodes.entries) {
            if (alias(key) || alias(value)) return true;
          }
        } else if (node is YamlList) {
          for (final item in node.nodes) {
            if (alias(item)) return true;
          }
        }
        return false;
      }

      if (!alias(root)) return text;
      Object? plain(Object? node) {
        if (node is YamlMap) {
          return <String, Object?>{
            for (final MapEntry(:key, :value) in node.entries)
              '$key': plain(value),
          };
        }
        if (node is YamlList) return <Object?>[for (final i in node) plain(i)];
        if (node is YamlScalar) return node.value;
        return node;
      }

      return '${jsonEncode(plain(root))}\n';
    } on Object {
      return null;
    }
  }

  static YamlMap? _load(String text) {
    try {
      final loaded = loadYaml(text);
      return loaded is YamlMap ? loaded : null;
    } on YamlException {
      return null;
    }
  }

  /// A `manifest.yaml` for [language], with every scalar quoted.
  static String manifestText({
    required LanguageInfo language,
    required String kind,
    required int revision,
    required String minApp,
    String? basedOn,
    String? ownName,
  }) {
    String q(String value) => jsonEncode(value);
    final lines = <String>[
      'format: ${q('fluenough-private')}',
      'package: ${q(packageIdFor(language.code))}',
      'revision: $revision',
      'kind: ${q(kind)}',
      if (basedOn != null) 'based_on: ${q(basedOn)}',
      'min_app: ${q(minApp)}',
      'license: ${q('CC-BY-SA-4.0')}',
      'language:',
      '  code: ${q(language.code)}',
      '  iso639_3: ${q(language.iso639_3)}',
      '  name: ${q(language.name)}',
      if (ownName != null) '  own_name: ${q(ownName)}',
      '  script: ${q(language.script)}',
      if (language.scripts.isNotEmpty)
        '  scripts: [${language.scripts.map(q).join(', ')}]',
      if (language.tts != null) '  tts: ${q(language.tts!)}',
      if (language.rtl) '  rtl: true',
      if (language.icon != null) '  icon: ${q(language.icon!)}',
    ];
    return '${lines.join('\n')}\n';
  }
}
