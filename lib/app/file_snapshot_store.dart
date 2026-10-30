import 'dart:io';

import 'deck_catalog.dart';

/// The catalog snapshot (#875, ADR-0048) in one file of the app's own
/// storage. Native only: the web build has no files and no snapshot.
///
/// Written beside its place and moved in, so that a launch cut short leaves
/// the old snapshot or the new, never half of one.
class FileSnapshotStore implements SnapshotStore {
  FileSnapshotStore(this.file);

  final File file;

  @override
  Future<String?> read() async {
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String text) async {
    await file.parent.create(recursive: true);
    final part = File('${file.path}.part');
    await part.writeAsString(text, flush: true);
    await part.rename(file.path);
  }
}
