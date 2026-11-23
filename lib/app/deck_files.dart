import 'deck_catalog.dart';

/// Deck files a worker isolate reads for itself (ADR-0062, Plan-Lazy-
/// Language-Loading, 3.2): the catalog job carries these, which hold only
/// paths or text and so cross to an isolate as they are, instead of the text
/// of every file read on the UI isolate.
abstract interface class DeckFiles {
  /// The catalog paths this reads.
  Iterable<String> get paths;

  /// Reads every file, by catalog path. A file that cannot be read is left
  /// out and its path is added to [failed]. Never throws.
  Map<String, String> readAll(List<String> failed);
}

/// [DeckFiles] already read, as the web build and the tests have them, and
/// as a job falls back to when no isolate can run.
class MemoryDeckFiles implements DeckFiles {
  const MemoryDeckFiles(this.texts);

  /// Reads [paths] of [source] in place, one `await` each so that the main
  /// loop is never held, leaving out those it cannot read.
  static Future<MemoryDeckFiles> read(
    DeckSource source,
    Iterable<String> paths,
  ) async {
    final texts = <String, String>{};
    for (final path in paths) {
      try {
        texts[path] = await source.read(path);
      } on Object {
        // Left out, as a file a disk read cannot open is.
      }
    }
    return MemoryDeckFiles(texts);
  }

  final Map<String, String> texts;

  @override
  Iterable<String> get paths => texts.keys;

  @override
  Map<String, String> readAll(List<String> failed) => texts;
}

/// [DeckFiles] made of several, read one after the other.
class JoinedDeckFiles implements DeckFiles {
  const JoinedDeckFiles(this.parts);

  final List<DeckFiles> parts;

  @override
  Iterable<String> get paths => <String>[
    for (final part in parts) ...part.paths,
  ];

  @override
  Map<String, String> readAll(List<String> failed) => <String, String>{
    for (final part in parts) ...part.readAll(failed),
  };
}

/// A stored snapshot a worker reads for itself.
abstract interface class SnapshotReader {
  /// The snapshot's text, or null if there is none or it cannot be read.
  String? read();
}

/// A [SnapshotReader] over text already read.
class MemorySnapshotReader implements SnapshotReader {
  const MemorySnapshotReader(this.text);

  final String? text;

  @override
  String? read() => text;
}

/// Where the file at catalog [path] is on disk when [from] is a
/// [DiskLocated] source that has it, else null. Promotion is done on a local
/// of type `Object?`, which a source or store typed as another interface
/// does not get.
String? locateOn(Object? from, String path) {
  final source = from;
  return source is DiskLocated ? source.locate(path) : null;
}

/// A deck source whose files are on disk, so that a worker isolate can read
/// them by path.
abstract interface class DiskLocated {
  /// Where the file at catalog [path] is on disk, or null when it is not a
  /// file of this source.
  String? locate(String path);
}
