import 'dart:convert';

import 'yaml_tree.dart';

/// The deck files' YAML, read once and kept as compact JSON (#875, ADR-0048).
///
/// Reading every downloaded deck's YAML is most of a cold start. A snapshot
/// keeps, for each deck file, the tree its YAML parses to (see
/// [plainTree]) with the file's SHA-256, so that the next launch reads one
/// JSON file instead. It holds the trees, not the parsed catalog, so the
/// parsers still run on every launch and a change to them can never leave a
/// stale catalog behind.
///
/// A snapshot is good only for the app version that wrote it, and a file's
/// tree only for the file whose SHA-256 it carries: a changed file is read
/// from YAML again, and a removed one is left out of the next snapshot.
/// Anything unreadable is no snapshot at all.
///
/// Pure Dart, no Flutter: this is in `lib/core` and stays so.
class CatalogSnapshot {
  const CatalogSnapshot({required this.app, required this.files});

  /// The layout of the JSON. Raised when it changes, which invalidates every
  /// snapshot written before.
  static const int format = 1;

  /// The app version that wrote it, such as `0.6.8`.
  final String app;

  /// The tree of each deck file, by path.
  final Map<String, SnapshotFile> files;

  /// [text] as a snapshot written by app version [app], or null if it is
  /// null, is not one, is of another [format] or app version, or is damaged
  /// in any way. Never throws.
  static CatalogSnapshot? tryDecode(String? text, {required String app}) {
    if (text == null || text.isEmpty) return null;
    try {
      final json = jsonDecode(text);
      if (json is! Map ||
          json['format'] != format ||
          json['app'] != app ||
          json['files'] is! Map) {
        return null;
      }
      final files = <String, SnapshotFile>{};
      for (final entry in (json['files'] as Map).entries) {
        final file = entry.value;
        if (entry.key is! String ||
            file is! Map ||
            file['sha'] is! String ||
            !file.containsKey('tree')) {
          return null;
        }
        files[entry.key as String] = SnapshotFile(
          sha: file['sha'] as String,
          tree: treeFromJson(file['tree']),
        );
      }
      return CatalogSnapshot(app: app, files: files);
    } on Object {
      return null;
    }
  }

  /// The snapshot as JSON text, which [tryDecode] reads back.
  String encode() => jsonEncode(<String, Object?>{
    'format': format,
    'app': app,
    'files': <String, Object?>{
      for (final e in files.entries)
        e.key: <String, Object?>{
          'sha': e.value.sha,
          'tree': treeToJson(e.value.tree),
        },
    },
  });

  /// The trees still good: those of the files in [shas] (path to SHA-256)
  /// whose SHA-256 is the one the snapshot has.
  Map<String, Object?> reusable(Map<String, String> shas) => <String, Object?>{
    for (final e in files.entries)
      if (shas[e.key] == e.value.sha) e.key: e.value.tree,
  };

  /// Whether the snapshot lists exactly [other]'s paths with its SHA-256s,
  /// so that writing [other] in its place would change nothing.
  bool sameFilesAs(CatalogSnapshot other) {
    if (files.length != other.files.length) return false;
    for (final e in files.entries) {
      if (other.files[e.key]?.sha != e.value.sha) return false;
    }
    return true;
  }
}

/// One deck file in a [CatalogSnapshot].
class SnapshotFile {
  const SnapshotFile({required this.sha, required this.tree});

  /// The SHA-256 of the file's text it was read from, as 64 hex digits.
  final String sha;

  /// The file's YAML as plain Dart ([plainTree]).
  final Object? tree;
}
