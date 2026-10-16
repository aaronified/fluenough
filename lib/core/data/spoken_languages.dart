import 'package:yaml/yaml.dart';

/// A language a learner can say they speak (#53).
class SpokenLanguage {
  const SpokenLanguage({
    required this.code,
    required this.iso639_3,
    required this.name,
    required this.ownName,
    this.script,
  });

  /// The same code decks use for `native.code`, such as `bn`.
  final String code;

  final String iso639_3;

  /// Its English name, such as "Bengali".
  final String name;

  /// Its name for itself, such as "বাংলা".
  final String ownName;

  /// The script it is written in, as decks name it (`latin`, `bengali`),
  /// or null where the list does not say (#462).
  final String? script;
}

final _code = RegExp(r'^[a-z]{2,3}$');
final _iso = RegExp(r'^[a-z]{3}$');
final _script = RegExp(r'^[a-z]+$');

/// The languages in [text], `assets/languages.yaml`, in its order. Throws
/// [FormatException] naming the entry at fault.
List<SpokenLanguage> parseSpokenLanguages(String text) {
  final root = loadYaml(text);
  if (root is! YamlMap || root['kind'] != 'languages') {
    throw const FormatException('a languages file has "kind: languages"');
  }
  final list = root['languages'];
  if (list is! YamlList || list.isEmpty) {
    throw const FormatException('languages must be a non-empty list');
  }
  final seen = <String>{};
  final languages = <SpokenLanguage>[];
  for (final (i, item) in list.indexed) {
    String field(String key, [RegExp? pattern]) {
      final value = item is YamlMap ? item[key] : null;
      if (value is! String ||
          value.trim().isEmpty ||
          (pattern != null && !pattern.hasMatch(value))) {
        throw FormatException('languages[$i]: $key is missing or malformed');
      }
      return value.trim();
    }

    final code = field('code', _code);
    if (!seen.add(code)) {
      throw FormatException('languages[$i]: $code is listed twice');
    }
    languages.add(
      SpokenLanguage(
        code: code,
        iso639_3: field('iso639_3', _iso),
        name: field('name'),
        ownName: field('own_name'),
        script: switch (item is YamlMap ? item['script'] : null) {
          final String s when _script.hasMatch(s) => s,
          null => null,
          _ => throw FormatException('languages[$i]: script is malformed'),
        },
      ),
    );
  }
  return languages;
}
