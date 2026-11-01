import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../../app/app_state.dart';
import '../../app/memory_progress.dart';
import '../../core/data/course_path.dart';
import '../../core/models/drill_mode.dart';
import '../../core/progress/mastery.dart';
import '../../core/progress/practice_week.dart';
import 'progress_mastery.dart';
import 'stats_numbers.dart';

/// What one language's Progress needs worked out from the review log
/// (#857), as plain data: it crosses to an isolate, which copies it as it
/// is sent, so it holds only the language's own slice of the log and
/// nothing that needs [AppState] or a closure.
class ProgressJob {
  const ProgressJob({
    required this.language,
    required this.now,
    required this.languages,
    required this.log,
    required this.scriptLog,
    required this.allAnswered,
    required this.codes,
    required this.inputs,
    required this.level,
    required this.parameters,
    required this.tags,
  });

  /// The language counted, or null for every language together.
  final String? language;
  final DateTime now;

  /// Tells which language a deck teaches.
  final LanguageTable languages;

  /// The answers in the languages counted, oldest first.
  final List<ReviewEvent> log;

  /// The script skills' reviews in the languages counted.
  final List<ReviewEvent> scriptLog;

  /// Every answer, for the weakest tags on All when some answer's language
  /// cannot be told ([log] leaves those out); null when [log] is all of it.
  final List<ReviewEvent>? allAnswered;

  /// The languages [log] has reviews in, in the order each first appears.
  final List<String> codes;

  /// What each of [codes]' courses holds.
  final Map<String, CourseInputs> inputs;

  /// The course's level reached, for one language.
  final Milestone? level;

  /// The parameters that schedule each mode, for each of [codes] and for ''
  /// (a review whose language cannot be told).
  final Map<String, Map<DrillMode, List<double>>> parameters;

  /// The tags of the cards of each of [codes].
  final List<CardTags> tags;
}

/// What a course holds, as plain data.
class CourseInputs {
  const CourseInputs({required this.totals, required this.scriptCards});

  final MasteryTotals totals;
  final Set<String> scriptCards;
}

/// The tags of one language's cards, as plain data (a card lookup is a
/// closure, which cannot cross to an isolate).
class CardTags {
  const CardTags({required this.listed, required this.first});

  /// By `deckId/cardId`: the cards each deck lists.
  final Map<String, List<String>> listed;

  /// By card id: the card the first deck listing it has.
  final Map<String, List<String>> first;
}

/// What Progress shows that comes from the review log: the mastery, and the
/// tags known least. Plain data, so that it comes back from an isolate
/// without being copied.
class ProgressNumbers {
  const ProgressNumbers({
    required this.mastery,
    required this.weakestTags,
    required this.none,
  });

  /// Nothing to show: the language has no answers, or there are none at all.
  ProgressNumbers.empty(DateTime now)
    : mastery = ProgressMastery.empty(now),
      weakestTags = const <String, Tally>{},
      none = true;

  final ProgressMastery mastery;

  /// Every tag taught, weakest first ([weakestTally]), whatever the range.
  final Map<String, Tally> weakestTags;

  /// Whether there are no answers in the language counted.
  final bool none;
}

/// Works out [job]'s numbers. Pure: no state, no Flutter, so that
/// [progressInIsolate] can run it on an isolate and [progressInPlace] gives
/// the same result. [withSeries] works out the star's weekly snapshots too,
/// which an isolate does so that they come back with the rest.
ProgressNumbers computeProgress(ProgressJob job, {bool withSeries = false}) {
  final languageOf = job.languages.of;
  final parts = <MasteryPart>[
    for (final code in job.codes)
      MasteryPart(
        log: <ReviewEvent>[
          for (final e in job.log)
            if (languageOf(e.deckId) == code) e,
        ],
        scriptLog: <ReviewEvent>[
          for (final e in job.scriptLog)
            if (languageOf(e.deckId) == code) e,
        ],
        totals: job.inputs[code]!.totals,
        scriptCards: job.inputs[code]!.scriptCards,
        parametersOf: (mode) => job.parameters[code]![mode]!,
      ),
  ];
  final mastery = ProgressMastery.fromParts(
    parts,
    log: job.log,
    at: job.now,
    level: job.level,
    withSeries: withSeries,
  );
  Iterable<String> tagsOf(ReviewEvent e) {
    final key = '${e.deckId}/${e.cardId}';
    for (final table in job.tags) {
      if (table.listed[key] case final tags?) return tags;
    }
    for (final table in job.tags) {
      if (table.first[e.cardId] case final tags?) return tags;
    }
    return const <String>[];
  }

  return ProgressNumbers(
    mastery: mastery,
    weakestTags: weakestTally(
      job.allAnswered ?? job.log,
      tagsOf: tagsOf,
      now: job.now,
      parametersOf: (e) => job.parameters[languageOf(e.deckId) ?? '']![e.mode]!,
      count: 1 << 30,
    ),
    none: false,
  );
}

/// Runs a [ProgressJob], somewhere.
typedef ProgressRunner = Future<ProgressNumbers> Function(ProgressJob job);

/// [computeProgress] on the calling isolate. Given to
/// [ProgressNumbersHolder], it works every number out as it is read, with
/// no waiting: for tests, which run on a fake clock, and the web, which has
/// no isolates.
Future<ProgressNumbers> progressInPlace(ProgressJob job) async =>
    computeProgress(job);

/// [computeProgress] on an isolate of its own (#857): the weekly snapshots,
/// the words and the weakest tags walk the whole log of a language, which on
/// the UI isolate is a stuttering tab. If the isolate cannot start or fails,
/// it works them out in place, so the result is the same either way.
Future<ProgressNumbers> progressInIsolate(ProgressJob job) async {
  try {
    return await Isolate.run(() => computeProgress(job, withSeries: true));
  } catch (_) {
    return computeProgress(job, withSeries: true);
  }
}

/// What Progress shows from the log, by language, kept good and read without
/// waiting (#857).
///
/// [of] returns what was worked out last, and, when what it comes from has
/// changed (the language's progress, the decks, the day), starts working it
/// out again through the runner and notifies when done. Until the first is
/// back [of] returns null, which a screen shows as a neutral state. One job
/// runs at a time for each language: asked again while one runs, the holder
/// works out only the latest once it ends, however many answers came in
/// between. With [progressInPlace] nothing waits: [of] works out and returns
/// at once.
class ProgressNumbersHolder extends ChangeNotifier {
  ProgressNumbersHolder({
    required this._state,
    this._runner = progressInIsolate,
  });

  final AppState _state;
  final ProgressRunner _runner;
  final Map<String?, _Entry> _entries = <String?, _Entry>{};
  bool _disposed = false;

  bool get _inPlace => identical(_runner, progressInPlace);

  /// The numbers of [language] (every language when null) as worked out
  /// last, or null before the first time. Asking starts working them out
  /// again if what they come from has changed; [ProgressNumbersHolder]
  /// notifies when they are back.
  ProgressNumbers? of(String? language) {
    final state = _state;
    final progress = state.progress;
    final now = state.now();
    final key = (
      progress: progress,
      // A language's own version: an answer in another language leaves this
      // one's numbers as they were. All languages go by the whole progress.
      version: language == null
          ? progress.version
          : progress.versionOf(language),
      decks: state.decks,
      day: calendarDay(now),
      native: language == null ? null : state.courseNative(language),
    );
    final entry = _entries[language] ??= _Entry();
    if (entry.key == key) return entry.value;
    if (entry.running != null) {
      // Worked out again when the running job ends, from what is there then.
      if (entry.running != key) entry.askedAgain = true;
      return entry.value;
    }
    final job = _jobFor(language, now);
    if (job == null) {
      entry
        ..value = ProgressNumbers.empty(now)
        ..key = key;
      return entry.value;
    }
    if (_inPlace) {
      entry
        ..value = computeProgress(job)
        ..key = key;
      return entry.value;
    }
    entry.running = key;
    _work(language, entry, key, job);
    return entry.value;
  }

  Future<void> _work(
    String? language,
    _Entry entry,
    Object key,
    ProgressJob job,
  ) async {
    try {
      final numbers = await _runner(job);
      if (_disposed) return;
      // Kept even when asked again since: a moment out of date, and better
      // than nothing while the next is worked out.
      entry.value = numbers;
      entry.key = key;
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'fluenough progress',
          context: ErrorDescription('while working out Progress'),
        ),
      );
      // Not tried again until something changes.
      entry.key = key;
    } finally {
      entry.running = null;
    }
    if (_disposed) return;
    if (entry.askedAgain) {
      entry.askedAgain = false;
      of(language);
    }
    notifyListeners();
  }

  /// The job for [language], or null if it has no answers: the one pass over
  /// the log that the UI isolate still makes, which cuts the language's
  /// slice out of it.
  ProgressJob? _jobFor(String? language, DateTime now) {
    final state = _state;
    final progress = state.progress;
    final table = LanguageTable.of(state);
    bool counts(String deckId) {
      final code = table.of(deckId);
      return language == null ? code != null : code == language;
    }

    final log = <ReviewEvent>[];
    final found = <String>{};
    var any = false;
    var unknown = false;
    for (final e in progress.log.answered) {
      any = true;
      final code = table.of(e.deckId);
      if (code == null) {
        unknown = true;
      } else if (language == null || code == language) {
        log.add(e);
        found.add(code);
      }
    }
    if (language == null ? !any : log.isEmpty) return null;
    final codes = language != null ? <String>[language] : found.toList();
    final inputs = <String, CourseInputs>{};
    Milestone? level;
    for (final code in codes) {
      final course = courseInputsOf(state, code);
      inputs[code] = CourseInputs(
        totals: course.totals,
        scriptCards: course.scriptCards,
      );
      if (language != null) level = course.level;
    }
    return ProgressJob(
      language: language,
      now: now,
      languages: table,
      log: log,
      scriptLog: <ReviewEvent>[
        for (final e in progress.scriptLog)
          if (counts(e.deckId)) e,
      ],
      allAnswered: language == null && unknown
          ? <ReviewEvent>[...progress.log.answered]
          : null,
      codes: codes,
      inputs: inputs,
      level: level,
      parameters: <String, Map<DrillMode, List<double>>>{
        for (final code in <String>{...codes, ''})
          code: <DrillMode, List<double>>{
            for (final mode in DrillMode.values)
              mode: progress.parameters.of(code, mode),
          },
      },
      tags: <CardTags>[for (final code in codes) _tagsOf(state, code)],
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _Entry {
  Object? key;
  Object? running;
  bool askedAgain = false;
  ProgressNumbers? value;
}

final Expando<Map<String, CardTags>> _tagTables =
    Expando<Map<String, CardTags>>('CardTags');

/// The tags of [code]'s cards, indexed once for as long as the catalog's
/// list is the same one.
CardTags _tagsOf(AppState state, String code) {
  final byCode = _tagTables[state.decks] ??= <String, CardTags>{};
  return byCode[code] ??= _indexTags(state, code);
}

CardTags _indexTags(AppState state, String code) {
  final cardOf = cardLookupOf(state);
  final listed = <String, List<String>>{};
  final first = <String, List<String>>{};
  for (final entry in state.decks) {
    if (entry.language.code != code) continue;
    for (final card in entry.cards) {
      listed['${entry.id}/${card.id}'] = card.tags;
      // Whichever deck lists the card first, in any language.
      first[card.id] ??= cardOf(card.id)?.tags ?? const <String>[];
    }
  }
  return CardTags(listed: listed, first: first);
}
