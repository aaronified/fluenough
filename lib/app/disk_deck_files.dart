import 'dart:io';

import 'deck_files.dart';

/// [DeckFiles] on disk, built from strings alone so that it is made inside
/// an isolate. Native only: the web build has no files.
class DiskDeckFiles implements DeckFiles {
  const DiskDeckFiles(this.locations);

  /// Each file's catalog path, to where it is on disk.
  final Map<String, String> locations;

  @override
  Iterable<String> get paths => locations.keys;

  @override
  Map<String, String> readAll(List<String> failed) {
    final texts = <String, String>{};
    for (final e in locations.entries) {
      try {
        texts[e.key] = File(e.value).readAsStringSync();
      } on Object {
        failed.add(e.key);
      }
    }
    return texts;
  }
}

/// A [SnapshotReader] of a file on disk.
class DiskSnapshotReader implements SnapshotReader {
  const DiskSnapshotReader(this.path);

  final String path;

  @override
  String? read() {
    try {
      final file = File(path);
      return file.existsSync() ? file.readAsStringSync() : null;
    } on Object {
      return null;
    }
  }
}
