import 'package:yaml/yaml.dart';

import '../data/yaml_tree.dart';
import '../private/private_ids.dart';
import 'language_summary.dart';
import 'shared_data.dart';

/// Which language unit each deck file belongs to (ADR-0062, Plan-Lazy-
/// Language-Loading, 3.1). Pure Dart, no Flutter: this is in `lib/core` and
/// stays so.

/// Where a learner's added decks are read from, as the catalog names them.
const String _addedPrefix = 'added/';

/// Where a private package's files are read from.
const String _privatePrefix = 'private/';

final RegExp _perLanguageFile = RegExp(
  r'^decks/(?:creators|recommendations)/([a-z]{2,3})\.yaml$',
);

final RegExp _languageFolder = RegExp(r'^decks/([a-z]{2,3})/');

final RegExp _languageCode = RegExp(r'^[a-z]{2,3}$');

/// Whether [path] is a file of the shared unit: the theme list and the
/// sections, which every language unit is parsed with.
bool isSharedUnitPath(String path) => sharedKinds.containsKey(path);

/// Whether [code] can name a unit: two or three lower-case letters.
bool isUnitCode(String code) => _languageCode.hasMatch(code);

/// The language whose own folder [path] is in (`decks/te/...`), or null.
String? languageFolderOf(String path) =>
    _languageFolder.firstMatch(path)?.group(1);

/// The language unit [path] belongs to, or null when it belongs to none that
/// the path alone tells: a shared file, a learner's added deck (its language
/// is in the file, see [languageCodeOfDeckText]) or a path of no known shape.
String? languageOfDeckPath(String path) {
  if (isSharedUnitPath(path)) return null;
  final shared = _perLanguageFile.firstMatch(path);
  if (shared != null) return shared.group(1);
  final folder = languageFolderOf(path);
  if (folder != null) return folder;
  if (path.startsWith(_privatePrefix)) {
    final name = path.substring(_privatePrefix.length).split('/').first;
    final code = packageCode('$name-x');
    if (code != null && name == packageIdFor(code)) return code;
  }
  return null;
}

/// The `language.code` of a single-file deck's [text], or null when it
/// cannot be told. Reads only the header of the YAML; never throws.
String? languageCodeOfDeckText(String text) {
  try {
    final root = loadYamlTree(withoutBom(text)).value;
    final language = root is YamlMap ? root['language'] : null;
    final code = language is YamlMap ? language['code'] : null;
    return code is String && isUnitCode(code) ? code : null;
  } on Object {
    return null;
  }
}

/// The paths of a catalog split by the unit each belongs to.
class LanguagePartition {
  const LanguagePartition({
    required this.shared,
    required this.byLanguage,
    required this.unrouted,
  });

  /// The shared unit's paths: the theme list and the sections.
  final List<String> shared;

  /// Each language's paths, sorted, by language code.
  final Map<String, List<String>> byLanguage;

  /// The paths that belong to no unit, such as an added deck whose language
  /// is not known.
  final List<String> unrouted;
}

/// Splits [paths] into units. [addedLanguages] gives the language of each
/// added deck (`added/...`) by path.
LanguagePartition partitionPaths(
  Iterable<String> paths, {
  Map<String, String> addedLanguages = const <String, String>{},
}) {
  final shared = <String>[];
  final byLanguage = <String, List<String>>{};
  final unrouted = <String>[];
  for (final path in paths) {
    if (isSharedUnitPath(path)) {
      shared.add(path);
      continue;
    }
    var code = languageOfDeckPath(path);
    if (code == null && path.startsWith(_addedPrefix)) {
      final routed = addedLanguages[path];
      if (routed != null && isUnitCode(routed)) code = routed;
    }
    if (code == null) {
      unrouted.add(path);
    } else {
      (byLanguage[code] ??= <String>[]).add(path);
    }
  }
  shared.sort();
  unrouted.sort();
  for (final list in byLanguage.values) {
    list.sort();
  }
  return LanguagePartition(
    shared: shared,
    byLanguage: byLanguage,
    unrouted: unrouted,
  );
}

/// What a cache check found: the cache is still good, or why it is not.
class CacheVerdict {
  const CacheVerdict.match() : reason = null;

  const CacheVerdict.mismatch(String this.reason);

  /// Why the cache does not match, or null when it does.
  final String? reason;

  bool get matches => reason == null;

  @override
  String toString() => matches ? 'match' : 'mismatch($reason)';
}

/// Checks a language's cached summary against the files on the phone, and
/// parses nothing: the cache is good when its stamp has the current format,
/// app version and files digest. [shas] are the SHA-256s of the language's
/// files as the downloads' manifest knows them. Never throws.
CacheVerdict verifyLanguageCache({
  required LanguageSummary? summary,
  required Map<String, String> shas,
  required String app,
}) {
  try {
    if (summary == null) return const CacheVerdict.mismatch('no summary');
    final stamp = summary.stamp;
    if (stamp.format != LanguageSummary.format) {
      return const CacheVerdict.mismatch('format changed');
    }
    if (stamp.filesDigest != filesDigestOf(shas)) {
      return const CacheVerdict.mismatch('files changed');
    }
    if (stamp.app != app) return const CacheVerdict.mismatch('app updated');
    return const CacheVerdict.match();
  } on Object catch (e) {
    return CacheVerdict.mismatch('unreadable: $e');
  }
}

/// [verifyLanguageCache] for several languages, from text only so that it
/// crosses to an isolate: [summaries] is the summaries file's text and
/// [shas] each language's known file hashes.
Map<String, CacheVerdict> verifyCaches({
  required String? summaries,
  required Map<String, Map<String, String>> shas,
  required String app,
}) {
  final known = decodeSummaries(summaries);
  return <String, CacheVerdict>{
    for (final e in shas.entries)
      e.key: verifyLanguageCache(
        summary: known[e.key],
        shas: e.value,
        app: app,
      ),
  };
}
