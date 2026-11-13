/// The deck-kinds fixture set on disk (`test/fixtures/deck-kinds/`), read as
/// files by their repository path (`decks/zz/zz-words.yaml`,
/// `decks/creators/zz.yaml`, `decks/sections.yaml`), as the catalog is given
/// them.
library;

import 'dart:io';

const String kindsFixtureRoot = 'test/fixtures/deck-kinds/';

/// Every YAML file of the fixture, by path. With [language] only that
/// language's own folder (`decks/<language>/`).
Map<String, String> kindsFixtureFiles({String? language}) {
  final files = <String, String>{};
  for (final entity in Directory(
    '${kindsFixtureRoot}decks',
  ).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.yaml')) continue;
    final path = entity.path.substring(kindsFixtureRoot.length);
    if (language != null && !path.startsWith('decks/$language/')) continue;
    files[path] = entity.readAsStringSync();
  }
  return files;
}
