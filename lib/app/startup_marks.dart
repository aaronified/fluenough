import 'dart:developer';

import 'app_log.dart';

/// Timing marks for a cold start (#857): each is a `dart:developer`
/// timeline event and one app-log line with the milliseconds since the
/// process's `main` began, so that the next step can be measured.
class StartupMarks {
  StartupMarks(this._log) : _clock = Stopwatch()..start();

  final AppLog _log;
  final Stopwatch _clock;

  /// Records that [what] has happened now.
  void mark(String what) {
    Timeline.startSync('startup: $what');
    Timeline.finishSync();
    _log.event('Startup: $what at ${_clock.elapsedMilliseconds} ms');
  }
}
