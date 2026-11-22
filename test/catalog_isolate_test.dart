// Reading the decks off the UI isolate must give the same catalog as
// reading them in place (#875).
import 'dart:isolate';

import 'package:fluenough/app/added_decks.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_files.dart';
import 'package:fluenough/app/language_unit_job.dart';
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

  test('a language unit crosses an isolate as it is made in place', () async {
    final source = RepositoryDeckSource();
    final files = <String, String>{
      for (final path in await source.list())
        if (path.startsWith('decks/tok/') || path == 'decks/themes.yaml')
          path: await source.read(path),
    };
    final job = LanguageJob(
      code: 'tok',
      files: files,
      shas: const <String, String>{},
      app: '1.0.0',
    );
    final inPlace = runLanguageJob(job);
    final told = <String>[];
    final isolated = await runLanguageJobInIsolate(job, onFallback: told.add);
    expect(told, isEmpty, reason: 'no fallback was needed');
    expect(inPlace.catalog.decks, isNotEmpty);
    expect(
      isolated.catalog.decks.map((e) => e.id),
      inPlace.catalog.decks.map((e) => e.id),
    );
    expect(
      isolated.catalog.decks.map((e) => e.cards.length),
      inPlace.catalog.decks.map((e) => e.cards.length),
    );
    expect(isolated.summary.decks.length, inPlace.summary.decks.length);
    expect(isolated.snapshot, inPlace.snapshot);
  });

  test('a job that cannot be sent runs in place, and says so', () async {
    final unsendable = _Unsendable();
    addTearDown(unsendable.port.close);
    final job = LanguageJob(
      code: 'xx',
      files: const <String, String>{},
      shas: const <String, String>{},
      app: '1.0.0',
      snapshot: unsendable,
    );
    final told = <String>[];
    final outcome = await runLanguageJobInIsolate(job, onFallback: told.add);
    expect(told, hasLength(1));
    expect(told.single, contains('on an isolate failed'));
    expect(outcome.catalog.decks, isEmpty);
  });
}

/// A snapshot reader holding a port, which no isolate message can carry.
class _Unsendable implements SnapshotReader {
  final ReceivePort port = ReceivePort();

  @override
  String? read() => null;
}
