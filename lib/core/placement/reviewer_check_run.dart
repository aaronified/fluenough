import 'dart:math' as math;

import 'item_registry.dart';
import 'reviewer_check_bank.dart';
import 'reviewer_check_rules.dart';

// One run of the reviewer check (ADR-0058, decision 1): the stricter mode of
// placement. It differs from "Find my level" on purpose:
//
//  * only top-band items, from the picks the owner's rule allows;
//  * a fixed number of scored items per group, tested against the null of
//    guessing at a confidence target far above placement's (a guesser passes
//    a group with a chance of at most 1 in 100);
//  * NO feedback of any kind while it runs: the run says nothing of right or
//    wrong, and the screen shows no score, count or running total;
//  * an "also right" tap suspends an item and takes it out of the score;
//  * no single miss decides: a group is passed by beating guessing, which a
//    run with a few misses still does;
//  * failing only means "not yet eligible".
//
// Pure Dart. A run is a function of its seed.

/// How one item ended.
enum ReviewerOutcome {
  right,
  wrong,
  dontKnow,

  /// "This is also right": out of the score.
  suspended,

  /// Could not be shown or played: out of the score.
  skipped,
}

/// One question as the screen shows it: plain data, no widgets. It carries
/// no key: [options] are in the order shown.
class ReviewerQuestion {
  const ReviewerQuestion({
    required this.id,
    required this.format,
    required this.group,
    required this.item,
    this.shown,
    this.shownIsTarget = false,
    this.audio,
    this.options = const <String>[],
    this.optionsAreTarget = false,
    this.gapBefore = '',
    this.gapAfter = '',
  });

  final String id;
  final String format;
  final ReviewerGroup group;

  /// The bank item, for its card (the screen plays a word from its card).
  final RegItem item;

  /// What is shown: a word or sentence of the language ([shownIsTarget]) or
  /// a meaning. Null for a question that is only heard.
  final String? shown;
  final bool shownIsTarget;

  /// The text to play, in the language learned; null when not heard.
  final String? audio;

  final List<String> options;
  final bool optionsAreTarget;

  /// For a sentence with a blank: the text before and after it.
  final String gapBefore;
  final String gapAfter;

  bool get isHeard => audio != null;
  bool get hasGap => gapBefore.isNotEmpty || gapAfter.isNotEmpty;
}

/// How one group ended, for the session only: a score never leaves the run's
/// owner and is never stored or sent.
class ReviewerGroupOutcome {
  const ReviewerGroupOutcome({
    required this.status,
    this.scored = 0,
    this.correct = 0,
  });

  final ReviewerGroupStatus status;

  /// Items that counted, and how many were right.
  final int scored;
  final int correct;
}

/// What a finished run found.
class ReviewerCheckResult {
  const ReviewerCheckResult({
    required this.groups,
    required this.eligibility,
    required this.suspended,
    required this.asked,
  });

  final Map<ReviewerGroup, ReviewerGroupOutcome> groups;

  /// What the reviewer is now eligible for; empty when not yet.
  final ReviewerEligibility eligibility;

  /// The ids of items suspended by an "also right" tap, for the owner's
  /// triage of the item bank (kept on the phone).
  final List<String> suspended;

  /// The ids of the cards of every item asked, so a retake is fresh.
  final List<String> asked;

  bool get passed => eligibility.passed;
}

/// P(at least [k] of independent events with chances [ps] happen): the exact
/// Poisson-binomial tail, the p-value of "a guesser did as well".
double reviewerTail(List<double> ps, int k) {
  if (k <= 0) return 1;
  if (k > ps.length) return 0;
  var dist = <double>[1];
  for (final p in ps) {
    final next = List<double>.filled(dist.length + 1, 0);
    for (var i = 0; i < dist.length; i++) {
      next[i] += dist[i] * (1 - p);
      next[i + 1] += dist[i] * p;
    }
    dist = next;
  }
  var sum = 0.0;
  for (var i = k; i < dist.length; i++) {
    sum += dist[i];
  }
  return sum;
}

class _Slot {
  _Slot(this.item, {this.pilot = false});

  final ReviewerItem item;
  final bool pilot;
}

class _Done {
  _Done(this.slot, this.outcome);

  final _Slot slot;
  final ReviewerOutcome outcome;
}

/// A run of the reviewer check.
class ReviewerCheckRun {
  ReviewerCheckRun({
    required ReviewerBank bank,
    required this.seed,
    required this.audio,
    Set<String> seen = const <String>{},
    PilotSink pilotSink = const NoPilotSink(),
  }) : _sink = pilotSink,
       _rng = math.Random(seed * 100003 + 29) {
    _plan(bank, seen);
    _advance();
  }

  /// Whether the course can be asked at all: Read and Write both have the
  /// cards the check needs.
  static bool isAvailable(ReviewerBank bank) => !bank.thin;

  final int seed;

  /// Whether the phone can play sound; without it Hear is not asked.
  final bool audio;

  final PilotSink _sink;
  final math.Random _rng;
  final List<_Slot> _queue = <_Slot>[];
  final Map<ReviewerGroup, List<ReviewerItem>> _reserve =
      <ReviewerGroup, List<ReviewerItem>>{};
  final Set<ReviewerGroup> _planned = <ReviewerGroup>{};
  final List<_Done> _done = <_Done>[];
  int _at = 0;
  List<int> _order = const <int>[];
  ReviewerQuestion? _question;

  /// The groups the run asks, in the order of the interleave.
  Set<ReviewerGroup> get groups => Set<ReviewerGroup>.unmodifiable(_planned);

  /// The cards the run may ask about, spares included: what a started run
  /// counts as asked, so quitting does not give a fresh set.
  List<String> get plannedCards => <String>[
    for (final s in _queue) s.item.item.cardId,
    for (final list in _reserve.values)
      for (final i in list) i.item.cardId,
  ];

  /// The current question, or null at the end.
  ReviewerQuestion? get question => _question;

  bool get finished => _question == null;

  /// How many items were answered, suspended or skipped, and how many the
  /// run has queued (the bar of the page; never a score).
  int get answered => _done.length;
  int get queued => _queue.length;

  // ----------------------------------------------------------------- plan

  void _plan(ReviewerBank bank, Set<String> seen) {
    final taken = <String>{};
    final main = <ReviewerGroup, List<ReviewerItem>>{};
    for (final g in ReviewerGroup.values) {
      if (g == ReviewerGroup.hear && !audio) continue;
      if (!bank.offers(g)) continue;
      final want = kReviewerItems[g]!;
      final picked = _pick(
        bank.scored[g] ?? const <ReviewerItem>[],
        want + kReviewerReserve,
        taken,
        seen,
        bank.topEnd - bank.topStart + 1,
      );
      if (picked.isEmpty) continue;
      _planned.add(g);
      main[g] = picked.take(want).toList();
      _reserve[g] = picked.skip(want).toList();
    }
    // Interleave the groups, so no skill is asked in one block.
    var round = 0;
    while (true) {
      var any = false;
      for (final g in ReviewerGroup.values) {
        final list = main[g];
        if (list != null && round < list.length) {
          _queue.add(_Slot(list[round]));
          any = true;
        }
      }
      if (!any) break;
      round++;
    }
    // Pilot items run unscored, between the others.
    final pool = List<ReviewerItem>.of(bank.pilot)..shuffle(_rng);
    var placed = 0;
    for (final p in pool) {
      if (placed >= kReviewerPilotSlots) break;
      if (p.group == ReviewerGroup.hear && !audio) continue;
      if (p.conflictKeys.any(taken.contains)) continue;
      taken.addAll(p.conflictKeys);
      final at = math.min(_queue.length, placed == 0 ? 5 : 20);
      _queue.insert(at, _Slot(p, pilot: true));
      placed++;
    }
  }

  List<ReviewerItem> _pick(
    List<ReviewerItem> all,
    int want,
    Set<String> taken,
    Set<String> seen,
    int bandDecks,
  ) {
    final fresh = <ReviewerItem>[
      for (final i in all)
        if (!seen.contains(i.item.cardId)) i,
    ]..shuffle(_rng);
    final old = <ReviewerItem>[
      for (final i in all)
        if (seen.contains(i.item.cardId)) i,
    ]..shuffle(_rng);
    final order = <ReviewerItem>[...fresh, ...old];
    final perDeck = <int, int>{};
    final cap = (want / math.max(1, bandDecks)).ceil() + 1;
    final out = <ReviewerItem>[];
    // A card is never asked twice in a run: the first pass keeps every deck
    // of the band to its share, the second takes what is left.
    for (final capped in <bool>[true, false]) {
      for (final i in order) {
        if (out.length >= want) break;
        if (out.contains(i)) continue;
        if (i.conflictKeys.any(taken.contains)) continue;
        final deck = i.item.deck;
        if (capped && (perDeck[deck] ?? 0) >= cap) continue;
        out.add(i);
        taken.addAll(i.conflictKeys);
        perDeck[deck] = (perDeck[deck] ?? 0) + 1;
      }
    }
    return out;
  }

  // -------------------------------------------------------------- answers

  /// The learner picked the option shown at [index].
  void answer(int index) {
    final slot = _current;
    if (slot == null || index < 0 || index >= _order.length) return;
    final right = _order[index] == slot.item.item.correct;
    if (slot.pilot) {
      _sink.record(slot.item.id, pickedKey: right);
    }
    _finish(right ? ReviewerOutcome.right : ReviewerOutcome.wrong);
  }

  /// "I don't know": a miss.
  void dontKnow() {
    if (_current == null) return;
    _finish(ReviewerOutcome.dontKnow);
  }

  /// "This is also right": the item is suspended and leaves the score, and
  /// another of its group takes its place.
  void alsoRight() {
    final slot = _current;
    if (slot == null) return;
    final already = _done
        .where(
          (d) =>
              d.outcome == ReviewerOutcome.suspended &&
              d.slot.item.group == slot.item.group,
        )
        .length;
    _finish(
      ReviewerOutcome.suspended,
      replace: !slot.pilot && already < kReviewerMaxSuspended,
    );
  }

  /// The question could not be shown (its sound would not play): left out of
  /// the score, never a miss.
  void skipUnplayable() {
    final slot = _current;
    if (slot == null) return;
    _finish(ReviewerOutcome.skipped, replace: !slot.pilot);
  }

  _Slot? get _current => _at < _queue.length ? _queue[_at] : null;

  void _finish(ReviewerOutcome outcome, {bool replace = false}) {
    final slot = _current!;
    _done.add(_Done(slot, outcome));
    if (replace) {
      final spare = _reserve[slot.item.group];
      if (spare != null && spare.isNotEmpty) {
        _queue.add(_Slot(spare.removeAt(0)));
      }
    }
    _at++;
    _advance();
  }

  void _advance() {
    final slot = _current;
    if (slot == null) {
      _question = null;
      return;
    }
    final item = slot.item.item;
    // The options are shown in a seeded order of their own, so the key has
    // no place of its own.
    final order = List<int>.generate(item.options.length, (i) => i)
      ..shuffle(_rng);
    _order = order;
    _question = _questionOf(slot.item, <String>[
      for (final i in order) item.options[i],
    ]);
  }

  static ReviewerQuestion _questionOf(
    ReviewerItem entry,
    List<String> options,
  ) {
    final item = entry.item;
    switch (item.format) {
      case 'F2' || 'F27':
        return ReviewerQuestion(
          id: item.id,
          format: item.format,
          group: entry.group,
          item: item,
          shown: item.prompt,
          shownIsTarget: true,
          options: options,
        );
      case 'F13' || 'F26':
        return ReviewerQuestion(
          id: item.id,
          format: item.format,
          group: entry.group,
          item: item,
          audio: item.prompt,
          options: options,
        );
      case 'F3':
        return ReviewerQuestion(
          id: item.id,
          format: item.format,
          group: entry.group,
          item: item,
          shown: item.prompt,
          options: options,
          optionsAreTarget: true,
        );
      case 'F28':
        final parts = item.prompt.split('___');
        return ReviewerQuestion(
          id: item.id,
          format: item.format,
          group: entry.group,
          item: item,
          shown: item.promptRoman,
          options: options,
          optionsAreTarget: true,
          gapBefore: parts.first,
          gapAfter: parts.length > 1 ? parts.last : '',
        );
    }
    throw StateError('The reviewer check has no screen for ${item.format}');
  }

  // --------------------------------------------------------------- result

  /// What the run found. Call at the end; before it, what is answered so far
  /// is judged as if the run ended now.
  ReviewerCheckResult get result {
    final out = <ReviewerGroup, ReviewerGroupOutcome>{};
    for (final g in ReviewerGroup.values) {
      if (!_planned.contains(g)) {
        out[g] = const ReviewerGroupOutcome(
          status: ReviewerGroupStatus.notAsked,
        );
        continue;
      }
      final counted = <_Done>[
        for (final d in _done)
          if (d.slot.item.group == g &&
              !d.slot.pilot &&
              (d.outcome == ReviewerOutcome.right ||
                  d.outcome == ReviewerOutcome.wrong ||
                  d.outcome == ReviewerOutcome.dontKnow))
            d,
      ];
      final right = counted
          .where((d) => d.outcome == ReviewerOutcome.right)
          .length;
      final suspended = _done
          .where(
            (d) =>
                d.outcome == ReviewerOutcome.suspended &&
                d.slot.item.group == g &&
                !d.slot.pilot,
          )
          .length;
      final skipped = _done
          .where(
            (d) =>
                d.outcome == ReviewerOutcome.skipped &&
                d.slot.item.group == g &&
                !d.slot.pilot,
          )
          .length;
      // A suspension beyond the cap is a miss: the tap cannot be used to
      // shape the scored set.
      final extra = math.max(0, suspended - kReviewerMaxSuspended);
      final total = counted.length + extra;
      final ReviewerGroupStatus status;
      if (total < (kReviewerMinScored[g] ?? 1) ||
          skipped > kReviewerMaxSkipped) {
        status = ReviewerGroupStatus.notEnough;
      } else {
        final p = reviewerTail(<double>[
          for (final d in counted) d.slot.item.nullGuess,
          for (var i = 0; i < extra; i++) reviewerNullGuess('F2'),
        ], right);
        final beatsGuessing = p <= (kReviewerAlpha[g] ?? 0.01);
        final accurate = right >= kReviewerMinAccuracy * total;
        status = beatsGuessing && accurate
            ? ReviewerGroupStatus.passed
            : ReviewerGroupStatus.notYet;
      }
      out[g] = ReviewerGroupOutcome(
        status: status,
        scored: total,
        correct: right,
      );
    }
    return ReviewerCheckResult(
      groups: out,
      eligibility: eligibilityOf(<ReviewerGroup, ReviewerGroupStatus>{
        for (final e in out.entries) e.key: e.value.status,
      }),
      suspended: <String>[
        for (final d in _done)
          if (d.outcome == ReviewerOutcome.suspended) d.slot.item.id,
      ],
      asked: <String>[for (final d in _done) d.slot.item.item.cardId],
    );
  }
}
