// Reading the decks off the UI isolate must give the same catalog as
// reading them in place (#875).
import 'package:fluenough/app/added_decks.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/repository_decks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an isolate parses the catalog as parsing in place does', () async {
    final source = RepositoryDeckSource();
    final files = <String, String>{
      for (final path in await source.list())
        if (path.startsWith('decks/tok/') || path == 'decks/themes.yaml')
          path: await source.read(path),
    };
    final inPlace = DeckCatalog.parseAll(files);
    final isolated = await parseInIsolate(files);
    expect(inPlace.decks, isNotEmpty);
    expect(isolated.decks.map((e) => e.id), inPlace.decks.map((e) => e.id));
    expect(
      isolated.decks.map((e) => e.cards.length),
      inPlace.decks.map((e) => e.cards.length),
    );
    expect(
      isolated.broken.map((b) => b.path),
      inPlace.broken.map((b) => b.path),
    );
    expect(isolated.paths.keys, inPlace.paths.keys);
    expect(isolated.themes.map((t) => t.id), inPlace.themes.map((t) => t.id));
  });

  test('the catalog parses what its source and added decks hold', () async {
    Map<String, String>? seen;
    final catalog = DeckCatalog(
      MemoryDeckSource(const <String, String>{'decks/a.yaml': 'a'}),
      added: MemoryDeckStore(),
      parser: (files) async {
        seen = files;
        return Catalog.empty;
      },
    );
    expect(await catalog.load(), same(Catalog.empty));
    expect(seen, <String, String>{'decks/a.yaml': 'a'});
  });
}
