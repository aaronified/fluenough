import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../core/achievements/achievement.dart';
import '../core/achievements/achievement_evaluator.dart';
import '../core/achievements/achievement_facts.dart';
import '../core/achievements/achievement_news.dart';
import '../core/data/course_path.dart';
import '../core/languages/language_skills.dart';
import '../core/models/card.dart';
import '../core/models/deck.dart';
import '../core/models/drill_mode.dart';
import '../core/models/review_event.dart';
import '../core/scheduling/fsrs.dart';
import 'app_state.dart';
import 'deck_catalog.dart';

/// The scope the app-wide badges (streaks, answer counts) are kept under in
/// the settings, beside the language codes of the course badges.
const String kAppAchievements = '*';

/// What the achievements of one language need worked out (#322), as plain
/// data: it crosses to an isolate, which copies it as it is sent, so it holds
/// the facts of the language's decks and the review log and nothing that
/// needs [AppState] or a closure.
class AchievementJob {
  const AchievementJob({
    required this.language,
    required this.facts,
    required this.log,
    required this.parameters,
    this.earnedBefore = const <String, DateTime>{},
  });

  /// The language counted, or null for the app-wide badges alone.
  final String? language;

  /// Its decks and path, or null when it has none loaded or no path.
  final AchievementFacts? facts;

  /// Every answer in every language, oldest first: streaks and answer counts
  /// are the app's, and a language's own reviews are cut from it by the
  /// evaluator.
  final List<ReviewEvent> log;

  /// The parameters that schedule each mode in [language], so that "known"
  /// here is Progress's known.
  final Map<DrillMode, List<double>> parameters;

  /// The badges already earned and when, from what the app kept (#323): they
  /// stay earned even if a deck has grown since, so that none is ever lost.
  final Map<String, DateTime> earnedBefore;
}

/// Works out [job]'s report. Pure: no state, no Flutter, so that
/// [achievementsInIsolate] runs it on an isolate and [achievementsInPlace]
/// gives the same result.
AchievementReport computeAchievements(AchievementJob job) {
  List<double> parametersOf(ReviewEvent e) => job.parameters[e.mode] ?? Fsrs.w;
  return evaluateAchievements(
    log: job.log,
    facts: job.facts,
    parametersOf: parametersOf,
    earnedBefore: job.earnedBefore,
  );
}

/// Runs an [AchievementJob], somewhere.
typedef AchievementRunner = Future<AchievementReport> Function(AchievementJob);

/// [computeAchievements] on the calling isolate: for tests, which run on a
/// fake clock, and the web, which has no isolates.
Future<AchievementReport> achievementsInPlace(AchievementJob job) async =>
    computeAchievements(job);

/// [computeAchievements] on an isolate of its own: the replay of a
/// language's whole log is the heavy part, and on the UI isolate it would
/// stutter a screen (#857, #1699). If the isolate cannot start or fails, it
/// works the report out in place, so the result is the same either way.
Future<AchievementReport> achievementsInIsolate(AchievementJob job) async {
  try {
    return await Isolate.run(() => computeAchievements(job));
  } catch (_) {
    return computeAchievements(job);
  }
}

/// The achievements by language, kept good and read without waiting.
///
/// Derived, never stored: [of] returns what was worked out last, and, when
/// what it comes from has changed (the review log, the language's decks or
/// the skills marked Leave), starts working it out again through the runner
/// and notifies when done. Until the first is back [of] returns null. One job
/// runs at a time for each language: asked again while one runs, the holder
/// works out only the latest once it ends. Nothing here walks the log or the
/// cards on the UI isolate except the one pass that copies the log into the
/// job, and the facts, built once for as long as the language's decks are the
/// same ones.
///
/// **Rate limit (#323).** Nothing here listens to the review log: a report is
/// worked out only when a screen asks for it with [of], and the screens that
/// ask are the Progress badges (once opened, and visible) and the session
/// summary (the end of a session), never a lesson or a drill. So an answer
/// costs nothing here, and a session costs at most one job per language.
class AchievementsHolder extends ChangeNotifier {
  AchievementsHolder({
    required this._state,
    this._runner = achievementsInIsolate,
  });

  final AppState _state;
  final AchievementRunner _runner;
  final Map<String, _Entry> _entries = <String, _Entry>{};
  bool _disposed = false;

  bool get _inPlace => identical(_runner, achievementsInPlace);

  /// The achievements of [language] and the app (the app's alone when null),
  /// as worked out last, or null before the first time. Asking starts
  /// working them out again if what they come from has changed.
  AchievementReport? of(String? language) {
    final key = _keyOf(language);
    final entry = _entries[language ?? ''] ??= _Entry();
    if (entry.key == key) return entry.value;
    if (entry.running != null) {
      // Worked out again when the running job ends, from what is there then.
      if (entry.running != key) entry.askedAgain = true;
      return entry.value;
    }
    final job = _jobFor(language);
    if (_inPlace) {
      final report = computeAchievements(job);
      entry
        ..value = report
        ..key = key;
      // Not while a widget builds: saving notifies the settings' listeners.
      scheduleMicrotask(() => _remember(language, report));
      return entry.value;
    }
    entry.running = key;
    _work(language, entry, key, job);
    return entry.value;
  }

  /// What the report of [language] is worked out from, as it is now: a
  /// report is current when it was worked out from this.
  Object _keyOf(String? language) {
    final state = _state;
    final progress = state.progress;
    return (
      progress: progress,
      version: progress.version,
      decks: language == null ? null : state.decksKeyOf(language),
      native: language == null ? null : state.courseNative(language),
      skills: language == null
          ? null
          : '${state.settings.languageSkillsOf(language)}',
    );
  }

  /// [of], but only a report worked out from what is there now, else null
  /// (the summary of a session waits for the one that counts its answers).
  AchievementReport? currentOf(String language) {
    final report = of(language);
    return _entries[language]?.key == _keyOf(language) ? report : null;
  }

  /// What the summary of a session that began at [since] announces for
  /// [language] (#323): the badges earned since the learner last looked, which
  /// the holder knows from what the settings keep as seen. Null until the
  /// report is back. The badges already earned when the learner is first
  /// looked at are the past reviews' (decision 4). Null until the report
  /// worked out from this session's answers is back.
  AchievementNews? newsFor(String language, {required DateTime since}) {
    final report = currentOf(language);
    if (report == null) return null;
    final settings = _state.settings;
    return AchievementNews.of(
      report,
      seenCourse: settings.achievementsSeenOf(language),
      seenApp: settings.achievementsSeenOf(kAppAchievements),
      since: since,
    );
  }

  /// Records that [news] was shown, so that it is not announced again.
  void markSeen(String language, AchievementNews news) {
    final settings = _state.settings;
    settings.markAchievementsSeen(language, news.courseIds);
    settings.markAchievementsSeen(kAppAchievements, news.appIds);
  }

  Future<void> _work(
    String? language,
    _Entry entry,
    Object key,
    AchievementJob job,
  ) async {
    try {
      final report = await _runner(job);
      if (_disposed) return;
      entry
        ..value = report
        ..key = key;
      _remember(language, report);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'fluenough achievements',
          context: ErrorDescription('while working out the achievements'),
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

  /// Keeps the badges [report] shows as earned, with their dates, in the
  /// settings, which the profile's database holds (#323): the next run is
  /// given them as `earnedBefore`, so that no badge is lost when a deck grows
  /// or the app restarts. The review log is never touched.
  void _remember(String? language, AchievementReport report) {
    if (_disposed) return;
    final course = <String, DateTime>{};
    final app = <String, DateTime>{};
    for (final result in report.results) {
      final at = result.earnedAt;
      if (!result.isEarned || at == null) continue;
      (result.def.isAppWide ? app : course)[result.def.id] = at;
    }
    final settings = _state.settings;
    settings.rememberAchievements(kAppAchievements, app);
    if (language != null) settings.rememberAchievements(language, course);
  }

  AchievementJob _jobFor(String? language) {
    final progress = _state.progress;
    final settings = _state.settings;
    return AchievementJob(
      language: language,
      earnedBefore: <String, DateTime>{
        ...settings.achievementsEarnedOf(kAppAchievements),
        if (language != null) ...settings.achievementsEarnedOf(language),
      },
      facts: language == null ? null : achievementFactsOf(_state, language),
      log: <ReviewEvent>[...progress.log.answered],
      parameters: <DrillMode, List<double>>{
        if (language != null)
          for (final mode in DrillMode.values)
            mode: progress.parameters.of(language, mode),
      },
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
  AchievementReport? value;
}

final Expando<Map<String, AchievementFacts?>> _factsTables =
    Expando<Map<String, AchievementFacts?>>('AchievementFacts');

/// The facts of [code]'s course for the achievements, or null when its decks
/// are not loaded or it has no path. Built in one pass over the path's decks
/// and kept for as long as the language's list of decks is the same one; only
/// the skills marked Leave are read again.
AchievementFacts? achievementFactsOf(AppState state, String code) {
  final entries = state.decksOf(code);
  if (entries.isEmpty) return null;
  final native = state.courseNative(code);
  final byCourse = _factsTables[entries] ??= <String, AchievementFacts?>{};
  final key = '$code/${native ?? ''}';
  if (!byCourse.containsKey(key)) {
    byCourse[key] = _buildFacts(state, code, native, entries);
  }
  final base = byCourse[key];
  if (base == null) return null;
  final stored = state.settings.languageSkillsOf(code);
  if (stored == null) return base;
  final chosen = LanguageSkills.fromStored(stored);
  return base.withLeave(<SkillKey>{
    for (final skill in base.skills)
      if (chosen.stateOf(skill) == SkillState.leave) skill,
  });
}

AchievementFacts? _buildFacts(
  AppState state,
  String code,
  String? native,
  List<DeckEntry> entries,
) {
  final course = <DeckEntry>[
    for (final e in entries)
      if (e.language.code == code && e.deck.native.code == native) e,
  ];
  if (course.isEmpty) return null;
  final path = state.pathOf(course.first);
  if (path == null) return null;
  final decks = <String, AchievementDeck>{};
  final unitDecks = <List<String>>[];
  final unitWritten = <bool>[];
  for (final unit in path.plan) {
    unitDecks.add(unit.decks);
    unitWritten.add(!unit.isComing && unit.decks.isNotEmpty);
    for (final id in unit.decks) {
      if (decks.containsKey(id)) continue;
      final entry = state.deckById(id);
      if (entry == null) continue;
      decks[id] = _deckFacts(entry, path.alphabet.contains(id));
    }
  }
  final language = course.first.language;
  final skills = skillsOfLanguage(
    language.allScripts,
    scriptOnly: language.isNotation,
    sign: language.script == 'signwriting',
    typed: language.typed,
  );
  return AchievementFacts(
    language: code,
    unitDecks: unitDecks,
    unitWritten: unitWritten,
    marks: <Milestone, int>{
      for (final level in Milestone.values)
        if (path.milestoneIndex(level) case final index?) level: index + 1,
    },
    decks: decks,
    sets: path.achievementSets,
    skills: skills,
  );
}

AchievementDeck _deckFacts(DeckEntry entry, bool isScript) {
  final deck = entry.deck;
  final reading = deck.kind == DeckKind.reading;
  return AchievementDeck(
    id: deck.id,
    isScript: isScript,
    script: isScript ? deck.language.script : null,
    cards: <AchievementCard>[
      for (final card in entry.cards)
        AchievementCard(
          card.id,
          reading ? 0 : _modeMask(card),
          isWord: !isScript && countsAsWord(card, deck.kind),
        ),
    ],
  );
}

/// The vocabulary skills [card] is asked in, whatever the phone's voices:
/// the data decides, not the device.
int _modeMask(Card card) {
  final modes = card.modesIn(ttsAvailable: true, speechAvailable: true);
  return AchievementCard.maskOf(modes.where(DrillMode.vocabulary.contains));
}
