import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/fsrs_fit.dart';

/// The port of `fsrs-rs`'s FSRS-6 fitting, checked against `fsrs-rs` itself.
///
/// The fixtures in `test/fixtures/fsrs_fit/` were made with the fsrs-rs
/// harness (fsrs 6.6.2 at 4bc0a09, model_version Fsrs6,
/// `TrainingConfig::default()`). Each holds the cards and what fsrs-rs gave
/// for them: the gate's counts, the first stabilities alone (`pretrain`),
/// the fitted parameters and their log loss, and the defaults' log loss.
///
/// - Six simulated learners (`tiny` to `slow`) and four probes of the
///   20-pair rule (`probe_*`). Their cards are `[start day, [rating, days
///   since the review before, ...]]`.
/// - Cases built to reach one branch each (the rest), with an `about` line
///   saying which. Their cards are templates, `[start day, [code, days,
///   ...], copies]`, repeated in place. Codes are ratings, Again to Easy,
///   except 5: an unrated grade 5, which the app counts as Good.
///
/// How closely each can agree:
///
/// - the gate's counts: exactly, being integer logic;
/// - the first stabilities: to one unit in the last place of a 32-bit
///   float, the search being the same f64 arithmetic;
/// - a full fit: every parameter to 2e-6 (relative, or absolute below 1).
///   The batches run in fsrs-rs's order (its `StdRng` is ported,
///   `test/rust_std_rng_test.dart`), so what remains is arithmetic: fsrs-rs
///   runs the model in 32-bit floats and this port in 64-bit, so each
///   step's gradient differs in its last bits, and Adam carries that into
///   the next step. Measured, the worst case is 8e-7; a 32-bit float's
///   rounding is 6e-8. `slow` is allowed 2e-5: its 25 steps move w3, on
///   which its loss is nearly flat (fsrs-rs's own seeds spread it by 0.6),
///   by 7e-6. `probability_clamp` is held to 5e-7 (it agrees to 1.5e-7),
///   because the gradient its last few items give, from beyond the clamp,
///   moves parameters by only 1.4e-6. Every other change to what is
///   computed that has been tried moves them by 1e-4 or more.
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
    for (final name in _defaults) {
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

  group('only the first stabilities are fitted, to the last bit', () {
    for (final name in _pretrainOnly) {
      test('$name: ${_Case.load(name).about}', () {
        final c = _Case.load(name);
        final fitted = FsrsFit.fit(c.histories)!;
        expect(fitted, hasLength(21));
        for (var i = 0; i < 4; i++) {
          final expected = math.max(c.pretrain[i], Fsrs.minStability);
          expect(
            _ulps(fitted[i], expected),
            lessThanOrEqualTo(1),
            reason: 'w$i',
          );
          expect(
            _ulps(fitted[i], math.max(c.fsrsRsFit[i], Fsrs.minStability)),
            lessThanOrEqualTo(1),
            reason: 'w$i',
          );
        }
        expect(fitted.sublist(4), Fsrs.w.sublist(4));
      });
    }
  });

  group('a full fit matches fsrs-rs, parameter by parameter', () {
    for (final name in _trained.keys) {
      final tolerance = _trained[name]!;
      test('$name, to $tolerance: ${_Case.load(name).about}', () {
        final c = _Case.load(name);
        final fitted = FsrsFit.fit(c.histories)!;
        for (var i = 0; i < 21; i++) {
          final expected = i < 4
              ? math.max(c.fsrsRsFit[i], Fsrs.minStability)
              : c.fsrsRsFit[i];
          expect(
            fitted[i],
            closeTo(expected, tolerance * math.max(1, expected.abs())),
            reason: 'w$i',
          );
        }
        if (c.minStabilityFloored) return;
        expect(
          FsrsFit.logLoss(c.histories, parameters: fitted),
          closeTo(FsrsFit.logLoss(c.histories, parameters: c.fsrsRsFit)!, 1e-6),
        );
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

  group('what the built cases reach', () {
    test('the gate at 7, 8 and 9 items', () {
      for (final n in [7, 8, 9]) {
        final gate = FsrsFit.gate(_Case.load('gate_$n').histories);
        expect(gate.trainItems, n);
        expect(gate.survivingFirstLongTermItems, 6);
      }
      expect(FsrsFit.fit(_Case.load('gate_7').histories), isNull);
      expect(FsrsFit.fit(_Case.load('gate_8').histories), isNotNull);
    });

    test('only first long-term reviews: pretrain only, even past 64', () {
      final gate = FsrsFit.gate(_Case.load('first_only').histories);
      expect(gate.trainItems, 70);
      expect(gate.survivingFirstLongTermItems, 70);
      expect(gate.outcome, FsrsFitOutcome.pretrainOnly);
      // Its first answers are unrated 5s: Good, not Easy.
      expect(gate.survivingFirstLongTermByRating, [0, 0, 70, 0]);
    });

    test('the outlier filter', () {
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
      // Equal groups go shortest gap first: gap 2 (four items a pair) goes,
      // gaps 3 (two) and 4 (one) stay.
      expect(gate('outlier_tiebreak').trainItems, 30);
    });

    test('the final clamp, and the scheduler floor on w0', () {
      final c = _Case.load('fill_clamp');
      final fitted = FsrsFit.fit(c.histories)!;
      expect(fitted.sublist(2, 4), [100, 100]);
      expect(c.fsrsRsFit[0], closeTo(0.0001, 1e-9));
      expect(fitted[0], Fsrs.minStability);
      expect(_Case.load('lapse_floor').fsrsRsFit[0], closeTo(0.0001, 1e-9));
    });

    test('the monotone fix with equal counts raises the smaller rating', () {
      final fitted = FsrsFit.fit(_Case.load('fill_monotone').histories)!;
      expect(fitted.sublist(1, 4).toSet(), hasLength(1));
    });

    test('clip bounds', () {
      final ceiling = FsrsFit.fit(_Case.load('stability_ceiling').histories)!;
      expect(ceiling[3], 100);
      final sameDay = FsrsFit.fit(_Case.load('same_day_ceiling').histories)!;
      expect(sameDay[17], 2);
      expect(sameDay[18], 2);
      expect(sameDay[20], 0.8);
      final floor = FsrsFit.fit(_Case.load('difficulty_floor').histories)!;
      expect(floor[19], 0.01);
      expect(floor[7], greaterThan(0.5));
    });

    test('a pair longer than 256 reviews, and two full batches', () {
      final long = _Case.load('long_pair').histories;
      expect(long.map((h) => h.length).reduce(math.max), 300);
      expect(
        FsrsFit.gate(_Case.load('two_full_batches').histories).trainItems,
        1024,
      );
    });
  });

  group('logLoss', () {
    for (final name in _all) {
      test('$name: matches fsrs-rs\'s evaluate to 1e-5', () {
        final c = _Case.load(name);
        expect(FsrsFit.logLoss(c.histories), closeTo(c.defaultLogLoss, 1e-5));
        // fsrs-rs floors stability at 0.0001 days, the scheduler at
        // Fsrs.minStability, 0.001: where the fitted w0 or a lapse goes
        // below 0.001, the two predict differently.
        if (c.minStabilityFloored || name == 'probability_clamp') return;
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

/// fsrs-rs gives the defaults.
const _defaults = <String>['tiny', 'probe_c16x4', 'probe_c19x7', 'gate_7'];

/// fsrs-rs fits w0-w3 only.
const _pretrainOnly = <String>[
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
];

/// fsrs-rs trains all 21, and how closely each parameter must agree
/// (relative, or absolute below 1). One batch, then several.
const _trained = <String, double>{
  'onebatch': 2e-6,
  'probe_c20x4': 2e-6,
  'outlier_5pct': 2e-6,
  'outlier_min6': 2e-6,
  'outlier_gaps': 2e-6,
  'lapse_floor': 2e-6,
  'stability_ceiling': 2e-6,
  'long_pair': 2e-6,
  'quick': 2e-6,
  'slow': 2e-5,
  'mixed': 2e-6,
  'two_full_batches': 2e-6,
  'same_day_ceiling': 2e-6,
  'probability_clamp': 5e-7,
  'difficulty_floor': 2e-6,
};

final _all = <String>[..._defaults, ..._pretrainOnly, ..._trained.keys];

const _outcomes = <String, FsrsFitOutcome>{
  'defaults': FsrsFitOutcome.defaults,
  'pretrain only': FsrsFitOutcome.pretrainOnly,
  'trained': FsrsFitOutcome.trained,
};

/// How many 32-bit floats apart [a] and [b] are, both positive.
int _ulps(double a, double b) {
  final bits = Int32List.view((Float32List.fromList([a, b])).buffer);
  return (bits[0] - bits[1]).abs();
}

List<double> _doubles(Object? list) => <double>[
  for (final v in list! as List) (v as num).toDouble(),
];

/// One reference case and what fsrs-rs gave for it.
class _Case {
  _Case(this.about, this.histories, this.expected);

  factory _Case.load(String name) => _cache.putIfAbsent(name, () {
    final doc = jsonDecode(
      File('test/fixtures/fsrs_fit/$name.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    return _Case(
      doc['about'] as String? ?? 'a simulated learner',
      _histories(doc['cards'] as List),
      doc['expected'] as Map<String, dynamic>,
    );
  });

  static final Map<String, _Case> _cache = <String, _Case>{};

  final String about;
  final List<List<FitReview>> histories;
  final Map<String, dynamic> expected;

  Map<String, dynamic> get _fit => expected['fit'] as Map<String, dynamic>;

  List<double> get fsrsRsFit => _doubles(_fit['parameters']);

  double get fsrsRsLogLoss => (_fit['log_loss'] as num).toDouble();

  double get defaultLogLoss => (expected['default_log_loss'] as num).toDouble();

  List<double> get pretrain => _doubles(expected['pretrain']);

  List<double> get trueParameters => _doubles(expected['true_parameters']);

  /// fsrs-rs fitted a first stability below [Fsrs.minStability], which
  /// the port raises to it.
  bool get minStabilityFloored =>
      fsrsRsFit.take(4).any((v) => v < Fsrs.minStability);

  /// The cards as the app's log would hold them. Each review is on its
  /// day, offset by the card's index in seconds and the review's in
  /// milliseconds, so that reviews sort as the harness sorts them: by day,
  /// then card, then review. Codes become grades as the app logs them:
  /// Again 1, Hard 3, Good 4, Easy a rated 5, and 5 an unrated 5.
  static List<List<FitReview>> _histories(List<dynamic> cards) {
    final base = DateTime.utc(2026, 1, 1);
    final histories = <List<FitReview>>[];
    for (final card in cards.cast<List<dynamic>>()) {
      final copies = card.length > 2 ? card[2] as int : 1;
      for (var copy = 0; copy < copies; copy++) {
        histories.add(
          _history(
            base,
            histories.length,
            card[0] as int,
            (card[1] as List).cast<int>(),
          ),
        );
      }
    }
    return histories;
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
      final code = flat[2 * i];
      day += flat[2 * i + 1];
      reviews.add((
        grade: const <int>[0, 1, 3, 4, 5, 5][code],
        at: base.add(Duration(days: day, seconds: index, milliseconds: i)),
        rated: code == 4,
      ));
    }
    return reviews;
  }
}
