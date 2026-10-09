import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/fsrs_tuner.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/fsrs_fit.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/scheduling/skill_fit.dart';

import '../support/fit_learner.dart';

/// A runner that fits in place and remembers each job it was given.
class Recording {
  final List<SkillFitJob> jobs = <SkillFitJob>[];

  Future<SkillFitResult> call(SkillFitJob job) async {
    jobs.add(job);
    return SkillFit.run(job);
  }
}

/// [reviews] recorded into a fresh [MemoryProgress], in order.
MemoryProgress progressOf(Iterable<LoggedReview> reviews) {
  final p = MemoryProgress();
  for (final r in reviews) {
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

void main() {
  const write = DrillMode.production;
  const hiWrite = (language: 'hi', mode: write);
  final start = DateTime(2026, 1, 1, 9);
  final now = DateTime(2026, 10, 9, 18);

  /// A learner of [language] with enough Write answers to fit.
  List<LoggedReview> learner(String language, {int seed = 1}) =>
      simulate(language: language, start: start, until: now, seed: seed);

  /// Records one more Write review of [card] at [at] and tells [tuner].
  ReviewEvent answer(
    MemoryProgress p,
    FsrsTuner tuner,
    String card, {
    DateTime? at,
  }) {
    final event = p.record(
      deckId: 'deck',
      cardId: card,
      mode: write,
      grade: 4,
      now: at ?? now,
      answerGiven: 'typed',
    );
    tuner.afterReview(event);
    return event;
  }

  group('Adjust to me', () {
    test('fits every skill that can be, and says so of the rest', () async {
      final p = progressOf(
        inTimeOrder([
          ...learner('hi'),
          ...simulate(
            language: 'hi',
            start: start,
            until: now,
            cards: 4,
            mode: DrillMode.listening,
          ),
        ]),
      );
      final runner = Recording();
      final tuner = FsrsTuner(
        progress: p,
        clock: () => now,
        runner: runner.call,
      );
      expect(tuner.canAdjust, isTrue);
      final results = (await tuner.adjustAll())!;
      expect(
        results.map((r) => r.key),
        unorderedEquals(<Object>[
          hiWrite,
          (language: 'hi', mode: DrillMode.listening),
        ]),
      );
      expect(runner.jobs.map((j) => j.key), [hiWrite], reason: 'one fittable');
      final fitted = results.firstWhere((r) => r.key == hiWrite).fitted!;
      expect(p.parameters.fitted[hiWrite], fitted);
      expect(
        results.firstWhere((r) => r.key != hiWrite).fitted,
        isNull,
        reason: 'not adjusted yet',
      );
      expect(tuner.lastAdjusted, now);
      expect(tuner.busy, isFalse);
    });

    test('the words of the skill are rescheduled with the new set', () async {
      final p = progressOf(learner('hi'));
      final before = p.stateOf('hi-0001', write)!;
      final tuner = FsrsTuner(
        progress: p,
        clock: () => now,
        runner: fitInPlace,
      );
      await tuner.adjustAll();
      final values = p.parameters.of('hi', write);
      expect(values, isNot(Fsrs.w));
      final after = p.stateOf('hi-0001', write)!;
      expect(after.stability, isNot(before.stability));
      final replayed = Fsrs.replay(<FitReview>[
        for (final e in p.log)
          if (e.key == (cardId: 'hi-0001', mode: write))
            (grade: e.grade, at: e.at, rated: e.answerGiven == null),
      ], parameters: values);
      expect(after.stability, replayed!.stability);
    });

    test('with too little anywhere, it waits', () async {
      final p = progressOf(
        simulate(language: 'hi', start: start, until: now, cards: 5),
      );
      final runner = Recording();
      final tuner = FsrsTuner(
        progress: p,
        clock: () => now,
        runner: runner.call,
      );
      expect(tuner.canAdjust, isFalse);
      final results = (await tuner.adjustAll())!;
      expect(results.single.fitted, isNull);
      expect(runner.jobs, isEmpty);
      expect(p.parameters.fitted, isEmpty);
    });

    test('a refit starts from the skill\'s last fit', () async {
      final p = progressOf(learner('hi'));
      final runner = Recording();
      final tuner = FsrsTuner(
        progress: p,
        clock: () => now,
        runner: runner.call,
      );
      await tuner.adjustAll();
      final first = p.parameters.fitted[hiWrite]!.values;
      await tuner.adjustAll();
      expect(runner.jobs.last.inUse, first);
    });

    test('a new language starts from the one studied most recently', () async {
      final hi = learner('hi');
      final p = progressOf(hi);
      final runner = Recording();
      final tuner = FsrsTuner(
        progress: p,
        clock: () => now,
        runner: runner.call,
      );
      await tuner.adjustAll();
      final hiFit = p.parameters.fitted[hiWrite]!.values;
      // Bengali, begun later than Hindi was last studied.
      for (final r in simulate(
        language: 'bn',
        start: now.add(const Duration(days: 1)),
        until: now.add(const Duration(days: 200)),
        seed: 2,
      )) {
        p.record(
          deckId: r.deckId,
          cardId: r.key.cardId,
          mode: write,
          grade: r.grade,
          now: r.at,
          answerGiven: 'typed',
        );
      }
      expect(p.parameters.of('bn', write), hiFit);
      final later = FsrsTuner(
        progress: p,
        clock: () => now.add(const Duration(days: 200)),
        runner: runner.call,
      );
      runner.jobs.clear();
      await later.adjustAll();
      final bnJob = runner.jobs.firstWhere((j) => j.key.language == 'bn');
      expect(bnJob.inUse, hiFit);
      expect(p.parameters.fitted[(language: 'bn', mode: write)], isNotNull);
    });
  });

  group('adjusting automatically', () {
    test(
      'refits a skill once it has 10% more answers than at its fit',
      () async {
        final p = progressOf(learner('hi'));
        final runner = Recording();
        final tuner = FsrsTuner(
          progress: p,
          clock: () => now,
          runner: runner.call,
        );
        await tuner.adjustAll();
        final fittedAt = p.parameters.fitted[hiWrite]!.reviewCount;
        runner.jobs.clear();
        final needed = (fittedAt * FsrsTuner.growth).ceil() - fittedAt;
        for (var i = 0; i < needed - 1; i++) {
          answer(p, tuner, 'hi-0001');
        }
        await pumpEventQueue();
        expect(runner.jobs, isEmpty, reason: 'one answer short of 10%');
        answer(p, tuner, 'hi-0001');
        await pumpEventQueue();
        expect(runner.jobs, hasLength(1));
        expect(runner.jobs.single.key, hiWrite);
        expect(runner.jobs.single.reviewCount, fittedAt + needed);
        expect(p.parameters.fitted[hiWrite]!.reviewCount, fittedAt + needed);
      },
    );

    test('fits a skill for the first time once it can be fitted', () async {
      final reviews = learner('hi');
      final p = MemoryProgress();
      final runner = Recording();
      final tuner = FsrsTuner(
        progress: p,
        clock: () => now,
        runner: runner.call,
      );
      var firstFitAt = -1;
      for (final r in reviews) {
        final event = p.record(
          deckId: r.deckId,
          cardId: r.key.cardId,
          mode: r.key.mode,
          grade: r.grade,
          now: r.at,
          answerGiven: r.answerGiven,
        );
        tuner.afterReview(event);
        await pumpEventQueue();
        if (firstFitAt < 0 && runner.jobs.isNotEmpty) firstFitAt = p.log.length;
      }
      // The first moment a fit was possible, and the fit came no later
      // than 10% of answers after it: the gate is not asked after every
      // answer.
      var possible = 0;
      while (!SkillFit.canFit(
        SkillFit.histories(reviews.take(possible))[hiWrite] ??
            SkillHistory(hiWrite, const []),
        now,
      )) {
        possible++;
      }
      expect(firstFitAt, greaterThanOrEqualTo(possible));
      expect(firstFitAt, lessThanOrEqualTo(possible * FsrsTuner.growth + 1));
      expect(p.parameters.fitted[hiWrite], isNotNull);
    });

    test('only one fit runs at a time', () async {
      final p = progressOf(learner('hi'));
      final gate = Completer<void>();
      var started = 0;
      Future<SkillFitResult> slow(SkillFitJob job) async {
        started++;
        await gate.future;
        return SkillFit.run(job);
      }

      final tuner = FsrsTuner(progress: p, clock: () => now, runner: slow);
      answer(p, tuner, 'hi-0001');
      await pumpEventQueue();
      expect(tuner.busy, isTrue);
      expect(tuner.current, hiWrite);
      answer(p, tuner, 'hi-0002');
      expect(await tuner.adjustAll(), isNull, reason: 'the button waits');
      await pumpEventQueue();
      expect(started, 1);
      gate.complete();
      await pumpEventQueue();
      expect(tuner.busy, isFalse);
      expect(p.parameters.fitted[hiWrite], isNotNull);
    });

    test('never when the app opens, and only with the switch on', () async {
      final runner = Recording();
      final state = AppState.test(
        progress: progressOf(learner('hi')),
        now: now,
        fitRunner: runner.call,
      );
      addTearDown(state.dispose);
      await state.load();
      await pumpEventQueue();
      expect(runner.jobs, isEmpty, reason: 'nothing at open');
      expect(state.settings.autoAdjust, isTrue, reason: 'on by default');

      const card = Card(
        id: 'hi-0001',
        deckId: 'deck',
        target: 'x',
        native: 'y',
      );
      const item = SessionItem(card: card, mode: write, state: null);
      state.settings.autoAdjust = false;
      state.record(item, 4, answerGiven: 'x');
      await pumpEventQueue();
      expect(runner.jobs, isEmpty, reason: 'switched off');

      state.settings.autoAdjust = true;
      state.record(item, 4, answerGiven: 'x');
      await pumpEventQueue();
      expect(runner.jobs.single.key, hiWrite);
    });
  });
}
