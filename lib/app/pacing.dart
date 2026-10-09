import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../core/scheduling/replay.dart';
import '../core/scheduling/skill_fit.dart';
import 'memory_progress.dart';

/// What working out the paces takes: plain data, so that it can be sent
/// to another isolate, which copies it as it is sent. The log is turned
/// into reviews there, not here.
typedef PaceJob = ({
  List<ReviewEvent> log,
  List<LeechAction> leechActions,
  SkillParameters parameters,
  DateTime now,
});

/// Works out [PaceJob]'s paces.
typedef PaceRunner = Future<List<SkillPace>> Function(PaceJob job);

List<SkillPace> _paces(PaceJob job) => SkillFit.paces(
  inTimeOrder(job.log.map(logged)),
  parameters: job.parameters,
  now: job.now,
  effects: LeechEffects(job.leechActions),
);

/// [SkillFit.paces] on an isolate of its own, off the main thread.
Future<List<SkillPace>> paceInIsolate(PaceJob job) =>
    Isolate.run(() => _paces(job));

/// [SkillFit.paces] in place: for tests, which run on a fake clock.
Future<List<SkillPace>> paceInPlace(PaceJob job) async => _paces(job);

/// How each skill is paced for the learner beside how it started (`docs/
/// plans/skill-model.md`, "Shown prominently"): what How you learn shows,
/// and Today's strip and tile marks.
///
/// Worked out only when asked for ([paces]), on an isolate, and again when
/// the log, the leech actions, the parameters or the day change. Nothing
/// is worked out at app start: Today asks only once [adjusted], a cheap
/// read of the stored fits, says that some skill is adjusted.
class Pacing extends ChangeNotifier {
  Pacing({
    required this.progress,
    required this._clock,
    this._runner = paceInIsolate,
  });

  final ProgressStore progress;
  final DateTime Function() _clock;
  final PaceRunner _runner;

  /// Whether any skill has been fitted, kept or not.
  bool get fitted => progress.parameters.fitted.isNotEmpty;

  /// Whether some fit kept a set other than FSRS-6's defaults, so that
  /// some skill is paced for the learner. Reads the stored fits only.
  bool get adjusted => progress.parameters.fitted.values.any(
    (f) => !SkillFit.isDefaults(f.values),
  );

  Object? _key;
  Object? _running;
  Map<SkillKey, SkillPace>? _paces;
  bool _disposed = false;

  /// Every skill with reviews, by language and mode, as worked out last;
  /// null until the first is. Asking starts working them out again if
  /// what they come from has changed since; [Pacing] notifies when done.
  Map<SkillKey, SkillPace>? get paces {
    final now = _clock();
    final log = progress.log;
    final actions = progress.leechActions;
    final key = (
      log.length,
      log.isEmpty ? null : log.last,
      actions.length,
      progress.parameters,
      DateTime(now.year, now.month, now.day),
    );
    if (key != _key && key != _running) {
      _running = key;
      _work(key, (
        log: log,
        leechActions: actions,
        parameters: progress.parameters,
        now: now,
      ));
    }
    return _paces;
  }

  Future<void> _work(Object key, PaceJob job) async {
    try {
      final paces = await _runner(job);
      if (_disposed || _running != key) return;
      _paces = <SkillKey, SkillPace>{for (final p in paces) p.key: p};
      _key = key;
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'fluenough pacing',
          context: ErrorDescription('while working out How you learn'),
        ),
      );
      // Not tried again until something changes.
      _key = key;
      _paces ??= const <SkillKey, SkillPace>{};
    } finally {
      if (_running == key) _running = null;
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
