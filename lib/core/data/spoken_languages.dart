import 'package:yaml/yaml.dart';

/// A language a learner can say they speak (#53).
class SpokenLanguage {
  const SpokenLanguage({
    required this.code,
    required this.iso639_3,
    required this.name,
    required this.ownName,
    this.script,
    this.family,
    this.scriptQuestion,
    this.scriptCanRead,
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

  /// The group it is listed in, folded by default (`indo_aryan`,
  /// `dravidian`, `tibeto_burman`, `austroasiatic`, `germanic`), or null for
  /// a language the list puts in none (#490).
  final String? family;

  /// The sheet's question, "Can you read the Bengali script?", written in
  /// the language's own script by a speaker of it, or null until one has
  /// (the sheet then asks in English) (#490).
  final String? scriptQuestion;

  /// The sheet's answer "I can read the Bengali script", in the same
  /// script, or null.
  final String? scriptCanRead;

  /// Whether the sheet asks in the language's own script: both sentences
  /// are there.
  bool get asksInOwnScript => scriptQuestion != null && scriptCanRead != null;

  /// Whether [query] is in its English name or its own name, ignoring case.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    return q.isNotEmpty &&
        (name.toLowerCase().contains(q) || ownName.toLowerCase().contains(q));
  }
}

/// The languages to offer first (#490): those of the phone's locales, then
/// English, then the languages of the phone's region, at most [limit], only
/// those in [all].
///
/// [locales] are the phone's languages as (language code, country code).
List<String> topPicksFor(
  List<(String, String?)> locales,
  List<SpokenLanguage> all, {
  int limit = 4,
}) {
  final known = <String>{for (final l in all) l.code};
  final picks = <String>[];
  void add(String code) {
    if (known.contains(code) && !picks.contains(code)) picks.add(code);
  }

  for (final (language, _) in locales) {
    add(language);
  }
  add('en');
  for (final (_, country) in locales) {
    for (final code
        in regionLanguages[country?.toUpperCase()] ?? const <String>[]) {
      add(code);
    }
  }
  return picks.take(limit).toList();
}

/// The languages most spoken in a region, for [topPicksFor]. A region not
/// here adds none.
const Map<String, List<String>> regionLanguages = <String, List<String>>{
  'IN': <String>['hi', 'bn', 'te', 'mr', 'ta'],
  'BD': <String>['bn'],
  'NP': <String>['ne'],
  'PK': <String>['ur'],
};

String? _optional(Object? item, String key, int i, [RegExp? pattern]) {
  final value = item is YamlMap ? item[key] : null;
  if (value == null) return null;
  if (value is! String ||
      value.trim().isEmpty ||
      (pattern != null && !pattern.hasMatch(value))) {
    throw FormatException('languages[$i]: $key is malformed');
  }
  return value.trim();
}

final _script = RegExp(r'^[a-z_]+$');
final _code = RegExp(r'^[a-z]{2,3}$');
final _iso = RegExp(r'^[a-z]{3}$');

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
    if ((item['script_question'] == null) !=
        (item['script_can_read'] == null)) {
      throw FormatException(
        'languages[$i]: script_question and script_can_read come together',
      );
    }
    languages.add(
      SpokenLanguage(
        code: code,
        iso639_3: field('iso639_3', _iso),
        name: field('name'),
        ownName: field('own_name'),
        family: _optional(item, 'family', i, _script),
        scriptQuestion: _optional(item, 'script_question', i),
        scriptCanRead: _optional(item, 'script_can_read', i),
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
