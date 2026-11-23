// The app read one language at a time (ADR-0062), from the cache: a start
// reads only the language to show, the others are read when picked, off the
// UI isolate, and a cache that does not match makes only its own language
// again.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/catalog_set.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/deck_files.dart';
import 'package:fluenough/app/language_unit_job.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/summary_store.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
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

/// A source that reads the files as they are now, so that a test can change
/// a file between two reads.
class _LiveSource implements DeckSource {
  _LiveSource(this.files);

  final Map<String, String> files;

  @override
  Future<List<String>> list() async => files.keys.toList()..sort();

  @override
  Future<String> read(String path) async =>
      files[path] ?? (throw StateError('no deck file at $path'));
}

/// One phone: its files and their SHA-256s, the caches the app keeps between
/// launches, and every language job that ran, with the files it read YAML of.
class _Phone {
  _Phone() {
    put('es', 'Spanish', 'spa', 1000, 2);
    put('fr', 'French', 'fra', 2000, 2);
    put('hi', 'Hindustani', 'hin', 3000, 2);
  }

  final Map<String, String> files = <String, String>{};
  final Map<String, String> shas = <String, String>{};
  final Map<String, MemorySnapshotStore> snapshots =
      <String, MemorySnapshotStore>{};
  final MemorySnapshotStore summaryFile = MemorySnapshotStore();
  final List<String> jobs = <String>[];
  final List<int> parsed = <int>[];
  final Set<String> failing = <String>{};

  void put(String code, String name, String iso, int from, int count) {
    final path = 'decks/$code/$code-en-words.yaml';
    files[path] = _deck(code, name, iso, from, count);
    shas[path] = '$code-$from-$count'.padLeft(64, '0');
  }

  Future<LanguageOutcome> _run(LanguageJob job) async {
    jobs.add(job.code);
    if (failing.contains(job.code)) throw StateError('cannot read');
    final outcome = runLanguageJob(job);
    parsed.add(outcome.parsed);
    return outcome;
  }

  /// A launch's catalog: the same files and caches every time.
  DeckCatalog catalog() => DeckCatalog(
    _LiveSource(files),
    mode: CatalogMode.lazy,
    summaries: SummaryBook(summaryFile),
    languageSnapshots: LanguageSnapshots(
      storeFor: (code) => snapshots.putIfAbsent(code, MemorySnapshotStore.new),
      readerFor: (code) => MemorySnapshotReader(snapshots[code]?.text),
      app: '1.0.0',
      knownShas: () async => Map<String, String>.of(shas),
    ),
    languageRunner: _run,
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await pumpEventQueue();
  }
}

/// A launch of the app over [phone]: loaded, and everything that follows the
/// first screens done.
Future<AppState> _launch(_Phone phone) async {
  final state = AppState.test(
    catalog: phone.catalog(),
    // The phone has every voice, as nearly all do.
    tts: FixedTtsEngine(const <String>{'en', 'es', 'fr', 'hi'}),
  );
  addTearDown(state.dispose);
  await state.load();
  await _settle();
  return state;
}

/// The second launch: the first made the caches.
Future<AppState> _warm(_Phone phone) async {
  await _launch(phone);
  phone.jobs.clear();
  phone.parsed.clear();
  return _launch(phone);
}

void main() {
  test('a valid cache starts on one language and parses no file', () async {
    final phone = _Phone();
    final state = await _warm(phone);
    expect(phone.jobs, <String>['es']);
    expect(phone.parsed, <int>[0], reason: 'every tree came from the cache');
    expect(state.deckCatalog.catalogSet.loadedCodes, <String>['es']);
    expect(state.shownLanguage, 'es');
    expect(state.contentStatus, CatalogStatus.ready);
    expect(
      <String>[for (final l in state.languages) l.code],
      <String>['es', 'fr', 'hi'],
      reason: 'the directory is complete with one unit loaded',
    );
    expect(state.decks.map((d) => d.id), <String>['es-en-words']);
  });

  test('the first start in this mode makes the caches, once', () async {
    final phone = _Phone();
    await _launch(phone);
    expect(phone.jobs.toSet(), <String>{'es', 'fr', 'hi'});
    phone.jobs.clear();
    await _launch(phone);
    expect(phone.jobs, <String>['es']);
  });

  test('picking another language shows a skeleton, then content', () async {
    final state = await _warm(_Phone());
    state.showLanguage('hi');
    expect(state.shownLanguage, 'hi', reason: 'the bar answers at once');
    expect(state.contentStatus, CatalogStatus.loading);
    await state.ensureLoaded('hi');
    expect(state.contentStatus, CatalogStatus.ready);
    final codes = <String>{for (final d in state.decks) d.language.code};
    expect(codes, <String>{'es', 'hi'});
  });

  test('reading one language keeps the other queues cached', () async {
    final state = await _warm(_Phone());
    const request = DrillRequest.today(language: 'es');
    state.buildSession(request);
    final builds = state.sessionBuilds['es'];
    expect(builds, 1);
    await state.ensureLoaded('fr');
    await _settle();
    state.buildSession(request);
    expect(state.sessionBuilds['es'], builds, reason: 'no rebuild for es');
  });

  test('a selection that is superseded still completes', () async {
    final state = await _warm(_Phone());
    state.showLanguage('fr');
    state.showLanguage('hi');
    await Future.wait(<Future<void>>[
      state.ensureLoaded('fr'),
      state.ensureLoaded('hi'),
    ]);
    expect(state.languageLoad('fr').isLoaded, isTrue);
    expect(state.languageLoad('hi').isLoaded, isTrue);
    expect(state.shownLanguage, 'hi');
    expect(state.contentStatus, CatalogStatus.ready);
  });

  test('a language that cannot be read shows failed, then retries', () async {
    final phone = _Phone();
    final state = await _warm(phone);
    phone.failing.add('hi');
    state.showLanguage('hi');
    await state.ensureLoaded('hi');
    await _settle();
    expect(state.languageLoad('hi').phase, LoadPhase.failed);
    expect(state.contentStatus, CatalogStatus.failed);
    expect(state.languageLoad('es').isLoaded, isTrue);
    expect(phone.jobs.where((code) => code == 'hi'), hasLength(1));
    phone.failing.clear();
    await state.ensureLoaded('hi');
    expect(state.contentStatus, CatalogStatus.ready);
  });

  test('a changed file of another language rebuilds only that one', () async {
    final phone = _Phone();
    await _launch(phone);
    phone.jobs.clear();
    phone.parsed.clear();
    phone.put('fr', 'French', 'fra', 2000, 3);
    final state = await _launch(phone);
    expect(phone.jobs, <String>['es', 'fr']);
    expect(phone.parsed, <int>[0, 1], reason: 'only the changed file');
    final set = state.deckCatalog.catalogSet;
    expect(set.summaryOf('fr')?.decks.single.cards, 3);
    expect(set.loadOf('fr').phase, LoadPhase.notLoaded);
  });

  test('a changed file of the shown language rebuilds first', () async {
    final phone = _Phone();
    await _launch(phone);
    phone.jobs.clear();
    phone.parsed.clear();
    phone.put('es', 'Spanish', 'spa', 1000, 4);
    final state = await _launch(phone);
    expect(phone.jobs, <String>['es']);
    expect(phone.parsed, <int>[1]);
    expect(state.decks.single.cards, hasLength(4));
  });

  test('files that change later rebuild only their language', () async {
    final phone = _Phone();
    final state = await _warm(phone);
    phone.jobs.clear();
    phone.put('hi', 'Hindustani', 'hin', 3000, 5);
    await state.reloadDecks();
    expect(phone.jobs, <String>['hi']);
    final set = state.deckCatalog.catalogSet;
    expect(set.summaryOf('hi')?.decks.single.cards, 5);
    expect(set.loadOf('es').isLoaded, isTrue);
    expect(set.loadOf('hi').phase, LoadPhase.notLoaded);
  });

  test('a language with no files left is forgotten', () async {
    final phone = _Phone();
    final state = await _warm(phone);
    phone.files.remove('decks/fr/fr-en-words.yaml');
    await state.reloadDecks();
    final codes = <String>[for (final l in state.languages) l.code];
    expect(codes, <String>['es', 'hi']);
    expect(state.deckCatalog.catalogSet.summaryOf('fr'), isNull);
  });

  group('the Adult content scope of a unit', () {
    final files = <String, String>{
      'decks/es/es-en-words.yaml': '''
schema: 1
id: es-en-words
name: "words"
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: es-1, target: "a", native: "x" }
  - { id: es-2, target: "b", native: "y" }
  - { id: es-3, target: "c", native: "z", tags: [offensive] }
''',
    };

    test('is made by the job and equals the whole-catalog scope', () {
      final job = LanguageJob(
        code: 'es',
        files: files,
        shas: const <String, String>{},
        app: '1.0.0',
        adult: false,
      );
      final outcome = runLanguageJob(job);
      expect(outcome.adult, isFalse);
      expect(outcome.scoped.decks.single.cards, hasLength(2));
      final whole = outcome.catalog.forAdult(adult: false);
      expect(
        outcome.scoped.decks.single.cards.map((c) => c.id),
        whole.decks.single.cards.map((c) => c.id),
      );
      expect(outcome.catalog.decks.single.cards, hasLength(3));
    });

    test('a change of the setting scopes the loaded unit in place', () async {
      final set = CatalogSet(source: MemoryDeckSource(files))..adult = false;
      await set.ensureLoaded('es');
      expect(set.scopedCatalog(adult: false).decks.single.cards, hasLength(2));
      expect(set.scopedCatalog(adult: true).decks.single.cards, hasLength(3));
      expect(
        identical(
          set.scopedCatalog(adult: true),
          set.scopedCatalog(adult: true),
        ),
        isTrue,
        reason: 'kept until a unit changes',
      );
    });
  });
}
