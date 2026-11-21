// The replay harness of the reviewer check (ADR-0058, decision 1; the launch
// gate of wiki/Plan-Placement-V3.md): simulated people play whole runs of
// [ReviewerCheckRun] over a bank, with a fixed seed per run, and the pass
// rates are counted.
//
// It reuses the V3 harness's leak profile (`leakLanguages`), the measured
// accuracy of the adversary of the V3 adversarial review (the first 100 words
// plus basic suffix and form rules and test-wise tricks) on each format.
import 'dart:math' as math;

import 'package:fluenough/core/placement/reviewer_check_bank.dart';
import 'package:fluenough/core/placement/reviewer_check_run.dart';
import 'package:fluenough/core/review/facets.dart';

import 'placement_v3_harness.dart';

/// How a simulated person answers.
class CheckPersona {
  const CheckPersona(
    this.name, {
    required this.knownDeck,
    this.slip = 0.05,
    this.beyond = _guess,
    this.alsoRightRate = 0,
    this.suspendUnknown = false,
    this.suspendAll = false,
    this.firstOption = false,
    this.knownFraction = 0,
  });

  final String name;

  /// The person knows every word of the decks up to this index.
  final int knownDeck;

  /// The chance of a wrong answer on a word known.
  final double slip;

  /// The chance of a right answer on an item beyond what is known, for a
  /// format and its option count.
  final double Function(String format, int options) beyond;

  /// The chance a known item is flagged "also right" (a flawed item).
  final double alsoRightRate;

  /// Taps "also right" on every item not known (an attempt to choose the
  /// scored items), and on every item at all with [suspendAll].
  final bool suspendUnknown;
  final bool suspendAll;

  /// Always picks the first option shown.
  final bool firstOption;

  /// A share of the items, drawn at random per card, that the person knows
  /// whatever its deck: partial knowledge of the top band.
  final double knownFraction;

  static double _guess(String format, int options) => 1 / options;
}

/// What the adversary of the V3 review achieved beyond its words on [format],
/// plus [bump] (the stress of an adversary stronger than measured).
double Function(String, int) leakBeyond(double bump) {
  final es = leakLanguages()['es']!;
  return (String format, int options) =>
      math.min(1.0, es.rate(format, false, BankProfile.fixed, true) + bump);
}

/// A fixed number in [0, 1) for [key]: the same on every platform.
double _share(String key) {
  var h = 2166136261;
  for (final c in key.codeUnits) {
    h = ((h ^ c) * 16777619) & 0x7fffffff;
  }
  return math.Random(h).nextDouble();
}

/// What a run came to.
class ReplayRun {
  const ReplayRun(this.result, this.items);

  final ReviewerCheckResult result;
  final int items;
}

/// Plays one run for [person].
ReplayRun playRun(
  ReviewerBank bank,
  CheckPersona person,
  int seed, {
  bool audio = true,
  Set<String> seen = const <String>{},
}) {
  final run = ReviewerCheckRun(
    bank: bank,
    seed: seed,
    audio: audio,
    seen: seen,
  );
  final rng = math.Random(seed * 7919 + 3);
  var items = 0;
  while (!run.finished) {
    final q = run.question!;
    final item = q.item;
    items++;
    final known =
        item.deck <= person.knownDeck ||
        (person.knownFraction > 0 &&
            _share('${person.name}/$seed/${item.cardId}') <
                person.knownFraction);
    if (person.suspendAll || (person.suspendUnknown && !known)) {
      run.alsoRight();
      continue;
    }
    if (known && person.alsoRightRate > 0) {
      if (rng.nextDouble() < person.alsoRightRate) {
        run.alsoRight();
        continue;
      }
    }
    if (person.firstOption) {
      run.answer(0);
      continue;
    }
    final p = known
        ? 1 - person.slip
        : person.beyond(item.format, q.options.length);
    final keyIndex = q.options.indexOf(item.options[item.correct]);
    if (rng.nextDouble() < p) {
      run.answer(keyIndex);
    } else {
      // Any other option: a miss.
      var i = rng.nextInt(q.options.length - 1);
      if (i >= keyIndex) i++;
      run.answer(i);
    }
  }
  return ReplayRun(run.result, items);
}

/// The share of [runs] runs of [person] (seeds 1 to [runs]) for which
/// [test] holds.
double passRate(
  ReviewerBank bank,
  CheckPersona person,
  int runs,
  bool Function(ReviewerCheckResult) test, {
  bool audio = true,
}) {
  var n = 0;
  for (var seed = 1; seed <= runs; seed++) {
    if (test(playRun(bank, person, seed, audio: audio).result)) n++;
  }
  return n / runs;
}

/// Read and Write both passed: Provisional status.
bool grantsStatus(ReviewerCheckResult r) =>
    r.eligibility.facets.contains(Facet.word);

/// Hear passed on top of Read and Write.
bool grantsHear(ReviewerCheckResult r) =>
    r.eligibility.facets.contains(Facet.reading);
