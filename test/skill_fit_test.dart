import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/models/leech_action.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/fsrs_fit.dart';
import 'package:fluenough/core/scheduling/replay.dart';
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

    test('both losses kept are on the window', () {
      final long = simulate(
        language: 'bn',
        start: DateTime(2024, 1, 1),
        until: now,
        cards: 150,
        spread: 400,
      );
      final h = SkillFit.histories(long)[(language: 'bn', mode: write)]!;
      final from = SkillFit.windowStart(h.reviews, now)!;
      final fitted = FsrsFit.fit(h.pairs, from: from)!;
      final kept = SkillFit.run(SkillFit.job(h, Fsrs.w, now)).fitted!;
      expect(kept.lossBefore, FsrsFit.logLoss(h.pairs, from: from));
      expect(
        kept.lossAfter,
        FsrsFit.logLoss(h.pairs, parameters: fitted, from: from),
      );
      expect(
        kept.lossAfter,
        isNot(FsrsFit.logLoss(h.pairs, parameters: fitted)),
      );
    });

    test('the 1,000th most recent review, where the window starts, is '
        'predicted', () {
      final long = simulate(
        language: 'bn',
        start: DateTime(2024, 1, 1),
        until: now,
        cards: 150,
        spread: 400,
      );
      final h = SkillFit.histories(long)[(language: 'bn', mode: write)]!;
      final from = SkillFit.windowStart(h.reviews, now)!;
      final times = <DateTime>[for (final r in h.reviews) r.at]..sort();
      expect(from, times[times.length - SkillFit.windowReviews]);
      // That review is one a day or more after the one before.
      final pair = h.pairs.firstWhere((p) => p.any((r) => r.at == from));
      final i = pair.indexWhere((r) => r.at == from);
      expect(i, greaterThan(0));
      expect(Fsrs.elapsedDays(pair[i - 1].at, from), greaterThanOrEqualTo(1));
      const tick = Duration(microseconds: 1);
      expect(
        FsrsFit.gate(h.pairs, from: from).items,
        FsrsFit.gate(h.pairs, from: from.add(tick)).items + 1,
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

    test('enough to fit only the first stabilities is enough to refit', () {
      // 30 words, each answered right once two days after it was first
      // seen: every item a first long-term review.
      final reviews = inTimeOrder([
        for (var c = 0; c < 30; c++) ...[
          review('ta-${c + 1}', write, start.add(Duration(minutes: c)), 4),
          review('ta-${c + 1}', write, start.add(const Duration(days: 2)), 4),
        ],
      ]);
      final h = SkillFit.histories(reviews)[(language: 'ta', mode: write)]!;
      expect(FsrsFit.gate(h.pairs).outcome, FsrsFitOutcome.pretrainOnly);
      expect(SkillFit.canFit(h, now), isTrue);
      expect(SkillFit.run(SkillFit.job(h, Fsrs.w, now)).fitted, isNotNull);
    });

    test('too little to fit gives nothing to keep', () {
      final few = SkillFit.histories(
        simulate(language: 'te', start: start, until: now, cards: 5),
      )[(language: 'te', mode: write)]!;
      expect(SkillFit.canFit(few, now), isFalse);
      final result = SkillFit.run(SkillFit.job(few, Fsrs.w, now));
      expect(result.fitted, isNull);
      expect(result.after, result.before);
      // Whatever set is in use: it is what the outlook is of.
      final inUse = <double>[...Fsrs.w]..[8] = 2.2;
      final adjusted = SkillFit.run(SkillFit.job(few, inUse, now));
      expect(adjusted.fitted, isNull);
      expect(adjusted.before, SkillFit.outlook(few.pairs, inUse, now));
      expect(adjusted.after, adjusted.before);
      expect(adjusted.before, isNot(SkillFit.outlook(few.pairs, Fsrs.w, now)));
    });

    test('before is the outlook of the set in use, after that of the set '
        'kept', () {
      final inUse = <double>[...Fsrs.w]..[8] = 2.2;
      final result = SkillFit.run(SkillFit.job(history, inUse, now));
      expect(result.fitted!.kept, isTrue);
      expect(result.before, SkillFit.outlook(history.pairs, inUse, now));
      expect(
        result.before,
        isNot(SkillFit.outlook(history.pairs, Fsrs.w, now)),
        reason: 'not the defaults',
      );
      expect(
        result.after,
        SkillFit.outlook(history.pairs, result.fitted!.values, now),
      );
    });

    test('a fit that does not predict better leaves the outlook as it '
        'was', () {
      // A learner who forgets often, refitted from each fit in turn until
      // a fit is no better than the set in use.
      final forgetful = SkillFit.histories(
        simulate(language: 'hi', start: start, until: now, recall: 0.8),
      )[(language: 'hi', mode: write)]!;
      var inUse = Fsrs.w;
      SkillFitResult? result;
      for (var i = 0; i < 10 && result?.fitted?.kept != false; i++) {
        if (result != null) inUse = result.fitted!.values;
        result = SkillFit.run(SkillFit.job(forgetful, inUse, now));
      }
      final fitted = result!.fitted!;
      expect(fitted.kept, isFalse);
      expect(fitted.values, inUse);
      expect(fitted.lossAfter, greaterThanOrEqualTo(fitted.lossBefore!));
      expect(result.before, SkillFit.outlook(forgetful.pairs, inUse, now));
      expect(result.after, result.before);
    });

    test('a long history with nothing to learn from in its window is not '
        'fitted, though all of it could be', () {
      // 30 words seen once, two days later, in 2024: items only before
      // the window. Then 1,200 answers to 48 new words, all on the one
      // day, so none is an item and the window, the last 1,000 reviews
      // or 6 months, takes in no old one.
      final day = DateTime(2026, 10, 1, 9);
      final reviews = inTimeOrder([
        for (var c = 0; c < 30; c++) ...[
          review('ta-${c + 1}', write, DateTime(2024, 1, 1, 9, c), 4),
          review('ta-${c + 1}', write, DateTime(2024, 1, 3, 9, c), 4),
        ],
        for (var c = 0; c < 48; c++)
          for (var i = 0; i < 25; i++)
            review(
              'ta-${100 + c}',
              write,
              day.add(Duration(minutes: i * 48 + c)),
              4,
            ),
      ]);
      final h = SkillFit.histories(reviews)[(language: 'ta', mode: write)]!;
      final from = SkillFit.windowStart(h.reviews, now);
      expect(from, isNotNull);
      expect(FsrsFit.gate(h.pairs).outcome, isNot(FsrsFitOutcome.defaults));
      expect(
        FsrsFit.gate(h.pairs, from: from).outcome,
        FsrsFitOutcome.defaults,
      );
      expect(SkillFit.canFit(h, now), isFalse);
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

  group('the pace: the set in use beside FSRS-6\'s defaults', () {
    // Words that come back later or sooner than on the defaults: w8 sets
    // how much a right answer lengthens the gap.
    List<double> slower(double by) => <double>[
      for (final (i, w) in Fsrs.w.indexed) i == 8 ? w + by : w,
    ];
    // Words still young, so that the next 30 days hold reviews.
    final recent = now.subtract(const Duration(days: 40));
    final reviews = inTimeOrder([
      ...simulate(language: 'hi', start: recent, until: now, cards: 20),
      ...simulate(
        language: 'hi',
        start: recent,
        until: now,
        cards: 10,
        mode: hear,
      ),
      ...simulate(language: 'bn', start: recent, until: now, cards: 10),
    ]);
    FittedParameters fit(List<double> values) =>
        FittedParameters(values: values, fittedAt: now, reviewCount: 100);

    test('nothing fitted: every skill as at the start', () {
      final paces = SkillFit.paces(
        reviews,
        parameters: SkillParameters.none,
        now: now,
      );
      expect(paces, hasLength(3));
      for (final p in paces) {
        expect(p.adjusted, isFalse);
        expect(p.now, p.start);
        expect(
          p.start,
          SkillFit.outlook(
            SkillFit.histories(reviews)[p.key]!.pairs,
            Fsrs.w,
            now,
          ),
        );
      }
      final hi = paces.firstWhere(
        (p) => p.key == (language: 'hi', mode: write),
      );
      expect(hi.answers, SkillFit.histories(reviews)[hi.key]!.reviewCount);
    });

    test('a set that keeps words longer: fewer reviews, later', () {
      final parameters = SkillParameters(
        fitted: {(language: 'hi', mode: write): fit(slower(0.6))},
      );
      final paces = SkillFit.paces(reviews, parameters: parameters, now: now);
      final hi = paces.firstWhere(
        (p) => p.key == (language: 'hi', mode: write),
      );
      expect(hi.adjusted, isTrue);
      expect(hi.now.days, greaterThan(hi.start.days));
      expect(hi.now.reviews, lessThan(hi.start.reviews));
      expect(SkillFit.direction(hi.start, hi.now), -1);
      // Hear has no fit of its own and no baseline: as at the start.
      final heard = paces.firstWhere(
        (p) => p.key == (language: 'hi', mode: hear),
      );
      expect(heard.adjusted, isFalse);
    });

    test('a set that keeps words shorter: more reviews, sooner', () {
      final parameters = SkillParameters(
        fitted: {(language: 'hi', mode: write): fit(slower(-0.6))},
      );
      final hi = SkillFit.paces(
        reviews,
        parameters: parameters,
        now: now,
      ).firstWhere((p) => p.key == (language: 'hi', mode: write));
      expect(hi.now.days, lessThan(hi.start.days));
      expect(hi.now.reviews, greaterThan(hi.start.reviews));
      expect(SkillFit.direction(hi.start, hi.now), 1);
    });

    test('another language\'s fit, as the baseline, adjusts it too', () {
      final parameters = SkillParameters(
        fitted: {(language: 'hi', mode: write): fit(slower(0.6))},
      );
      final bn = SkillFit.paces(
        reviews,
        parameters: parameters,
        now: now,
      ).firstWhere((p) => p.key == (language: 'bn', mode: write));
      expect(bn.adjusted, isTrue);
      expect(bn.now.reviews, lessThan(bn.start.reviews));
    });

    test('a kept copy of the defaults is not adjusted', () {
      final parameters = SkillParameters(
        fitted: {(language: 'hi', mode: write): fit(Fsrs.w)},
      );
      final hi = SkillFit.paces(
        reviews,
        parameters: parameters,
        now: now,
      ).firstWhere((p) => p.key == (language: 'hi', mode: write));
      expect(hi.adjusted, isFalse);
      expect(hi.now, hi.start);
    });

    test('together: reviews added, the days of the most answered', () {
      SkillPace pace(String language, int answers, int days, int reviews) => (
        key: (language: language, mode: write),
        answers: answers,
        adjusted: true,
        start: (days: 4, reviews: reviews + 10),
        now: (days: days, reviews: reviews),
      );
      expect(SkillFit.together(const []), isNull);
      expect(
        SkillFit.together([pace('hi', 300, 6, 100), pace('bn', 50, 2, 40)]),
        (start: (days: 4, reviews: 160), now: (days: 6, reviews: 140)),
      );
    });
  });
}
