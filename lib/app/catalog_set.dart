import 'dart:async';

import '../core/decks/language_summary.dart';
import '../core/decks/language_unit.dart';
import '../core/logs/log_entry.dart';
import 'added_decks.dart';
import 'app_log.dart';
import 'deck_catalog.dart';
import 'deck_files.dart';
import 'disk_deck_files.dart';
import 'language_unit_job.dart';
import 'private_store.dart';
import 'startup_marks.dart';
import 'summary_store.dart';

/// How the catalog is read (ADR-0062, Plan-Lazy-Language-Loading, 6): [whole]
/// is one unit of every language, read as it always was but with the files
/// read on a worker isolate; [lazy] is one unit per language, each read when
/// it is first needed.
enum CatalogMode { whole, lazy }

/// The mode the app starts in. Whole stays the default until every consumer
/// of the catalog has moved to the per-language API.
const bool kLazyCatalogDefault = false;

/// Where a language's unit is in loading.
enum LoadPhase { notLoaded, loading, loaded, failed }

/// A language unit's loading state.
class LanguageLoad {
  const LanguageLoad._(this.phase, [this.message]);

  const LanguageLoad.failed(String this.message) : phase = LoadPhase.failed;

  static const LanguageLoad notLoaded = LanguageLoad._(LoadPhase.notLoaded);
  static const LanguageLoad loading = LanguageLoad._(LoadPhase.loading);
  static const LanguageLoad loaded = LanguageLoad._(LoadPhase.loaded);

  final LoadPhase phase;

  /// Why it failed, for the log; null unless [phase] is failed.
  final String? message;

  bool get isLoaded => phase == LoadPhase.loaded;
}

/// One language's parsed files, and the summary worked out with them.
class LanguageCatalog {
  const LanguageCatalog({
    required this.code,
    required this.catalog,
    required this.summary,
    required this.version,
  });

  final String code;

  /// The language's decks and language files, with the shared theme list
  /// and sections. Its decks are only this language's.
  final Catalog catalog;

  final LanguageSummary summary;

  /// Changes whenever the unit is read again, so that a cache keyed on a
  /// unit can tell.
  final int version;
}

/// Where each language's snapshot (ADR-0048, one file per language) is kept.
class LanguageSnapshots {
  LanguageSnapshots({
    required this.storeFor,
    required this.readerFor,
    required this.app,
    this.seed,
    this.knownShas,
  });

  /// The store of language [code]'s snapshot.
  final SnapshotStore Function(String code) storeFor;

  /// A reader a worker uses for the same snapshot.
  final SnapshotReader Function(String code) readerFor;

  /// The app's version (`AppInfo.version`).
  final String app;

  /// The older single snapshot of every language, whose trees seed a
  /// language that has no snapshot of its own yet.
  final SnapshotReader? seed;

  /// The SHA-256 of each file the phone already knows by path, such as the
  /// downloads' manifest.
  final Future<Map<String, String>> Function()? knownShas;
}

enum _From { source, added, private }

class _Layout {
  const _Layout({
    required this.shared,
    required this.byLanguage,
    required this.from,
  });

  final List<String> shared;
  final Map<String, List<String>> byLanguage;
  final Map<String, _From> from;
}

/// The catalog as one unit per language (ADR-0062). In lazy mode each
/// language is read by [ensureLoaded] when it is needed, on a worker
/// isolate, one at a time; [catalog] is what is loaded, composed as one
/// [Catalog] so that nothing that reads the whole catalog has to change.
///
/// Startup is from the cache: each language's summary and snapshot are kept
/// between launches, [verify] only compares their stamps with the files on
/// the phone (and parses nothing), and a language is read again, in the
/// worker and in idle time, only when its stamp does not match.
class CatalogSet {
  CatalogSet({
    required this.source,
    this.added,
    this.privateStore,
    this.log,
    this.marks,
    this.snapshots,
    this.summaries,
    this.app = '',
    this.runner = runLanguageJobInPlace,
    this.verifier = verifyInPlace,
  });

  final DeckSource source;
  final DeckStore? added;
  final PrivateStore? privateStore;
  final AppLog? log;
  final StartupMarks? marks;
  final LanguageSnapshots? snapshots;
  final SummaryBook? summaries;

  /// The app's version, which stamps a summary.
  final String app;

  final LanguageJobRunner runner;
  final CacheVerifier verifier;

  final Map<String, LanguageCatalog> _units = <String, LanguageCatalog>{};
  final Map<String, Future<LanguageCatalog>> _loading =
      <String, Future<LanguageCatalog>>{};
  final Map<String, LanguageLoad> _loads = <String, LanguageLoad>{};
  final Map<String, int> _versions = <String, int>{};
  int _clock = 0;
  int _generation = 0;
  Future<_Layout>? _layout;
  Future<void> _tail = Future<void>.value();
  Catalog? _composed;
  Catalog? _sharedOnly;

  /// Where [code] is in loading.
  LanguageLoad loadOf(String code) => _loads[code] ?? LanguageLoad.notLoaded;

  /// Changes whenever [code]'s unit is read again; 0 before it is first read.
  int versionOf(String code) => _versions[code] ?? 0;

  /// The loaded unit of [code], or null.
  LanguageCatalog? unitOf(String code) => _units[code];

  /// The kept summary of [code], or null.
  LanguageSummary? summaryOf(String code) => summaries?[code];

  /// What is loaded, as one catalog: the loaded units' decks and files, in
  /// the order a whole read gives them.
  Catalog get catalog => _composed ??= _compose();

  Catalog _compose() {
    if (_units.isEmpty) return _sharedOnly ?? Catalog.empty;
    final codes = _units.keys.toList()..sort();
    return Catalog.compose(<Catalog>[
      for (final code in codes) _units[code]!.catalog,
    ]);
  }

  /// Forgets what is loaded of [code], or of every language, and the list of
  /// files, so that the next read looks at the phone again.
  void invalidate([String? code]) {
    _layout = null;
    _composed = null;
    _generation++;
    if (code == null) {
      _units.clear();
      _loading.clear();
      _loads.clear();
      for (final key in _versions.keys.toList()) {
        _versions[key] = ++_clock;
      }
    } else {
      _units.remove(code);
      _loading.remove(code);
      _loads.remove(code);
      _versions[code] = ++_clock;
    }
  }

  /// Reads every language on the phone, one at a time, and returns [catalog].
  /// A language that cannot be read is told in the log and left out.
  Future<Catalog> loadAll() async {
    final layout = await _scan();
    final codes = layout.byLanguage.keys.toList()..sort();
    for (final code in codes) {
      try {
        await ensureLoaded(code);
      } on Object {
        // Told in the log by the load; the other languages still load.
      }
    }
    if (codes.isEmpty) await _readSharedOnly(layout);
    return catalog;
  }

  Future<void> _readSharedOnly(_Layout layout) async {
    final texts = <String, String>{};
    for (final path in layout.shared) {
      try {
        texts[path] = await _store(layout.from[path]!).read(path);
      } on Object catch (e, stack) {
        log?.warning(describeError('Deck file $path', e, stack));
      }
    }
    _sharedOnly = DeckCatalog.parseAll(texts);
    _composed = null;
  }

  /// The unit of [code], read now if it is not loaded: in a worker, after
  /// any read already under way, and joined with a read of the same
  /// language. Throws when the language cannot be read at all.
  Future<LanguageCatalog> ensureLoaded(String code) {
    final loaded = _units[code];
    if (loaded != null) return Future<LanguageCatalog>.value(loaded);
    return _loading[code] ??= _enqueue(() => _load(code)).whenComplete(() {
      _loading.remove(code);
    });
  }

  Future<LanguageCatalog> _load(String code) async {
    final generation = _generation;
    _loads[code] = LanguageLoad.loading;
    try {
      final outcome = await _run(code, 'load');
      final unit = _keep(code, outcome, generation);
      _persist(code, outcome);
      return unit;
    } on Object catch (e, stack) {
      _loads[code] = LanguageLoad.failed('$e');
      log?.error(describeError('Reading the $code decks failed', e, stack));
      rethrow;
    }
  }

  LanguageCatalog _keep(String code, LanguageOutcome outcome, int generation) {
    final unit = LanguageCatalog(
      code: code,
      catalog: outcome.catalog,
      summary: outcome.summary,
      version: ++_clock,
    );
    if (generation == _generation) {
      _units[code] = unit;
      _versions[code] = unit.version;
      _loads[code] = LanguageLoad.loaded;
      _composed = null;
    }
    return unit;
  }

  /// Makes [code]'s unit and summary again from the files, as after a
  /// download, an update or a failed [verify], and keeps them (and the
  /// snapshot) for the next launch. A unit that was loaded is replaced; one
  /// that was not stays unloaded. A language with no files left loses its
  /// summary. Returns the new summary, or null when there is none.
  Future<LanguageSummary?> summarise(String code) => _enqueue(() async {
    final generation = _generation;
    final layout = await _scan();
    if ((layout.byLanguage[code] ?? const <String>[]).isEmpty) {
      _units.remove(code);
      _loads.remove(code);
      _versions[code] = ++_clock;
      _composed = null;
      try {
        await summaries?.open();
        await summaries?.remove(code);
      } on Object catch (e, stack) {
        log?.warning(describeError('Forgetting the $code summary', e, stack));
      }
      return null;
    }
    final outcome = await _run(code, 'rebuild');
    if (_units.containsKey(code)) _keep(code, outcome, generation);
    _persist(code, outcome);
    return outcome.summary;
  });

  /// Hears that the files of [code] changed (null: shared ones, which every
  /// unit is parsed with): the language is made again; null drops every unit.
  Future<void> languageChanged(String? code) async {
    if (code == null) {
      invalidate();
      return;
    }
    _layout = null;
    await summarise(code);
  }

  /// Checks the kept summary of each of [codes] (every language on the phone
  /// by default) against the files on the phone, in a worker, and parses
  /// nothing. A language whose files, app version or summary format differ
  /// from what its summary was made from is a mismatch.
  Future<Map<String, CacheVerdict>> verify([Iterable<String>? codes]) async {
    final watch = Stopwatch()..start();
    await summaries?.open();
    final layout = await _scan();
    final known = await _known();
    final wanted = codes ?? layout.byLanguage.keys;
    final shas = <String, Map<String, String>>{
      for (final code in wanted)
        code: <String, String>{
          for (final path in layout.byLanguage[code] ?? const <String>[])
            if (known[path] case final sha?) path: sha,
        },
    };
    final verdicts = await verifier(
      VerifyJob(summaries: summaries?.text, shas: shas, app: app),
    );
    marks?.record(
      'catalog.verify',
      watch.elapsedMilliseconds,
      isolate: 'worker',
      extra: <String, Object?>{
        'languages': verdicts.length,
        'mismatches': verdicts.values.where((v) => !v.matches).length,
      },
    );
    return verdicts;
  }

  /// [verify], then makes again, one at a time, only the languages that did
  /// not match, and keeps the result. Returns the codes made again.
  Future<List<String>> verifyAndRebuild([Iterable<String>? codes]) async {
    final verdicts = await verify(codes);
    final rebuilt = <String>[];
    for (final MapEntry(key: code, value: verdict) in verdicts.entries) {
      if (verdict.matches) continue;
      log?.event('The $code cache does not match: $verdict');
      await summarise(code);
      rebuilt.add(code);
    }
    return rebuilt;
  }

  Future<Map<String, String>> _known() async {
    try {
      return await snapshots?.knownShas?.call() ?? const <String, String>{};
    } on Object {
      return const <String, String>{};
    }
  }

  Future<LanguageOutcome> _run(String code, String why) async {
    await summaries?.open();
    final watch = Stopwatch()..start();
    final layout = await _scan();
    final job = await _jobFor(code, layout);
    final outcome = await runner(job);
    marks?.record(
      'catalog.unit.$code.$why',
      watch.elapsedMilliseconds,
      isolate: 'worker',
      extra: <String, Object?>{
        'read': outcome.filesRead,
        'bytes': outcome.bytesRead,
        'hashed': outcome.hashed,
        'reused': outcome.reused,
        'parsed': outcome.parsed,
      },
    );
    for (final path in outcome.unreadable) {
      log?.warning('Deck file $path could not be read');
    }
    return outcome;
  }

  Future<LanguageJob> _jobFor(String code, _Layout layout) async {
    final texts = <String, String>{};
    final disk = <String, String>{};
    final paths = <String>[...layout.shared, ...?layout.byLanguage[code]];
    for (final path in paths) {
      final store = _store(layout.from[path]!);
      final at = store is DiskLocated ? store.locate(path) : null;
      if (at != null) {
        disk[path] = at;
        continue;
      }
      try {
        texts[path] = await store.read(path);
      } on Object catch (e, stack) {
        log?.warning(describeError('Deck file $path', e, stack));
      }
    }
    final known = await _known();
    final snapshots = this.snapshots;
    return LanguageJob(
      code: code,
      files: texts,
      disk: disk.isEmpty ? null : DiskDeckFiles(disk),
      shas: <String, String>{
        for (final path in paths)
          if (known[path] case final sha?) path: sha,
      },
      snapshot: snapshots?.readerFor(code),
      seed: snapshots?.seed,
      app: app,
    );
  }

  /// Writes the snapshot and the summary a job made, not waited for: the
  /// first screens do not need them written.
  void _persist(String code, LanguageOutcome outcome) {
    final text = outcome.snapshot;
    final snapshots = this.snapshots;
    if (text != null && snapshots != null) {
      try {
        unawaited(
          snapshots
              .storeFor(code)
              .write(text)
              .then<void>((_) {}, onError: (Object _) {}),
        );
      } on Object catch (e, stack) {
        log?.warning(describeError('Keeping the $code snapshot', e, stack));
      }
    }
    final book = summaries;
    if (book != null) {
      unawaited(
        book.put(outcome.summary).then<void>((_) {}, onError: (Object _) {}),
      );
    }
  }

  DeckSource _store(_From origin) => switch (origin) {
    _From.source => source,
    _From.added => added!,
    _From.private => privateStore!,
  };

  Future<_Layout> _scan() {
    final cached = _layout;
    if (cached != null) return cached;
    final next = _scanNow();
    _layout = next;
    unawaited(
      next.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_layout, next)) _layout = null;
        },
      ),
    );
    return next;
  }

  Future<_Layout> _scanNow() async {
    final from = <String, _From>{};
    for (final path in await source.list()) {
      from[path] = _From.source;
    }
    final addedLanguages = <String, String>{};
    final addedStore = added;
    if (addedStore != null) {
      for (final path in await addedStore.list()) {
        from[path] = _From.added;
        final code = await _languageOfAdded(addedStore, path);
        if (code != null) addedLanguages[path] = code;
      }
    }
    final privates = privateStore;
    if (privates != null) {
      try {
        for (final path in await privates.list()) {
          from[path] = _From.private;
        }
      } on Object catch (e, stack) {
        log?.error(describeError('The private decks', e, stack));
      }
    }
    final parts = partitionPaths(from.keys, addedLanguages: addedLanguages);
    for (final path in parts.unrouted) {
      log?.warning('Deck file $path belongs to no language and is not read');
    }
    return _Layout(
      shared: parts.shared,
      byLanguage: parts.byLanguage,
      from: from,
    );
  }

  Future<String?> _languageOfAdded(DeckStore store, String path) async {
    try {
      if (store is AddedLanguages) return await store.languageOf(path);
      return languageCodeOfDeckText(await store.read(path));
    } on Object catch (e, stack) {
      log?.warning(describeError('The language of $path', e, stack));
      return null;
    }
  }

  /// Runs [job] after every job queued before it, one at a time.
  Future<T> _enqueue<T>(Future<T> Function() job) {
    final done = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        done.complete(await job());
      } on Object catch (e, stack) {
        done.completeError(e, stack);
      }
    });
    return done.future;
  }
}
