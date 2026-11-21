// The launch gate of the reviewer check (wiki/Plan-Placement-V3.md, "Adversarial
// review and required amendments"; ADR-0058, decision 1): a persona replay and
// an adversarial retest of the stricter mode. The check ships OFF
// (`kReviewerCheckEnabled`) and the owner switches it on only while these bars
// hold on the decks that will ship.
//
// Runs are seeded, so the numbers are the same every time. They are printed,
// so that the CI log carries what the pull request reports.
import 'package:fluenough/core/placement/reviewer_check_run.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reviewer_check_fixture.dart';
import 'support/reviewer_check_harness.dart';

const int _runs = 600;

void main() {
  final fixture = ReviewerFixture();
  final bank = fixture.bank();

  double rate(CheckPersona p, bool Function(ReviewerCheckResult) test) {
    final r = passRate(bank, p, _runs, test);
    // ignore: avoid_print
    print('reviewer check replay: ${p.name}: ${(r * 100).toStringAsFixed(2)}%');
    return r;
  }

  group('the reviewer check replay, over the fixture course', () {
    test('a true speaker at the top band passes with at least 95%', () {
      final speaker = CheckPersona('true speaker', knownDeck: fixture.b1End);
      expect(rate(speaker, grantsStatus), greaterThanOrEqualTo(0.95));
      // Hear on top, for the reading, IPA and audio facets.
      expect(rate(speaker, grantsHear), greaterThanOrEqualTo(0.95));
    });

    test('a true speaker who flags a few flawed items still passes', () {
      final speaker = CheckPersona(
        'true speaker, some flawed items',
        knownDeck: fixture.b1End,
        alsoRightRate: 0.03,
      );
      // Not the owner's bar: taps beyond the cap count as misses, so a
      // speaker who meets many flawed items fails more often.
      expect(rate(speaker, grantsStatus), greaterThanOrEqualTo(0.9));
    });

    test('a learner at B1 passes, at A1 and A2 does not', () {
      final b1 = CheckPersona('learner B1', knownDeck: fixture.b1End);
      final a2 = CheckPersona('learner A2', knownDeck: fixture.a2End);
      final a1 = CheckPersona('learner A1', knownDeck: fixture.a1End);
      expect(rate(b1, grantsStatus), greaterThanOrEqualTo(0.95));
      expect(rate(a2, grantsStatus), lessThanOrEqualTo(0.01));
      expect(rate(a1, grantsStatus), lessThanOrEqualTo(0.01));
    });

    test('a guesser passes with at most 1%', () {
      const guesser = CheckPersona('guesser', knownDeck: -1);
      const first = CheckPersona(
        'always the first option',
        knownDeck: -1,
        firstOption: true,
      );
      expect(rate(guesser, grantsStatus), lessThanOrEqualTo(0.01));
      expect(rate(first, grantsStatus), lessThanOrEqualTo(0.01));
    });

    test('the first 100 words with basic suffix and form rules (the V3 '
        'adversary) pass with at most 1%, measured and 0.10 stronger', () {
      // The fixture's first deck holds 6 words: 100 words are the first 17
      // decks, all below the top band.
      final known = (100 / fixture.perDeck).ceil() - 1;
      for (final bump in <double>[0, 0.05, 0.10]) {
        final adversary = CheckPersona(
          '100 words and rules (+$bump)',
          knownDeck: known,
          beyond: leakBeyond(bump),
        );
        expect(rate(adversary, grantsStatus), lessThanOrEqualTo(0.01));
      }
    });

    test('partial knowledge of the top band does not pass, with or without '
        'tapping also right on what is not known', () {
      // Between A2 and B1: the first third of the top band is known by deck.
      final between = CheckPersona(
        'between A2 and B1',
        knownDeck: (fixture.a2End + fixture.b1End) ~/ 2,
      );
      expect(rate(between, grantsStatus), lessThanOrEqualTo(0.01));
      for (final share in <double>[0.3, 0.5, 0.6]) {
        for (final dodge in <bool>[false, true]) {
          final person = CheckPersona(
            'knows $share of the items${dodge ? ', dodges' : ''}',
            knownDeck: -1,
            knownFraction: share,
            suspendUnknown: dodge,
          );
          expect(rate(person, grantsStatus), lessThanOrEqualTo(0.01));
        }
      }
    });

    test('tapping also right on everything passes nobody', () {
      final all = CheckPersona(
        'suspends everything',
        knownDeck: fixture.b1End,
        suspendAll: true,
      );
      expect(rate(all, grantsStatus), 0);
    });

    test('the V3 adversary who also dodges what it does not know passes '
        'with at most 1%', () {
      final unknown = CheckPersona(
        '100 words and rules, dodges what it does not know',
        knownDeck: 16,
        beyond: leakBeyond(0.05),
        suspendUnknown: true,
      );
      expect(rate(unknown, grantsStatus), lessThanOrEqualTo(0.01));
    });
  });
}
