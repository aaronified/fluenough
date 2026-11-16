import 'dart:io';
import 'dart:typed_data';

import 'blob_store.dart';

/// A [BlobStore] in a folder, one file per key: what the phone keeps the
/// Find my level question banks in. A write goes to a temporary file first
/// and is renamed over, so a file is never half written; keys are names of
/// files, so they may hold only letters, digits and `-_.` (the caller's keys
/// do).
class FileBlobStore implements BlobStore {
  FileBlobStore(this.directory);

  final Directory directory;

  File _file(String key) => File('${directory.path}/$key');

  @override
  Future<List<String>> keys() async {
    if (!await directory.exists()) return const <String>[];
    return <String>[
      await for (final e in directory.list())
        if (e is File && !e.path.endsWith('.tmp')) e.uri.pathSegments.last,
    ]..sort();
  }

  @override
  Future<Uint8List?> read(String key) async {
    final file = _file(key);
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<void> write(
    Map<String, Uint8List> puts, {
    Iterable<String> deletes = const <String>[],
  }) async {
    await directory.create(recursive: true);
    for (final e in puts.entries) {
      final tmp = File('${directory.path}/${e.key}.tmp');
      await tmp.writeAsBytes(e.value, flush: true);
      await tmp.rename(_file(e.key).path);
    }
    for (final key in deletes) {
      final file = _file(key);
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<void> clear() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
