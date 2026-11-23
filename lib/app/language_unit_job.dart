import 'dart:isolate';

import '../core/data/course_path.dart' show CoursePath;
import '../core/decks/adult_gate.dart';
import '../core/decks/language_catalog.dart' show B1Unit;
import '../core/decks/language_summary.dart';
import '../core/decks/language_unit.dart';
import '../core/languages/language_skills.dart' show kanaScript, kanjiScript;
import '../core/models/deck.dart';
import 'deck_catalog.dart';
import 'deck_files.dart';

/// The job that reads and parses one language's files (ADR-0062, Plan-Lazy-
/// Language-Loading, 3.2), run on an isolate of its own: the files, and the
/// snapshot of the language, are read there, so that no deck text is on the
/// UI isolate. Only the parsed model and the summary come back.
class LanguageJob {
  const LanguageJob({
    required this.code,
    required this.files,
    required this.shas,
    required this.app,
    this.disk,
    this.snapshot,
    this.seed,
  });

  /// The language's code, such as `te`.
  final String code;

  /// The text of the files read already: the shared theme list and
  /// sections, and what no disk holds.
  final Map<String, String> files;

  /// The language's files the job reads for itself; null for none.
  final DeckFiles? disk;

  /// The SHA-256 of the language's files the phone already knows by path.
  /// A file it lacks is hashed by the job.
  final Map<String, String> shas;

  /// The language's own snapshot.
  final SnapshotReader? snapshot;

  /// The snapshot of every language that the first launch of this layout
  /// leaves, whose trees are taken only when [snapshot] has none.
  final SnapshotReader? seed;

  /// The running app's version.
  final String app;
}

/// What [runLanguageJob] found.
class LanguageOutcome {
  const LanguageOutcome({
    required this.catalog,
    required this.summary,
    required this.snapshot,
    this.filesRead = 0,
    this.bytesRead = 0,
    this.hashed = 0,
    this.reused = 0,
    this.parsed = 0,
    this.unreadable = const <String>[],
  });

  /// The language's files, as [DeckCatalog.parseLanguage] reads them.
  final Catalog catalog;

  final LanguageSummary summary;

  /// The text of the language's snapshot to write, or null when the stored
  /// one is still right.
  final String? snapshot;

  /// Files the job read itself, their bytes, files it hashed, kept trees it
  /// reused, files whose YAML it read, and files it could not read.
  final int filesRead;
  final int bytesRead;
  final int hashed;
  final int reused;
  final int parsed;
  final List<String> unreadable;
}

/// Runs [job]: reads its files, parses the language with the snapshot's
/// trees where the SHA-256s allow, and works out its summary. Pure but for
/// the reads [LanguageJob.disk] and [LanguageJob.snapshot] make.
LanguageOutcome runLanguageJob(LanguageJob job) {
  final unreadable = <String>[];
  final read = job.disk?.readAll(unreadable) ?? const <String, String>{};
  final files = read.isEmpty
      ? job.files
      : <String, String>{...job.files, ...read};
  var bytes = 0;
  for (final text in read.values) {
    bytes += text.length;
  }
  var stored = job.snapshot?.read();
  var seeded = false;
  if (stored == null) {
    stored = job.seed?.read();
    seeded = stored != null;
  }
  final parsed = parseWithSnapshot(
    files: files,
    knownShas: job.shas,
    snapshot: stored,
    app: job.app,
    parse: (all) => DeckCatalog.parseLanguage(job.code, all),
    forceWrite: seeded,
  );
  final digest = filesDigestOf(<String, String>{
    for (final e in job.shas.entries)
      if (files.containsKey(e.key) && !isSharedUnitPath(e.key)) e.key: e.value,
  });
  final summary = summariseLanguage(
    parsed.catalog,
    job.code,
    SummaryStamp(
      format: LanguageSummary.format,
      filesDigest: digest,
      app: job.app,
    ),
  );
  return LanguageOutcome(
    catalog: parsed.catalog,
    summary: summary,
    snapshot: parsed.snapshot,
    filesRead: read.length,
    bytesRead: bytes,
    hashed: parsed.hashed,
    reused: parsed.reused,
    parsed: files.length - parsed.reused,
    unreadable: unreadable,
  );
}

/// Runs a [LanguageJob] somewhere.
typedef LanguageJobRunner = Future<LanguageOutcome> Function(LanguageJob job);

/// [runLanguageJob] in place, on the calling isolate.
Future<LanguageOutcome> runLanguageJobInPlace(LanguageJob job) async =>
    runLanguageJob(job);

// Made in a function of its own, with only the job in scope: a closure
// carries the context it is made in, and one made beside a log callback could
// not be sent (#1699).
Future<LanguageOutcome> _runLanguageOnIsolate(LanguageJob job) =>
    Isolate.run(() => runLanguageJob(job));

/// [runLanguageJob] on an isolate of its own. Where an isolate cannot run
/// (the web) or the outcome cannot cross, it runs in place, and [onFallback]
/// hears why.
Future<LanguageOutcome> runLanguageJobInIsolate(
  LanguageJob job, {
  void Function(String message)? onFallback,
}) async {
  try {
    return await _runLanguageOnIsolate(job);
  } catch (e, stack) {
    tellFallback(
      onFallback,
      'Reading a language on an isolate failed',
      e,
      stack,
    );
    return runLanguageJob(job);
  }
}

/// What a verify job is given: text only, so that it crosses to an isolate.
class VerifyJob {
  const VerifyJob({
    required this.summaries,
    required this.shas,
    required this.app,
  });

  /// The summaries file's text, or null.
  final String? summaries;

  /// Each language's known file hashes, by language code.
  final Map<String, Map<String, String>> shas;

  final String app;
}

/// Checks the caches of [job]'s languages against their files' hashes and
/// parses nothing.
Map<String, CacheVerdict> runVerifyJob(VerifyJob job) =>
    verifyCaches(summaries: job.summaries, shas: job.shas, app: job.app);

/// Runs a [VerifyJob] somewhere.
typedef CacheVerifier = Future<Map<String, CacheVerdict>> Function(
  VerifyJob job,
);

/// [runVerifyJob] in place.
Future<Map<String, CacheVerdict>> verifyInPlace(VerifyJob job) async =>
    runVerifyJob(job);

Future<Map<String, CacheVerdict>> _verifyOnIsolate(VerifyJob job) =>
    Isolate.run(() => runVerifyJob(job));

/// [runVerifyJob] on an isolate of its own, in place where none can run.
Future<Map<String, CacheVerdict>> verifyInIsolate(
  VerifyJob job, {
  void Function(String message)? onFallback,
}) async {
  try {
    return await _verifyOnIsolate(job);
  } catch (e, stack) {
    tellFallback(
      onFallback,
      'Checking the caches on an isolate failed',
      e,
      stack,
    );
    return runVerifyJob(job);
  }
}

/// The units of [language]'s course from [native], as completeness counts
/// them: each unit of its path with the words its decks have, script decks
/// and grammar tables left out. Without a path, each deck as a unit with no
/// plan, so that only the course's size is known.
List<B1Unit> b1UnitsOf(Catalog catalog, String language, String native) {
  final course = <DeckEntry>[
    for (final entry in catalog.decks)
      if (entry.language.code == language && entry.deck.native.code == native)
        entry,
  ];
  if (course.isEmpty) return const <B1Unit>[];
  final path = catalog.pathOf(course.first);
  final byId = <String, DeckEntry>{for (final e in course) e.id: e};
  if (path == null) {
    return <B1Unit>[
      for (final entry in course)
        B1Unit(has: _words(<DeckEntry>[entry], const <String>{}).length),
    ];
  }
  return <B1Unit>[
    for (final unit in path.plan)
      B1Unit(
        planned: unit.isPlanned,
        words: unit.words,
        milestone: unit.milestone,
        grammar: unit.grammar,
        has: unit.isComing || (unit.decks.isEmpty && unit.open)
            ? null
            : _words(<DeckEntry>[
                for (final id in unit.decks) ?byId[id],
              ], path.alphabet).length,
      ),
  ];
}

Set<String> _words(List<DeckEntry> entries, Set<String> alphabet) => <String>{
  for (final entry in entries)
    if (!alphabet.contains(entry.id))
      for (final card in entry.cards)
        if (countsAsWord(card, entry.deck.kind)) card.id,
};

/// The script [language]'s course starts with: the one most of its decks
/// use.
String _primaryScript(List<DeckEntry> decks) {
  final counts = <String, int>{};
  for (final entry in decks) {
    final language = entry.language;
    // A deck written in kanji lists kana beside it and is read on top of
    // kana (ADR-0053): it counts for the kana the course starts with.
    final script =
        language.script == kanjiScript &&
            language.allScripts.contains(kanaScript)
        ? kanaScript
        : language.script;
    counts[script] = (counts[script] ?? 0) + 1;
  }
  if (counts.isEmpty) return 'latin';
  return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

/// What the screens that list languages read of [code], from its unit's
/// [catalog], stamped with [stamp]. Counts are made as
/// `catalogLanguageFromDecks` makes them.
LanguageSummary summariseLanguage(
  Catalog catalog,
  String code,
  SummaryStamp stamp,
) {
  final teaching = <DeckEntry>[
    for (final entry in catalog.decks)
      if (entry.language.code == code) entry,
  ];
  final first = teaching.firstOrNull;
  final info =
      first?.language ?? LanguageInfo(code: code, iso639_3: code, name: code);
  final natives = <String, LanguageInfo>{
    for (final entry in teaching) entry.deck.native.code: entry.deck.native,
  };
  bool alphabetDeck(DeckEntry entry) {
    final CoursePath? path = catalog.pathOf(entry);
    return path?.alphabet.contains(entry.id) ?? false;
  }

  final courses = <SummaryCourse>[
    for (final native in natives.values)
      _course(catalog, teaching, code, native),
  ];
  final scriptDecks = <String>[
    for (final entry in teaching)
      if (alphabetDeck(entry)) entry.id,
  ];
  final language = catalog.languagePaths[code];
  return LanguageSummary(
    code: code,
    info: info,
    courses: courses,
    decks: <SummaryDeck>[
      for (final entry in <DeckEntry>[...catalog.decks, ...catalog.hidden])
        if (entry.language.code == code)
          SummaryDeck(
            id: entry.id,
            path: entry.path,
            native: entry.deck.native.code,
            kind: entry.deck.kind.name,
            genre: entry.deck.genre,
            theme: entry.deck.theme,
            hidden: entry.deck.hidden,
            adult: isAdultDeck(entry.deck),
            cards: entry.cards.length,
            bundled: entry.bundled,
            private: entry.private,
          ),
    ],
    scriptDecks: scriptDecks,
    hasAlphabet: scriptDecks.isNotEmpty,
    primaryScript: _primaryScript(teaching),
    formHeardCards: <String>[
      for (final entry in teaching)
        for (final card in entry.cards)
          if (card.hearsForm) card.id,
    ],
    hasPath: language != null,
    planUnits: language?.plan.length ?? 0,
    hasFacts: catalog.facts.containsKey(code),
    hasSituations: catalog.situations.containsKey(code),
    hasTopics: catalog.topics.containsKey(code),
    hasCulture: teaching.any((e) => e.deck.genre == 'culture'),
    hasRomanisation: catalog.romanisations.containsKey(code),
    hasSounds: catalog.sounds.containsKey(code),
    hasNumbers: catalog.numberRules.containsKey(code),
    scriptGuideKeys: <String>[
      for (final guide in catalog.scriptGuides.values)
        if (guide.language == code) guide.key,
    ]..sort(),
    stamp: stamp,
  );
}

SummaryCourse _course(
  Catalog catalog,
  List<DeckEntry> teaching,
  String code,
  LanguageInfo native,
) {
  final decks = <DeckEntry>[
    for (final entry in teaching)
      if (entry.deck.native.code == native.code) entry,
  ];
  return SummaryCourse(
    native: native.code,
    nativeName: native.name,
    units: b1UnitsOf(catalog, code, native.code),
    decks: decks.length,
    cards: decks.fold(0, (sum, e) => sum + e.cards.length),
    words: _words(decks, const <String>{}).length,
    cultureCards: decks
        .where((e) => e.deck.genre == 'culture')
        .fold(0, (sum, e) => sum + e.cards.length),
    hasPath: decks.isNotEmpty && catalog.pathOf(decks.first) != null,
  );
}
