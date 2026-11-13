import 'package:yaml/yaml.dart';

import '../decks/app_version.dart';
import '../models/deck.dart';
import 'private_ids.dart';

/// Whether a private package adds a language or changes one the app teaches.
enum PrivateKind {
  /// A language the app does not teach.
  newLanguage('new-language'),

  /// A path (and decks) for a language the app already teaches.
  modifiedLanguage('modified-language');

  const PrivateKind(this.text);

  /// How `manifest.yaml` writes it.
  final String text;
}

/// The `manifest.yaml` of a private language package (#1017): what the
/// package is, its revision, and the language it teaches.
///
/// Pure Dart: [parse] reads text and throws a [FormatException] that names
/// the field at fault; it never returns half a manifest.
class PrivateManifest {
  const PrivateManifest({
    required this.package,
    required this.revision,
    required this.kind,
    required this.language,
    required this.minApp,
    this.basedOn,
  });

  /// The `format` every manifest carries.
  static const String formatName = 'fluenough-private';

  /// The one licence a private package has, as the repository's decks.
  static const String licenseName = 'CC-BY-SA-4.0';

  static const Set<String> _fields = <String>{
    'format',
    'package',
    'revision',
    'kind',
    'language',
    'min_app',
    'license',
    'based_on',
  };

  static const Set<String> _languageFields = <String>{
    'code',
    'iso639_3',
    'name',
    'script',
    'scripts',
    'tts',
    'rtl',
    'icon',
  };

  /// `fnpd-<code>`: one package per language code on a phone.
  final String package;

  /// A whole number that rises with each update and is never reused.
  final int revision;

  final PrivateKind kind;

  /// The language the package teaches.
  final LanguageInfo language;

  /// The oldest app version that reads the package, such as `0.9.0`.
  final String minApp;

  /// For a modified language, the course revision the package starts from.
  final String? basedOn;

  /// The language code, such as `qaa`.
  String get code => language.code;

  /// Reads [text]. Throws a [FormatException] naming the field at fault.
  static PrivateManifest parse(String text) {
    final Object? root;
    try {
      root = loadYaml(text.startsWith('﻿') ? text.substring(1) : text);
    } on YamlException catch (e) {
      throw FormatException('manifest.yaml is not YAML: ${e.message}');
    }
    if (root is! YamlMap) {
      throw const FormatException('manifest.yaml must be a mapping');
    }
    for (final key in root.keys) {
      if (!_fields.contains(key)) {
        throw FormatException('manifest.yaml: unknown field "$key"');
      }
    }

    String string(YamlMap map, String name, String where) {
      final value = map[name];
      if (value == null) {
        throw FormatException('manifest.yaml: missing "$where$name"');
      }
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('manifest.yaml: "$where$name" must be text');
      }
      return value;
    }

    if (string(root, 'format', '') != formatName) {
      throw const FormatException(
        'manifest.yaml: "format" must be "$formatName"',
      );
    }
    final languageNode = root['language'];
    if (languageNode is! YamlMap) {
      throw const FormatException(
        'manifest.yaml: "language" must be a mapping',
      );
    }
    for (final key in languageNode.keys) {
      if (!_languageFields.contains(key)) {
        throw FormatException('manifest.yaml: language: unknown field "$key"');
      }
    }
    final code = string(languageNode, 'code', 'language.');
    final kindText = string(root, 'kind', '');
    final kind = PrivateKind.values
        .where((k) => k.text == kindText)
        .firstOrNull;
    if (kind == null) {
      throw FormatException(
        'manifest.yaml: "kind" must be "new-language" or "modified-language", '
        'got "$kindText"',
      );
    }
    // A new language takes a private-use code, qaa to qtz, that no built-in
    // language uses, so it can never clash with an official course. A package
    // that modifies a language the app teaches carries that language's own
    // code (te), and may not take a free private-use code: it modifies
    // nothing (plan task 11).
    if (kind == PrivateKind.newLanguage && !isPrivateCode(code)) {
      throw FormatException(
        'manifest.yaml: "language.code" "$code" must be a private-use code, '
        'qaa to qtz, that no built-in language uses, for a new language',
      );
    }
    if (kind == PrivateKind.modifiedLanguage && !isModifiableCode(code)) {
      throw FormatException(
        'manifest.yaml: "language.code" "$code" must be the code of a '
        'language the app teaches, such as te, for a modified language',
      );
    }
    final package = string(root, 'package', '');
    if (package != packageIdFor(code)) {
      throw FormatException(
        'manifest.yaml: "package" must be "${packageIdFor(code)}", the '
        'language code after $privateIdMarker, got "$package"',
      );
    }
    final revision = root['revision'];
    if (revision is! int || revision < 1) {
      throw const FormatException(
        'manifest.yaml: "revision" must be a whole number, 1 or more',
      );
    }
    final minApp = string(root, 'min_app', '');
    if (parseAppVersion(minApp) == null) {
      throw FormatException(
        'manifest.yaml: "min_app" must be a version like 0.9.0, got "$minApp"',
      );
    }
    final license = string(root, 'license', '');
    if (license != licenseName) {
      throw FormatException(
        'manifest.yaml: "license" must be "$licenseName", got "$license"',
      );
    }
    final iso = string(languageNode, 'iso639_3', 'language.');
    if (iso.length != 3 || iso.toLowerCase() != iso) {
      throw FormatException(
        'manifest.yaml: "language.iso639_3" must be three lowercase letters, '
        'got "$iso"',
      );
    }
    final scriptsNode = languageNode['scripts'];
    if (scriptsNode != null &&
        (scriptsNode is! YamlList || scriptsNode.any((s) => s is! String))) {
      throw const FormatException(
        'manifest.yaml: "language.scripts" must be a list of text',
      );
    }
    final rtl = languageNode['rtl'];
    if (rtl != null && rtl is! bool) {
      throw const FormatException(
        'manifest.yaml: "language.rtl" must be true or false',
      );
    }
    final basedOn = root['based_on'];
    if (basedOn != null && basedOn is! String) {
      throw const FormatException('manifest.yaml: "based_on" must be text');
    }
    final tts = languageNode['tts'];
    final icon = languageNode['icon'];
    return PrivateManifest(
      package: package,
      revision: revision,
      kind: kind,
      minApp: minApp,
      basedOn: basedOn as String?,
      language: LanguageInfo(
        code: code,
        iso639_3: iso,
        name: string(languageNode, 'name', 'language.'),
        script: languageNode['script'] == null
            ? 'latin'
            : string(languageNode, 'script', 'language.'),
        scripts: <String>[
          if (scriptsNode is YamlList)
            for (final s in scriptsNode) s as String,
        ],
        tts: tts is String ? tts : null,
        rtl: rtl == true,
        icon: icon is String ? icon : null,
      ),
    );
  }
}
