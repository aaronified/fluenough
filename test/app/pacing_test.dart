import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/pacing.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/skill_fit.dart';

import '../support/fit_learner.dart';

void main() {
  final now = DateTime(2026, 10, 9, 18);
  final start = now.subtract(const Duration(days: 40));
  const write = (language: 'hi', mode: DrillMode.production);

  MemoryProgress learner() {
    final p = MemoryProgress();
    for (final r in simulate(
      language: 'hi',
      start: start,
      until: now,
      cards: 10,
    )) {
      p.record(
        deckId: r.deckId,
        cardId: r.key.cardId,
        mode: r.key.mode,
        grade: r.grade,
        now: r.at,
        answerGiven: r.answerGiven,
      );
    }
    return p;
  }

  FittedParameters fit(List<double> values) =>
      FittedParameters(values: values, fittedAt: now, reviewCount: 50);

  /// A runner that counts its jobs and works each out in place.
  ({PaceRunner run, List<PaceJob> jobs}) counting() {
    final jobs = <PaceJob>[];
    return (
      run: (job) async {
        jobs.add(job);
        return paceInPlace(job);
      },
      jobs: jobs,
    );
  }

  test('whether anything is adjusted is read from the stored fits, '
      'without working anything out', () async {
    final runner = counting();
    final progress = learner();
    final pacing = Pacing(
      progress: progress,
      clock: () => now,
      runner: runner.run,
    );
    expect(pacing.adjusted, isFalse);

    // A first fit that lost keeps FSRS-6's defaults: stored, not adjusted.
    await progress.putFitted(write, fit(Fsrs.w));
    expect(progress.parameters.fitted, isNotEmpty);
    expect(pacing.adjusted, isFalse);

    await progress.putFitted(write, fit(<double>[...Fsrs.w]..[8] += 0.5));
    expect(pacing.adjusted, isTrue);
    expect(runner.jobs, isEmpty);
  });

  test('worked out when asked, once, and again when the log grows', () async {
    final runner = counting();
    final progress = learner();
    await progress.putFitted(write, fit(<double>[...Fsrs.w]..[8] -= 0.5));
    final pacing = Pacing(
      progress: progress,
      clock: () => now,
      runner: runner.run,
    );
    var told = 0;
    pacing.addListener(() => told++);

    expect(pacing.paces, isNull);
    await pumpEventQueue();
    expect(told, 1);
    final paces = pacing.paces!;
    expect(runner.jobs, hasLength(1));
    // SkillFit's own figures, from the same log and parameters.
    expect(
      paces[write],
      SkillFit.paces(
        inTimeOrder(progress.log.map(logged)),
        parameters: progress.parameters,
        now: now,
      ).single,
    );
    expect(paces[write]!.adjusted, isTrue);

    // Asked again with nothing changed: the same, not worked out again.
    expect(pacing.paces, same(paces));
    await pumpEventQueue();
    expect(runner.jobs, hasLength(1));

    progress.record(
      deckId: 'deck',
      cardId: 'hi-0001',
      mode: DrillMode.production,
      grade: 3,
      now: now,
    );
    // The last figures stand while the new ones are worked out.
    expect(pacing.paces, same(paces));
    await pumpEventQueue();
    expect(runner.jobs, hasLength(2));
    expect(pacing.paces![write]!.answers, paces[write]!.answers + 1);
  });

  test('on an isolate, as in place', () async {
    final progress = learner();
    await progress.putFitted(write, fit(<double>[...Fsrs.w]..[8] += 0.5));
    final PaceJob job = (
      log: progress.log,
      leechActions: progress.leechActions,
      parameters: progress.parameters,
      now: now,
    );
    expect(await paceInIsolate(job), await paceInPlace(job));
  });

  test('a run that fails is reported, gives nothing, and is not retried '
      'until something changes', () async {
    var runs = 0;
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    final pacing = Pacing(
      progress: learner(),
      clock: () => now,
      runner: (job) async {
        runs++;
        throw StateError('no isolate');
      },
    );
    expect(pacing.paces, isNull);
    await pumpEventQueue();
    expect(pacing.paces, isEmpty);
    await pumpEventQueue();
    expect(runs, 1);
    expect(reported, hasLength(1));
  });

  test('one job at a time: asked again while one runs, only the latest '
      'is worked out, once it ends', () async {
    final gates = <Completer<void>>[];
    final jobs = <PaceJob>[];
    final progress = learner();
    final pacing = Pacing(
      progress: progress,
      clock: () => now,
      runner: (job) async {
        jobs.add(job);
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        return paceInPlace(job);
      },
    );
    final first = progress.log.length;
    expect(pacing.paces, isNull);
    // Three answers while it runs, each asking again, as Today would.
    for (var i = 0; i < 3; i++) {
      progress.record(
        deckId: 'deck',
        cardId: 'hi-0001',
        mode: DrillMode.production,
        grade: 3,
        now: now,
      );
      expect(pacing.paces, isNull);
    }
    expect(jobs, hasLength(1), reason: 'none started beside the running one');

    gates.first.complete();
    await pumpEventQueue();
    // Its figures stand, a moment out of date, while the latest are
    // worked out: one job for the three answers, from the log as it is.
    expect(pacing.latest![write]!.answers, first);
    expect(jobs, hasLength(2));
    expect(jobs.last.log.length, progress.log.length);

    gates.last.complete();
    await pumpEventQueue();
    expect(pacing.paces![write]!.answers, progress.log.length);
    await pumpEventQueue();
    expect(jobs, hasLength(2));
  });

  test('the latest figures are read without starting anything', () async {
    final runner = counting();
    final progress = learner();
    final pacing = Pacing(
      progress: progress,
      clock: () => now,
      runner: runner.run,
    );
    expect(pacing.latest, isNull);
    await pumpEventQueue();
    expect(runner.jobs, isEmpty);
    pacing.paces;
    await pumpEventQueue();
    progress.record(
      deckId: 'deck',
      cardId: 'hi-0001',
      mode: DrillMode.production,
      grade: 3,
      now: now,
    );
    expect(pacing.latest, isNotNull);
    await pumpEventQueue();
    expect(runner.jobs, hasLength(1));
  });
}
