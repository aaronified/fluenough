import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/leech_action.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/fsrs_fit.dart';
import 'package:fluenough/core/scheduling/skill_fit.dart';
import 'package:fluenough/core/scheduling/skill_parameters.dart';

import 'support/fit_learner.dart';

void main() {
  const write = DrillMode.production;
  const hear = DrillMode.listening;
  final start = DateTime(2026, 1, 1, 9);
  final now = DateTime(2026, 10, 9, 18);

  group('histories', () {
    test('one per skill and language, each pair oldest first', () {
      final h = SkillFit.histories([
        review('hi-0001', write, start, 4),
        review('bn-0001', write, start, 4),
        review('hi-0001', hear, start, 4),
        review('hi-0001', write, start.add(const Duration(days: 2)), 3),
        review('hi-0002', write, start.add(const Duration(days: 2)), 1),
      ]);
      expect(
        h.keys,
        unorderedEquals(<Object>[
          (language: 'hi', mode: write),
          (language: 'bn', mode: write),
          (language: 'hi', mode: hear),
        ]),
      );
      final hi = h[(language: 'hi', mode: write)]!;
      expect(hi.reviewCount, 3);
      expect(hi.pairs.map((p) => p.map((r) => r.grade)), [
        [4, 3],
        [1],
      ]);
      expect(hi.pairs.first.first.rated, isFalse, reason: 'an answer given');
    });

    test('a reset pair starts at its reset, but every review counts', () {
      const pair = (cardId: 'hi-0001', mode: write);
      final h = SkillFit.histories(
        [
          review('hi-0001', write, start, 1),
          review('hi-0001', write, start.add(const Duration(days: 1)), 1),
          review('hi-0001', write, start.add(const Duration(days: 3)), 4),
        ],
        effects: LeechEffects([
          LeechAction(
            at: start.add(const Duration(days: 2)),
            key: pair,
            kind: LeechActionKind.reset,
          ),
        ]),
      );
      final hi = h[(language: 'hi', mode: write)]!;
      expect(hi.reviewCount, 3);
      expect(hi.pairs.single.map((r) => r.grade), [4]);
    });
  });

  group('the window: the last three months or the last 1,000 reviews, '
      'whichever is more', () {
    List<FitReview> at(Iterable<DateTime> times) => <FitReview>[
      for (final t in times) (grade: 4, at: t, rated: false),
    ];

    test('1,000 reviews or fewer: all of them', () {
      expect(
        SkillFit.windowStart(
          at([for (var i = 0; i < 1000; i++) start.add(Duration(hours: i))]),
          now,
        ),
        isNull,
      );
    });

    test('more than 1,000 in the last three months: the three months', () {
      final reviews = at([
        for (var i = 0; i < 1500; i++) now.subtract(Duration(hours: i)),
        for (var i = 0; i < 200; i++) start.add(Duration(hours: i)),
      ]);
      expect(SkillFit.windowStart(reviews, now), DateTime(2026, 7, 9, 18));
    });

    test('fewer in the three months: back to the 1,000th most recent', () {
      final times = [
        for (var i = 0; i < 1500; i++) start.add(Duration(hours: 3 * i)),
      ];
      final from = SkillFit.windowStart(at(times.reversed), now)!;
      expect(from, times[500]);
      expect(times.where((t) => !t.isBefore(from)), hasLength(1000));
    });
  });

  group('keep a new set only if it predicts the window better', () {
    final fitted = <double>[...Fsrs.w]..[2] = 9;
    FittedParameters keep(double? before, double? after) => SkillFit.keepBetter(
      fitted: fitted,
      inUse: Fsrs.w,
      lossBefore: before,
      lossAfter: after,
      at: now,
      reviewCount: 321,
    );

    test('lower: the new set', () {
      final kept = keep(0.40, 0.35);
      expect(kept.values, fitted);
      expect(kept.kept, isTrue);
      expect(kept.reviewCount, 321);
      expect(kept.fittedAt, now);
    });

    test('higher or the same: the set in use, the losses noted', () {
      for (final kept in [keep(0.35, 0.40), keep(0.35, 0.35)]) {
        expect(kept.values, Fsrs.w);
        expect(kept.kept, isFalse);
        expect(kept.lossBefore, 0.35);
        expect(kept.reviewCount, 321, reason: 'the next refit waits again');
      }
    });

    test('nothing to compare with: the new set only if it has a loss', () {
      expect(keep(null, 0.3).values, fitted);
      expect(keep(0.3, null).values, Fsrs.w);
    });
  });

  group('a fit of one skill', () {
    final reviews = simulate(language: 'hi', start: start, until: now);
    final history = SkillFit.histories(reviews)[(language: 'hi', mode: write)]!;

    test('learns a learner who remembers well: longer intervals, fewer '
        'reviews, and a lower loss', () {
      expect(SkillFit.canFit(history, now), isTrue);
      final result = SkillFit.run(SkillFit.job(history, Fsrs.w, now));
      final fitted = result.fitted!;
      expect(fitted.kept, isTrue);
      expect(fitted.lossAfter, lessThan(fitted.lossBefore!));
      expect(fitted.reviewCount, history.reviewCount);
      expect(fitted.fittedAt, now);
      expect(result.after.days, greaterThan(result.before.days));
      expect(SkillFit.direction(result.before, result.after), -1);
    });

    /// What a fit of [h] from [inUse] should keep: [FsrsFit] from
    /// [inUse] on the window, if it predicts the window better.
    List<double> expected(SkillHistory h, List<double> inUse) {
      final from = SkillFit.windowStart(h.reviews, now);
      final fitted = FsrsFit.fit(h.pairs, start: inUse, from: from)!;
      return SkillFit.keepBetter(
        fitted: fitted,
        inUse: inUse,
        lossBefore: FsrsFit.logLoss(h.pairs, parameters: inUse, from: from),
        lossAfter: FsrsFit.logLoss(h.pairs, parameters: fitted, from: from),
        at: now,
        reviewCount: h.reviewCount,
      ).values;
    }

    test('starts from the set in use', () {
      final inUse = <double>[...Fsrs.w]..[8] = 2.2;
      final warm = SkillFit.run(SkillFit.job(history, inUse, now));
      expect(warm.fitted!.values, expected(history, inUse));
      expect(
        warm.fitted!.values,
        isNot(SkillFit.run(SkillFit.job(history, Fsrs.w, now)).fitted!.values),
      );
    });

    test('a long history learns only from its window', () {
      final long = simulate(
        language: 'bn',
        start: DateTime(2024, 1, 1),
        until: now,
        cards: 150,
        spread: 400,
      );
      final h = SkillFit.histories(long)[(language: 'bn', mode: write)]!;
      final from = SkillFit.windowStart(h.reviews, now);
      expect(h.reviewCount, greaterThan(SkillFit.windowReviews));
      expect(from, isNotNull);
      expect(
        SkillFit.run(SkillFit.job(h, Fsrs.w, now)).fitted!.values,
        expected(h, Fsrs.w),
      );
      expect(
        FsrsFit.gate(h.pairs, from: from).items,
        lessThan(FsrsFit.gate(h.pairs).items),
      );
    });

    test('a learner who stopped adding words long ago is still fitted, '
        'keeping the first stabilities of the set in use', () {
      // Every word first seen in the first 20 days of 2024: its first
      // long-term review is long before the window.
      final settled = simulate(
        language: 'mr',
        start: DateTime(2024, 1, 1),
        until: now,
        cards: 300,
        recall: 0.9,
      );
      final h = SkillFit.histories(settled)[(language: 'mr', mode: write)]!;
      final from = SkillFit.windowStart(h.reviews, now);
      expect(from, isNotNull);
      final gate = FsrsFit.gate(h.pairs, from: from);
      expect(gate.firstLongTermItems, 0);
      expect(gate.outcome, FsrsFitOutcome.trained);
      expect(SkillFit.canFit(h, now), isTrue);
      final inUse = <double>[...Fsrs.w]..[8] = 2.2;
      final fitted = SkillFit.run(SkillFit.job(h, inUse, now)).fitted!;
      expect(fitted.values.sublist(0, 4), inUse.sublist(0, 4));
      expect(fitted.values, expected(h, inUse));
    });

    test('too little to fit gives nothing to keep', () {
      final few = SkillFit.histories(
        simulate(language: 'te', start: start, until: now, cards: 5),
      )[(language: 'te', mode: write)]!;
      expect(SkillFit.canFit(few, now), isFalse);
      final result = SkillFit.run(SkillFit.job(few, Fsrs.w, now));
      expect(result.fitted, isNull);
      expect(result.after, result.before);
    });

    test('deterministic', () {
      expect(
        SkillFit.run(SkillFit.job(history, Fsrs.w, now)).fitted,
        SkillFit.run(SkillFit.job(history, Fsrs.w, now)).fitted,
      );
    });
  });

  group('the outlook', () {
    test('no words yet: a new word\'s first right answer, and no reviews', () {
      expect(SkillFit.outlook(const [], Fsrs.w, now), (
        days: Fsrs.intervalFor(Fsrs.w[2]),
        reviews: 0,
      ));
    });

    test('one word, answered right each time it comes due', () {
      final pair = <FitReview>[(grade: 4, at: now, rated: false)];
      var state = Fsrs.next(null, 4, now: now);
      final end = now.add(const Duration(days: 30));
      var reviews = 0;
      while (state.dueAt.isBefore(end)) {
        reviews++;
        state = Fsrs.review(state, Rating.good, now: state.dueAt);
      }
      final outlook = SkillFit.outlook([pair], Fsrs.w, now);
      expect(outlook.reviews, reviews);
      expect(
        outlook.days,
        Fsrs.review(
          Fsrs.next(null, 4, now: now),
          Rating.good,
          now: now,
        ).intervalDays,
      );
    });

    test('which way: fewer, more, or about the same', () {
      expect(
        SkillFit.direction((days: 4, reviews: 160), (days: 6, reviews: 120)),
        -1,
      );
      expect(
        SkillFit.direction((days: 4, reviews: 150), (days: 3, reviews: 175)),
        1,
      );
      expect(
        SkillFit.direction((days: 4, reviews: 305), (days: 4, reviews: 300)),
        0,
      );
      expect(
        SkillFit.direction((days: 4, reviews: 0), (days: 6, reviews: 0)),
        -1,
      );
    });
  });
}
