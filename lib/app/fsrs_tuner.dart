import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../core/scheduling/replay.dart';
import '../core/scheduling/skill_fit.dart';
import 'memory_progress.dart';

/// Runs one skill's fit and gives what it found.
typedef FitRunner = Future<SkillFitResult> Function(SkillFitJob job);

/// [SkillFit.run] on an isolate of its own, off the main thread, so that a
/// fit never holds up the screen.
Future<SkillFitResult> fitInIsolate(SkillFitJob job) =>
    Isolate.run(() => SkillFit.run(job));

/// [SkillFit.run] in place: for tests, which run on a fake clock.
Future<SkillFitResult> fitInPlace(SkillFitJob job) async => SkillFit.run(job);

/// Fits FSRS to the learner (`docs/plans/skill-model.md`): every skill on
/// Settings' "Adjust to me" ([adjustAll]), and one skill in the background
/// once it has 10% more answers than at its last fit ([afterReview]).
///
/// Only one fit runs at a time, and none starts at app open: the automatic
/// refit is set off only by recording a review. A fit kept is stored with
/// [ProgressStore.putFitted], which reschedules the skill's words with it.
class FsrsTuner extends ChangeNotifier {
  FsrsTuner({
    required this.progress,
    required this._clock,
    this._runner = fitInIsolate,
  });

  final ProgressStore progress;
  final DateTime Function() _clock;
  final FitRunner _runner;

  /// How much a skill's reviews must grow since its last fit before the
  /// automatic refit runs: 10% (owner, 2026-10-09).
  static const double growth = 1.1;

  bool _busy = false;
  SkillKey? _current;
  int _done = 0;
  int _total = 0;
  bool _disposed = false;

  /// Whether a fit is running.
  bool get busy => _busy;

  /// The skill being fitted, while [busy].
  SkillKey? get current => _current;

  /// How many skills of this run are fitted so far, and how many it has.
  int get done => _done;
  int get total => _total;

  /// When a skill was last fitted, in any language, or null if none ever
  /// was.
  DateTime? get lastAdjusted {
    DateTime? last;
    for (final fitted in progress.parameters.fitted.values) {
      if (last == null || fitted.fittedAt.isAfter(last)) {
        last = fitted.fittedAt;
      }
    }
    return last;
  }

  int _canAdjustAt = -1;
  bool _canAdjust = false;

  /// Whether some skill holds enough answers to fit (`FsrsFit.gate`):
  /// until then "Adjust to me" waits.
  bool get canAdjust {
    final log = progress.log;
    if (_canAdjustAt != log.length) {
      final now = _clock();
      _canAdjust = _histories(log).values.any((h) => SkillFit.canFit(h, now));
      _canAdjustAt = log.length;
    }
    return _canAdjust;
  }

  /// Fits every skill, in every language, that holds enough answers, one
  /// after another, the languages studied most recently first, so that a
  /// language without a fit of its own starts from the newest. Gives a
  /// result for every skill with answers, fitted or not; null, and does
  /// nothing, while another fit runs.
  Future<List<SkillFitResult>?> adjustAll() async {
    if (_busy) return null;
    final now = _clock();
    final histories = _histories(progress.log);
    final studied = progress.parameters.lastStudied;
    final keys = histories.keys.toList()
      ..sort((a, b) {
        final at = studied[a.language];
        final bt = studied[b.language];
        final byTime = at == null || bt == null
            ? (bt == null ? 0 : 1) - (at == null ? 0 : 1)
            : bt.compareTo(at);
        if (byTime != 0) return byTime;
        final byLanguage = a.language.compareTo(b.language);
        return byLanguage != 0
            ? byLanguage
            : a.mode.index.compareTo(b.mode.index);
      });
    final fittable = <SkillKey>[
      for (final key in keys)
        if (SkillFit.canFit(histories[key]!, now)) key,
    ];
    final results = <SkillFitResult>[];
    _start(fittable.length);
    try {
      for (final key in keys) {
        if (!fittable.contains(key)) {
          const none = (days: 0, reviews: 0);
          results.add((key: key, fitted: null, before: none, after: none));
          continue;
        }
        _current = key;
        _notify();
        results.add(await _fit(histories[key]!, now));
        _done++;
        _notify();
      }
    } finally {
      _finish();
    }
    return results;
  }

  int _countedAt = 0;
  final Map<SkillKey, int> _counts = <SkillKey, int>{};
  final Map<SkillKey, int> _checkedAt = <SkillKey, int>{};

  /// After [event] is recorded: refits its skill in the background if it
  /// has 10% more answers than at its last fit, or, never fitted, has
  /// enough to fit for the first time. Nothing while a fit runs; the next
  /// answer looks again.
  void afterReview(ReviewEvent event) {
    final key = skillOf(event.key);
    final log = progress.log;
    if (_countedAt == log.length - 1 && log.isNotEmpty) {
      _counts[key] = (_counts[key] ?? 0) + 1;
    } else {
      _counts.clear();
      for (final e in log) {
        final k = skillOf(e.key);
        _counts[k] = (_counts[k] ?? 0) + 1;
      }
    }
    _countedAt = log.length;
    if (_busy) return;
    final count = _counts[key] ?? 0;
    final fitted = progress.parameters.fitted[key];
    final now = _clock();
    if (fitted != null) {
      if (count < fitted.reviewCount * growth) return;
    } else {
      // Not fittable yet: looked at again once it has grown by as much,
      // so that the gate is not worked out after every answer.
      final checked = _checkedAt[key];
      if (checked != null && count < checked * growth) return;
      _checkedAt[key] = count;
    }
    final history = _histories(log, only: key)[key];
    if (history == null) return;
    if (fitted == null && !SkillFit.canFit(history, now)) return;
    _runInBackground(history, now);
  }

  Future<void> _runInBackground(SkillHistory history, DateTime now) async {
    _start(1);
    _current = history.key;
    _notify();
    try {
      await _fit(history, now);
      _done = 1;
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'fluenough fitting',
          context: ErrorDescription('while adjusting to the learner'),
        ),
      );
    } finally {
      _finish();
    }
  }

  /// Fits [history] from the set that schedules it now, and keeps what
  /// the fit gives, which reschedules the skill's words.
  Future<SkillFitResult> _fit(SkillHistory history, DateTime now) async {
    final key = history.key;
    final inUse = progress.parameters.of(key.language, key.mode);
    final result = await _runner(SkillFit.job(history, inUse, now));
    final fitted = result.fitted;
    if (fitted != null && !_disposed) {
      await progress.putFitted(key, fitted);
    }
    return result;
  }

  Map<SkillKey, SkillHistory> _histories(
    List<ReviewEvent> log, {
    SkillKey? only,
  }) => SkillFit.histories(<LoggedReview>[
    for (final e in log)
      if (only == null || skillOf(e.key) == only) logged(e),
  ], effects: progress.leechEffects);

  void _start(int total) {
    _busy = true;
    _done = 0;
    _total = total;
    _notify();
  }

  void _finish() {
    _busy = false;
    _current = null;
    _canAdjustAt = -1;
    _notify();
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
