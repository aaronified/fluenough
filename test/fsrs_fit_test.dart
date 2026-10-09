import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/fsrs_fit.dart';

/// The port of `fsrs-rs`'s FSRS-6 fitting, checked against `fsrs-rs` itself.
///
/// The fixtures in `test/fixtures/fsrs_fit/` are the reference cases of the
/// fsrs-rs harness (fsrs 6.6.2 at 4bc0a09, run with model_version Fsrs6 and
/// `TrainingConfig::default()`): six simulated learners and four probes of
/// the thresholds. Each holds the cards, as `[start day, [rating, days since
/// the review before, ...]]`, and what fsrs-rs gave: the gate's counts, the
/// first stabilities alone (`pretrain`), the fitted parameters and their log
/// loss, the defaults' log loss, and, for the cases of several batches, the
/// log loss of refits with eight other shuffle seeds. The harness's JSON was
/// only compacted; nothing was trimmed.
///
/// How closely each can agree:
///
/// - the gate's counts: exactly, being integer logic;
/// - the first stabilities: to about 1e-5;
/// - a fit of one batch (up to 512 items): closely, since there is no
///   shuffle;
/// - a fit of several batches: only within the spread of shuffle seeds,
///   because fsrs-rs shuffles the batch order with Rust's ChaCha12 and this
///   port with a generator of its own. These are compared by log loss.
void main() {
  group('the gate matches fsrs-rs exactly', () {
    for (final name in _all) {
      test(name, () {
        final c = _Case.load(name);
        final gate = FsrsFit.gate(c.histories);
        final expected = c.expected['gate'] as Map<String, dynamic>;
        expect(gate.items, expected['items']);
        expect(
          gate.firstLongTermItems,
          expected['first_long_term_items_before_filter'],
        );
        expect(
          gate.survivingFirstLongTermItems,
          expected['first_long_term_items_after_filter'],
        );
        expect(
          gate.survivingFirstLongTermByRating,
          expected['first_long_term_items_after_filter_by_first_rating'],
        );
        expect(gate.trainItems, expected['train_items_after_filter']);
        expect(gate.outcome, _outcomes[expected['outcome']]);
      });
    }
  });

  group('too little history gives null, where fsrs-rs gives the defaults', () {
    for (final name in ['tiny', 'probe_c16x4', 'probe_c19x7']) {
      test(name, () {
        final c = _Case.load(name);
        expect(c.fsrsRsFit, Fsrs.w, reason: 'fsrs-rs gave the defaults');
        expect(FsrsFit.fit(c.histories), isNull);
      });
    }

    test('19 pairs with 133 reviews to predict are not enough: 20 pairs must '
        'share a first rating', () {
      final gate = FsrsFit.gate(_Case.load('probe_c19x7').histories);
      expect(gate.items, 133);
      expect(gate.trainItems, 0);
    });

    test('no history at all', () {
      expect(FsrsFit.fit(const <List<FitReview>>[]), isNull);
      expect(FsrsFit.gate(const <List<FitReview>>[]).items, 0);
      expect(FsrsFit.logLoss(const <List<FitReview>>[]), isNull);
    });
  });

  group('with less than 64 items, only the first stabilities are fitted', () {
    for (final name in ['small', 'probe_c20x3']) {
      test('$name: w0-w3 match fsrs-rs to 1e-5, and w4-w20 are the '
          'defaults', () {
        final c = _Case.load(name);
        final fitted = FsrsFit.fit(c.histories)!;
        expect(fitted, hasLength(21));
        for (var i = 0; i < 4; i++) {
          expect(
            fitted[i],
            _relativelyClose(c.pretrain[i], 1e-5),
            reason: 'w$i',
          );
          expect(fitted[i], _relativelyClose(c.fsrsRsFit[i], 1e-5));
        }
        expect(fitted.sublist(4), Fsrs.w.sublist(4));
      });
    }
  });

  group('a fit of one batch matches fsrs-rs', () {
    for (final name in ['onebatch', 'probe_c20x4']) {
      test('$name: every parameter to 1e-4, log loss to 1e-6', () {
        final c = _Case.load(name);
        final fitted = FsrsFit.fit(c.histories)!;
        for (var i = 0; i < 21; i++) {
          expect(
            fitted[i],
            _relativelyClose(c.fsrsRsFit[i], 1e-4),
            reason: 'w$i',
          );
        }
        expect(
          FsrsFit.logLoss(c.histories, parameters: fitted),
          closeTo(c.fsrsRsLogLoss, 1e-6),
        );
      });
    }
  });

  group('a fit of several batches does as well as fsrs-rs', () {
    for (final name in ['quick', 'slow', 'mixed']) {
      test('$name: log loss within 1% of fsrs-rs\'s, below the defaults\', '
          'and no worse than fsrs-rs\'s worst seed', () {
        final c = _Case.load(name);
        final fitted = FsrsFit.fit(c.histories)!;
        final loss = FsrsFit.logLoss(c.histories, parameters: fitted)!;
        final defaults = FsrsFit.logLoss(c.histories)!;
        expect(
          (loss - c.fsrsRsLogLoss).abs(),
          lessThan(0.01 * c.fsrsRsLogLoss),
        );
        expect(loss, lessThan(defaults));
        expect(loss, lessThanOrEqualTo(c.seedSweep.reduce(math.max)));
        // Parameters move by up to about 0.1 from one seed to another (0.6
        // for w3 in slow), so they are only checked loosely.
        for (var i = 0; i < 21; i++) {
          expect(fitted[i], closeTo(c.fsrsRsFit[i], 0.25), reason: 'w$i');
        }
      });
    }

    test('slow: the fit recovers most of what the defaults lose', () {
      final c = _Case.load('slow');
      final fitted = FsrsFit.fit(c.histories)!;
      expect(
        FsrsFit.logLoss(c.histories, parameters: fitted),
        lessThan(c.defaultLogLoss - 0.03),
      );
    });
  });

  group('logLoss', () {
    for (final name in _all) {
      test('$name: matches fsrs-rs\'s evaluate to 1e-5', () {
        final c = _Case.load(name);
        expect(FsrsFit.logLoss(c.histories), closeTo(c.defaultLogLoss, 1e-5));
        expect(
          FsrsFit.logLoss(c.histories, parameters: c.fsrsRsFit),
          closeTo(c.fsrsRsLogLoss, 1e-5),
        );
        final trueLogLoss = c.expected['true_log_loss'] as num?;
        if (trueLogLoss != null) {
          expect(
            FsrsFit.logLoss(c.histories, parameters: c.trueParameters),
            closeTo(trueLogLoss, 1e-5),
          );
        }
      });
    }
  });

  test('the hand-written gradient agrees with finite differences', () {
    final histories = _Case.load('onebatch').histories;
    // Off the defaults, so that w7, w17 and w19 are not near their bounds.
    final w = <double>[...Fsrs.w]
      ..[7] = 0.05
      ..[17] = 0.6
      ..[19] = 0.2;
    final analytic = FsrsFit.lossAndGradient(histories, w).gradient;
    for (var i = 0; i < 21; i++) {
      final h = 1e-6 * (w[i].abs() + 1e-3);
      final up = FsrsFit.lossAndGradient(histories, [...w]..[i] += h).loss;
      final down = FsrsFit.lossAndGradient(histories, [...w]..[i] -= h).loss;
      final numeric = (up - down) / (2 * h);
      expect(
        analytic[i],
        closeTo(numeric, 1e-5 * math.max(1, numeric.abs())),
        reason: 'w$i',
      );
    }
  });

  group('deterministic', () {
    test('the same log always gives the same parameters', () {
      for (final name in ['onebatch', 'mixed']) {
        final first = FsrsFit.fit(_Case.load(name).histories);
        final again = FsrsFit.fit(_Case.load(name).histories);
        expect(again, first);
      }
    });

    test('the same in any time zone', () {
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
  });

  group('days are counted as the scheduler counts them', () {
    final start = DateTime.utc(2026, 3, 1, 22);

    List<FitReview> pair(List<int> hoursAfterStart) => <FitReview>[
      for (final h in hoursAfterStart)
        (grade: 4, at: start.add(Duration(hours: h)), rated: false),
    ];

    test('a review 12 hours later, on the next calendar day, is same-day', () {
      // fsrs-rs's own converter would count a calendar day here; the
      // scheduler counts 24 hours, and so does the fit.
      expect(Fsrs.elapsedDays(start, start.add(const Duration(hours: 12))), 0);
      expect(
        FsrsFit.gate([
          pair([0, 12]),
        ]).items,
        0,
      );
      expect(
        FsrsFit.gate([
          pair([0, 12, 36]),
        ]).items,
        1,
      );
      expect(
        FsrsFit.gate([
          pair([0, 24]),
        ]).items,
        1,
      );
    });

    test('a same-day review is not predicted, but shapes what follows', () {
      // Good, then a miss an hour later, then Good three days after that.
      final withMiss = <FitReview>[
        ...pair([0]),
        (grade: 1, at: start.add(const Duration(hours: 1)), rated: false),
        ...pair([73]),
      ];
      expect(FsrsFit.gate([withMiss]).items, 1);
      expect(
        FsrsFit.logLoss([withMiss]),
        isNot(
          FsrsFit.logLoss([
            pair([0, 72]),
          ]),
        ),
      );
    });
  });

  group('Fsrs with fitted parameters', () {
    final at = DateTime.utc(2026, 1, 5, 9);
    final fitted = FsrsFit.fit(_Case.load('slow').histories)!;

    test('the defaults, passed, change nothing', () {
      var withDefaults = Fsrs.next(null, 4, now: at, parameters: Fsrs.w);
      var without = Fsrs.next(null, 4, now: at);
      for (final (days, grade) in [(0, 3), (2, 1), (3, 4), (9, 5)]) {
        final now = at.add(Duration(days: days, hours: 1));
        withDefaults = Fsrs.next(
          withDefaults,
          grade,
          now: now,
          parameters: Fsrs.w,
        );
        without = Fsrs.next(without, grade, now: now);
        expect(withDefaults.stability, without.stability);
        expect(withDefaults.difficulty, without.difficulty);
        expect(withDefaults.dueAt, without.dueAt);
      }
    });

    test('a fitted set schedules differently', () {
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

    test('a set that is not 21 values is refused', () {
      expect(
        () => Fsrs.next(null, 4, now: at, parameters: Fsrs.w.sublist(1)),
        throwsArgumentError,
      );
    });
  });
}

const _all = <String>[
  'tiny',
  'small',
  'onebatch',
  'quick',
  'slow',
  'mixed',
  'probe_c16x4',
  'probe_c19x7',
  'probe_c20x3',
  'probe_c20x4',
];

const _outcomes = <String, FsrsFitOutcome>{
  'defaults': FsrsFitOutcome.defaults,
  'pretrain only': FsrsFitOutcome.pretrainOnly,
  'trained': FsrsFitOutcome.trained,
};

Matcher _relativelyClose(double expected, double tolerance) =>
    closeTo(expected, tolerance * math.max(1, expected.abs()));

List<double> _doubles(Object? list) => <double>[
  for (final v in list! as List) (v as num).toDouble(),
];

/// One reference case and what fsrs-rs gave for it.
class _Case {
  _Case(this.histories, this.expected);

  factory _Case.load(String name) {
    final doc = jsonDecode(
      File('test/fixtures/fsrs_fit/$name.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    return _Case(
      _histories(doc['cards'] as List),
      doc['expected'] as Map<String, dynamic>,
    );
  }

  final List<List<FitReview>> histories;
  final Map<String, dynamic> expected;

  Map<String, dynamic> get _fit => expected['fit'] as Map<String, dynamic>;

  List<double> get fsrsRsFit => _doubles(_fit['parameters']);

  double get fsrsRsLogLoss => (_fit['log_loss'] as num).toDouble();

  double get defaultLogLoss => (expected['default_log_loss'] as num).toDouble();

  List<double> get pretrain => _doubles(expected['pretrain']);

  List<double> get seedSweep => _doubles(expected['seed_sweep_log_loss']);

  List<double> get trueParameters => _doubles(expected['true_parameters']);

  /// The cards as the app's log would hold them. Each review is on its
  /// day, offset by the card's index in seconds and the review's in
  /// milliseconds, so that reviews sort as the harness sorts them: by day,
  /// then card, then review. Ratings become grades as the app logs them:
  /// Again 1, Hard 3, Good 4, and Easy a rated 5.
  static List<List<FitReview>> _histories(List<dynamic> cards) {
    final base = DateTime.utc(2026, 1, 1);
    return <List<FitReview>>[
      for (final (index, card) in cards.indexed)
        _history(base, index, card[0] as int, (card[1] as List).cast<int>()),
    ];
  }

  static List<FitReview> _history(
    DateTime base,
    int index,
    int startDay,
    List<int> flat,
  ) {
    final reviews = <FitReview>[];
    var day = startDay;
    for (var i = 0; i < flat.length ~/ 2; i++) {
      final rating = flat[2 * i];
      day += flat[2 * i + 1];
      reviews.add((
        grade: const <int>[0, 1, 3, 4, 5][rating],
        at: base.add(Duration(days: day, seconds: index, milliseconds: i)),
        rated: rating == 4,
      ));
    }
    return reviews;
  }
}
