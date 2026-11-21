// The one review quorum (ADR-0058, W2): the Dart constant and the tools'
// constant are the same number, the rule counts distinct reviewers, and the
// Verified requirement is a switch that is off today.

import 'dart:io';

import 'package:fluenough/core/review/facets.dart';
import 'package:fluenough/core/review/review_quorum.dart';
import 'package:flutter_test/flutter_test.dart';

ReviewCheck _check(
  String rater, {
  ReviewerTier tier = ReviewerTier.provisional,
  FacetAnswer? answer,
}) => ReviewCheck(rater: rater, tier: tier, answer: answer);

void main() {
  group('the quorum constant', () {
    test(
      'tools/review_quorum.py holds the same number and the same switch',
      () {
        final py = File('tools/review_quorum.py').readAsStringSync();
        final number = RegExp(
          r'^REVIEW_QUORUM\s*=\s*(\d+)',
          multiLine: true,
        ).firstMatch(py);
        expect(
          number,
          isNotNull,
          reason: 'REVIEW_QUORUM not found in the tools',
        );
        expect(int.parse(number!.group(1)!), kReviewQuorum);

        final dart = File('lib/core/review/review_quorum.dart')
            .readAsStringSync();
        final dartNumber = RegExp(r'const int kReviewQuorum = (\d+);')
            .firstMatch(dart);
        expect(int.parse(dartNumber!.group(1)!), kReviewQuorum);

        final pySwitch = RegExp(
          r'^QUORUM_NEEDS_VERIFIED\s*=\s*(True|False)',
          multiLine: true,
        ).firstMatch(py);
        expect(pySwitch, isNotNull);
        expect(pySwitch!.group(1) == 'True', kQuorumNeedsVerified);
      },
    );

    test('the quorum is two, and the Verified switch is off until W7', () {
      expect(kReviewQuorum, 2);
      expect(kQuorumNeedsVerified, isFalse);
    });

    test('no interface string carries the quorum or its setting name', () {
      // The number is never shown: reviewer screens say "needs another
      // speaker's check". The new keys are checked by name, because other
      // strings may hold the digit for other reasons.
      for (final file
          in Directory('lib/l10n')
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('app_en.arb'))) {
        final text = file.readAsStringSync();
        expect(text.contains('kReviewQuorum'), isFalse);
        expect(text.contains('REVIEW_QUORUM'), isFalse);
      }
    });
  });

  group('facetReachedQuorum', () {
    test('needs the quorum of distinct rater codes', () {
      expect(facetReachedQuorum(const <ReviewCheck>[]), isFalse);
      expect(facetReachedQuorum([_check('FL-AAAA-AAAA-0')]), isFalse);
      expect(
        facetReachedQuorum([
          _check('FL-AAAA-AAAA-0'),
          _check('FL-BBBB-BBBB-0'),
        ]),
        isTrue,
      );
    });

    test('one code twice is one reviewer, however it is written', () {
      expect(
        facetReachedQuorum([
          _check('FL-AAAA-AAAA-0'),
          _check(' fl-aaaa-aaaa-0 '),
        ]),
        isFalse,
      );
    });

    test('a flag is not an endorsement and does not count', () {
      final flag = FacetAnswer.flagged(<PointerTag>{PointerTag.meaningWrong});
      expect(
        facetReachedQuorum([_check('A'), _check('B', answer: flag)]),
        isFalse,
      );
      expect(
        facetReachedQuorum([
          _check('A'),
          _check('B', answer: const FacetAnswer.right()),
        ]),
        isTrue,
      );
    });

    test('today, with everyone Provisional, two checks settle a facet', () {
      final checks = [_check('A'), _check('B')];
      expect(checks.every((c) => c.tier == ReviewerTier.provisional), isTrue);
      expect(facetReachedQuorum(checks), isTrue);
    });

    test('with the switch on, one of the two must be Verified or Trusted', () {
      final two = [_check('A'), _check('B')];
      expect(facetReachedQuorum(two, needsVerified: true), isFalse);
      expect(
        facetReachedQuorum([
          _check('A', tier: ReviewerTier.verified),
          _check('B'),
        ], needsVerified: true),
        isTrue,
      );
      expect(
        facetReachedQuorum([
          _check('A'),
          _check('B', tier: ReviewerTier.trusted),
        ], needsVerified: true),
        isTrue,
      );
    });

    test('a code seen at two tiers counts once, at its best', () {
      expect(
        facetReachedQuorum([
          _check('A'),
          _check('A', tier: ReviewerTier.verified),
        ], needsVerified: true),
        isFalse,
        reason: 'one reviewer is below the quorum however often it is listed',
      );
      expect(
        facetReachedQuorum([
          _check('A'),
          _check('A', tier: ReviewerTier.verified),
          _check('B'),
        ], needsVerified: true),
        isTrue,
      );
    });

    test('an empty rater code never counts', () {
      expect(
        facetReachedQuorum([_check(''), _check('  '), _check('A')]),
        isFalse,
      );
    });
  });

  group('cardReachedQuorum', () {
    test('needs every applicable facet to have the quorum', () {
      final applicable = <Facet>{Facet.word, Facet.meaning};
      final two = [_check('A'), _check('B')];
      expect(
        cardReachedQuorum(applicable, {Facet.word: two, Facet.meaning: two}),
        isTrue,
      );
      expect(
        cardReachedQuorum(applicable, {
          Facet.word: two,
          Facet.meaning: [_check('A')],
        }),
        isFalse,
      );
      expect(cardReachedQuorum(applicable, {Facet.word: two}), isFalse);
      expect(cardReachedQuorum(const <Facet>{}, const {}), isFalse);
    });
  });

  group('facetStatus', () {
    FacetAnswer fix(String text) => FacetAnswer.flagged(<PointerTag>{
      PointerTag.readingWrong,
    }, replacement: text);

    test('unchecked, checking and settled', () {
      expect(facetStatus(const <ReviewCheck>[]), FacetStatus.unchecked);
      expect(facetStatus([_check('A')]), FacetStatus.checking);
      expect(facetStatus([_check('A'), _check('B')]), FacetStatus.settled);
    });

    test('one reviewer\'s tag with no resolution is flagged', () {
      expect(
        facetStatus([
          _check(
            'A',
            answer: FacetAnswer.flagged(<PointerTag>{PointerTag.readingWrong}),
          ),
        ]),
        FacetStatus.flagged,
      );
      expect(
        facetStatus([_check('A', answer: fix('amma'))]),
        FacetStatus.flagged,
      );
    });

    test('a right and a flag disagree: contested', () {
      expect(
        facetStatus([_check('A'), _check('B', answer: fix('amma'))]),
        FacetStatus.contested,
      );
    });

    test('two flags with different fixes are contested', () {
      expect(
        facetStatus([
          _check('A', answer: fix('amma')),
          _check('B', answer: fix('ammā')),
        ]),
        FacetStatus.contested,
      );
    });

    test('two flags with the same fix after normalising agree', () {
      expect(
        facetStatus([
          _check('A', answer: fix('ammā')),
          _check('B', answer: fix(' ammā ')),
        ]),
        FacetStatus.agreedFix,
      );
    });

    test('one reviewer changing their answer does not contest themselves', () {
      expect(
        facetStatus([_check('A', answer: fix('amma')), _check('A')]),
        FacetStatus.checking,
      );
    });
  });
}
