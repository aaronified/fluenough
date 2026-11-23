import 'dart:async';

import '../core/decks/language_summary.dart';
import '../core/decks/language_unit.dart';
import '../core/logs/log_entry.dart';
import '../core/models/deck.dart' show LanguageInfo;
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

/// The mode the phone app starts in when no `catalogMode` setting says
/// otherwise: one language at a time, from the cache (ADR-0062). Every
/// consumer of the catalog has moved to the per-language API, so this is
/// true; to roll back, a patch release sets it to false, and a learner
/// whose stored setting is `whole` or `lazy` keeps that either way. Only
/// `main.dart` reads it: a [DeckCatalog] made with no mode, as the tests,
/// the gallery and the web build make one, reads whole.
const bool kLazyCatalogDefault = true;

/// The mode a stored `catalogMode` setting names, else the app's default.
CatalogMode catalogModeFor(String? setting) => switch (setting) {
  'lazy' => CatalogMode.lazy,
  'whole' => CatalogMode.whole,
  _ => kLazyCatalogDefault ? CatalogMode.lazy : CatalogMode.whole,
};

/// Where a language's unit is in loading.
enum LoadPhase { notLoaded, loading, loaded, failed }

/// A language unit's loading state.
class LanguageLoad {
  const LanguageLoad._(this.phase) : message = null;

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
  LanguageCatalog({
    required this.code,
    required this.catalog,
    required this.summary,
    required this.version,
    Catalog? scoped,
    bool adult = false,
  }) : _scoped = scoped ?? catalog,
       _scopedAdult = scoped == null ? null : adult;

  final String code;

  /// The language's decks and language files, with the shared theme list
  /// and sections. Its decks are only this language's.
  final Catalog catalog;

  final LanguageSummary summary;

  /// Changes whenever the unit is read again, so that a cache keyed on a
  /// unit can tell.
  final int version;

  Catalog _scoped;
  bool? _scopedAdult;

  /// The unit as a learner with Adult content [adult] has it (`forAdult`):
  /// the worker made it for the setting the unit was read under, so that
  /// only a change of the setting works it out again, for this unit alone.
  Catalog scopedFor({required bool adult}) {
    if (_scopedAdult != adult) {
      _scoped = catalog.forAdult(adult: adult);
      _scopedAdult = adult;
    }
    return _scoped;
  }
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
  Catalog? _scopedComposed;
  bool? _scopedComposedAdult;
  Catalog? _sharedOnly;
  List<LanguageInfo> _directory = const <LanguageInfo>[];
  int _directoryEpoch = -1;
  bool? _directoryAdult;

  /// The Adult content setting the units are scoped for when they are read.
  /// Set before a unit is read; a unit read under another value is scoped
  /// again, for that unit alone, when [scopedCatalog] is asked.
  bool adult = false;

  void _dirty() {
    _composed = null;
    _scopedComposed = null;
  }

  /// Where [code] is in loading.
  LanguageLoad loadOf(String code) => _loads[code] ?? LanguageLoad.notLoaded;

  /// Changes whenever [code]'s unit is read again; 0 before it is first read.
  int versionOf(String code) => _versions[code] ?? 0;

  /// The loaded unit of [code], or null.
  LanguageCatalog? unitOf(String code) => _units[code];

  /// The kept summary of [code], or null.
  LanguageSummary? summaryOf(String code) => summaries?[code];

  /// Every summary kept (the loaded units' own when none is kept), which the
  /// directory and the skill map are made from.
  Iterable<LanguageSummary> get knownSummaries {
    final book = summaries;
    if (book != null) return book.all;
    return <LanguageSummary>[for (final unit in _units.values) unit.summary];
  }

  /// The codes of the loaded units, sorted.
  List<String> get loadedCodes => _units.keys.toList()..sort();

  /// A number that changes whenever any unit is read again or forgotten, for
  /// what is kept against the whole of what is loaded.
  int get versionSum => _versions.values.fold<int>(0, (sum, v) => sum + v);

  /// Opens the kept summaries and lists the files on the phone, which is all
  /// a start from the cache needs before it knows which language to show.
  Future<void> openCache() async {
    await summaries?.open();
    await _scan();
  }

  /// Looks at the files on the phone again the next time they are listed.
  void rescan() {
    _layout = null;
  }

  /// The codes of the languages that have files on the phone, in the order
  /// the whole catalog lists its languages: the downloaded ones by folder,
  /// then private packages, then the learner's own decks.
  Future<List<String>> codesOnPhone() async {
    final layout = await _scan();
    final firsts = <(String, String)>[
      for (final e in layout.byLanguage.entries)
        if (e.value.isNotEmpty) (e.key, e.value.first),
    ]..sort((a, b) => _byRankAndPath(a.$2, b.$2));
    return <String>[for (final first in firsts) first.$1];
  }

  /// Every language the kept summaries name, as the language bar and the
  /// screens that list languages read it, in the order the whole catalog
  /// lists them. With Adult content off a language of adult decks alone is
  /// not one. Without summaries, the loaded units' languages.
  List<LanguageInfo> directory({required bool adult}) {
    final book = summaries;
    if (book == null) return catalog.languages;
    if (_directoryEpoch == book.epoch && _directoryAdult == adult) {
      return _directory;
    }
    final firsts = <(LanguageInfo, String)>[];
    for (final summary in book.all) {
      final paths = <String>[
        for (final deck in summary.decks)
          if (!deck.hidden && (adult || !deck.adult)) deck.path,
      ]..sort(_byRankAndPath);
      if (paths.isEmpty) continue;
      firsts.add((summary.info, paths.first));
    }
    firsts.sort((a, b) => _byRankAndPath(a.$2, b.$2));
    _directoryEpoch = book.epoch;
    _directoryAdult = adult;
    return _directory = List<LanguageInfo>.unmodifiable(<LanguageInfo>[
      for (final first in firsts) first.$1,
    ]);
  }

  static int _rank(String path) => path.startsWith(addedDeckPrefix)
      ? 2
      : path.startsWith(privateDeckPrefix)
      ? 1
      : 0;

  static int _byRankAndPath(String a, String b) {
    final byRank = _rank(a).compareTo(_rank(b));
    return byRank != 0 ? byRank : a.compareTo(b);
  }

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

  /// [catalog] as a learner with Adult content [adult] has it: each unit's
  /// own scoped catalog, composed, so that a change of the setting never
  /// loops over a language that is not loaded.
  Catalog scopedCatalog({required bool adult}) {
    final kept = _scopedComposed;
    if (kept != null && _scopedComposedAdult == adult) return kept;
    final Catalog next;
    if (_units.isEmpty) {
      next = _sharedOnly ?? Catalog.empty;
    } else {
      final codes = _units.keys.toList()..sort();
      next = Catalog.compose(<Catalog>[
        for (final code in codes) _units[code]!.scopedFor(adult: adult),
      ]);
    }
    _scopedComposed = next;
    _scopedComposedAdult = adult;
    return next;
  }

  /// Forgets what is loaded of [code], or of every language, and the list of
  /// files, so that the next read looks at the phone again.
  void invalidate([String? code]) {
    _layout = null;
    _dirty();
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

  /// Lets go of the loaded unit of [code], as after a read made only to work
  /// something out from it (the learned figures of a language the learner is
  /// not on). Its summary and snapshot stay, so it loads again from the
  /// cache. Does nothing for a language that is not loaded.
  void drop(String code) {
    if (_units.remove(code) == null) return;
    _loads.remove(code);
    _versions[code] = ++_clock;
    _dirty();
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
    _dirty();
  }

  /// Reads the shared files alone (the theme list and the sections): what a
  /// phone with no language on it has to show.
  Future<void> loadShared() async {
    await _readSharedOnly(await _scan());
  }

  /// The unit of [code], read now if it is not loaded: in a worker, after
  /// any read already under way, and joined with a read of the same
  /// language. Throws when the language cannot be read at all.
  Future<LanguageCatalog> ensureLoaded(String code) {
    final loaded = _units[code];
    if (loaded != null) return Future<LanguageCatalog>.value(loaded);
    final joined = _loading[code];
    if (joined != null) return joined;
    late final Future<LanguageCatalog> next;
    next = _enqueue(() => _load(code)).whenComplete(() {
      if (identical(_loading[code], next)) _loading.remove(code);
    });
    _loading[code] = next;
    return next;
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
      scoped: outcome.scoped,
      adult: outcome.adult,
    );
    if (generation == _generation) {
      _units[code] = unit;
      _versions[code] = unit.version;
      _loads[code] = LanguageLoad.loaded;
      _dirty();
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
      _dirty();
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
    // A language that has a summary and no files left is checked too, so
    // that its summary is found stale and forgotten.
    final wanted = codes ?? _everyCode(layout);
    final shas = <String, Map<String, String>>{};
    final unhashed = <String, DeckFiles>{};
    for (final code in wanted) {
      final paths = layout.byLanguage[code] ?? const <String>[];
      shas[code] = <String, String>{
        for (final path in paths) path: ?known[path],
      };
      // A deck the learner added, a private package and a shared file of the
      // language are not in the download manifest: the verify job reads and
      // hashes them, so that they are vouched for like any other file.
      final unknown = <String>[
        for (final path in paths)
          if (!known.containsKey(path)) path,
      ];
      if (unknown.isNotEmpty) unhashed[code] = await _filesOf(unknown, layout);
    }
    final verdicts = await verifier(
      VerifyJob(
        summaries: summaries?.text,
        shas: shas,
        local: unhashed,
        app: app,
      ),
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

  /// Every language that has files on the phone or a kept summary.
  Set<String> _everyCode(_Layout layout) => <String>{
    ...layout.byLanguage.keys,
    ...?summaries?.all.map((summary) => summary.code),
  };

  /// The files at [paths] as a worker reads them: those on disk by their
  /// place, the rest read now.
  Future<DeckFiles> _filesOf(List<String> paths, _Layout layout) async {
    final disk = <String, String>{};
    final texts = <String, String>{};
    for (final path in paths) {
      final store = _store(layout.from[path]!);
      final at = locateOn(store, path);
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
    return JoinedDeckFiles(<DeckFiles>[
      DiskDeckFiles(disk),
      MemoryDeckFiles(texts),
    ]);
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
      final at = locateOn(store, path);
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
      shas: <String, String>{for (final path in paths) path: ?known[path]},
      snapshot: snapshots?.readerFor(code),
      seed: snapshots?.seed,
      app: app,
      adult: adult,
      stored: summaries?[code],
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
    // A summary kept as it is, because its stamp is the one the job found,
    // is not written again.
    final book = summaries;
    final kept = book?[code]?.stamp;
    if (book != null && !_sameStamp(kept, outcome.summary.stamp)) {
      unawaited(
        book.put(outcome.summary).then<void>((_) {}, onError: (Object _) {}),
      );
    }
  }

  static bool _sameStamp(SummaryStamp? kept, SummaryStamp found) =>
      kept != null &&
      kept.format == found.format &&
      kept.filesDigest == found.filesDigest &&
      kept.app == found.app;

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
      final known = addedLanguageOn(store, path);
      if (known != null) return await known;
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
