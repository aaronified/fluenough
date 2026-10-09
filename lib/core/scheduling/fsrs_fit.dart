import 'dart:math' as math;
import 'dart:typed_data';

import 'fsrs.dart';
import 'rust_std_rng.dart';

/// One review in a pair's history, as [Fsrs.replay] takes it: the grade
/// as the log keeps it (0–5), when it was given, and whether the learner
/// rated it with the buttons ([Fsrs.ratingOf]).
typedef FitReview = ({int grade, DateTime at, bool rated});

/// What fitting a set of histories gives, decided by [FsrsFitGate].
enum FsrsFitOutcome {
  /// Too little to fit: FSRS-6's defaults stand, and [FsrsFit.fit] gives
  /// null.
  defaults,

  /// Enough to fit the first stabilities, w0 to w3, from first answers
  /// alone; w4 to w20 stay at their defaults.
  pretrainOnly,

  /// Enough to train all 21 parameters. In a window (`FsrsFit.fit`'s
  /// `from`) where no pair's first long-term review survives, there is
  /// nothing to fit w0 to w3 from: they stay the start's, and w4 to w20
  /// are trained.
  trained,
}

/// How much of a skill's history fitting can use, counted the way
/// `fsrs-rs` counts it, and so what [FsrsFit.fit] will give.
///
/// An item is one prediction: a review that is not a pair's first and
/// comes a day or more after the review before it. A *first long-term*
/// item is a pair's first such review. `fsrs-rs` drops every pair whose
/// first rating fewer than 20 pairs share among those that have reached a
/// first long-term review, and the smallest and the very long first gaps
/// of the rest, so nothing is fitted until 20 pairs share a first rating.
///
/// In a window, a pair whose first long-term review came before it has no
/// first long-term item, but its later reviews are still items. A window
/// can therefore hold many items and no surviving first long-term one;
/// then only w4 to w20 can be fitted, and only with enough to train.
class FsrsFitGate {
  const FsrsFitGate({
    required this.items,
    required this.firstLongTermItems,
    required this.survivingFirstLongTermItems,
    required this.survivingFirstLongTermByRating,
    required this.trainItems,
  });

  /// Every item, before anything is dropped.
  final int items;

  /// The items that are a pair's first long-term review.
  final int firstLongTermItems;

  /// [firstLongTermItems] that survive the outlier filter.
  final int survivingFirstLongTermItems;

  /// [survivingFirstLongTermItems] by the pair's first rating, Again to
  /// Easy.
  final List<int> survivingFirstLongTermByRating;

  /// The items that survive the outlier filter: what training sees.
  final int trainItems;

  FsrsFitOutcome get outcome {
    if (trainItems < 8) return FsrsFitOutcome.defaults;
    if (trainItems == survivingFirstLongTermItems || trainItems < 64) {
      // Nothing to fit the first stabilities from, and too little to
      // train: only in a window.
      return survivingFirstLongTermItems == 0
          ? FsrsFitOutcome.defaults
          : FsrsFitOutcome.pretrainOnly;
    }
    return FsrsFitOutcome.trained;
  }

  @override
  String toString() =>
      'FsrsFitGate(items: $items, first long-term: $firstLongTermItems, '
      'surviving: $survivingFirstLongTermItems '
      '$survivingFirstLongTermByRating, train: $trainItems, '
      '${outcome.name})';
}

/// Fits FSRS-6's 21 parameters to one skill's review histories: a port to
/// Dart of `fsrs-rs`'s `compute_parameters` for FSRS-6 (crate `fsrs`
/// 6.6.2), with `TrainingConfig::default()`, short-term on and no card ids.
///
/// It follows `fsrs-rs` step by step: the outlier filter and the gate
/// ([FsrsFitGate]), the search for the first stabilities w0 to w3, then 5
/// epochs of Adam (betas 0.7 and 0.98) at a learning rate of 0.04 on a
/// cosine schedule, over batches of 512 items sorted by length, on the
/// recency-weighted log loss plus an L2 pull towards the starting values,
/// with the gradient computed by hand as `fsrs-rs` does, and the
/// parameters clipped after every step. The batches are shuffled with a
/// port of Rust's `StdRng` ([RustStdRng]) from `fsrs-rs`'s seed, so they
/// run in `fsrs-rs`'s order.
///
/// One thing differs: **arithmetic.** `fsrs-rs` runs the model in 32-bit
/// floats; this runs it in 64-bit and rounds only the parameters and
/// Adam's state to 32 bits, as `fsrs-rs` stores them. Each step's
/// gradient therefore differs from `fsrs-rs`'s in its last bits, and the
/// difference grows a little with every step.
///
/// On the reference cases (`test/fsrs_fit_test.dart`) the gate's counts
/// match `fsrs-rs` exactly, the first stabilities to within one unit in
/// the last place of a 32-bit float, and a full fit every parameter to
/// within 2e-6, but for one learner's w3, on which the loss is nearly
/// flat: 7e-6.
///
/// While training, stability is floored at `fsrs-rs`'s 0.0001 days, not
/// the scheduler's [Fsrs.minStability] of 0.001; the two differ only
/// below 0.001 days.
///
/// Elapsed days are [Fsrs.elapsedDays], whole periods of 24 hours, so that
/// the fit is of the model the scheduler runs; `fsrs-rs`'s own converter
/// counts calendar days instead. A same-day review is never predicted, but
/// it stays in the history of the reviews after it.
///
/// Everything is deterministic: the same histories always give the same
/// parameters, which matters because every state is rebuilt from the log.
///
/// A fit is not always better than the set in use. `fsrs-rs`, like Anki,
/// keeps a new set only when its log loss on the same history is lower:
/// compare [logLoss] for both.
///
/// Two additions of the app's own, both off unless asked for, so that
/// without them every result is `fsrs-rs`'s:
///
/// - **A window** (`from`): every review still builds its pair's history,
///   but only those given at or after `from` are predicted, so only they
///   are learnt from, gated on, weighted and scored. A skill's window is
///   its reviews of the last three months or its last 1,000, whichever is
///   more (`docs/plans/skill-model.md`).
/// - **A start** (`start`): 21 values that fitting starts from in place of
///   FSRS-6's defaults, such as the skill's previous fit. They are what
///   the search for the first stabilities is pulled towards and fills in
///   from, what training starts from, and what its L2 term pulls towards,
///   as `fsrs-rs` does with the parameters its model starts from; with
///   only the first stabilities fitted, the rest are the start's. A refit
///   so starts from the last instead of from scratch, and moves from it
///   only as far as the new answers argue.
///
/// The two meet in one case `fsrs-rs` never sees, since it always has the
/// whole history: a window holding many reviews but no first long-term
/// review that survives the outlier filter, such as a learner who has
/// stopped adding words. `fsrs-rs` would refuse to fit; here w0 to w3 stay
/// the start's, unchanged through training, and w4 to w20 are trained
/// ([FsrsFitGate]).
abstract final class FsrsFit {
  /// Seeds the shuffle of the batch order: `fsrs-rs`'s seed.
  static const int seed = 2023;

  static const int _batchSize = 512;
  static const int _epochs = 5;
  static const double _learningRate = 0.04;
  static const int _maxSeqLen = 256;
  static const double _l2Weight = 0.5; // PENALTY_W_L2 x gamma 1.0

  /// [histories], one per pair of the skill, each oldest first, as items.
  /// What fitting would do with them, without fitting. With [from], only
  /// the reviews given at or after it are items.
  static FsrsFitGate gate(
    Iterable<Iterable<FitReview>> histories, {
    DateTime? from,
  }) => _Prepared(_items(histories, from)).gate;

  /// Parameters fitted to [histories], one per pair of the skill, each
  /// oldest first: 21 values for `Fsrs`'s `parameters`. Null when
  /// `fsrs-rs` would give FSRS-6's defaults unchanged (too little
  /// history: [FsrsFitOutcome.defaults]) or refuse to fit.
  ///
  /// With [FsrsFitOutcome.pretrainOnly], only w0 to w3 are fitted, and w4
  /// to w20 are [Fsrs.w] exactly. A first stability is never below
  /// [Fsrs.minStability], which the scheduler would raise it to anyway.
  ///
  /// A pair reset since (a leech's fresh start) should pass only its
  /// reviews since the reset, as the scheduler replays it.
  ///
  /// With [from], only the reviews given at or after it are predicted;
  /// those before still build each pair's history; a window with no
  /// surviving first long-term review keeps w0 to w3 at [start]'s, or
  /// FSRS-6's defaults, and trains the rest. With [start], 21
  /// values, fitting starts from them and is pulled towards them instead
  /// of FSRS-6's defaults (see the class), and with
  /// [FsrsFitOutcome.pretrainOnly] w4 to w20 are [start]'s exactly. Throws
  /// [ArgumentError] for a [start] that is not 21 values.
  static List<double>? fit(
    Iterable<Iterable<FitReview>> histories, {
    List<double>? start,
    DateTime? from,
  }) {
    if (start != null && start.length != Fsrs.w.length) {
      throw ArgumentError.value(
        start.length,
        'start',
        'must hold ${Fsrs.w.length} values, w0 to w20',
      );
    }
    final base = start == null
        ? _defaults
        : <double>[for (final v in start) _f32(v)];
    final prepared = _Prepared(_items(histories, from));
    final train = prepared.train;
    if (prepared.gate.outcome == FsrsFitOutcome.defaults) return null;
    if (prepared.gate.survivingFirstLongTermItems == 0) {
      // Only in a window, and only when trained (the gate): nothing to fit
      // the first stabilities from, so they are the start's throughout.
      final trained = _train(train, base.sublist(0, 4), base, keepFirst: true);
      if (trained == null) return null;
      return <double>[
        ...(start ?? Fsrs.w).sublist(0, 4),
        for (var i = 4; i < 21; i++) _shortest(trained[i]),
      ];
    }

    final ratingCount = <int, int>{};
    final pretrained = _pretrain(prepared, ratingCount, base);
    if (pretrained == null) return null; // fsrs-rs: NotEnoughData
    if (prepared.gate.outcome == FsrsFitOutcome.pretrainOnly) {
      return _output(pretrained, (start ?? Fsrs.w).sublist(4));
    }

    final trained = _train(train, pretrained, base);
    if (trained == null) return null; // fsrs-rs: InvalidInput
    final first = _smoothAndFill(
      {for (var r = 1; r <= 4; r++) r: trained[r - 1]},
      ratingCount,
      base,
    );
    if (first == null) return null;
    return _output(first, <double>[
      for (var i = 4; i < 21; i++) _shortest(trained[i]),
    ]);
  }

  /// The log loss of [parameters] on [histories]: how well the scheduler,
  /// run with them, predicts each review that is not a pair's first and
  /// comes a day or more after the one before. Weighted towards recent
  /// reviews, as `fsrs-rs`'s `evaluate` weights it. Null when there is no
  /// such review. Lower is better. With [from], only the reviews given at
  /// or after it are predicted, as [fit] predicts them.
  static double? logLoss(
    Iterable<Iterable<FitReview>> histories, {
    List<double> parameters = Fsrs.w,
    DateTime? from,
  }) {
    final predictions = <(DateTime, int, int, double, bool)>[];
    for (final (p, history) in histories.indexed) {
      FsrsState? state;
      for (final (i, review) in history.indexed) {
        if (state != null &&
            Fsrs.elapsedDays(state.lastReviewAt, review.at) >= 1 &&
            (from == null || !review.at.isBefore(from))) {
          predictions.add((
            review.at,
            p,
            i,
            Fsrs.retrievability(state, review.at, parameters: parameters),
            Fsrs.ratingOf(review.grade, rated: review.rated) != Rating.again,
          ));
        }
        state = Fsrs.next(
          state,
          review.grade,
          now: review.at,
          rated: review.rated,
          parameters: parameters,
        );
      }
    }
    if (predictions.isEmpty) return null;
    predictions.sort(_byTime);
    final last = math.max(predictions.length - 1, 1);
    var loss = 0.0;
    var weights = 0.0;
    for (final (i, (_, _, _, p, recalled)) in predictions.indexed) {
      final weight = 0.25 + 0.75 * math.pow(i / last, 3).toDouble();
      final r = p.clamp(0.0001, 0.9999);
      loss -= weight * (recalled ? math.log(r) : math.log(1 - r));
      weights += weight;
    }
    return loss / weights;
  }

  /// The loss training minimises, without its L2 term, for every item of
  /// [histories] as one batch, and its gradient with respect to
  /// [parameters], as the hand-written backward pass computes it. For
  /// checking that pass against finite differences.
  static ({double loss, List<double> gradient}) lossAndGradient(
    Iterable<Iterable<FitReview>> histories,
    List<double> parameters,
  ) {
    final items = _items(histories);
    final weights = _recencyWeights(items.length);
    final model = _Model(parameters, _longest(items));
    final gradient = Float64List(21);
    var loss = 0.0;
    for (final (i, item) in items.indexed) {
      loss += model.lossAndGradient(item, weights[i], gradient);
    }
    return (loss: loss, gradient: gradient.toList());
  }

  // ---------------------------------------------------------------------
  // Items and the gate (fsrs-rs dataset.rs, training.rs:605-718)

  static int _byTime(
    (DateTime, int, int, Object?, Object?) a,
    (DateTime, int, int, Object?, Object?) b,
  ) {
    final byTime = a.$1.compareTo(b.$1);
    if (byTime != 0) return byTime;
    final byPair = a.$2.compareTo(b.$2);
    return byPair != 0 ? byPair : a.$3.compareTo(b.$3);
  }

  /// One item per review that is not a pair's first and comes a day or
  /// more after the one before, in the order the reviews were given; ties
  /// by pair, then by review. With [from], only reviews given at or after
  /// it.
  static List<_Item> _items(
    Iterable<Iterable<FitReview>> histories, [
    DateTime? from,
  ]) {
    final keyed = <(DateTime, int, int, _Item, Object?)>[];
    for (final (p, history) in histories.indexed) {
      final reviews = history.toList();
      if (reviews.isEmpty) continue;
      final pair = _Pair(reviews);
      for (var i = 1; i < reviews.length; i++) {
        if (pair.dt[i] > 0 && (from == null || !reviews[i].at.isBefore(from))) {
          keyed.add((reviews[i].at, p, i, _Item(pair, i), null));
        }
      }
    }
    keyed.sort(_byTime);
    return <_Item>[for (final k in keyed) k.$4];
  }

  static int _longest(List<_Item> items) =>
      items.fold(1, (longest, item) => math.max(longest, item.end + 1));

  /// fsrs-rs training.rs:539-562, in f32.
  static Float64List _recencyWeights(int n) {
    final weights = Float64List(n);
    final length = _f32(math.max(n - 1.0, 1.0));
    for (var i = 0; i < n; i++) {
      final x = _f32(i / length);
      final cube = _f32(_f32(x * x) * x);
      weights[i] = _f32(0.25 + _f32(0.75 * cube));
    }
    return weights;
  }

  // ---------------------------------------------------------------------
  // Pretrain: w0..w3 from first long-term reviews
  // (fsrs-rs parameter_initialization.rs)

  /// [base]: the start, as 32-bit floats: what each first stability is
  /// pulled towards, and the curve's decay.
  static List<double>? _pretrain(
    _Prepared prepared,
    Map<int, int> ratingCount,
    List<double> base,
  ) {
    final train = prepared.train;
    var recalled = 0;
    for (final item in train) {
      if (item.pair.rating[item.end] > 1) recalled++;
    }
    final averageRecall = _f32(recalled / train.length);

    // first rating -> first long-term gap -> (recalled, count)
    final groups = <int, Map<int, List<int>>>{};
    for (final item in prepared.initialization) {
      final r0 = item.pair.rating[0];
      final first = item.pair.firstLongTerm;
      final group = groups
          .putIfAbsent(r0, () => <int, List<int>>{})
          .putIfAbsent(item.pair.dt[first], () => <int>[0, 0]);
      if (item.pair.rating[first] > 1) group[0]++;
      group[1]++;
    }
    final stabilities = <int, double>{};
    for (final MapEntry(key: r0, value: byGap) in groups.entries) {
      final gaps = byGap.keys.toList()..sort();
      final t = <double>[for (final g in gaps) g.toDouble()];
      final count = <double>[for (final g in gaps) byGap[g]![1].toDouble()];
      final recall = <double>[
        for (final (i, g) in gaps.indexed)
          ((byGap[g]![0] / count[i]) * count[i] + averageRecall) /
              (count[i] + 1),
      ];
      ratingCount[r0] = count.fold(0.0, (a, b) => a + b).toInt();
      stabilities[r0] = _f32(
        _searchStability(t, recall, count, base[r0 - 1], base[20]),
      );
    }
    return _smoothAndFill(stabilities, ratingCount, base);
  }

  /// Ternary search for the first stability that best fits the recall
  /// at each gap, pulled towards the start's (fsrs-rs :126-171), on the
  /// curve of the start's [w20].
  static double _searchStability(
    List<double> t,
    List<double> recall,
    List<double> count,
    double defaultS0,
    double w20,
  ) {
    final decay = -w20;
    final factor = math.pow(0.9, 1 / decay).toDouble() - 1;
    double loss(double s) {
      var sum = 0.0;
      for (var i = 0; i < t.length; i++) {
        final y = math.pow(t[i] / s * factor + 1, decay);
        sum +=
            -(recall[i] * math.log(y) + (1 - recall[i]) * math.log(1 - y)) *
            count[i];
      }
      return sum + (s - defaultS0).abs() / 16;
    }

    var low = _sMin;
    var high = _initSMax;
    var optimal = defaultS0;
    for (var i = 0; high - low > _f64Epsilon && i < 1000; i++) {
      final mid1 = low + (high - low) / 3;
      final mid2 = high - (high - low) / 3;
      if (loss(mid1) < loss(mid2)) {
        high = mid2;
      } else {
        low = mid1;
      }
      optimal = (high + low) / 2;
    }
    return optimal;
  }

  /// Keeps the first stabilities in rating order and fills in those of
  /// first ratings with no data from the rest (fsrs-rs :173-283), in f32.
  /// Null with none to fill from. One rating alone scales [base]'s.
  static List<double>? _smoothAndFill(
    Map<int, double> stability,
    Map<int, int> count,
    List<double> base,
  ) {
    final s = <int, double>{
      for (final MapEntry(:key, :value) in stability.entries)
        if (count.containsKey(key)) key: value,
    };
    for (final (small, big) in const [
      (1, 2),
      (2, 3),
      (3, 4),
      (1, 3),
      (2, 4),
      (1, 4),
    ]) {
      final sv = s[small];
      final bv = s[big];
      if (sv != null && bv != null && sv > bv) {
        if (count[small]! > count[big]!) {
          s[big] = sv;
        } else {
          s[small] = bv;
        }
      }
    }

    final w1 = _f32(0.41);
    final w2 = _f32(0.54);
    double pw(double a, double e) => _f32(math.pow(a, e).toDouble());
    double inv(double x) => _f32(1 / x);
    double one(double x) => _f32(1 - x);
    double mul(double a, double b) => _f32(a * b);

    final List<double> init;
    switch (s.length) {
      case 0:
        return null;
      case 1:
        final MapEntry(key: rating, value: value) = s.entries.single;
        final factor = _f32(value / base[rating - 1]);
        init = <double>[for (var r = 0; r < 4; r++) mul(base[r], factor)]
          ..sort();
      case 2 || 3:
        final r = <double?>[null, s[1], s[2], s[3], s[4]];
        if (s.length == 2) {
          final [_, r1, r2, r3, r4] = r;
          if (r1 == null && r2 == null) {
            final e = inv(one(w2));
            final v2 = mul(pw(r3!, e), pw(r4!, one(e)));
            r[2] = v2;
            r[1] = mul(pw(v2, inv(w1)), pw(r3, one(inv(w1))));
          } else if (r1 == null && r3 == null) {
            final v3 = mul(pw(r2!, one(w2)), pw(r4!, w2));
            r[3] = v3;
            r[1] = mul(pw(r2, inv(w1)), pw(v3, one(inv(w1))));
          } else if (r1 == null && r4 == null) {
            r[4] = mul(pw(r2!, one(inv(w2))), pw(r3!, inv(w2)));
            r[1] = mul(pw(r2, inv(w1)), pw(r3, one(inv(w1))));
          } else if (r2 == null && r3 == null) {
            // w1.mul_add(-w2, w1 + w2), fused: one rounding.
            final d = _f32(w1 * -w2 + _f32(w1 + w2));
            final a = _f32(w1 / d);
            final b = _f32(w2 / d);
            r[2] = mul(pw(r1!, a), pw(r4!, one(a)));
            r[3] = mul(pw(r1, one(b)), pw(r4, b));
          } else if (r2 == null && r4 == null) {
            final v2 = mul(pw(r1!, w1), pw(r3!, one(w1)));
            r[2] = v2;
            r[4] = mul(pw(v2, one(inv(w2))), pw(r3, inv(w2)));
          } else if (r3 == null && r4 == null) {
            final e = inv(one(w1));
            final v3 = mul(pw(r1!, one(e)), pw(r2!, e));
            r[3] = v3;
            r[4] = mul(pw(r2, one(inv(w2))), pw(v3, inv(w2)));
          }
        } else {
          final [_, r1, r2, r3, r4] = r;
          if (r1 == null) {
            r[1] = mul(pw(r2!, inv(w1)), pw(r3!, one(inv(w1))));
          } else if (r2 == null) {
            r[2] = mul(pw(r1, w1), pw(r3!, one(w1)));
          } else if (r3 == null) {
            r[3] = mul(pw(r2, one(w2)), pw(r4!, w2));
          } else if (r4 == null) {
            r[4] = mul(pw(r2, one(inv(w2))), pw(r3, inv(w2)));
          }
        }
        init = <double>[for (var i = 1; i <= 4; i++) r[i]!];
      default:
        init = <double>[for (var i = 1; i <= 4; i++) s[i]!];
    }
    return <double>[for (final v in init) v.clamp(_sMin, _initSMax)];
  }

  // ---------------------------------------------------------------------
  // Training (fsrs-rs training.rs:1245-1419)

  /// With [keepFirst], w0 to w3 are held at [pretrained] throughout.
  static Float32List? _train(
    List<_Item> train,
    List<double> pretrained,
    List<double> base, {
    bool keepFirst = false,
  }) {
    final weights = _recencyWeights(train.length);
    final kept = <(_Item, double)>[
      for (final (i, item) in train.indexed)
        if (item.end + 1 <= _maxSeqLen) (item, weights[i]),
    ];
    final total = kept.length;
    // A stable sort by length, cut into batches.
    final sorted = kept.indexed.toList()
      ..sort((a, b) {
        final byLength = a.$2.$1.end.compareTo(b.$2.$1.end);
        return byLength != 0 ? byLength : a.$1.compareTo(b.$1);
      });
    final batches = <List<(_Item, double)>>[
      for (var start = 0; start < total; start += _batchSize)
        <(_Item, double)>[
          for (final (_, entry) in sorted.skip(start).take(_batchSize)) entry,
        ],
    ];

    final w = Float32List.fromList(<double>[...pretrained, ...base.sublist(4)]);
    final initial = Float32List.fromList(w);
    final adam = _Adam();
    final schedule = _CosineAnnealing(
      ((total ~/ _batchSize + 1) * _epochs).toDouble(),
      _learningRate,
    );
    final random = RustStdRng.seedFromU64(seed);
    final order = <int>[for (var i = 0; i < batches.length; i++) i];
    final model = _Model(w, _maxSeqLen);
    final grad64 = Float64List(21);
    final grad = Float32List(21);

    for (var epoch = 0; epoch < _epochs; epoch++) {
      random.shuffle(order);
      for (final index in order) {
        final batch = batches[index];
        model.parameters = w;
        grad64.fillRange(0, 21, 0);
        for (final (item, weight) in batch) {
          model.lossAndGradient(item, weight, grad64);
        }
        final scale = _l2Weight * batch.length / total;
        for (var j = 0; j < 21; j++) {
          final sigma = _paramsStddev[j];
          final diff = w[j] - initial[j];
          final l2 = _f32(2 * diff / (sigma * sigma) * scale);
          grad[j] = _f32(_f32(grad64[j]) + (l2.isFinite ? l2 : 0));
        }
        adam.step(w, grad, schedule.step());
        _clip(w);
        if (keepFirst) w.setRange(0, 4, initial);
      }
    }
    for (final v in w) {
      if (v.isInfinite || v.isNaN) return null;
    }
    return w;
  }

  /// fsrs-rs parameter_clipper_v6.rs, with one relearning step and
  /// short-term on.
  static void _clip(Float32List w) {
    for (var i = 0; i < 21; i++) {
      final (low, high) = _clips[i];
      w[i] = w[i].clamp(low, high);
    }
  }

  static final List<(double, double)> _clips = <(double, double)>[
    for (final (low, high) in _bounds) (_f32(low), _f32(high)),
  ];

  /// What training clips each of w0 to w20 to (fsrs-rs
  /// parameter_clipper_v6.rs), as decimals.
  static const List<(double, double)> _bounds = <(double, double)>[
    (0.0001, 100), (0.0001, 100), (0.0001, 100), (0.0001, 100), //
    (1, 10), (0.001, 4), (0.001, 4), (0.001, 0.75), (0, 4.5), (0, 0.8),
    (0.001, 3.5), (0.001, 5), (0.001, 0.25), (0.001, 0.9), (0, 4), (0, 1),
    (1, 6), (0, 2), (0, 2), (0.01, 0.8), (0.1, 0.8),
  ];

  /// Whether [w] is 21 values, each within what training clips it to:
  /// what a fit, or FSRS-6's defaults, can be. A set outside them, such
  /// as one with w20 at 0, can make the scheduler divide by zero.
  static bool isPlausible(List<double> w) {
    if (w.length != _bounds.length) return false;
    for (final (i, v) in w.indexed) {
      final (low, high) = _bounds[i];
      // A fit stores the shortest decimal of a 32-bit float, which may
      // lie a hair outside the decimal bound the float was clipped to.
      if (!(v >= low * (1 - 1e-6) && v <= high * (1 + 1e-6))) return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------
  // Output

  static List<double> _output(List<double> first, List<double> rest) =>
      <double>[
        for (final v in first) math.max(_shortest(v), Fsrs.minStability),
        ...rest,
      ];

  /// The shortest decimal that reads back as the same 32-bit float [x],
  /// as `fsrs-rs` prints it: 6.4133, not 6.413300037384033.
  static double _shortest(double x) {
    for (var digits = 1; digits <= 9; digits++) {
      final candidate = double.parse(x.toStringAsPrecision(digits));
      if (_f32(candidate) == x) return candidate;
    }
    return x;
  }
}

// -----------------------------------------------------------------------
// Constants (fsrs-rs simulation.rs:199-202, parameter_initialization.rs:124,
// training_v6.rs:5-8, inference_v6.rs:4-26), as the 32-bit floats it uses.

final double _sMin = _f32(0.0001);
const double _sMax = 36500;
const double _dMin = 1;
const double _dMax = 10;
const double _initSMax = 100;
const double _f64Epsilon = 2.220446049250313e-16;
final double _minProb = _f32(1e-7);
final double _maxProb = _f32(1 - _f32(1e-7));

final List<double> _defaults = <double>[for (final v in Fsrs.w) _f32(v)];

final List<double> _paramsStddev = <double>[
  for (final v in const <double>[
    6.43, 9.66, 17.58, 27.85, 0.57, 0.28, 0.6, 0.12, 0.39, 0.18, 0.33, //
    0.3, 0.09, 0.16, 0.57, 0.25, 1.03, 0.31, 0.32, 0.14, 0.27,
  ])
    _f32(v),
];

final Float32List _f32Buffer = Float32List(1);

/// [x] rounded to the nearest 32-bit float.
double _f32(double x) {
  _f32Buffer[0] = x;
  return _f32Buffer[0];
}

double _clamp(double x, double low, double high) =>
    x < low ? low : (x > high ? high : x);

/// 1 inside the range, its ends included, else 0 (fsrs-rs `clamp_grad`).
double _clampGrad(double x, double low, double high) =>
    x >= low && x <= high ? 1 : 0;

// -----------------------------------------------------------------------
// Data

/// One pair's reviews: days since the review before, and FSRS ratings.
class _Pair {
  _Pair(List<FitReview> reviews)
    : dt = Int32List(reviews.length),
      rating = Int8List(reviews.length) {
    for (final (i, review) in reviews.indexed) {
      rating[i] = Fsrs.ratingOf(review.grade, rated: review.rated).value;
      if (i > 0) dt[i] = Fsrs.elapsedDays(reviews[i - 1].at, review.at);
    }
    firstLongTerm = dt.indexWhere((d) => d >= 1);
  }

  final Int32List dt;
  final Int8List rating;

  /// The index of the first review a day or more after the one before, or
  /// -1.
  late final int firstLongTerm;
}

/// The reviews of [pair] up to [end]: [end] is predicted from the rest.
class _Item {
  const _Item(this.pair, this.end);

  final _Pair pair;
  final int end;

  /// How many of the item's reviews come a day or more after the one
  /// before (fsrs-rs `long_term_review_cnt`).
  int get longTermReviews {
    var n = 0;
    for (var i = 0; i <= end; i++) {
      if (pair.dt[i] >= 1) n++;
    }
    return n;
  }
}

/// The items split as fsrs-rs's `prepare_training_data` splits them,
/// through the outlier filter (dataset.rs:96-168).
class _Prepared {
  _Prepared(List<_Item> items) {
    final firstLongTerm = <_Item>[
      for (final item in items)
        if (item.longTermReviews == 1) item,
    ];
    // first rating -> first long-term gap -> items
    final groups = <int, Map<int, List<_Item>>>{};
    for (final item in firstLongTerm) {
      groups
          .putIfAbsent(item.pair.rating[0], () => <int, List<_Item>>{})
          .putIfAbsent(_bucket(item), () => <_Item>[])
          .add(item);
    }
    final removed = <(int, int)>{};
    final kept = <_Item>[];
    for (final r0 in groups.keys.toList()..sort()) {
      final byGap = groups[r0]!;
      // Smallest group first, then shortest gap.
      final gaps = byGap.keys.toList()
        ..sort((a, b) {
          final bySize = byGap[a]!.length.compareTo(byGap[b]!.length);
          return bySize != 0 ? bySize : a.compareTo(b);
        });
      final total = byGap.values.fold(0, (n, g) => n + g.length);
      var hasBeenRemoved = 0;
      for (final gap in gaps) {
        final n = byGap[gap]!.length;
        if (hasBeenRemoved + n >= math.max(20, total ~/ 20)) {
          if (n < 6 || gap > (r0 != 4 ? 100 : 365)) {
            removed.add((r0, gap));
          } else {
            kept.addAll(byGap[gap]!);
          }
        } else {
          hasBeenRemoved += n;
          removed.add((r0, gap));
        }
      }
    }
    initialization = kept;
    train = <_Item>[
      for (final item in items)
        if (item.longTermReviews == 0 ||
            !removed.contains((item.pair.rating[0], _bucket(item))))
          item,
    ];
    final byRating = List<int>.filled(4, 0);
    for (final item in kept) {
      byRating[item.pair.rating[0] - 1]++;
    }
    gate = FsrsFitGate(
      items: items.length,
      firstLongTermItems: firstLongTerm.length,
      survivingFirstLongTermItems: kept.length,
      survivingFirstLongTermByRating: List<int>.unmodifiable(byRating),
      trainItems: train.length,
    );
  }

  /// The first long-term gap of [item]'s pair, at least 1.
  static int _bucket(_Item item) =>
      math.max(item.pair.dt[item.pair.firstLongTerm], 1);

  /// The surviving first long-term items, in no particular order.
  late final List<_Item> initialization;

  /// The surviving items, in time order.
  late final List<_Item> train;

  late final FsrsFitGate gate;
}

// -----------------------------------------------------------------------
// The model and its gradient (fsrs-rs analytic_v6.rs), in f64

class _Model {
  _Model(List<double> parameters, int longest)
    : _lastS = Float64List(longest),
      _lastD = Float64List(longest),
      _stateS = Float64List(longest),
      _stateD = Float64List(longest),
      _r = Float64List(longest),
      _base = Float64List(longest),
      _preS = Float64List(longest),
      _meanD = Float64List(longest),
      _raw = Float64List(longest),
      _value = Float64List(longest),
      _flag = Uint8List(longest) {
    this.parameters = parameters;
  }

  late List<double> _w;
  late double _decay;
  late double _factor;
  late double _dFactorDDecay;
  late double _easyD;

  set parameters(List<double> parameters) {
    _w = List<double>.of(parameters);
    _decay = -_w[20];
    _factor = math.exp(math.log(0.9) / _decay) - 1;
    const c = -0.10536051565782628; // ln 0.9
    _dFactorDDecay = math.exp(c / _decay) * (-c / (_decay * _decay));
    _easyD = _initDifficulty(4);
  }

  // Per step of the history: the state in, clamped and not, and what the
  // backward pass needs of the branch taken.
  final Float64List _lastS;
  final Float64List _lastD;
  final Float64List _stateS;
  final Float64List _stateD;
  final Float64List _r;
  final Float64List _base;
  final Float64List _preS;
  final Float64List _meanD;
  final Float64List _raw;
  final Float64List _value;
  final Uint8List _flag;

  static const int _usedFloor = 1; // a lapse took s / exp(w17 * w18)
  static const int _rawActive = 2; // a same-day multiplier was not floored

  double _initDifficulty(int rating) =>
      _w[4] - math.exp(_w[5] * (rating - 1)) + 1;

  /// Adds the weighted loss of predicting [item]'s last review to its
  /// gradient into [gw], and returns the loss.
  double lossAndGradient(_Item item, double weight, Float64List gw) {
    final w = _w;
    final dt = item.pair.dt;
    final ratings = item.pair.rating;
    final end = item.end;

    // Forward.
    var s = 0.0;
    var d = 0.0;
    for (var j = 0; j < end; j++) {
      final g = ratings[j];
      _stateS[j] = s;
      _stateD[j] = d;
      final lastS = _clamp(s, _sMin, _sMax);
      final lastD = _clamp(d, _dMin, _dMax);
      _lastS[j] = lastS;
      _lastD[j] = lastD;
      _flag[j] = 0;
      if (j == 0 && s == 0) {
        final newS = w[g - 1];
        _preS[j] = newS;
        s = _clamp(newS, _sMin, _sMax);
        d = _clamp(_initDifficulty(g), _dMin, _dMax);
        continue;
      }
      final t = math.max(dt[j], 0).toDouble();
      final base = t / lastS * _factor + 1;
      final r = math.pow(base, _decay).toDouble();
      _base[j] = base;
      _r[j] = r;
      double newS;
      if (t == 0) {
        final raw = math.exp(w[17] * (g - 3 + w[18])) * math.pow(lastS, -w[19]);
        if (!(g >= 2 && raw < 1)) _flag[j] |= _rawActive;
        final value = g >= 2 ? math.max(raw, 1.0) : raw;
        _raw[j] = raw;
        _value[j] = value;
        newS = lastS * value;
      } else if (g == 1) {
        final raw =
            w[11] *
            math.pow(lastD, -w[12]) *
            (math.pow(lastS + 1, w[13]) - 1) *
            math.exp((1 - r) * w[14]);
        final floor = lastS / math.exp(w[17] * w[18]);
        _raw[j] = raw;
        _value[j] = floor;
        if (floor < raw) {
          _flag[j] |= _usedFloor;
          newS = floor;
        } else {
          newS = raw;
        }
      } else {
        final hardPenalty = g == 2 ? w[15] : 1.0;
        final easyBonus = g == 4 ? w[16] : 1.0;
        final increase =
            math.exp(w[8]) *
            (11 - lastD) *
            math.pow(lastS, -w[9]) *
            (math.exp((1 - r) * w[10]) - 1) *
            hardPenalty *
            easyBonus;
        newS = lastS * (increase + 1);
      }
      final deltaD = -w[6] * (g - 3);
      final nextD = lastD + (10 - lastD) * deltaD / 9;
      final meanD = w[7] * (_easyD - nextD) + nextD;
      _preS[j] = newS;
      _meanD[j] = meanD;
      s = _clamp(newS, _sMin, _sMax);
      d = _clamp(meanD, _dMin, _dMax);
    }

    // The prediction and its loss.
    final t = math.max(dt[end], 0).toDouble();
    final base = t / s * _factor + 1;
    final rRaw = math.pow(base, _decay).toDouble();
    final label = ratings[end] > 1 ? 1.0 : 0.0;
    if (weight == 0) return 0;
    final r = _clamp(rRaw, _minProb, _maxProb);
    final loss =
        -(label * math.log(r) + (1 - label) * math.log(1 - r)) * weight;
    final gR = rRaw > _minProb && rRaw < _maxProb
        ? -weight * (label / r - (1 - label) / (1 - r))
        : 0.0;

    // Backward.
    var gS = _curveBackward(t, s, rRaw, base, gR, gw);
    var gD = 0.0;
    for (var j = end - 1; j >= 0; j--) {
      final g = ratings[j];
      final gPreS = gS * _clampGrad(_preS[j], _sMin, _sMax);
      if (j == 0 && _stateS[j] == 0) {
        gw[g - 1] += gPreS;
        final rawD = _initDifficulty(g);
        final gRawD = gD * _clampGrad(rawD, _dMin, _dMax);
        if (gRawD != 0) {
          gw[4] += gRawD;
          gw[5] += gRawD * -(g - 1) * math.exp((g - 1) * w[5]);
        }
        gS = 0;
        gD = 0;
        continue;
      }
      final lastS = _lastS[j];
      final lastD = _lastD[j];
      final r = _r[j];
      var gLastS = 0.0;
      var gLastD = 0.0;
      var gRj = 0.0;
      final stepT = math.max(dt[j], 0).toDouble();
      if (stepT == 0) {
        if (gPreS != 0) {
          gLastS += gPreS * _value[j];
          if (_flag[j] & _rawActive != 0) {
            final gRaw = gPreS * lastS;
            final raw = _raw[j];
            gw[17] += gRaw * raw * (g - 3 + w[18]);
            gw[18] += gRaw * raw * w[17];
            gw[19] += gRaw * raw * -math.log(lastS);
            gLastS += gRaw * raw * (-w[19] / lastS);
          }
        }
      } else if (g == 1) {
        if (gPreS != 0) {
          if (_flag[j] & _usedFloor != 0) {
            final floor = _value[j];
            gw[17] += gPreS * floor * -w[18];
            gw[18] += gPreS * floor * -w[17];
            gLastS += gPreS * floor / lastS;
          } else {
            final raw = _raw[j];
            final base1 = lastS + 1;
            final p = math.pow(base1, w[13]).toDouble();
            final dPow = math.pow(lastD, -w[12]).toDouble();
            final er = math.exp((1 - r) * w[14]);
            gw[11] += gPreS * raw / w[11];
            gw[12] += gPreS * raw * -math.log(lastD);
            gw[13] += gPreS * w[11] * dPow * er * p * math.log(base1);
            gw[14] += gPreS * raw * (1 - r);
            gLastS += gPreS * w[11] * dPow * er * w[13] * p / base1;
            gLastD += gPreS * raw * (-w[12] / lastD);
            gRj += gPreS * raw * -w[14];
          }
        }
      } else if (gPreS != 0) {
        final a = math.exp(w[8]);
        final b = 11 - lastD;
        final cS = math.pow(lastS, -w[9]).toDouble();
        final e = math.exp((1 - r) * w[10]) - 1;
        final expE = e + 1;
        final hp = g == 2 ? w[15] : 1.0;
        final eb = g == 4 ? w[16] : 1.0;
        final increase = a * b * cS * e * hp * eb;
        final gIncrease = gPreS * lastS;
        gLastS +=
            gPreS * (increase + 1) + gIncrease * increase * (-w[9] / lastS);
        gLastD += -(gIncrease * a * cS * e * hp * eb);
        gRj += gIncrease * a * b * cS * hp * eb * (-w[10] * expE);
        gw[8] += gIncrease * increase;
        gw[9] += gIncrease * increase * -math.log(lastS);
        gw[10] += gIncrease * a * b * cS * hp * eb * ((1 - r) * expE);
        if (g == 2) gw[15] += gIncrease * a * b * cS * e * eb;
        if (g == 4) gw[16] += gIncrease * a * b * cS * e * hp;
      }
      // Difficulty.
      if (gD != 0) {
        final gMean = gD * _clampGrad(_meanD[j], _dMin, _dMax);
        if (gMean != 0) {
          final ratingMinus3 = (g - 3).toDouble();
          final deltaD = -w[6] * ratingMinus3;
          final nextD = lastD + (10 - lastD) * deltaD / 9;
          gw[7] += gMean * (_easyD - nextD);
          gw[4] += gMean * w[7];
          gw[5] += gMean * w[7] * -3 * math.exp(3 * w[5]);
          final gNext = gMean * (1 - w[7]);
          gw[6] += gNext * (10 - lastD) * -ratingMinus3 / 9;
          gLastD += gNext * (1 - deltaD / 9);
        }
      }
      gLastS += _curveBackward(stepT, lastS, r, _base[j], gRj, gw);
      gS = gLastS * _clampGrad(_stateS[j], _sMin, _sMax);
      gD = gLastD * _clampGrad(_stateD[j], _dMin, _dMax);
    }
    return loss;
  }

  /// Through R = (1 + factor * t / s)^decay: adds to w20's gradient and
  /// returns the gradient with respect to s.
  double _curveBackward(
    double t,
    double s,
    double r,
    double base,
    double gR,
    Float64List gw,
  ) {
    if (gR == 0) return 0;
    final dBdS = -t * _factor / (s * s);
    final gS = gR * r * _decay / base * dBdS;
    final dBdDecay = t / s * _dFactorDDecay;
    final dRdDecay = r * (math.log(base) + _decay / base * dBdDecay);
    gw[20] += -gR * dRdDecay;
    return gS;
  }
}

// -----------------------------------------------------------------------
// The optimiser

/// Adam as fsrs-rs's `HostAdam` runs it, in f32 (training.rs:1245-1276).
class _Adam {
  final Float32List _m = Float32List(21);
  final Float32List _v = Float32List(21);
  int _time = 0;

  static final double _beta1 = _f32(0.7);
  static final double _beta2 = _f32(0.98);
  static final double _epsilon = _f32(1e-8);

  void step(Float32List w, Float32List grad, double learningRate) {
    _time++;
    final mCorrection = _f32(1 - _powi(_beta1, _time));
    final vCorrection = _f32(1 - _powi(_beta2, _time));
    final lr = _f32(learningRate);
    final oneMinusBeta1 = _f32(1 - _beta1);
    final oneMinusBeta2 = _f32(1 - _beta2);
    for (var i = 0; i < 21; i++) {
      final g = grad[i];
      _m[i] = _f32(_f32(_m[i] * _beta1) + _f32(g * oneMinusBeta1));
      _v[i] = _f32(_f32(_v[i] * _beta2) + _f32(_f32(g * g) * oneMinusBeta2));
      final mHat = _f32(_m[i] / mCorrection);
      final vHat = _f32(_v[i] / vCorrection);
      final denominator = _f32(_f32(math.sqrt(vHat)) + _epsilon);
      w[i] = _f32(w[i] - _f32(_f32(lr * mHat) / denominator));
    }
  }

  /// `f32::powi`, by repeated squaring in f32, as compiler-rt computes it.
  static double _powi(double a, int b) {
    var r = 1.0;
    var x = a;
    var n = b;
    while (true) {
      if (n & 1 == 1) r = _f32(r * x);
      n >>= 1;
      if (n == 0) break;
      x = _f32(x * x);
    }
    return r;
  }
}

/// fsrs-rs's `CosineAnnealingLR` with no floor: the rate for each step,
/// from [_initial] down along half a cosine over [_tMax] steps.
class _CosineAnnealing {
  _CosineAnnealing(this._tMax, this._initial) : _current = _initial;

  final double _tMax;
  final double _initial;
  double _current;
  double _step = -1;

  double step() {
    _step++;
    if (_step == 0) {
      _current = _initial;
    } else if ((_step - 1 - _tMax).remainder(2 * _tMax) == 0) {
      _current = _initial * (1 - math.cos(math.pi / _tMax)) / 2;
    } else {
      _current =
          (1 + math.cos(math.pi * _step / _tMax)) /
          (1 + math.cos(math.pi * (_step - 1) / _tMax)) *
          _current;
    }
    return _current;
  }
}
