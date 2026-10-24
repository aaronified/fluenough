import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/decks/deck_fetch.dart';
import '../core/decks/deck_index.dart';
import '../core/decks/sha256.dart';
import 'app_log.dart';
import 'deck_catalog.dart';
import 'downloaded_decks.dart';
import 'fair_slots.dart';
import 'script_fonts.dart';

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
///   have changed the app asks; "Not now" leaves them waiting on Languages I'm
/// learning.
/// - **Cancelling** a language's download ([cancel]) keeps what is in and
///   stops the rest, which then waits on Languages I'm learning rather
///   than resuming at launch.
/// - **Removing** a language deletes its files ([remove]). Progress is in
///   the review log, by card id, so it stays, and comes back with the
///   decks.
/// - **Fonts** (ADR-0042): a language's decks come with the fonts of the
///   scripts they are shown in, which phones often draw wrongly or lack.
///   They download first, with the same size and SHA-256 checks, and are
///   loaded for [fonts] to hand out. A font shared by several languages is
///   downloaded once, and removing a language deletes only the fonts no
///   language on the phone still lists.
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
    ScriptFonts? scriptFonts,
  }) : fonts = scriptFonts ?? ScriptFonts();

  /// How long after the last check an automatic one is due.
  static const Duration interval = Duration(days: 1);

  /// How many decks one write keeps, so that a download cut short keeps
  /// what came before it.
  static const int decksPerWrite = 10;

  /// How many recordings and images one write keeps.
  static const int mediaPerWrite = 50;

  /// How many files are downloaded at once, over every language: shared
  /// between the languages downloading in turn, so that a large one never
  /// holds them all while another waits.
  static const int maxConcurrentFetches = 6;

  static const String _indexNote = 'index.json';
  static const String _stateNote = 'state.json';

  final DeckFetcher fetcher;
  final DownloadedDecks files;
  final DeckFileCheck check;

  /// The script fonts loaded from what is on the phone (ADR-0042).
  final ScriptFonts fonts;
  final DateTime Function() _clock;
  final AppLog? _log;

  /// Whether a course's download brings the font of [script] (#611): true
  /// once the learner answered the font check "No, it shows boxes". Null
  /// brings every font, as before the check. A font already on the phone is
  /// kept up to date whatever it says.
  bool Function(String script)? wantsFont;

  /// Whether the font of [script] on the phone is drawn with: false after
  /// the learner said the phone's own font draws it. Null draws with every
  /// font on the phone.
  bool Function(String script)? usesFont;

  /// Called once files on the phone have changed, so that the catalog is
  /// read again. Set by `AppState`.
  Future<void> Function()? onFilesChanged;

  DeckIndex? _index;
  IndexStatus _indexStatus = IndexStatus.none;
  DeckDownloadFailure? _indexFailure;
  Map<String, IndexFile> _onPhone = const <String, IndexFile>{};
  Map<String, IndexFont> _fontsOnPhone = const <String, IndexFont>{};
  final Set<String> _fontsFetching = <String>{};
  final Map<String, List<String>> _fontScripts = <String, List<String>>{};
  DateTime? _checkedAt;
  String? _declined;
  bool _autoCheck = true;
  bool _reviewer = false;
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
  late final FairSlots _slots = FairSlots(maxConcurrentFetches);
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
      _fontsOnPhone = await files.fontManifest();
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
    await _loadFonts();
    _notify();
  }

  /// Loads the fonts on the phone that are not loaded yet, so that text in
  /// their scripts is drawn in them (ADR-0042). A font that cannot be read
  /// leaves its script in the phone's own font.
  Future<void> _loadFonts() async {
    for (final font in _fontsOnPhone.values.toList()) {
      if (fonts.isLoaded(font)) continue;
      if (usesFont != null && !usesFont!(font.script)) continue;
      try {
        final bytes = await files.readFont(font.path);
        if (bytes != null && !await fonts.load(font, bytes)) {
          _log?.warning('Deck downloads: could not load ${font.path}');
        }
      } on Object catch (e) {
        _log?.warning('Deck downloads: could not read ${font.path}: $e');
      }
    }
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
        (f) => f.language == language && !f.isLanguageFile && !f.isMedia,
      );
    }
    return entry
        .firstFiles(entry.nativesFor(spoken), count: decksBeforeReady)
        .every((f) => _onPhone.containsKey(f.path));
  }

  /// Whether any deck of [language] is on the phone, whatever else is
  /// missing: whether it can be studied at all, offline.
  bool hasDecks(String language) => _onPhone.values.any(
    (f) => f.language == language && !f.isLanguageFile && !f.isMedia,
  );

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

  /// The script of a font [language]'s download is still fetching, or null
  /// when it fetches none: the downloads then say the font is coming too
  /// (ADR-0042).
  String? fontDownloading(String language) {
    final scripts = _fontScripts[language];
    return scripts == null || scripts.isEmpty ? null : scripts.first;
  }

  /// The fonts of [entry] not on the phone, or changed since.
  List<IndexFont> _fontsToFetch(IndexLanguage entry) => <IndexFont>[
    for (final font in entry.fonts)
      if (_fontsOnPhone[font.path]?.sha256 != font.sha256 &&
          (wantsFont == null ||
              wantsFont!(font.script) ||
              _fontsOnPhone.containsKey(font.path)))
        font,
  ];

  /// The font of [script] the index offers, or null.
  IndexFont? fontOffered(String script) {
    for (final language in _index?.languages ?? const <IndexLanguage>[]) {
      for (final font in language.fonts) {
        if (font.script == script) return font;
      }
    }
    return null;
  }

  /// Whether the font of [script] is on the phone.
  bool hasFont(String script) =>
      _fontsOnPhone.values.any((font) => font.script == script);

  /// Whether the font of [script] is downloading on its own ([downloadFont]).
  bool isFontDownloading(String script) => _fontsFetching.contains(script);

  /// Downloads the font of [script] alone, as the learner asked in the font
  /// check (#611), checks it as every font is, and loads it. Null once it
  /// is on the phone, else why not.
  Future<DeckDownloadFailure?> downloadFont(String script) async {
    if (_fontsFetching.contains(script)) return null;
    _fontsFetching.add(script);
    _notify();
    final key = 'font:$script';
    try {
      if (!await ensureIndex()) return _indexFailure;
      final font = fontOffered(script);
      if (font == null) return DeckDownloadFailure.notOffered;
      final failure = await _downloadFonts(key, <IndexFont>[font], (_) {});
      // One already on the phone, from a course, is loaded at once.
      if (failure == null) await _loadFonts();
      return failure;
    } finally {
      _failures.remove(key);
      _fontsFetching.remove(script);
      _notify();
    }
  }

  /// Deletes the downloaded font of [script], when the learner asks to
  /// (#611). It stays drawn with the phone's own font; a course that needs
  /// it downloads it again only if the learner says so.
  Future<void> removeFont(String script) async {
    final paths = <String>[
      for (final font in _fontsOnPhone.values)
        if (font.script == script) font.path,
    ];
    fonts.unload(script);
    if (paths.isEmpty) return;
    try {
      await files.removeFonts(paths);
      _fontsOnPhone = await files.fontManifest();
    } on Object catch (e) {
      _log?.warning('Deck downloads: could not remove fonts: $e');
    }
    _notify();
  }

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
  /// Languages I'm learning, and is not resumed at launch.
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
  /// on Languages I'm learning ([downloadRest]), and is not resumed at
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
          return _fetchAndKeep(
            language,
            first,
            groups: false,
            fonts: _fontsToFetch(entry),
          );
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
            fonts: _fontsToFetch(entry),
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
  /// time, each deck's files together; else all in one write. The [fonts]
  /// the language needs come first, each kept as it arrives.
  Future<DeckDownloadFailure?> _fetchAndKeep(
    String language,
    List<IndexFile> wanted, {
    required bool groups,
    List<IndexFont> fonts = const <IndexFont>[],
  }) async {
    final changes = changesFor(language, wanted, _onPhone, reviewer: _reviewer);
    // Files not on the phone, and those whose proposals alone changed,
    // which come along with them (#444). A change a learner sees waits
    // for them to update.
    final fetch = <IndexFile>[
      for (final file in changes.fetch)
        if (!_onPhone.containsKey(file.path) || changes.quiet.contains(file))
          file,
    ];
    if (fetch.isEmpty && fonts.isEmpty || _stopping.remove(language)) {
      _failures.remove(language);
      _notify();
      return null;
    }
    _failures.remove(language);
    final total = fetch.length + fonts.length;
    final fetchBytes = fetch.fold(0, (sum, f) => sum + f.size);
    final fontBytes = fonts.fold(0, (sum, f) => sum + f.size);
    final totalBytes = fetchBytes + fontBytes;
    var done = 0;
    var bytes = 0;
    _fontScripts[language] = <String>[for (final font in fonts) font.script];
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
    void kept(IndexFont font) {
      done++;
      bytes += font.size;
      _progress[language] = (
        done: done,
        total: total,
        bytes: bytes,
        totalBytes: totalBytes,
      );
      _notify();
    }

    try {
      final fontFailure = await _downloadFonts(language, fonts, kept);
      if (fontFailure != null) return fontFailure;
      for (final batch in batches) {
        final result = await _fetchFiles(language, batch, (file) {
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
        }, cancellable: true);
        if (result.failure case final failure?) {
          return _failed(language, failure);
        }
        final got = result.got;
        if (result.stopped) {
          return await _stopped(language, batch, got, remove);
        }
        final failure = await _keep(language, got, remove);
        if (failure != null) return _failed(language, failure);
        remove = const <String>[];
      }
    } finally {
      _progress.remove(language);
      _fetched.remove(language);
      _fontScripts.remove(language);
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
  /// that every write leaves decks the catalog can read whole. The cards'
  /// recordings and images come last, [mediaPerWrite] to a write.
  static List<List<IndexFile>> _batches(List<IndexFile> files) {
    final own = <IndexFile>[
      for (final f in files)
        if (f.deck == null && !f.isMedia) f,
    ];
    final media = <IndexFile>[
      for (final f in files)
        if (f.isMedia) f,
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
    for (var i = 0; i < media.length; i += mediaPerWrite) {
      batches.add(media.sublist(i, min(i + mediaPerWrite, media.length)));
    }
    return batches;
  }

  /// Downloads [files] of [language] up to [maxConcurrentFetches] at a
  /// time, sharing that bound fairly with the other languages, and calls
  /// [onFetched] as each arrives. Stops starting files at the first
  /// failure, and, with [cancellable], once [language] is cancelled; files
  /// already on their way finish. The files fetched are in [got], in the
  /// order of [files], whenever they arrived; [stopped] says a file was
  /// left unstarted because of the cancel.
  Future<
    ({
      Map<IndexFile, List<int>> got,
      DeckDownloadFailure? failure,
      bool stopped,
    })
  >
  _fetchFiles(
    String language,
    List<IndexFile> files,
    void Function(IndexFile file) onFetched, {
    bool cancellable = false,
  }) async {
    final results = List<List<int>?>.filled(files.length, null);
    DeckDownloadFailure? failure;
    var stopped = false;
    var next = 0;
    // Whether no more files are to be started.
    bool halted() {
      if (next >= files.length) return true;
      if (failure != null) return true;
      if (cancellable && _stopping.contains(language)) {
        stopped = true;
        return true;
      }
      return false;
    }

    Future<void> worker() async {
      while (!halted()) {
        await _slots.acquire(language);
        try {
          // Things change while waiting for a slot.
          if (halted()) return;
          final index = next++;
          final result = await _fetchChecked(files[index]);
          if (result.failure case final why?) {
            failure ??= why;
          } else {
            results[index] = result.bytes;
            onFetched(files[index]);
          }
        } finally {
          _slots.release(language);
        }
      }
    }

    await Future.wait(<Future<void>>[
      for (var i = 0; i < min(maxConcurrentFetches, files.length); i++)
        worker(),
    ]);
    return (
      got: <IndexFile, List<int>>{
        for (var i = 0; i < files.length; i++) files[i]: ?results[i],
      },
      failure: failure,
      stopped: stopped,
    );
  }

  /// [file], downloaded and checked against its size and hash.
  Future<({List<int>? bytes, DeckDownloadFailure? failure})> _fetchChecked(
    IndexFile file,
  ) async {
    final fetched = await fetcher.fetch(file.path);
    final bytes = fetched.bytes;
    if (bytes == null) {
      _log?.warning(
        'Deck download failed (${fetched.failure!.name}'
        '${fetched.cause == null ? '' : ': ${fetched.cause}'}): ${file.path}',
      );
      return (bytes: null, failure: _failureOf(fetched.failure!));
    }
    if (bytes.length != file.size || sha256Hex(bytes) != file.sha256) {
      _log?.warning('Deck download did not match the index: ${file.path}');
      return (bytes: null, failure: DeckDownloadFailure.badFile);
    }
    return (bytes: bytes, failure: null);
  }

  /// Downloads [fonts] for [language], one at a time, keeps each as it
  /// arrives and loads it, and calls [onKept] after each, including one
  /// that another language's download brought in the meantime. Returns why
  /// it stopped, or null when all are in.
  Future<DeckDownloadFailure?> _downloadFonts(
    String language,
    List<IndexFont> fonts,
    void Function(IndexFont font) onKept,
  ) async {
    for (final font in fonts) {
      if (_fontsOnPhone[font.path]?.sha256 != font.sha256) {
        final asFile = IndexFile(
          path: font.path,
          size: font.size,
          sha256: font.sha256,
        );
        await _slots.acquire(language);
        final ({List<int>? bytes, DeckDownloadFailure? failure}) result;
        try {
          result = await _fetchChecked(asFile);
        } finally {
          _slots.release(language);
        }
        if (result.failure case final failure?) {
          return _failed(language, failure);
        }
        try {
          await _writing(
            () => files.putFonts(<IndexFont, List<int>>{font: result.bytes!}),
          );
          _fontsOnPhone = await files.fontManifest();
        } on Object catch (e) {
          _log?.error('Downloaded font could not be kept: $e');
          return _failed(language, DeckDownloadFailure.storage);
        }
        await _loadFonts();
      }
      _fontScripts[language]?.remove(font.script);
      onKept(font);
    }
    return null;
  }

  /// Checks every file of [got] as the app reads it, then keeps them all,
  /// with [remove] removed, or keeps none.
  Future<DeckDownloadFailure?> _keep(
    String language,
    Map<IndexFile, List<int>> got,
    List<String> remove,
  ) async {
    for (final MapEntry(key: file, value: bytes) in got.entries) {
      // A recording or an image is checked by its hash alone: it is not
      // a deck, and is never read as one.
      if (file.isMedia) continue;
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
      await _writing(() async {
        await files.putAll(got, remove: remove);
        _onPhone = await files.manifest();
      });
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

  /// One write to the phone's files at a time, whichever language asks:
  /// downloads run side by side, what they keep does not.
  Future<T> _writing<T>(Future<T> Function() body) {
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

  /// Whether the learner reviews decks (Settings' "Review decks"): then a
  /// change to reviewers' proposals alone is an update, as they see
  /// proposals; for a learner it is not, and comes along quietly with the
  /// next change they do see (#444). Set by `AppState`.
  bool get reviewer => _reviewer;

  set reviewer(bool on) {
    if (on == _reviewer) return;
    _reviewer = on;
    if (_spoken case final spoken?) _findUpdates(spoken);
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
        reviewer: _reviewer,
        fonts: entry.fonts,
        fontsOnPhone: _fontsOnPhone,
      );
      if (!changes.isEmpty) updates[language] = changes;
    }
    _updates = updates;
    _notify();
  }

  /// Answers "Not now": the update waits on Languages I'm learning, and
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
      // Every language at once: they share the bound on files in flight.
      final failures = await Future.wait(<Future<DeckDownloadFailure?>>[
        for (final language in (languages ?? _updates.keys).toList())
          if (_updates.containsKey(language))
            _job(
              language,
              () => _againIfStale(language, () async {
                // Read here, as the index read again may have changed them.
                final changes = _updates[language];
                return changes == null ? null : _applyUpdate(language, changes);
              }),
            ).then((failure) {
              if (failure == null) {
                changed = true;
                _updates = Map<String, LanguageChanges>.of(_updates)
                  ..remove(language);
              }
              return failure;
            }),
      ]);
      first = failures.nonNulls.firstOrNull;
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
    final total = changes.fetch.length + changes.fonts.length;
    final totalBytes = changes.bytes;
    var done = 0;
    var bytes = 0;
    _progress[language] = (
      done: 0,
      total: total,
      bytes: 0,
      totalBytes: totalBytes,
    );
    _fontScripts[language] = <String>[
      for (final font in changes.fonts) font.script,
    ];
    _notify();
    void kept(IndexFont font) {
      done++;
      bytes += font.size;
      _progress[language] = (
        done: done,
        total: total,
        bytes: bytes,
        totalBytes: totalBytes,
      );
      _notify();
    }

    try {
      final fontFailure = await _downloadFonts(language, changes.fonts, kept);
      if (fontFailure != null) return fontFailure;
      final result = await _fetchFiles(language, changes.fetch, (file) {
        done++;
        bytes += file.size;
        _progress[language] = (
          done: done,
          total: total,
          bytes: bytes,
          totalBytes: totalBytes,
        );
        _notify();
      });
      if (result.failure case final failure?) {
        return _failed(language, failure);
      }
      final got = result.got;
      final failure = await _keep(language, got, changes.remove);
      if (failure != null) return _failed(language, failure);
    } finally {
      _progress.remove(language);
      _fontScripts.remove(language);
    }
    _log?.event(
      'Decks updated for $language: ${changes.fetch.length} files, '
      '${changes.fonts.length} fonts, ${changes.remove.length} replaced',
    );
    return null;
  }

  /// A fingerprint of the updates waiting, to know whether the learner
  /// already said "Not now" to them. For a learner, a file's content hash:
  /// a proposal made since is no reason to ask again (#444).
  String _fingerprint() {
    final parts = <String>[
      for (final changes in _updates.values) ...<String>[
        for (final f in changes.fetch)
          if (_reviewer)
            '${f.path}:${f.sha256}'
          else if (!changes.quiet.contains(f))
            '${f.path}:${f.contentSha256}',
        for (final path in changes.remove) '-$path',
        for (final f in changes.fonts) 'font:${f.path}:${f.sha256}',
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
      await _removeUnusedFonts();
      _log?.event('Language removed from the phone: $language');
      return null;
    });
    _notify();
    await _filesChanged();
  }

  /// Deletes the fonts no language on the phone lists any more, after one
  /// was removed (ADR-0042). A font shared with a language that stays is
  /// kept. Where a language on the phone is not in the index, what it needs
  /// is not known, and every font stays.
  Future<void> _removeUnusedFonts() async {
    final index = _index;
    if (index == null) return;
    final used = <String>{};
    for (final code in languagesOnPhone) {
      final entry = index.language(code);
      if (entry == null) return;
      used.addAll(<String>[for (final font in entry.fonts) font.path]);
    }
    final unused = <String>[
      for (final path in _fontsOnPhone.keys)
        if (!used.contains(path)) path,
    ];
    if (unused.isEmpty) return;
    try {
      await files.removeFonts(unused);
      _fontsOnPhone = await files.fontManifest();
    } on Object catch (e) {
      _log?.warning('Deck downloads: could not remove fonts: $e');
    }
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
    await _loadFonts();
    final changed = onFilesChanged;
    if (changed != null && !_disposed) await changed();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // Closes the connection kept for the next file.
    if (fetcher case final GitHubDeckFetcher github) github.close();
    fonts.dispose();
    super.dispose();
  }
}
