import 'dart:async';
import 'dart:developer';

import 'package:flutter/scheduler.dart';

import '../core/logs/log_entry.dart';
import 'app_log.dart';

/// Timing marks for a cold start (#857): each is a `dart:developer`
/// timeline event and one app-log line with the milliseconds since the
/// process's `main` began, so that the next step can be measured.
///
/// Beyond single marks it times *spans* ([span], [record]): one log line
/// each, `Startup: <what> took N ms (isolate=..., k=v) at T ms`, so that the
/// next slow thing shows in the app log without a profiler. A frame probe
/// ([watchFrames]) logs every frame that took more than [slowFrame] to build
/// and rasterise inside a watched window. Instrumentation never throws: a
/// failure in it goes to the log and the work it wraps carries on.
class StartupMarks {
  StartupMarks(this._log, {Stopwatch? clock})
    : _clock = clock ?? (Stopwatch()..start());

  final AppLog _log;
  final Stopwatch _clock;

  /// A frame whose build and raster together take longer than this is jank.
  static const Duration slowFrame = Duration(milliseconds: 100);

  /// How many spans the summary names.
  static const int summarySpans = 5;

  final List<({String what, int ms})> _spans = <({String what, int ms})>[];
  Duration _watchUntil = Duration.zero;
  String _watchLabel = 'start';
  bool _probing = false;

  /// Milliseconds since the clock started.
  int get elapsedMs => _clock.elapsedMilliseconds;

  /// Records that [what] has happened now.
  void mark(String what) {
    try {
      Timeline.startSync('startup: $what');
      Timeline.finishSync();
      _log.event('Startup: $what at ${_clock.elapsedMilliseconds} ms');
    } on Object catch (e) {
      _report('mark $what', e);
    }
  }

  /// Runs [body], times it and logs one line. The result, or the error, of
  /// [body] is passed on unchanged. [isolate] names where the work ran; the
  /// pairs of [extra] are listed after it.
  Future<T> span<T>(
    String what,
    FutureOr<T> Function() body, {
    String isolate = 'main',
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    final watch = Stopwatch()..start();
    TimelineTask? task;
    try {
      task = TimelineTask()..start('startup: $what');
    } on Object catch (e) {
      _report('span $what', e);
    }
    try {
      return await body();
    } finally {
      watch.stop();
      try {
        task?.finish();
      } on Object catch (e) {
        _report('span $what', e);
      }
      record(what, watch.elapsedMilliseconds, isolate: isolate, extra: extra);
    }
  }

  /// Logs a span of [ms] milliseconds that was timed elsewhere, such as
  /// inside an isolate, or whose [extra] counts are only known afterwards.
  void record(
    String what,
    int ms, {
    String isolate = 'main',
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    try {
      _spans.add((what: what, ms: ms));
      final details = <String>[
        'isolate=$isolate',
        for (final e in extra.entries) '${e.key}=${e.value}',
      ].join(', ');
      _log.event(
        'Startup: $what took $ms ms ($details) at '
        '${_clock.elapsedMilliseconds} ms',
      );
    } on Object catch (e) {
      _report('record $what', e);
    }
  }

  /// Logs counts worked out while loading, such as how many cards.
  void count(String what, Map<String, Object?> counts) {
    try {
      final text = counts.entries.map((e) => '${e.key}=${e.value}').join(', ');
      _log.event('Startup: $what: $text at ${_clock.elapsedMilliseconds} ms');
    } on Object catch (e) {
      _report('count $what', e);
    }
  }

  /// Logs `Startup summary: total X ms, top 5 spans: ...`.
  void summary() {
    try {
      final top = List<({String what, int ms})>.of(_spans)
        ..sort((a, b) => b.ms.compareTo(a.ms));
      final named = top
          .take(summarySpans)
          .map((s) => '${s.what} ${s.ms} ms')
          .join(', ');
      _log.event(
        'Startup summary: total ${_clock.elapsedMilliseconds} ms, '
        'top $summarySpans spans: ${named.isEmpty ? 'none' : named}',
      );
    } on Object catch (e) {
      _report('summary', e);
    }
  }

  /// Logs every frame that takes more than [slowFrame] to build and
  /// rasterise, from now until [window] has passed (the first 20 seconds
  /// after launch, or an update: call again to extend it; [label] says
  /// which). One log line per frame, with its timestamp.
  void watchFrames(
    String label, {
    Duration window = const Duration(seconds: 20),
  }) {
    try {
      final until = _clock.elapsed + window;
      if (until > _watchUntil) {
        _watchUntil = until;
        _watchLabel = label;
      }
      if (_probing) return;
      _probing = true;
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    } on Object catch (e) {
      _report('frame probe', e);
    }
  }

  void _onTimings(List<FrameTiming> timings) {
    try {
      if (_clock.elapsed > _watchUntil) return;
      for (final t in timings) {
        final build = t.buildDuration.inMilliseconds;
        final raster = t.rasterDuration.inMilliseconds;
        if (build + raster > slowFrame.inMilliseconds) {
          _log.event(
            'Startup: slow frame during $_watchLabel: build $build ms, '
            'raster $raster ms at ${_clock.elapsedMilliseconds} ms',
          );
        }
      }
    } on Object catch (e) {
      _report('frame timings', e);
    }
  }

  void _report(String what, Object error) {
    try {
      _log.warning(describeError('Startup marks: $what failed', error, null));
    } on Object {
      // Nothing more can be done: instrumentation never throws.
    }
  }
}
