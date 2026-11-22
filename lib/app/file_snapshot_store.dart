import 'dart:io';

import '../core/decks/language_unit.dart';
import 'catalog_set.dart';
import 'deck_catalog.dart';
import 'disk_deck_files.dart';

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
    // A name of its own per write, so two launches never share a part file.
    final part = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.part',
    );
    await part.writeAsString(text, flush: true);
    await part.rename(file.path);
  }
}

/// The snapshots of the languages, one file each in [directory]
/// (`<code>.json`), as [CatalogSet] keeps them (ADR-0048, ADR-0062). [legacy]
/// is the older single snapshot of every language, read only to seed a
/// language that has none of its own. A code that is not two or three
/// lower-case letters has no file.
LanguageSnapshots fileLanguageSnapshots({
  required Directory directory,
  required File legacy,
  required String app,
  Future<Map<String, String>> Function()? knownShas,
}) {
  String name(String code) {
    if (!isUnitCode(code)) throw ArgumentError.value(code, 'code', 'bad code');
    return '${directory.path}/$code.json';
  }

  return LanguageSnapshots(
    storeFor: (code) => FileSnapshotStore(File(name(code))),
    readerFor: (code) => DiskSnapshotReader(name(code)),
    app: app,
    seed: DiskSnapshotReader(legacy.path),
    knownShas: knownShas,
  );
}
