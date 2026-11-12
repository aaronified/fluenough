/// Deck-owned data (owner, 2026-11-11): files that are entirely about the
/// decks, change with them, and belong to no one language, such as the theme
/// list. The index lists them under `shared`; the app downloads them with
/// the decks update, checks them here, and reads them in place of its bundled
/// copy. Free of Flutter, so that it is tested in milliseconds.
library;

import '../data/creators.dart';
import '../data/deck_parser.dart';
import '../data/recommendations.dart';
import '../data/sections.dart';
import '../data/themes.dart';
import 'app_version.dart';

/// The most a shared file may be, in bytes: far over the theme list, far under
/// a deck. The index's claim is refused above it before anything downloads.
const int maxSharedFileBytes = 512 * 1024;

/// What the app can read from the downloads, by path: the file's `kind`. A
/// path the index lists that is not here (and matches no pattern of
/// [sharedKindOf]) is passed by (a later app reads it), so adding a file here
/// is one line and a loader.
const Map<String, String> sharedKinds = <String, String>{
  'decks/themes.yaml': 'themes',
  'decks/sections.yaml': 'sections',
};

/// The files of a kind that has one per language, by path: the creators and
/// the recommendations of a language (deck-kinds plan, D5, D13).
final Map<RegExp, String> _sharedKindPatterns = <RegExp, String>{
  RegExp(r'^decks/creators/[a-z]{2,3}\.yaml$'): 'creators',
  RegExp(r'^decks/recommendations/[a-z]{2,3}\.yaml$'): 'recommendations',
};

/// The `kind` of the shared file at [path], or null for a path this app does
/// not read: the exact paths of [sharedKinds], then the per-language patterns.
String? sharedKindOf(String path) {
  final exact = sharedKinds[path];
  if (exact != null) return exact;
  for (final MapEntry(:key, :value) in _sharedKindPatterns.entries) {
    if (key.hasMatch(path)) return value;
  }
  return null;
}

/// The newest schema of each kind the app reads. A file of a later schema is
/// not used: the bundled copy stays, as for an app too old for it.
const Map<String, int> supportedSharedSchemas = <String, int>{
  'themes': 1,
  'sections': 1,
  'creators': supportedCreatorsSchema,
  'recommendations': supportedRecommendationsSchema,
};

final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

/// One deck-owned file in the index's `shared` list.
class SharedFile {
  const SharedFile({
    required this.path,
    required this.size,
    required this.sha256,
    required this.kind,
    this.schema = 1,
    this.minApp,
    this.appTooOld = false,
  });

  /// Where it is in the repository, such as `decks/themes.yaml`.
  final String path;
  final int size;

  /// 64 lower-case hex digits; a download that does not match is thrown away.
  final String sha256;
  final String kind;
  final int schema;

  /// The oldest app version that can read it (`min_app`, ADR-0052).
  final String? minApp;

  /// Whether this app is older than [minApp].
  final bool appTooOld;

  /// Why this app does not use the file, or null when it can: the bundled
  /// copy stays in that case. Said in words, for the app log.
  String? get unusableReason {
    if (appTooOld) return '$path needs app $minApp';
    final supported = supportedSharedSchemas[kind];
    if (supported == null) return '$path is of a kind this app does not read';
    if (schema > supported) {
      return '$path is of schema $schema, this app reads $supported';
    }
    if (size <= 0 || size > maxSharedFileBytes) {
      return '$path has a size of $size bytes, over the $maxSharedFileBytes '
          'a shared file may be';
    }
    return null;
  }
}

/// The shared files [json], the index's `shared` list, that this app knows
/// how to read, with the reason for each entry left out in [problems].
/// Never throws: a bad entry costs its file and never the index.
({List<SharedFile> files, List<String> problems}) parseSharedFiles(
  Object? json, {
  String? appVersion,
}) {
  final files = <SharedFile>[];
  final problems = <String>[];
  if (json == null) return (files: files, problems: problems);
  if (json is! List) {
    return (
      files: files,
      problems: <String>['the shared list of the index is not a list'],
    );
  }
  final seen = <String>{};
  for (final item in json) {
    try {
      if (item is! Map) {
        problems.add('a shared file is not an object');
        continue;
      }
      final path = item['path'];
      if (path is! String) {
        problems.add('a shared file has no path');
        continue;
      }
      final kind = sharedKindOf(path);
      if (kind == null) {
        // A file a later app reads: not a fault.
        continue;
      }
      if (seen.contains(path)) {
        problems.add('$path is listed twice');
        continue;
      }
      final size = item['size'];
      final sha = item['sha256'];
      if (size is! int || sha is! String || !_hex64.hasMatch(sha)) {
        problems.add('$path has a bad size or sha256');
        continue;
      }
      if (item['kind'] != null && item['kind'] != kind) {
        problems.add('$path is of kind ${item['kind']}, not $kind');
        continue;
      }
      final minApp = cleanMinApp(item['min_app']);
      final schema = item['schema'];
      seen.add(path);
      files.add(
        SharedFile(
          path: path,
          size: size,
          sha256: sha,
          kind: kind,
          schema: schema is int ? schema : 1,
          minApp: minApp,
          appTooOld: appVersion != null && appIsOlderThan(appVersion, minApp),
        ),
      );
    } on Object catch (e) {
      problems.add('a shared file could not be read: $e');
    }
  }
  return (files: files, problems: problems);
}

/// Whether the app can use [text] as the shared file at [path]: null when it
/// can, else what is wrong, in words for the log. The same parser the
/// catalog reads it with, so a file that passes here is one the catalog
/// reads. Never throws.
String? checkSharedText(String path, String text) {
  final kind = sharedKindOf(path);
  if (kind == null) return '$path is not a file this app reads';
  try {
    final source = path.split('/').last;
    if (kind == 'themes') parseThemes(text, source: source);
    if (kind == 'sections') parseSections(text, source: source);
    // A per-language file names its language in its name and in its text.
    final named = source.substring(0, source.length - '.yaml'.length);
    if (kind == 'creators') {
      final file = parseCreators(text, source: source);
      if (file.languageCode != named) {
        return '$path is for language ${file.languageCode}';
      }
    }
    if (kind == 'recommendations') {
      final file = parseRecommendations(text, source: source);
      if (file.languageCode != named) {
        return '$path is for language ${file.languageCode}';
      }
    }
    return null;
  } on DeckParseException catch (e) {
    return e.toString();
  } on Object catch (e) {
    return '$path: $e';
  }
}

/// The name a shared file's copy is kept under on the phone, apart from the
/// decks: `shared-themes.yaml`; a per-language file keeps its folder in the
/// name so that two kinds of one language do not meet: `shared-creators-te.yaml`.
String sharedNoteName(String path) {
  final parts = path.split('/');
  return parts.length > 2 && sharedKinds[path] == null
      ? 'shared-${parts[parts.length - 2]}-${parts.last}'
      : 'shared-${parts.last}';
}
