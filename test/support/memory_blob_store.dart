import 'dart:typed_data';

import 'package:fluenough/app/blob_store.dart';

/// [BlobStore] in a map, standing in for the browser's IndexedDB, with its
/// failures set by hand: storage that is denied, or full.
class MemoryBlobStore implements BlobStore {
  /// What is held, by key. Tests read and damage it directly.
  final Map<String, Uint8List> data = <String, Uint8List>{};

  /// While set, every read throws: storage that is denied.
  bool failReads = false;

  /// While set, [write] throws and changes nothing: storage that is full.
  bool failWrites = false;

  /// How many times [write] was called, failed or not.
  int writes = 0;

  @override
  Future<List<String>> keys() async {
    if (failReads) throw StateError('storage denied');
    return data.keys.toList()..sort();
  }

  @override
  Future<Uint8List?> read(String key) async {
    if (failReads) throw StateError('storage denied');
    return data[key];
  }

  @override
  Future<void> write(
    Map<String, Uint8List> puts, {
    Iterable<String> deletes = const <String>[],
  }) async {
    writes++;
    if (failWrites) throw StateError('quota exceeded');
    deletes.forEach(data.remove);
    data.addAll(puts);
  }

  @override
  Future<void> clear() async {
    if (failWrites) throw StateError('quota exceeded');
    data.clear();
  }
}
