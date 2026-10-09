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

  test('whether anything is fitted or adjusted is read from the stored '
      'fits, without working anything out', () async {
    final runner = counting();
    final progress = learner();
    final pacing = Pacing(
      progress: progress,
      clock: () => now,
      runner: runner.run,
    );
    expect(pacing.fitted, isFalse);
    expect(pacing.adjusted, isFalse);

    // A first fit that lost keeps FSRS-6's defaults: fitted, not adjusted.
    await progress.putFitted(write, fit(Fsrs.w));
    expect(pacing.fitted, isTrue);
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

  test('a run overtaken by a newer one is dropped', () async {
    final gates = <Completer<void>>[];
    final progress = learner();
    final pacing = Pacing(
      progress: progress,
      clock: () => now,
      runner: (job) async {
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        return paceInPlace(job);
      },
    );
    pacing.paces;
    progress.record(
      deckId: 'deck',
      cardId: 'hi-0001',
      mode: DrillMode.production,
      grade: 3,
      now: now,
    );
    pacing.paces;
    expect(gates, hasLength(2));
    gates.first.complete();
    await pumpEventQueue();
    expect(pacing.paces, isNull, reason: 'the first run is out of date');
    gates.last.complete();
    await pumpEventQueue();
    expect(pacing.paces![write]!.answers, progress.log.length);
  });
}
