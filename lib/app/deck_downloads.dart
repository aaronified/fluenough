import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/decks/deck_fetch.dart';
import '../core/decks/deck_index.dart';
import '../core/decks/sha256.dart';
import 'app_log.dart';
import 'deck_catalog.dart';
import 'downloaded_decks.dart';

/// Why a language's decks could not be downloaded (ADR-0037).
enum DeckDownloadFailure {
  /// GitHub could not be reached, or the connection broke part-way.
  offline,

  /// GitHub refused for now: too many requests from this network.
  rateLimited,

  /// A file did not arrive as the index lists it: changed on GitHub since
  /// the index was read, missing, or damaged on the way.
  badFile,

  /// A file arrived whole but the app cannot read it: the decks on the
  /// phone are kept.
  invalid,

  /// The phone could not keep the files: it may be full.
  storage,

  /// The index is of a format this app is too old to read.
  appTooOld,

  /// GitHub no longer offers the language.
  notOffered,
}

/// Where the index is in loading.
enum IndexStatus { none, loading, ready, failed }

/// How far a language's download has got: files and bytes, of how many.
typedef DownloadProgress = ({int done, int total, int bytes, int totalBytes});

/// How much of a language is on the phone, for a learner who speaks some
/// languages, counting what is downloading (the language picker's bar,
/// #211): its decks and bytes, of how many, and the bytes of the first
/// [decksBeforeReady] decks, where it can be learned.
typedef LanguageDownload = ({
  int decks,
  int totalDecks,
  int bytes,
  int totalBytes,
  int readyBytes,
  bool ready,
});

/// What a language is, on this phone, beside what GitHub offers.
enum LanguageDownloadState {
  /// None of its files are on the phone.
  notOnPhone,

  /// Its files are downloading.
  downloading,

  /// Its last download failed: [DeckDownloads.failureOf] says why.
  failed,

  /// Its first decks are in and it can be learned, but the rest are not.
  partial,

  /// Every file is in, and an update is waiting.
  updateWaiting,

  /// Every file is in, as the last index read lists it.
  upToDate,

  /// On the phone, but GitHub no longer offers it: it is kept.
  notOffered,
}

/// Checks [text], the file at [path], before it is used: null when the app
/// can read it, else what is wrong.
typedef DeckFileCheck = String? Function(String path, String text);

/// Downloads decks from GitHub and keeps them up to date (#210, ADR-0037).
///
/// - The **index**, `decks/index.json` on `main`, lists every language and
///   its files. The last one read is kept, so that the app knows its
///   languages offline.
/// - **A language** downloads its first [decksBeforeReady] decks on its
///   path, with its own files, and can then be learned
///   ([downloadFirst]); the rest follow ([downloadRest]).
/// - **Updates** are looked for at most once a day ([checkForUpdates]),
///   unless the learner turns that off ([checksAutomatically]). When decks
///   have changed the app asks; "Not now" leaves them waiting on Settings >
///   Deck downloads.
/// - **Cancelling** a language's download ([cancel]) keeps what is in and
///   stops the rest, which then waits on Settings > Deck downloads rather
///   than resuming at launch.
/// - **Removing** a language deletes its files ([remove]). Progress is in
///   the review log, by card id, so it stays, and comes back with the
///   decks.
///
/// Every file is checked against the index's SHA-256, then read as the app
/// reads it ([DeckCatalog.checkFile]), before it replaces one on the phone;
/// a batch with any file that fails is not used at all. A file that does
/// not match may have changed on `main` since the index was read, so the
/// index is read again once, and the download tried again with it. A file
/// GitHub no longer lists stays on the phone unless a new file takes its
/// place.
class DeckDownloads extends ChangeNotifier {
  DeckDownloads({
    required this.fetcher,
    required this.files,
    required this._clock,
    this._log,
    this.check = DeckCatalog.checkFile,
  });

  /// How long after the last check an automatic one is due.
  static const Duration interval = Duration(days: 1);

  /// How many decks one write keeps, so that a download cut short keeps
  /// what came before it.
  static const int decksPerWrite = 10;

  static const String _indexNote = 'index.json';
  static const String _stateNote = 'state.json';

  final DeckFetcher fetcher;
  final DownloadedDecks files;
  final DeckFileCheck check;
  final DateTime Function() _clock;
  final AppLog? _log;

  /// Called once files on the phone have changed, so that the catalog is
  /// read again. Set by `AppState`.
  Future<void> Function()? onFilesChanged;

  DeckIndex? _index;
  IndexStatus _indexStatus = IndexStatus.none;
  DeckDownloadFailure? _indexFailure;
  Map<String, IndexFile> _onPhone = const <String, IndexFile>{};
  DateTime? _checkedAt;
  String? _declined;
  bool _autoCheck = true;
  List<String>? _spoken;
  Set<String> _complete = <String>{};
  Set<String> _paused = <String>{};
  final Set<String> _stopping = <String>{};
  final Map<String, Set<String>> _fetched = <String, Set<String>>{};
  final Map<String, DownloadProgress> _progress = <String, DownloadProgress>{};
  final Map<String, DeckDownloadFailure> _failures =
      <String, DeckDownloadFailure>{};
  final Map<String, Future<DeckDownloadFailure?>> _jobs =
      <String, Future<DeckDownloadFailure?>>{};
  Map<String, LanguageChanges> _updates = const <String, LanguageChanges>{};
  bool _asked = false;
  bool _updating = false;
  Future<void> _lock = Future<void>.value();
  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // The index

  /// The last index read, or null if none ever was.
  DeckIndex? get index => _index;

  IndexStatus get indexStatus => _indexStatus;

  /// Why the index could not be read, when [indexStatus] is failed.
  DeckDownloadFailure? get indexFailure => _indexFailure;

  /// When the last check reached GitHub.
  DateTime? get checkedAt => _checkedAt;

  /// Reads what is on the phone: the files, the last index and the state
  /// kept beside them. Deletes what a download cut short left. Never
  /// touches the network.
  Future<void> open() async {
    try {
      await files.clean();
      _onPhone = await files.manifest();
      final text = await files.readNote(_indexNote);
      if (text != null) {
        _index = DeckIndex.parse(text);
        _indexStatus = IndexStatus.ready;
      }
    } on Object catch (e) {
      _log?.warning('Deck downloads: could not read what is kept: $e');
    }
    try {
      final state = await files.readNote(_stateNote);
      if (state != null) {
        final json = jsonDecode(state);
        if (json is Map) {
          final checked = json['checked'];
          _checkedAt = checked is String ? DateTime.tryParse(checked) : null;
          final declined = json['declined'];
          _declined = declined is String ? declined : null;
          _autoCheck = json['auto'] != false;
          _complete = <String>{
            if (json['complete'] case final List<Object?> codes)
              for (final code in codes)
                if (code is String) code,
          };
          _paused = <String>{
            if (json['paused'] case final List<Object?> codes)
              for (final code in codes)
                if (code is String) code,
          };
        }
      }
    } on Object catch (e) {
      _log?.warning('Deck downloads: could not read their state: $e');
    }
    _notify();
  }

  /// Reads the index from GitHub again, and keeps it. Returns whether it
  /// was read; [indexFailure] says why not.
  Future<bool> refreshIndex() async {
    _indexStatus = IndexStatus.loading;
    _indexFailure = null;
    _notify();
    final fetched = await fetcher.fetch('decks/index.json');
    final bytes = fetched.bytes;
    if (bytes == null) {
      return _indexFailed(_failureOf(fetched.failure!), 'not downloaded');
    }
    final String text;
    final DeckIndex index;
    try {
      text = utf8.decode(bytes);
      index = DeckIndex.parse(text);
    } on IndexTooNewException catch (e) {
      return _indexFailed(DeckDownloadFailure.appTooOld, '$e');
    } on FormatException catch (e) {
      return _indexFailed(DeckDownloadFailure.badFile, e.message);
    }
    _index = index;
    _indexStatus = IndexStatus.ready;
    _checkedAt = _clock();
    try {
      await files.writeNote(_indexNote, text);
    } on Object catch (e) {
      _log?.warning('Deck downloads: could not keep the index: $e');
    }
    await _saveState();
    _log?.event('Deck index read: ${index.languages.length} languages');
    _notify();
    return true;
  }

  bool _indexFailed(DeckDownloadFailure failure, String why) {
    // An index read before stays in use: only its status says it is old.
    _indexStatus = IndexStatus.failed;
    _indexFailure = failure;
    _log?.warning('Deck index failed (${failure.name}): $why');
    _notify();
    return false;
  }

  /// Makes sure an index is known: the one kept, or one read now.
  Future<bool> ensureIndex() async => _index != null || await refreshIndex();

  /// Runs [attempt], [language]'s download or update. When a file did not
  /// match the index, it may have changed on `main` since the index was
  /// read: the index is read again, the updates waiting worked out again
  /// from it, and [attempt] run once more. Returns why it failed, if it did.
  Future<DeckDownloadFailure?> _againIfStale(
    String language,
    Future<DeckDownloadFailure?> Function() attempt,
  ) async {
    final failure = await attempt();
    if (failure != DeckDownloadFailure.badFile) return failure;
    _log?.event('Deck files did not match the index: reading it again');
    if (!await refreshIndex()) {
      return _failed(language, _indexFailure ?? DeckDownloadFailure.badFile);
    }
    if (_spoken case final spoken?) _findUpdates(spoken);
    _failures.remove(language);
    return attempt();
  }

  // ---------------------------------------------------------------------------
  // What is on the phone

  /// Every language with a file on the phone.
  Set<String> get languagesOnPhone => <String>{
    for (final file in _onPhone.values) file.language,
  };

  /// The bytes [language]'s files take on the phone.
  int sizeOnPhone(String language) => _onPhone.values
      .where((f) => f.language == language)
      .fold(0, (sum, f) => sum + f.size);

  /// Whether [language] can be learned by someone who speaks [spoken]: its
  /// first decks and its own files are on the phone. Without an index, as
  /// offline with none kept, whether any deck of it is.
  bool isReady(String language, List<String> spoken) {
    final entry = _index?.language(language);
    if (entry == null) {
      return _onPhone.values.any(
        (f) => f.language == language && !f.isLanguageFile,
      );
    }
    return entry
        .firstFiles(entry.nativesFor(spoken), count: decksBeforeReady)
        .every((f) => _onPhone.containsKey(f.path));
  }

  /// Whether any deck of [language] is on the phone, whatever else is
  /// missing: whether it can be studied at all, offline.
  bool hasDecks(String language) =>
      _onPhone.values.any((f) => f.language == language && !f.isLanguageFile);

  /// The files of [language] a learner who speaks [spoken] has yet to
  /// download, as the index lists them.
  List<IndexFile> missing(String language, List<String> spoken) {
    final entry = _index?.language(language);
    if (entry == null) return const <IndexFile>[];
    return <IndexFile>[
      for (final file in entry.filesFor(entry.nativesFor(spoken)))
        if (!_onPhone.containsKey(file.path)) file,
    ];
  }

  /// Whether some files of [language] cannot be downloaded until the app
  /// is updated: they are of a newer schema than it reads.
  bool needsNewerApp(String language, List<String> spoken) {
    final entry = _index?.language(language);
    return entry != null &&
        entry.unreadable(entry.nativesFor(spoken)).isNotEmpty;
  }

  /// How [language] stands on this phone.
  LanguageDownloadState stateOf(String language, List<String> spoken) {
    if (_progress.containsKey(language)) {
      return LanguageDownloadState.downloading;
    }
    if (_failures.containsKey(language)) return LanguageDownloadState.failed;
    if (!languagesOnPhone.contains(language)) {
      return LanguageDownloadState.notOnPhone;
    }
    final index = _index;
    if (index != null && index.language(language) == null) {
      return LanguageDownloadState.notOffered;
    }
    if (_updates.containsKey(language)) {
      return LanguageDownloadState.updateWaiting;
    }
    if (missing(language, spoken).isNotEmpty) {
      return LanguageDownloadState.partial;
    }
    return LanguageDownloadState.upToDate;
  }

  /// How far [language]'s download has got, while it downloads.
  DownloadProgress? progressOf(String language) => _progress[language];

  /// How much of [language] a learner who speaks [spoken] has on the phone,
  /// with what has arrived of a download under way: its decks (a deck
  /// counts once all its files are in) and bytes, of all it has for them,
  /// and where the first [decksBeforeReady] decks end. Null without an
  /// index that lists it.
  LanguageDownload? languageDownload(String language, List<String> spoken) {
    final entry = _index?.language(language);
    if (entry == null) return null;
    final natives = entry.nativesFor(spoken);
    final wanted = entry.filesFor(natives);
    final fetched = _fetched[language] ?? const <String>{};
    bool isIn(IndexFile f) =>
        _onPhone.containsKey(f.path) || fetched.contains(f.path);
    final byDeck = <String, List<IndexFile>>{};
    for (final file in wanted) {
      if (file.deck case final deck?) {
        (byDeck[deck] ??= <IndexFile>[]).add(file);
      }
    }
    // A deck counts once a learner can open it: a core alone teaches nobody.
    final teaching = byDeck.values.where((files) => files.any((f) => !f.core));
    return (
      decks: teaching.where((files) => files.every(isIn)).length,
      totalDecks: teaching.length,
      bytes: wanted.where(isIn).fold(0, (sum, f) => sum + f.size),
      totalBytes: wanted.fold(0, (sum, f) => sum + f.size),
      readyBytes: entry
          .firstFiles(natives, count: decksBeforeReady)
          .fold(0, (sum, f) => sum + f.size),
      ready: isReady(language, spoken),
    );
  }

  /// Whether [language]'s download was cancelled: the rest waits on
  /// Settings > Deck downloads, and is not resumed at launch.
  bool isPaused(String language) => _paused.contains(language);

  /// Why [language]'s last download failed, until it is tried again.
  DeckDownloadFailure? failureOf(String language) => _failures[language];

  bool isDownloading(String language) => _progress.containsKey(language);

  /// Whether [language] has a job under way or waiting, from the moment it
  /// is asked for: [isDownloading] only once the index is read and its
  /// files are known. What [cancel] needs to stop.
  bool hasJob(String language) =>
      _jobs.containsKey(language) || _progress.containsKey(language);

  // ---------------------------------------------------------------------------
  // Downloading a language

  /// Stops [language]'s download, keeping what is in: each deck whose
  /// files have all arrived, and the language's own files. The rest waits
  /// on Settings > Deck downloads ([downloadRest]), and is not resumed at
  /// launch ([isPaused]).
  Future<void> cancel(String language) async {
    _paused.add(language);
    if (_jobs.containsKey(language)) _stopping.add(language);
    _failures.remove(language);
    _log?.event('Deck download cancelled: $language');
    _notify();
    await _saveState();
  }

  /// Lets [language] download again after [cancel], when the learner asks.
  void _unpause(String language) {
    _stopping.remove(language);
    if (_paused.remove(language)) unawaited(_saveState());
  }

  /// Downloads what [language] needs before it can be learned by someone
  /// who speaks [spoken] ([isReady]). Reads the index first if none is
  /// kept. Returns null once it is ready, else why not.
  Future<DeckDownloadFailure?> downloadFirst(
    String language,
    List<String> spoken,
  ) {
    _unpause(language);
    return _first(language, spoken);
  }

  Future<DeckDownloadFailure?> _first(String language, List<String> spoken) =>
      _job(
        language,
        () => _againIfStale(language, () async {
          if (!await ensureIndex()) return _indexFailure;
          final entry = _index!.language(language);
          if (entry == null) return DeckDownloadFailure.notOffered;
          final first = entry.firstFiles(
            entry.nativesFor(spoken),
            count: decksBeforeReady,
          );
          return _fetchAndKeep(language, first, groups: false);
        }),
      );

  /// Downloads the rest of [language] for someone who speaks [spoken], a
  /// few decks at a time, and marks it complete. Returns null when all of
  /// it is in, else why not; what came before a failure is kept.
  Future<DeckDownloadFailure?> downloadRest(
    String language,
    List<String> spoken,
  ) {
    _unpause(language);
    return _rest(language, spoken);
  }

  Future<DeckDownloadFailure?> _rest(String language, List<String> spoken) =>
      _job(
        language,
        () => _againIfStale(language, () async {
          if (!await ensureIndex()) return _indexFailure;
          final entry = _index!.language(language);
          if (entry == null) return DeckDownloadFailure.notOffered;
          final failure = await _fetchAndKeep(
            language,
            entry.filesFor(entry.nativesFor(spoken)),
            groups: true,
          );
          if (failure == null && !_paused.contains(language)) {
            _complete.add(language);
            await _saveState();
          }
          return failure;
        }),
      );

  /// "Try again" for [language], on the phone, whose last download or
  /// update failed: its update again, when one is waiting, else the rest
  /// of its decks. The rest alone would skip the files an update changes.
  Future<DeckDownloadFailure?> retry(String language, List<String> spoken) =>
      _updates.containsKey(language)
      ? update(<String>[language])
      : downloadRest(language, spoken);

  /// Downloads [language]'s first decks, then the rest in the background,
  /// as on first launch and when a language is added. Completes once it is
  /// ready, with null, or with why it is not.
  Future<DeckDownloadFailure?> download(
    String language,
    List<String> spoken,
  ) async {
    final failure = await downloadFirst(language, spoken);
    if (failure == null && !_paused.contains(language)) {
      unawaited(_rest(language, spoken));
    }
    return failure;
  }

  /// At launch: finishes the languages whose download was cut short, in
  /// the background, from the index kept. Touches the network only if one
  /// was.
  Future<void> resume(Iterable<String> learning, List<String> spoken) async {
    for (final language in <String>{...learning, ...languagesOnPhone}) {
      if (_complete.contains(language) || _paused.contains(language)) continue;
      if (_index?.language(language) == null) continue;
      if (missing(language, spoken).isEmpty) {
        _complete.add(language);
        await _saveState();
        continue;
      }
      if (!languagesOnPhone.contains(language)) continue;
      await _rest(language, spoken);
    }
  }

  /// Runs [body] as [language]'s one job: a second call while it runs
  /// waits for the first.
  Future<DeckDownloadFailure?> _job(
    String language,
    Future<DeckDownloadFailure?> Function() body,
  ) {
    final running = _jobs[language];
    late final Future<DeckDownloadFailure?> next;
    next = (running ?? Future<DeckDownloadFailure?>.value(null))
        .then((_) => body())
        .whenComplete(() {
          if (identical(_jobs[language], next)) _jobs.remove(language);
        });
    _jobs[language] = next;
    return next;
  }

  /// Fetches those of [wanted] not on the phone, checks each, and keeps
  /// them, with what they replace removed. With [groups], a few decks at a
  /// time, each deck's files together; else all in one write.
  Future<DeckDownloadFailure?> _fetchAndKeep(
    String language,
    List<IndexFile> wanted, {
    required bool groups,
  }) async {
    final changes = changesFor(language, wanted, _onPhone);
    final fetch = <IndexFile>[
      for (final file in changes.fetch)
        if (!_onPhone.containsKey(file.path)) file,
    ];
    if (fetch.isEmpty || _stopping.remove(language)) {
      _failures.remove(language);
      _notify();
      return null;
    }
    _failures.remove(language);
    final total = fetch.length;
    final totalBytes = fetch.fold(0, (sum, f) => sum + f.size);
    var done = 0;
    var bytes = 0;
    _progress[language] = (
      done: 0,
      total: total,
      bytes: 0,
      totalBytes: totalBytes,
    );
    _notify();
    final batches = groups ? _batches(fetch) : <List<IndexFile>>[fetch];
    var remove = changes.remove;
    final fetched = _fetched[language] = <String>{};
    try {
      for (final batch in batches) {
        final got = <IndexFile, List<int>>{};
        for (final file in batch) {
          if (_stopping.contains(language)) {
            return await _stopped(language, batch, got, remove);
          }
          final result = await _fetchChecked(file);
          if (result.failure case final failure?) {
            return _failed(language, failure);
          }
          got[file] = result.bytes!;
          fetched.add(file.path);
          done++;
          bytes += file.size;
          _progress[language] = (
            done: done,
            total: total,
            bytes: bytes,
            totalBytes: totalBytes,
          );
          _notify();
        }
        final failure = await _keep(language, got, remove);
        if (failure != null) return _failed(language, failure);
        remove = const <String>[];
      }
    } finally {
      _progress.remove(language);
      _fetched.remove(language);
      _stopping.remove(language);
    }
    _log?.event('Decks downloaded for $language: $total files');
    _notify();
    await _filesChanged();
    return null;
  }

  /// After [cancel]: keeps those of [got], fetched of [batch], that leave
  /// whole decks on the phone, with the language's own files, and stops.
  /// A batch that replaces files ([remove]) is kept whole or not at all.
  Future<DeckDownloadFailure?> _stopped(
    String language,
    List<IndexFile> batch,
    Map<IndexFile, List<int>> got,
    List<String> remove,
  ) async {
    final whole = <IndexFile, List<int>>{
      if (remove.isEmpty)
        for (final MapEntry(key: file, value: bytes) in got.entries)
          if (file.deck == null ||
              batch.where((f) => f.deck == file.deck).every(got.containsKey))
            file: bytes,
    };
    _log?.event(
      'Deck download stopped for $language: ${whole.length} more files kept',
    );
    if (whole.isEmpty) {
      _notify();
      return null;
    }
    final failure = await _keep(language, whole, const <String>[]);
    if (failure != null) return _failed(language, failure);
    _notify();
    await _filesChanged();
    return null;
  }

  /// [files] in writes of up to [decksPerWrite] decks, each deck's files
  /// (a core, its layers) together and the language's own files first, so
  /// that every write leaves decks the catalog can read whole.
  static List<List<IndexFile>> _batches(List<IndexFile> files) {
    final own = <IndexFile>[
      for (final f in files)
        if (f.deck == null) f,
    ];
    final byDeck = <String, List<IndexFile>>{};
    for (final f in files) {
      if (f.deck case final deck?) {
        (byDeck[deck] ??= <IndexFile>[]).add(f);
      }
    }
    final batches = <List<IndexFile>>[];
    var current = <IndexFile>[...own];
    var decks = 0;
    for (final group in byDeck.values) {
      // A core before its layers, so a write never holds a layer alone.
      group.sort((a, b) => (a.core ? 0 : 1).compareTo(b.core ? 0 : 1));
      current.addAll(group);
      if (++decks == decksPerWrite) {
        batches.add(current);
        current = <IndexFile>[];
        decks = 0;
      }
    }
    if (current.isNotEmpty) batches.add(current);
    return batches;
  }

  /// [file], downloaded and checked against its size and hash.
  Future<({List<int>? bytes, DeckDownloadFailure? failure})> _fetchChecked(
    IndexFile file,
  ) async {
    final fetched = await _locked(() => fetcher.fetch(file.path));
    final bytes = fetched.bytes;
    if (bytes == null) {
      _log?.warning(
        'Deck download failed (${fetched.failure!.name}): ${file.path}',
      );
      return (bytes: null, failure: _failureOf(fetched.failure!));
    }
    if (bytes.length != file.size || sha256Hex(bytes) != file.sha256) {
      _log?.warning('Deck download did not match the index: ${file.path}');
      return (bytes: null, failure: DeckDownloadFailure.badFile);
    }
    return (bytes: bytes, failure: null);
  }

  /// Checks every file of [got] as the app reads it, then keeps them all,
  /// with [remove] removed, or keeps none.
  Future<DeckDownloadFailure?> _keep(
    String language,
    Map<IndexFile, List<int>> got,
    List<String> remove,
  ) async {
    for (final MapEntry(key: file, value: bytes) in got.entries) {
      final String text;
      try {
        text = utf8.decode(bytes);
      } on FormatException {
        _log?.warning('Downloaded deck is not UTF-8: ${file.path}');
        return DeckDownloadFailure.invalid;
      }
      final problem = check(file.path, text);
      if (problem != null) {
        _log?.warning('Downloaded deck failed its check: $problem');
        return DeckDownloadFailure.invalid;
      }
    }
    try {
      await files.putAll(got, remove: remove);
      _onPhone = await files.manifest();
    } on Object catch (e) {
      _log?.error('Downloaded decks could not be kept: $e');
      return DeckDownloadFailure.storage;
    }
    return null;
  }

  DeckDownloadFailure _failed(String language, DeckDownloadFailure failure) {
    _failures[language] = failure;
    _notify();
    return failure;
  }

  /// One download at a time, whichever language asks.
  Future<T> _locked<T>(Future<T> Function() body) {
    final result = _lock.then((_) => body());
    _lock = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  static DeckDownloadFailure _failureOf(FetchFailure failure) =>
      switch (failure) {
        FetchFailure.offline => DeckDownloadFailure.offline,
        FetchFailure.rateLimited => DeckDownloadFailure.rateLimited,
        FetchFailure.notFound ||
        FetchFailure.badReply => DeckDownloadFailure.badFile,
      };

  // ---------------------------------------------------------------------------
  // Updates

  /// The updates waiting, by language: files changed or added on GitHub
  /// since the language was downloaded.
  Map<String, LanguageChanges> get updates =>
      Map<String, LanguageChanges>.unmodifiable(_updates);

  /// The bytes the waiting updates would download.
  int get updateBytes => _updates.values.fold(0, (sum, c) => sum + c.bytes);

  /// Whether to ask now whether to update: an update is waiting that the
  /// learner has not answered "Not now" to, and has not been asked about
  /// since the app opened.
  bool get askToUpdate =>
      !_asked && _updates.isNotEmpty && _fingerprint() != _declined;

  /// Whether an update is downloading.
  bool get updating => _updating;

  /// Whether the app looks for deck updates by itself, at launch, at most
  /// once a day. On unless the learner turns it off: each check is a
  /// request to GitHub (ADR-0037). "Check for deck updates" works either
  /// way.
  bool get checksAutomatically => _autoCheck;

  Future<void> setChecksAutomatically(bool on) async {
    if (on == _autoCheck) return;
    _autoCheck = on;
    _notify();
    await _saveState();
  }

  /// Compares the index with the files on the phone, at most once a day
  /// unless [force]. Reads the index first. Afterwards [updates] says what
  /// changed, and [askToUpdate] whether to ask.
  Future<void> checkForUpdates(
    List<String> spoken, {
    bool force = false,
  }) async {
    _spoken = spoken;
    final last = _checkedAt;
    if (!force && last != null && _clock().difference(last) < interval) {
      _findUpdates(spoken);
      return;
    }
    if (!await refreshIndex()) return;
    _findUpdates(spoken);
    if (_updates.isNotEmpty) {
      _log?.event('Deck updates found for ${_updates.keys.join(', ')}');
    }
  }

  /// Works out [updates] from the index kept and the files on the phone,
  /// for the languages whose download was finished.
  void _findUpdates(List<String> spoken) {
    final index = _index;
    if (index == null) return;
    final updates = <String, LanguageChanges>{};
    for (final language in languagesOnPhone) {
      if (!_complete.contains(language)) continue;
      final entry = index.language(language);
      if (entry == null) continue;
      final changes = changesFor(
        language,
        entry.filesFor(entry.nativesFor(spoken)),
        _onPhone,
      );
      if (!changes.isEmpty) updates[language] = changes;
    }
    _updates = updates;
    _notify();
  }

  /// Answers "Not now": the update waits on Settings > Deck downloads, and
  /// is not asked about again until something else changes.
  Future<void> declineUpdate() async {
    _asked = true;
    _declined = _fingerprint();
    await _saveState();
    _notify();
  }

  /// Marks the question asked, so that it is asked once per launch.
  void markAsked() {
    _asked = true;
    _notify();
  }

  /// Downloads the updates waiting for [languages], or for all. Each
  /// language's update is kept whole or not at all. Returns null when all
  /// are in, else the first failure; the other languages are still tried.
  Future<DeckDownloadFailure?> update([Iterable<String>? languages]) async {
    _asked = true;
    _updating = true;
    _notify();
    DeckDownloadFailure? first;
    var changed = false;
    try {
      for (final language in (languages ?? _updates.keys).toList()) {
        if (!_updates.containsKey(language)) continue;
        final failure = await _job(
          language,
          () => _againIfStale(language, () async {
            // Read here, as the index read again may have changed them.
            final changes = _updates[language];
            return changes == null ? null : _applyUpdate(language, changes);
          }),
        );
        if (failure == null) {
          changed = true;
          _updates = Map<String, LanguageChanges>.of(_updates)
            ..remove(language);
        } else {
          first ??= failure;
        }
      }
    } finally {
      _updating = false;
      _notify();
    }
    if (changed) await _filesChanged();
    return first;
  }

  Future<DeckDownloadFailure?> _applyUpdate(
    String language,
    LanguageChanges changes,
  ) async {
    _failures.remove(language);
    final total = changes.fetch.length;
    final totalBytes = changes.bytes;
    var done = 0;
    var bytes = 0;
    _progress[language] = (
      done: 0,
      total: total,
      bytes: 0,
      totalBytes: totalBytes,
    );
    _notify();
    try {
      final got = <IndexFile, List<int>>{};
      for (final file in changes.fetch) {
        final result = await _fetchChecked(file);
        if (result.failure case final failure?) {
          return _failed(language, failure);
        }
        got[file] = result.bytes!;
        done++;
        bytes += file.size;
        _progress[language] = (
          done: done,
          total: total,
          bytes: bytes,
          totalBytes: totalBytes,
        );
        _notify();
      }
      final failure = await _keep(language, got, changes.remove);
      if (failure != null) return _failed(language, failure);
    } finally {
      _progress.remove(language);
    }
    _log?.event(
      'Decks updated for $language: ${changes.fetch.length} files, '
      '${changes.remove.length} replaced',
    );
    return null;
  }

  /// A fingerprint of the updates waiting, to know whether the learner
  /// already said "Not now" to them.
  String _fingerprint() {
    final parts = <String>[
      for (final changes in _updates.values) ...<String>[
        for (final f in changes.fetch) '${f.path}:${f.sha256}',
        for (final path in changes.remove) '-$path',
      ],
    ]..sort();
    return sha256Hex(utf8.encode(parts.join('\n')));
  }

  // ---------------------------------------------------------------------------
  // Removing a language

  /// Deletes every file of [language]. Its progress stays, in the review
  /// log, and comes back if it is downloaded again.
  Future<void> remove(String language) async {
    await _job(language, () async {
      await files.removeLanguage(language);
      _onPhone = await files.manifest();
      _complete.remove(language);
      _failures.remove(language);
      // Nothing of it is left to finish: no longer cancelled.
      _paused.remove(language);
      _stopping.remove(language);
      _updates = Map<String, LanguageChanges>.of(_updates)..remove(language);
      await _saveState();
      _log?.event('Language removed from the phone: $language');
      return null;
    });
    _notify();
    await _filesChanged();
  }

  // ---------------------------------------------------------------------------

  Future<void> _saveState() async {
    try {
      await files.writeNote(
        _stateNote,
        jsonEncode(<String, Object?>{
          'checked': ?_checkedAt?.toIso8601String(),
          'declined': ?_declined,
          if (!_autoCheck) 'auto': false,
          'complete': _complete.toList()..sort(),
          if (_paused.isNotEmpty) 'paused': _paused.toList()..sort(),
        }),
      );
    } on Object catch (e) {
      _log?.warning('Deck downloads: could not keep their state: $e');
    }
  }

  Future<void> _filesChanged() async {
    final changed = onFilesChanged;
    if (changed != null && !_disposed) await changed();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
