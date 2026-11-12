/// Shared plumbing for reading the deck-owned files of the deck kinds
/// (topics, creators, recommendations; wiki/Plan-Deck-Kinds-And-Topics.md):
/// the file as a plain tree, and tolerant readers for the few value shapes
/// they use. Free of Flutter.
///
/// The rule of all of them is the sections file's: an entry or a field that
/// cannot be read costs itself, is named in a [KindsProblems] list for the
/// app log, and the rest is used. Only a file that is not of the expected
/// kind, or is of a newer schema, is refused whole, with a
/// [DeckParseException], so that the copy the app already has stays in use.
library;

import 'package:yaml/yaml.dart';

import 'deck_parser.dart';
import 'yaml_tree.dart';

/// What in a file could not be read and was left out, one line each.
class KindsProblems {
  final List<String> _lines = <String>[];

  void add(String path, String what) => _lines.add('$path: $what');

  /// The lines so far, for the log.
  List<String> get lines => List<String>.unmodifiable(_lines);
}

/// The id a data entry has: lowercase words joined by hyphens.
final RegExp dataIdPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

/// A language code, 2 or 3 letters.
final RegExp languageCodePattern = RegExp(r'^[a-z]{2,3}$');

/// The root mapping of the file in [text], which must have `kind: [kind]` and
/// a schema no newer than [supportedSchema]. Throws [DeckParseException]
/// otherwise, naming [source].
Map<Object?, Object?> readKindsFile(
  String text, {
  required String source,
  required String kind,
  required int supportedSchema,
}) {
  DeckParseException bad(String message, [YamlNode? at]) => DeckParseException(
    message,
    source: source,
    line: at == null ? null : at.span.start.line + 1,
    column: at == null ? null : at.span.start.column + 1,
  );

  final YamlNode root;
  try {
    root = loadYamlTree(withoutBom(text));
  } on YamlException catch (e) {
    throw bad(e.message);
  }
  if (root is! YamlMap || root['kind'] != kind) {
    throw bad('a $kind file is a mapping with "kind: $kind"', root);
  }
  final schema = root['schema'];
  if (schema is int && schema > supportedSchema) {
    throw bad(
      '$kind schema $schema is newer than this app reads ($supportedSchema)',
      root,
    );
  }
  final tree = plainTree(root);
  if (tree is! Map) throw bad('a $kind file is a mapping', root);
  return tree;
}

/// The language code a file names: `language: "zz"` or `language: { code: zz }`.
/// Throws [DeckParseException] when it names none.
String readLanguageCode(Map<Object?, Object?> file, {required String source}) {
  final raw = file['language'];
  final code = raw is Map ? raw['code'] : raw;
  if (code is! String || !languageCodePattern.hasMatch(code)) {
    throw DeckParseException(
      'language must be a 2-3 letter code',
      source: source,
    );
  }
  return code;
}

/// [value] as trimmed non-blank text, or null. Years and other numbers are
/// not text.
String? plainText(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}

/// [value] as a whole number, or null: an int, or text of digits (with a
/// leading minus for a BCE year).
int? plainInt(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value.trim());
  return null;
}

/// A mapping of language code to non-blank text, such as a `name` or a `bio`.
/// An entry that is not text or whose key is no language code is left out
/// and named under [path].
Map<String, String> localisedText(
  Object? raw,
  String path,
  KindsProblems problems,
) {
  if (raw == null) return const <String, String>{};
  if (raw is! Map) {
    problems.add(path, 'is not a mapping of language to text, left out');
    return const <String, String>{};
  }
  final out = <String, String>{};
  for (final MapEntry(:key, :value) in raw.entries) {
    final text = plainText(value);
    if (key is String && languageCodePattern.hasMatch(key) && text != null) {
      out[key] = text;
    } else {
      problems.add('$path.$key', 'is not text of a language, left out');
    }
  }
  return Map<String, String>.unmodifiable(out);
}

/// The items of [raw] that are text, in order; any other item is left out
/// and named under [path].
List<String> textList(Object? raw, String path, KindsProblems problems) {
  if (raw == null) return const <String>[];
  if (raw is! List) {
    problems.add(path, 'is not a list, left out');
    return const <String>[];
  }
  final out = <String>[];
  for (final (i, item) in raw.indexed) {
    final text = plainText(item);
    if (text == null) {
      problems.add('$path[$i]', 'is not text, left out');
    } else {
      out.add(text);
    }
  }
  return List<String>.unmodifiable(out);
}

/// The text of [byLanguage] in the first of [spoken] that has one, else
/// English, else the first there is, else the empty string.
String pickLocalised(Map<String, String> byLanguage, Iterable<String> spoken) {
  for (final code in spoken) {
    final text = byLanguage[code];
    if (text != null) return text;
  }
  return byLanguage['en'] ??
      (byLanguage.values.isEmpty ? '' : byLanguage.values.first);
}
