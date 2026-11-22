// Startup is from the cache (ADR-0062): with a valid cache the verify job
// parses nothing, and a changed file makes only its own language again.
import 'package:fluenough/app/catalog_set.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_files.dart';
import 'package:fluenough/app/language_unit_job.dart';
import 'package:fluenough/app/summary_store.dart';
import 'package:flutter_test/flutter_test.dart';

String _deck(String code, String name, String iso, int from, int count) =>
    '''
schema: 1
id: $code-en-words
name: "$code words"
language: { code: $code, iso639_3: $iso, name: $name, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
${[for (var i = 0; i < count; i++) '  - { id: $code-${from + i}, target: "w$i", native: "n$i" }'].join('\n')}
''';

/// One phone: its files and their SHA-256s, the caches the app keeps, and
/// every language job that ran.
class _Phone {
  _Phone() {
    put('es', 'Spanish', 'spa', 1000, 2);
    put('fr', 'French', 'fra', 2000, 2);
  }

  final Map<String, String> files = <String, String>{};
  final Map<String, String> shas = <String, String>{};
  final Map<String, MemorySnapshotStore> snapshots =
      <String, MemorySnapshotStore>{};
  final MemorySnapshotStore summaryFile = MemorySnapshotStore();
  final List<String> jobs = <String>[];

  void put(String code, String name, String iso, int from, int count) {
    final path = 'decks/$code/$code-en-words.yaml';
    files[path] = _deck(code, name, iso, from, count);
    shas[path] = '$code-$count'.padLeft(64, '0');
  }

  Future<LanguageOutcome> _run(LanguageJob job) async {
    jobs.add(job.code);
    return runLanguageJob(job);
  }

  /// A launch: a new catalog set over the same files and caches.
  CatalogSet launch({String app = '1.0.0'}) => CatalogSet(
    source: MemoryDeckSource(files),
    app: app,
    summaries: SummaryBook(summaryFile),
    snapshots: LanguageSnapshots(
      storeFor: (code) => snapshots.putIfAbsent(code, MemorySnapshotStore.new),
      readerFor: (code) => MemorySnapshotReader(snapshots[code]?.text),
      app: app,
      knownShas: () async => Map<String, String>.of(shas),
    ),
    runner: _run,
  );
}

void main() {
  test('a valid cache is verified without parsing a file', () async {
    final phone = _Phone();
    final first = phone.launch();
    await first.loadAll();
    expect(phone.jobs, <String>['es', 'fr']);
    await pumpEventQueue();
    expect(phone.snapshots.keys, containsAll(<String>['es', 'fr']));

    phone.jobs.clear();
    final second = phone.launch();
    final verdicts = await second.verify();
    expect(verdicts.keys.toList()..sort(), <String>['es', 'fr']);
    expect(verdicts.values.every((v) => v.matches), isTrue);
    expect(await second.verifyAndRebuild(), isEmpty);
    expect(phone.jobs, isEmpty, reason: 'nothing was read or parsed');
    expect(second.summaryOf('es')?.decks.single.cards, 2);
    expect(second.loadOf('es'), same(LanguageLoad.notLoaded));
  });

  test('a changed file makes only its own language again', () async {
    final phone = _Phone();
    await phone.launch().loadAll();
    await pumpEventQueue();
    phone.jobs.clear();

    phone.put('fr', 'French', 'fra', 2000, 3);
    final next = phone.launch();
    final verdicts = await next.verify();
    expect(verdicts['es']!.matches, isTrue);
    expect(verdicts['fr']!.reason, 'files changed');

    expect(await next.verifyAndRebuild(), <String>['fr']);
    expect(phone.jobs, <String>['fr']);
    expect(next.summaryOf('fr')?.decks.single.cards, 3);
    expect(next.summaryOf('es')?.decks.single.cards, 2);
    expect(next.loadOf('fr'), same(LanguageLoad.notLoaded));

    // The cache was written back: the next launch matches.
    await pumpEventQueue();
    phone.jobs.clear();
    expect(await phone.launch().verifyAndRebuild(), isEmpty);
    expect(phone.jobs, isEmpty);
  });

  test('an app update makes every summary stale and rebuilt once', () async {
    final phone = _Phone();
    await phone.launch().loadAll();
    await pumpEventQueue();
    phone.jobs.clear();

    final updated = phone.launch(app: '1.0.1');
    final verdicts = await updated.verify();
    expect(verdicts.values.map((v) => v.reason), everyElement('app updated'));
    expect(await updated.verifyAndRebuild(), <String>['es', 'fr']);
    expect(phone.jobs, <String>['es', 'fr']);
  });

  test('a selected language loads in one joined job', () async {
    final phone = _Phone();
    final lazy = phone.launch();
    final both = await Future.wait(<Future<LanguageCatalog>>[
      lazy.ensureLoaded('fr'),
      lazy.ensureLoaded('fr'),
    ]);
    expect(phone.jobs, <String>['fr']);
    expect(identical(both[0], both[1]), isTrue);
    expect(lazy.loadOf('fr').isLoaded, isTrue);
    expect(lazy.loadOf('es'), same(LanguageLoad.notLoaded));
    expect(lazy.catalog.decks.map((e) => e.id), <String>['fr-en-words']);
    await lazy.ensureLoaded('es');
    expect(lazy.catalog.decks.map((e) => e.id), <String>[
      'es-en-words',
      'fr-en-words',
    ]);
  });
}
