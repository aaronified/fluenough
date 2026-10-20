// Scheduling: when a word comes back, and how the app fits that to the
// learner. FSRS against py-fsrs, the fit against fsrs-rs, the window and
// the start of a fit, what one skill's answer implies for another, leech
// actions, the log replaying to the same states, and Adjust to me.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/fsrs_tuner.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/core/data/card_state_repository.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/data/review_log.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/ability.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/fsrs_fit.dart';
import 'package:fluenough/core/scheduling/replay.dart';
import 'package:fluenough/core/scheduling/skill_fit.dart';
import 'package:fluenough/core/scheduling/skill_map.dart';
import 'package:fluenough/features/settings/activities_page.dart';

import 'support/fit_learner.dart' show simulate;
import 'support/harness.dart';
import 'support/settings_pages.dart';

/// One review: its rating, the hours since the one before, and the
/// stability, difficulty and interval in days that `py-fsrs` 6.3.2 gives
/// after it, with no learning steps and fuzzing off.
typedef Step = (int rating, int hours, double s, double d, int days);

/// Generated with `py-fsrs` 6.3.2:
/// `Scheduler(learning_steps=(), relearning_steps=(), enable_fuzzing=False)`.
const List<List<Step>> _pyFsrs = <List<Step>>[
  <Step>[
    (3, 0, 2.3065, 2.118103970459016, 2),
    (3, 24, 7.31530074407728, 2.111214235785395, 7),
    (3, 72, 19.833473465759585, 2.1043313908464483, 20),
    (3, 200, 48.19959255862878, 2.0974554287524403, 48),
    (3, 500, 109.1400821994129, 2.0905863426205262, 109),
  ],
  <Step>[
    (1, 0, 0.212, 6.4133, 1),
    (3, 24, 1.8867876195204154, 6.402115069296838, 2),
    (1, 48, 0.505065042540485, 8.802628058192235, 1),
    (3, 24, 1.5541689995045016, 8.789053799430881, 2),
    (4, 120, 8.161246379564238, 8.369640378590466, 8),
    (2, 400, 15.792853860577507, 8.902919677846832, 16),
  ],
  <Step>[
    (4, 0, 8.2956, 1.0, 8),
    (4, 500, 111.58629207285774, 1.0, 112),
    (1, 2000, 4.174052754309081, 7.0269895692968385, 4),
    (3, 24, 6.367272729551076, 7.0151909490243805, 6),
  ],
  <Step>[
    (3, 0, 2.3065, 2.118103970459016, 2),
    (3, 1, 2.3065, 2.111214235785395, 2),
    (1, 2, 0.7750839828558984, 7.392238132342694, 1),
    (3, 30, 2.6506751734904603, 7.38007426350719, 3),
    (2, 24, 3.876382253483383, 8.24599957687359, 4),
    (3, 10, 3.876382253483383, 8.232981946593554, 4),
  ],
  <Step>[
    (2, 0, 1.2931, 5.112170705601056, 1),
    (2, 30, 3.2494117658571677, 6.7404595108297, 3),
    (2, 80, 6.728346299675288, 7.821393497998797, 7),
    (1, 300, 1.1808515340128602, 9.269135226613255, 1),
    (1, 1, 0.4146889741744458, 9.744998088165074, 1),
    (3, 25, 0.9847047143320571, 9.730481459373747, 1),
    (4, 600, 6.616206228892827, 9.625649291957284, 7),
  ],
  <Step>[
    (3, 0, 2.3065, 2.118103970459016, 2),
    (3, 72, 13.826903694354568, 2.111214235785395, 14),
    (3, 216, 44.818186773368375, 2.1043313908464483, 45),
    (3, 600, 117.94157014125328, 2.0974554287524403, 118),
    (3, 1680, 290.1852328384116, 2.0905863426205262, 290),
    (3, 4800, 700.6513628009862, 2.083724125574744, 701),
    (3, 14400, 1709.9797916391822, 2.0768687707460076, 1710),
  ],
];

/// Every field of [s], so two states compare by value.
(double, double, int, DateTime, int, int) _fields(FsrsState s) => (
  s.stability,
  s.difficulty,
  s.intervalDays,
  s.dueAt,
  s.repetitions,
  s.lapses,
);

Map<ProgressKey, (double, double, int, DateTime, int, int)> _byValue(
  Map<ProgressKey, FsrsState> states,
) => {for (final e in states.entries) e.key: _fields(e.value)};

LoggedReview _review(
  ProgressKey key,
  DateTime at,
  int grade, {
  String deckId = 'hi-en-market',
}) => (
  key: key,
  deckId: deckId,
  at: at,
  grade: grade,
  elapsed: Duration.zero,
  answerGiven: 'typed',
  script: null,
  asked: null,
);

/// [reviews] recorded into a fresh [MemoryProgress], in order.
MemoryProgress _progressOf(Iterable<LoggedReview> reviews) {
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

/// A fit runner that fits in place and remembers each job it was given.
class _Recording {
  final List<SkillFitJob> jobs = <SkillFitJob>[];

  Future<SkillFitResult> call(SkillFitJob job) async {
    jobs.add(job);
    return SkillFit.run(job);
  }
}

void main() {
  group('FSRS', () {
    final start = DateTime.utc(2026, 1, 5, 9);
    final later = start.add(const Duration(days: 10));
    final learnt = Fsrs.replay([
      (grade: 4, at: start, rated: false),
      (grade: 4, at: start.add(const Duration(days: 3)), rated: false),
    ])!;

    test('matches py-fsrs review by review', () {
      for (final (i, steps) in _pyFsrs.indexed) {
        FsrsState? state;
        var at = start;
        for (final (rating, hours, s, d, days) in steps) {
          at = at.add(Duration(hours: hours));
          state = Fsrs.review(state, Rating.values[rating - 1], now: at);
          expect(state.stability, closeTo(s, 1e-9), reason: 'sequence $i');
          expect(state.difficulty, closeTo(d, 1e-9), reason: 'sequence $i');
          expect(state.intervalDays, days, reason: 'sequence $i');
          expect(state.dueAt, at.add(Duration(days: days)));
        }
      }
    });

    test('grades map to ratings: below 3 Again, 3 Hard, 4 and 5 Good, 5 '
        'Easy only when the learner rated it, outside 0-5 refused', () {
      expect(
        [for (var g = 0; g <= 5; g++) Fsrs.ratingOf(g)],
        [
          Rating.again,
          Rating.again,
          Rating.again,
          Rating.hard,
          Rating.good,
          Rating.good,
        ],
      );
      expect(Fsrs.ratingOf(5, rated: true), Rating.easy);
      expect(Fsrs.ratingOf(4, rated: true), Rating.good);
      expect(() => Fsrs.ratingOf(6), throwsArgumentError);
      expect(() => Fsrs.next(null, -1, now: start), throwsArgumentError);
    });

    test('a better rating never gives a shorter interval', () {
      for (final before in <FsrsState?>[null, learnt]) {
        final intervals = [
          for (final r in Rating.values)
            Fsrs.review(before, r, now: later).intervalDays,
        ];
        for (var i = 1; i < intervals.length; i++) {
          expect(intervals[i], greaterThanOrEqualTo(intervals[i - 1]));
        }
      }
    });

    test('a miss lowers stability and counts a lapse, but not on a pair '
        'never passed', () {
      final missed = Fsrs.next(learnt, 1, now: later);
      expect(missed.stability, lessThan(learnt.stability));
      expect(missed.lapses, 1);
      expect(missed.repetitions, 0);
      final first = Fsrs.next(null, 1, now: start);
      expect(Fsrs.next(first, 1, now: later).lapses, 0);
    });

    test('a first review is due the next day, in whole days of 24 hours '
        'across daylight saving', () {
      final first = Fsrs.next(null, 1, now: start);
      expect(first.intervalDays, 1);
      expect(first.isDue(start), isFalse);
      expect(first.isDue(start.add(const Duration(days: 1))), isTrue);

      final local = DateTime(2026, 3, 28, 9);
      final beforeDst = Fsrs.next(null, 1, now: local);
      expect(beforeDst.dueAt.difference(local), const Duration(days: 1));
      expect(beforeDst.dueAt.isUtc, isFalse);
      final second = Fsrs.next(beforeDst, 4, now: beforeDst.dueAt);
      expect(
        second.stability,
        Fsrs.next(
          beforeDst,
          4,
          now: local.add(const Duration(days: 1)),
        ).stability,
      );
      expect(second.intervalDays, greaterThan(1));
    });
  });

  group('the fit, against fsrs-rs', () {
    test('the gate gives what fsrs-rs gives, outlier filter included, and '
        'too little history fits nothing', () {
      for (final name in _all) {
        final c = _Case.load(name);
        _expectGate(FsrsFit.gate(c.histories), c.expected, name);
      }
      for (final name in _defaults) {
        final c = _Case.load(name);
        expect(c.fsrsRsFit, Fsrs.w, reason: 'fsrs-rs gave the defaults');
        expect(FsrsFit.fit(c.histories), isNull, reason: name);
      }
      expect(FsrsFit.fit(const <List<FitReview>>[]), isNull);

      FsrsFitGate gate(String name) => FsrsFit.gate(_Case.load(name).histories);
      // 18 removed, then a group of 7 reaches 25 >= 400 ~/ 20 and is kept.
      expect(gate('outlier_5pct').survivingFirstLongTermItems, 382);
      // A group of 5 that reaches 20 goes; a group of 6 stays.
      expect(gate('outlier_min6').survivingFirstLongTermByRating, [
        0,
        0,
        6,
        30,
      ]);
      // Gaps of 100 (Good) and 365 (Easy) stay; 101 and 366 go.
      expect(gate('outlier_gaps').survivingFirstLongTermByRating, [
        0,
        0,
        20,
        20,
      ]);
      expect(gate('gate_63').outcome, FsrsFitOutcome.pretrainOnly);
      expect(gate('gate_64').outcome, FsrsFitOutcome.trained);
    });

    // Three cases chosen to reach the rare paths: a pair longer than 256
    // reviews, two full batches, and the outlier filter at 5%. Each fitted
    // parameter must agree with fsrs-rs to 2e-6 (relative, or absolute
    // below 1); the batches run in fsrs-rs's order, through the port of its
    // StdRng, so a drift there fails here.
    test('a full fit matches fsrs-rs parameter by parameter: a long pair, '
        'two full batches, the outlier filter', () {
      final long = _Case.load('long_pair').histories;
      expect(long.map((h) => h.length).reduce(math.max), 300);
      expect(
        FsrsFit.gate(_Case.load('two_full_batches').histories).trainItems,
        1024,
      );
      for (final name in ['long_pair', 'two_full_batches', 'outlier_5pct']) {
        final c = _Case.load(name);
        final fitted = FsrsFit.fit(c.histories)!;
        for (var i = 0; i < 21; i++) {
          final expected = i < 4
              ? math.max(c.fsrsRsFit[i], Fsrs.minStability)
              : c.fsrsRsFit[i];
          expect(
            fitted[i],
            closeTo(expected, 2e-6 * math.max(1, expected.abs())),
            reason: '$name w$i',
          );
        }
        expect(
          FsrsFit.logLoss(c.histories, parameters: fitted),
          closeTo(FsrsFit.logLoss(c.histories, parameters: c.fsrsRsFit)!, 1e-6),
          reason: name,
        );
      }
    });

    test('the same log gives the same parameters, in any time zone', () {
      for (final name in ['onebatch', 'mixed']) {
        expect(
          FsrsFit.fit(_Case.load(name).histories),
          FsrsFit.fit(_Case.load(name).histories),
        );
      }
      final c = _Case.load('quick');
      final local = <List<FitReview>>[
        for (final history in c.histories)
          <FitReview>[
            for (final r in history)
              (grade: r.grade, at: r.at.toLocal(), rated: r.rated),
          ],
      ];
      expect(FsrsFit.fit(local), FsrsFit.fit(c.histories));
    });

    test('a window predicts only its reviews, but the reviews before it '
        'still build each pair\'s memory', () {
      final c = _Case.load('quick');
      final all = <DateTime>[
        for (final h in c.histories)
          for (final r in h) r.at,
      ]..sort();
      final from = all[all.length ~/ 2];
      var inWindow = 0;
      for (final h in c.histories) {
        for (var i = 1; i < h.length; i++) {
          if (Fsrs.elapsedDays(h[i - 1].at, h[i].at) >= 1 &&
              !h[i].at.isBefore(from)) {
            inWindow++;
          }
        }
      }
      expect(FsrsFit.gate(c.histories, from: from).items, inWindow);

      final cut = <List<FitReview>>[
        for (final h in c.histories)
          <FitReview>[
            for (final r in h)
              if (!r.at.isBefore(from)) r,
          ],
      ];
      expect(
        FsrsFit.logLoss(c.histories, from: from),
        isNot(closeTo(FsrsFit.logLoss(cut)!, 1e-9)),
      );
      expect(FsrsFit.fit(c.histories, from: from), isNot(FsrsFit.fit(cut)));

      // fsrs-rs, given only the window's items, fits the same.
      final w = _Case.load('window_quick');
      _expectGate(FsrsFit.gate(w.histories, from: w.from), w.expected, 'w');
      final fitted = FsrsFit.fit(w.histories, start: w.start, from: w.from)!;
      for (var i = 0; i < 21; i++) {
        expect(
          fitted[i],
          closeTo(w.fsrsRsFit[i], 2e-6 * math.max(1, w.fsrsRsFit[i].abs())),
          reason: 'w$i',
        );
      }
    });

    test('a fit from a start ends nearer it than a fit from the defaults; '
        'the defaults as the start change nothing', () {
      // How far apart two sets are, parameter by parameter in units of
      // fsrs-rs's spread for each, over w4 to w20.
      double distance(List<double> a, List<double> b) {
        const spread = <double>[
          6.43, 9.66, 17.58, 27.85, 0.57, 0.28, 0.6, 0.12, 0.39, 0.18, 0.33, //
          0.3, 0.09, 0.16, 0.57, 0.25, 1.03, 0.31, 0.32, 0.14, 0.27,
        ];
        var sum = 0.0;
        for (var i = 4; i < 21; i++) {
          final d = (a[i] - b[i]) / spread[i];
          sum += d * d;
        }
        return math.sqrt(sum);
      }

      final start = FsrsFit.fit(_Case.load('slow').histories)!;
      for (final name in ['quick', 'mixed']) {
        final c = _Case.load(name);
        final cold = FsrsFit.fit(c.histories)!;
        final warm = FsrsFit.fit(c.histories, start: start)!;
        expect(warm, isNot(cold), reason: name);
        expect(
          distance(warm, start),
          lessThan(distance(cold, start)),
          reason: name,
        );
        expect(FsrsFit.fit(c.histories, start: Fsrs.w), cold, reason: name);
      }
      // fsrs-rs, given the same start, fits the same.
      final s = _Case.load('start_quick');
      final fitted = FsrsFit.fit(s.histories, start: s.start, from: s.from)!;
      for (var i = 0; i < 21; i++) {
        expect(
          fitted[i],
          closeTo(s.fsrsRsFit[i], 2e-6 * math.max(1, s.fsrsRsFit[i].abs())),
          reason: 'w$i',
        );
      }
    });

    test('a fitted set schedules differently', () {
      final at = DateTime.utc(2026, 1, 5, 9);
      final fitted = FsrsFit.fit(_Case.load('slow').histories)!;
      final first = Fsrs.next(null, 4, now: at, parameters: fitted);
      expect(first.stability, fitted[2]);
      expect(first.stability, isNot(Fsrs.next(null, 4, now: at).stability));
      final later = at.add(const Duration(days: 3));
      expect(
        Fsrs.retrievability(first, later, parameters: fitted),
        isNot(Fsrs.retrievability(first, later)),
      );
      expect(
        Fsrs.replay([
          (grade: 4, at: at, rated: false),
          (grade: 4, at: later, rated: false),
        ], parameters: fitted)!.stability,
        Fsrs.next(first, 4, now: later, parameters: fitted).stability,
      );
    });
  });

  group('fitting a skill', () {
    const write = DrillMode.production;
    final start = DateTime(2026, 1, 1, 9);
    final now = DateTime(2026, 10, 9, 18);

    test('the window is the last three months or the last 1,000 reviews, '
        'whichever is more', () {
      List<FitReview> at(Iterable<DateTime> times) => <FitReview>[
        for (final t in times) (grade: 4, at: t, rated: false),
      ];
      expect(
        SkillFit.windowStart(
          at([for (var i = 0; i < 1000; i++) start.add(Duration(hours: i))]),
          now,
        ),
        isNull,
      );
      final busy = at([
        for (var i = 0; i < 1500; i++) now.subtract(Duration(hours: i)),
        for (var i = 0; i < 200; i++) start.add(Duration(hours: i)),
      ]);
      expect(SkillFit.windowStart(busy, now), DateTime(2026, 7, 9, 18));
      final times = [
        for (var i = 0; i < 1500; i++) start.add(Duration(hours: 3 * i)),
      ];
      final from = SkillFit.windowStart(at(times.reversed), now)!;
      expect(from, times[500]);
      expect(times.where((t) => !t.isBefore(from)), hasLength(1000));
    });

    test('a new set is kept only if it predicts the window better', () {
      final fitted = <double>[...Fsrs.w]..[2] = 9;
      FittedParameters keep(double? before, double? after) =>
          SkillFit.keepBetter(
            fitted: fitted,
            inUse: Fsrs.w,
            lossBefore: before,
            lossAfter: after,
            at: now,
            reviewCount: 321,
          );
      final lower = keep(0.40, 0.35);
      expect(lower.values, fitted);
      expect(lower.kept, isTrue);
      for (final kept in [keep(0.35, 0.40), keep(0.35, 0.35)]) {
        expect(kept.values, Fsrs.w);
        expect(kept.kept, isFalse);
        expect(kept.lossBefore, 0.35);
        expect(kept.reviewCount, 321, reason: 'the next refit waits again');
      }
      expect(keep(null, 0.3).values, fitted);
      expect(keep(0.3, null).values, Fsrs.w);
    });

    test('a learner who remembers well gets longer intervals, every time '
        'the same; too little to fit gives nothing', () {
      final reviews = simulate(language: 'hi', start: start, until: now);
      final history = SkillFit.histories(
        reviews,
      )[(language: 'hi', mode: write)]!;
      expect(SkillFit.canFit(history, now), isTrue);
      final result = SkillFit.run(SkillFit.job(history, Fsrs.w, now));
      final fitted = result.fitted!;
      expect(fitted.kept, isTrue);
      expect(fitted.lossAfter, lessThan(fitted.lossBefore!));
      expect(result.after.days, greaterThan(result.before.days));
      expect(SkillFit.direction(result.before, result.after), -1);
      expect(
        SkillFit.run(SkillFit.job(history, Fsrs.w, now)).fitted,
        result.fitted,
      );

      final few = SkillFit.histories(
        simulate(language: 'te', start: start, until: now, cards: 5),
      )[(language: 'te', mode: write)]!;
      expect(SkillFit.canFit(few, now), isFalse);
      final none = SkillFit.run(SkillFit.job(few, Fsrs.w, now));
      expect(none.fitted, isNull);
      expect(none.after, none.before);
    });

    test('a skill is scheduled by its own fit, else by its fit in the '
        'language most recently studied, and the replay uses that set', () {
      const hear = DrillMode.listening;
      final monday = DateTime(2026, 10, 5, 9);
      final tuesday = DateTime(2026, 10, 6, 9);
      final wednesday = DateTime(2026, 10, 7, 9);
      FittedParameters fitWith(double w2) => FittedParameters(
        values: <double>[...Fsrs.w]..[2] = w2,
        fittedAt: DateTime(2026, 10, 1),
        reviewCount: 500,
      );
      expect(SkillParameters.none.of('hi', hear), Fsrs.w);
      final hi = fitWith(5);
      final bn = fitWith(7);
      final p = SkillParameters(
        fitted: {
          (language: 'hi', mode: hear): hi,
          (language: 'bn', mode: hear): bn,
        },
        lastStudied: {'hi': monday, 'bn': tuesday, 'te': wednesday},
      );
      // te is the latest studied, but has no Hear fit: bn's is next.
      expect(p.of('te', hear), bn.values);
      expect(p.of('hi', hear), hi.values, reason: 'its own comes first');
      expect(p.of('te', write), Fsrs.w, reason: 'no Write fit anywhere');

      final hiWrite = fitWith(9);
      final parameters = SkillParameters(
        fitted: {(language: 'hi', mode: write): hiWrite},
        lastStudied: {'hi': tuesday, 'bn': monday},
      );
      final replayed = replayReviews([
        _review((cardId: 'hi-0001', mode: write), monday, 4),
        _review((cardId: 'bn-0001', mode: write), monday, 4),
        _review((cardId: 'hi-0001', mode: write), wednesday, 4),
      ], parameters: parameters);
      final first = Fsrs.next(null, 4, now: monday, parameters: hiWrite.values);
      expect(
        replayed.states[(cardId: 'hi-0001', mode: write)]!.stability,
        Fsrs.next(
          first,
          4,
          now: wednesday,
          parameters: hiWrite.values,
        ).stability,
      );
      // bn has no Write fit of its own: it starts from hi's.
      expect(replayed.states[(cardId: 'bn-0001', mode: write)]!.stability, 9);
      expect(
        replayReviews([_review((cardId: 'hi-0001', mode: write), monday, 4)])
            .events
            .single
            .after
            .stability,
        Fsrs.w[2],
      );
    });
  });

  group('one skill\'s answer and another', () {
    test('a right answer raises the ability, a miss lowers it', () {
      ({String cardId, String deckId, DrillMode mode, int grade}) r(int g) => (
        cardId: 'te-0001',
        deckId: 'te-en-words',
        mode: DrillMode.listening,
        grade: g,
      );
      final right = Abilities.replay([r(4)]);
      final wrong = Abilities.replay([r(1)]);
      expect(right.of('te', DrillMode.listening), closeTo(0.5, 1e-9));
      expect(wrong.of('te', DrillMode.listening), closeTo(-0.5, 1e-9));
    });

    test('Write and Say imply Recognition: a right answer raises its '
        'stability in part, a miss does not touch it', () {
      const words = SkillMap(formHeardIn: <String>{'te-en-script'});
      for (final mode in [DrillMode.production, DrillMode.speaking]) {
        expect(words.impliedBy(mode, 'te-en-words'), {
          DrillMode.recognition: SkillMap.implied,
        });
      }
      final day = DateTime(2026, 10, 1, 9);
      final later = day.add(const Duration(days: 3));
      LoggedReview review(DrillMode mode, int grade, DateTime at) => _review(
        (cardId: 'te-0001', mode: mode),
        at,
        grade,
        deckId: 'te-en-words',
      );
      final recognised = review(DrillMode.recognition, 4, day);
      const rec = (cardId: 'te-0001', mode: DrillMode.recognition);
      final alone = replayReviews([recognised]).states;
      final withWrite = replayReviews([
        recognised,
        review(DrillMode.production, 4, later),
      ], skills: words).states;
      expect(withWrite[rec]!.stability, greaterThan(alone[rec]!.stability));
      expect(withWrite[rec]!.dueAt, alone[rec]!.dueAt);
      final missed = replayReviews([
        recognised,
        review(DrillMode.production, 1, later),
      ], skills: words).states;
      expect(missed[rec]!.stability, alone[rec]!.stability);
    });
  });

  group('leeches', () {
    const pair = (cardId: 'hi-0231', mode: DrillMode.production);
    const other = (cardId: 'hi-0232', mode: DrillMode.production);
    final day0 = DateTime(2026, 9, 1, 9);
    DateTime day(int n) => DateTime(day0.year, day0.month, day0.day + n, 9);
    LeechAction act(LeechActionKind kind, int d) => LeechAction(
      at: day(d).add(const Duration(hours: 1)),
      key: pair,
      kind: kind,
    );
    final history = <LoggedReview>[
      _review(pair, day(0), 4),
      _review(pair, day(1), 1),
      _review(other, day(1), 5),
      _review(pair, day(3), 4),
      _review(pair, day(5), 2),
    ];

    test('a reset restarts the pair and keeps its reviews; undo takes back '
        'only the latest reset', () {
      final replayed = replayReviews(
        history,
        effects: LeechEffects([act(LeechActionKind.reset, 1)]),
      );
      expect(replayed.events, hasLength(5), reason: 'nothing is dropped');
      expect(replayed.events[1].before, isNotNull);
      expect(replayed.events[3].before, isNull, reason: 'starts fresh');
      var expected = Fsrs.next(null, 4, now: day(3), rated: true);
      expected = Fsrs.next(expected, 2, now: day(5), rated: true);
      expect(_fields(replayed.states[pair]!), _fields(expected));
      expect(
        _fields(replayed.states[other]!),
        _fields(replayReviews(history).states[other]!),
        reason: 'other pairs are untouched',
      );

      final undone = LeechEffects([
        act(LeechActionKind.reset, 1),
        act(LeechActionKind.undoReset, 1),
      ]);
      expect(
        _fields(replayReviews(history, effects: undone).states[pair]!),
        _fields(replayReviews(history).states[pair]!),
      );
      final twice = LeechEffects([
        act(LeechActionKind.reset, 1),
        act(LeechActionKind.reset, 4),
        act(LeechActionKind.undoReset, 5),
      ]);
      expect(twice.resetAt(pair), act(LeechActionKind.reset, 1).at);
    });

    test('set aside holds until the pair is brought back', () {
      expect(
        LeechEffects([act(LeechActionKind.setAside, 0)]).isSetAside(pair),
        isTrue,
      );
      expect(
        LeechEffects([
          act(LeechActionKind.setAside, 0),
          act(LeechActionKind.bringBack, 1),
        ]).isSetAside(pair),
        isFalse,
      );
      expect(
        LeechEffects([act(LeechActionKind.setAside, 0)]).isSetAside(other),
        isFalse,
      );
    });
  });

  group('the log', () {
    late AppDatabase db;
    late ReviewLog log;
    late CardStateRepository states;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      log = ReviewLog(db);
      states = CardStateRepository(db);
    });
    tearDown(() => db.close());

    test('20 reviews rebuilt from the log give the same states; a grade '
        'outside 0 to 5 writes nothing', () async {
      final start = DateTime(2026, 9, 29, 8, 30);
      const pairs = <(String, String, DrillMode)>[
        ('hi-en-market', 'hi-0231', DrillMode.recognition),
        ('hi-en-market', 'hi-0231', DrillMode.production),
        ('bn-en-market', 'bn-0246', DrillMode.recognition),
      ];
      const grades = <int>[
        4, 5, 3, 1, 4, 2, 5, 4, 0, 3, 4, 5, 1, 4, 4, 3, 5, 2, 4, 5, //
      ];
      await expectLater(
        log.record(
          deckId: 'hi-en-market',
          cardId: 'hi-0231',
          mode: DrillMode.recognition,
          grade: 6,
          now: start,
        ),
        throwsArgumentError,
      );
      expect(await db.reviewsDao.all(), isEmpty);

      for (var i = 0; i < grades.length; i++) {
        await log.record(
          deckId: pairs[i % 3].$1,
          cardId: pairs[i % 3].$2,
          mode: pairs[i % 3].$3,
          grade: grades[i],
          now: start.add(Duration(hours: 20 * i, minutes: i)),
          elapsed: Duration(milliseconds: 1500 + i),
          answerGiven: pairs[i % 3].$3 == DrillMode.production ? 'kitna' : null,
        );
      }
      final recorded = _byValue(await states.all());
      expect(recorded, hasLength(3));

      // Wreck the cache: drop one pair, corrupt another.
      await db.cardStatesDao.clear();
      await db.cardStatesDao.put(
        Fsrs.next(
          null,
          1,
          now: start,
        ).toRow((cardId: 'hi-0231', mode: DrillMode.recognition)),
      );
      await log.rebuildStates();
      expect(_byValue(await states.all()), recorded);
    });
  });

  group('Adjust to me', () {
    const write = DrillMode.production;
    const hiWrite = (language: 'hi', mode: write);
    final start = DateTime(2026, 1, 1, 9);
    final now = DateTime(2026, 10, 9, 18);

    test('fits every skill that can be, says so of the rest, and '
        'reschedules the fitted skill\'s words with the new set', () async {
      final p = _progressOf(
        inTimeOrder([
          ...simulate(language: 'hi', start: start, until: now),
          ...simulate(
            language: 'hi',
            start: start,
            until: now,
            cards: 4,
            mode: DrillMode.listening,
          ),
        ]),
      );
      final before = p.stateOf('hi-0001', write)!;
      final runner = _Recording();
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
      expect(results.firstWhere((r) => r.key != hiWrite).fitted, isNull);
      expect(p.parameters.fitted[hiWrite], isNotNull);

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
      final p = _progressOf(
        simulate(language: 'hi', start: start, until: now, cards: 5),
      );
      final runner = _Recording();
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

    testWidgets('Adjust shows its progress, then what changed, per skill', (
      tester,
    ) async {
      usePhone(tester);
      final gate = Completer<void>();
      final state = AppState.test(
        progress: _progressOf(
          inTimeOrder([
            ...simulate(language: 'hi', start: start, until: now),
            ...simulate(
              language: 'hi',
              start: start,
              until: now,
              cards: 3,
              mode: DrillMode.listening,
            ),
          ]),
        ),
        now: now,
        fitRunner: (job) async {
          await gate.future;
          return SkillFit.run(job);
        },
      );
      await pumpScreen(tester, const ActivitiesPage(), state: state);
      final l10n = l10nOf(tester);
      await scrollTo(tester, find.text(l10n.settingsAdjustHelp));
      Finder button() =>
          find.widgetWithText(FilledButton, l10n.settingsAdjustButton);

      expect(find.text(l10n.settingsAdjustNotYet), findsOneWidget);
      await tester.ensureVisible(button());
      await tester.pumpAndSettle();
      await tester.tap(button());
      await tester.pump();

      // Adjusting: a progress bar, the button waiting.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(tester.widget<FilledButton>(button()).onPressed, isNull);

      gate.complete();
      await tester.pumpAndSettle();

      // The sheet: every skill, fitted or not.
      expect(find.text(l10n.adjustedTitle), findsOneWidget);
      expect(find.text(l10n.adjustedNotYet('listening')), findsOneWidget);
      expect(
        find.textContaining(
          RegExp(
            '^(${RegExp.escape(l10n.adjustedFewer('production'))}|'
            '${RegExp.escape(l10n.adjustedMore('production'))}|'
            '${RegExp.escape(l10n.adjustedSame('production'))})\$',
          ),
        ),
        findsOneWidget,
      );
      expect(state.progress.parameters.fitted[hiWrite], isNotNull);

      await tester.tap(find.text(l10n.commonDone));
      await tester.pumpAndSettle();
      expect(find.text(l10n.settingsAdjustLastToday), findsOneWidget);
      expect(tester.widget<FilledButton>(button()).onPressed, isNotNull);
    });
  });
}

/// fsrs-rs gives the defaults.
const _defaults = <String>['tiny', 'probe_c16x4', 'probe_c19x7', 'gate_7'];

/// Every reference case in `test/fixtures/fsrs_fit/` that is not a window
/// or a start: fsrs-rs gives the defaults, fits w0-w3 only, or trains all
/// 21.
final _all = <String>[
  ..._defaults,
  'small',
  'probe_c20x3',
  'gate_8',
  'gate_9',
  'first_only',
  'outlier_tiebreak',
  'fill_34',
  'fill_24',
  'fill_23',
  'fill_14',
  'fill_13',
  'fill_12',
  'fill_234',
  'fill_134',
  'fill_124',
  'fill_123',
  'fill_monotone',
  'fill_clamp',
  'gate_63',
  'onebatch',
  'probe_c20x4',
  'outlier_5pct',
  'outlier_min6',
  'outlier_gaps',
  'lapse_floor',
  'stability_ceiling',
  'long_pair',
  'quick',
  'slow',
  'mixed',
  'two_full_batches',
  'same_day_ceiling',
  'probability_clamp',
  'difficulty_floor',
  'gate_64',
];

const _outcomes = <String, FsrsFitOutcome>{
  'defaults': FsrsFitOutcome.defaults,
  'pretrain only': FsrsFitOutcome.pretrainOnly,
  'trained': FsrsFitOutcome.trained,
};

/// [gate] is what fsrs-rs's gate gave, in [expected].
void _expectGate(FsrsFitGate gate, Map<String, dynamic> expected, String name) {
  final g = expected['gate'] as Map<String, dynamic>;
  expect(gate.items, g['items'], reason: name);
  expect(
    gate.firstLongTermItems,
    g['first_long_term_items_before_filter'],
    reason: name,
  );
  expect(
    gate.survivingFirstLongTermItems,
    g['first_long_term_items_after_filter'],
    reason: name,
  );
  expect(
    gate.survivingFirstLongTermByRating,
    g['first_long_term_items_after_filter_by_first_rating'],
    reason: name,
  );
  expect(gate.trainItems, g['train_items_after_filter'], reason: name);
  expect(gate.outcome, _outcomes[g['outcome']], reason: name);
}

List<double> _doubles(Object? list) => <double>[
  for (final v in list! as List) (v as num).toDouble(),
];

/// One reference case and what fsrs-rs gave for it.
///
/// The fixtures in `test/fixtures/fsrs_fit/` were made with the fsrs-rs
/// harness (fsrs 6.6.2 at 4bc0a09, model_version Fsrs6,
/// `TrainingConfig::default()`). Each holds the cards and what fsrs-rs gave
/// for them: the gate's counts, the fitted parameters and their log loss.
/// Simulated learners' cards are `[start day, [rating, days since the
/// review before, ...]]`; built cases' are templates, `[start day, [code,
/// days, ...], copies]`. A window case (`from`) gave fsrs-rs only the items
/// at or after it, each with its pair's whole history; a start case ran a
/// copy of fsrs-rs whose defaults are the start.
class _Case {
  _Case(this.histories, this.expected, {this.from, this.start});

  factory _Case.load(String name) => _cache.putIfAbsent(name, () {
    Map<String, dynamic> read(String name) =>
        jsonDecode(File('test/fixtures/fsrs_fit/$name.json').readAsStringSync())
            as Map<String, dynamic>;
    final doc = read(name);
    final cardsOf = doc['cards_of'] as String?;
    final histories = _histories(
      (cardsOf == null ? doc : read(cardsOf))['cards'] as List,
    );
    final from = doc['from'] as List?;
    return _Case(
      histories,
      doc['expected'] as Map<String, dynamic>,
      from: from == null ? null : histories[from[0] as int][from[1] as int].at,
      start: doc['start'] == null ? null : _doubles(doc['start']),
    );
  });

  static final Map<String, _Case> _cache = <String, _Case>{};

  final List<List<FitReview>> histories;
  final Map<String, dynamic> expected;
  final DateTime? from;
  final List<double>? start;

  List<double> get fsrsRsFit =>
      _doubles((expected['fit'] as Map<String, dynamic>)['parameters']);

  /// The cards as the app's log would hold them. Each review is on its
  /// day, offset by the card's index in seconds and the review's in
  /// milliseconds, so that reviews sort as the harness sorts them. Codes
  /// become grades as the app logs them: Again 1, Hard 3, Good 4, Easy a
  /// rated 5, and 5 an unrated 5.
  static List<List<FitReview>> _histories(List<dynamic> cards) {
    final base = DateTime.utc(2026, 1, 1);
    final histories = <List<FitReview>>[];
    for (final card in cards.cast<List<dynamic>>()) {
      final copies = card.length > 2 ? card[2] as int : 1;
      for (var copy = 0; copy < copies; copy++) {
        final flat = (card[1] as List).cast<int>();
        final index = histories.length;
        final reviews = <FitReview>[];
        var day = card[0] as int;
        for (var i = 0; i < flat.length ~/ 2; i++) {
          final code = flat[2 * i];
          day += flat[2 * i + 1];
          reviews.add((
            grade: const <int>[0, 1, 3, 4, 5, 5][code],
            at: base.add(Duration(days: day, seconds: index, milliseconds: i)),
            rated: code == 4,
          ));
        }
        histories.add(reviews);
      }
    }
    return histories;
  }
}
