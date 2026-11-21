// The reviewer check's rules (ADR-0058, decisions 1 and 2): which items may
// be asked, what a run reveals, and what the phone remembers.
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/placement/item_registry.dart';
import 'package:fluenough/core/placement/placement_data.dart';
import 'package:fluenough/core/placement/reviewer_check_bank.dart';
import 'package:fluenough/core/placement/reviewer_check_rules.dart';
import 'package:fluenough/core/placement/reviewer_check_run.dart';
import 'package:fluenough/core/placement/reviewer_check_status.dart';
import 'package:fluenough/core/review/facets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/reviewer_check_fixture.dart';

/// Plays a run right on every item except those at [wrongAt], flagging those
/// at [alsoRightAt] as also right.
ReviewerCheckRun _scripted(
  ReviewerBank bank, {
  Set<int> wrongAt = const <int>{},
  Set<int> alsoRightAt = const <int>{},
  int seed = 1,
  Set<String> seen = const <String>{},
}) {
  final run = ReviewerCheckRun(bank: bank, seed: seed, audio: true, seen: seen);
  var n = 0;
  while (!run.finished) {
    final q = run.question!;
    final key = q.options.indexOf(q.item.options[q.item.correct]);
    if (alsoRightAt.contains(n)) {
      run.alsoRight();
    } else if (wrongAt.contains(n)) {
      run.answer((key + 1) % q.options.length);
    } else {
      run.answer(key);
    }
    n++;
  }
  return run;
}

Card _card(
  String id,
  String target,
  String native, {
  List<String> altNative = const <String>[],
  String pos = 'noun',
}) => Card(
  id: id,
  deckId: 'd',
  target: target,
  native: native,
  altNative: altNative,
  pos: pos,
);

RegItem _f2(String card, String word, List<String> options, {int deck = 0}) =>
    RegItem(
      id: '$card:F2',
      format: 'F2',
      cardId: card,
      deck: deck,
      prompt: word,
      options: options,
      correct: 0,
      lemmas: <String>{'l$card'},
    );

void main() {
  final fixture = ReviewerFixture();

  group('which items the check may ask', () {
    test('only picks of the allowed formats: no typed answer, no yes/no', () {
      final bank = fixture.bank();
      final formats = <String>{
        for (final g in ReviewerGroup.values)
          for (final i in bank.scored[g]!) i.item.format,
        for (final i in bank.pilot) i.item.format,
      };
      expect(formats, everyElement(isIn(kReviewerFormats.keys)));
      expect(formats, isNot(contains('F7')));
      expect(formats, isNot(contains('F1')));
      // And every question of a run is one the screen shows as a pick.
      final run = _scripted(bank);
      expect(run.finished, isTrue);
    });

    test('a key card must be checked twice, else the item is only a pilot', () {
      final one = fixture.bank(checkedTwice: (id, group) => id != 'fx-50-0');
      bool scoredFor(ReviewerBank b, String card) => <bool>[
        for (final g in ReviewerGroup.values)
          for (final i in b.scored[g]!) i.item.cardId == card,
      ].any((x) => x);
      expect(scoredFor(one, 'fx-50-0'), isFalse);
      expect(
        one.pilot.any((i) => i.item.cardId == 'fx-50-0'),
        isTrue,
        reason: 'it can still be piloted unscored',
      );
      expect(scoredFor(fixture.bank(), 'fx-50-0'), isTrue);
    });

    test('no item outside the top band is scored', () {
      final bank = fixture.bank();
      expect(bank.topEnd, fixture.b1End);
      expect(bank.topStart, greaterThan(fixture.a2End));
      for (final g in ReviewerGroup.values) {
        for (final i in bank.scored[g]!) {
          expect(i.item.deck, inInclusiveRange(bank.topStart, bank.topEnd));
        }
      }
    });

    test('a distractor that is a synonym of the key is refused', () {
      final cards = <Card>[
        _card('a', 'wa', 'big', altNative: <String>['large']),
        _card('b', 'wb', 'large'),
        _card('c', 'wc', 'house'),
        _card('d', 'wd', 'tree'),
        _card('e', 'we', 'river'),
      ];
      final data = PlacementLanguageData(
        language: 'xx',
        decks: <PlacementDeck>[PlacementDeck(id: 'd', cards: cards)],
      );
      ReviewerBank bankOf(List<String> options) => ReviewerBank.build(
        data: data,
        items: <RegItem>[_f2('a', 'wa', options)],
        checkedTwice: (_, _) => true,
      );
      // "large" is another card's meaning and the key card's own alt_native.
      expect(
        bankOf(<String>['big', 'large', 'house', 'tree'])
            .scored[ReviewerGroup.read]!,
        isEmpty,
      );
      // Different words with nothing in common are proved wrong.
      expect(
        bankOf(<String>['big', 'house', 'tree', 'river'])
            .scored[ReviewerGroup.read]!,
        hasLength(1),
      );
      // A distractor that is no word of the course cannot be proved wrong.
      expect(
        bankOf(<String>['big', 'house', 'tree', 'unknown thing'])
            .scored[ReviewerGroup.read]!,
        isEmpty,
      );
    });

    test('a fix two reviewers agreed on makes a gold item, old form wrong', () {
      final bank = fixture.bank(
        history: <FixHistoryEntry>[
          const FixHistoryEntry(
            cardId: 'fx-50-0',
            facet: Facet.meaning,
            oldForm: 'a wrong meaning',
            agreedFix: 'meaning 50 x 0',
          ),
        ],
      );
      final gold = <ReviewerItem>[
        for (final i in bank.scored[ReviewerGroup.read]!)
          if (i.tier == ReviewerItemTier.gold) i,
      ];
      expect(gold, hasLength(1));
      final options = gold.single.item.options;
      expect(options[gold.single.item.correct], 'meaning 50 x 0');
      expect(options, contains('a wrong meaning'));
    });

    test('no pilot item is promoted by default, and a promotion needs '
        'about 8 Verified responses with 90% agreeing', () {
      expect(const NoItemPromoted().isPromoted('x'), isFalse);
      expect(
        judgePilot(const PilotTally(verified: 7, agreeing: 7)),
        PilotVerdict.keepPiloting,
      );
      expect(
        judgePilot(const PilotTally(verified: 10, agreeing: 9)),
        PilotVerdict.promote,
      );
      expect(
        judgePilot(const PilotTally(verified: 10, agreeing: 6)),
        PilotVerdict.retire,
      );
      expect(
        judgePilot(const PilotTally(verified: 10, agreeing: 8)),
        PilotVerdict.keepPiloting,
      );
      // A pilot item is asked unscored; once promoted it is scored.
      final pilotId = fixture
          .bank(checkedTwice: (id, g) => id != 'fx-50-0')
          .pilot
          .firstWhere((i) => i.item.cardId == 'fx-50-0')
          .id;
      final promoted = fixture.bank(
        checkedTwice: (id, g) => id != 'fx-50-0',
        promotion: TallyPromotion(<String, PilotTally>{
          pilotId: const PilotTally(verified: 8, agreeing: 8),
        }),
      );
      expect(<String>[
        for (final g in ReviewerGroup.values)
          for (final i in promoted.scored[g]!) i.id,
      ], contains(pilotId));
    });

    test('a thin course has no check to take', () {
      final thin = fixture.bank(checkedTwice: (id, g) => id.endsWith('-0'));
      expect(thin.thin, isTrue);
      expect(fixture.bank().thin, isFalse);
      expect(ReviewerBank.empty().thin, isTrue);
    });
  });

  group('what a run reveals and decides', () {
    final bank = fixture.bank();

    test('a perfect run grants Read, Write, Hear and grammar facets', () {
      final r = _scripted(bank).result;
      expect(r.eligibility.facets, containsAll(kReadWriteFacets));
      expect(r.eligibility.facets, containsAll(kHearFacets));
      expect(r.eligibility.facets, containsAll(kGrammarFacets));
      expect(r.eligibility.grammarNotes, isTrue);
      expect(r.eligibility.passedFacetsWire, contains('word'));
    });

    test('no single miss decides', () {
      final total = _scripted(bank).answered;
      for (var at = 0; at < total; at++) {
        final r = _scripted(bank, wrongAt: <int>{at}).result;
        expect(
          r.eligibility.facets.containsAll(kReadWriteFacets),
          isTrue,
          reason: 'a miss at question $at decided',
        );
      }
    });

    test('an also right tap leaves the score and another item takes its '
        'place; more than a few taps leave the group not enough', () {
      final plain = _scripted(bank);
      final two = _scripted(bank, alsoRightAt: <int>{0, 4});
      // The two suspended items are answered by tapping, and two spare items
      // are asked in their place.
      expect(two.answered, plain.answered + 2);
      final taps = two.result.suspended;
      expect(taps, hasLength(2));
      for (final g in ReviewerGroup.values) {
        // Suspended items are not in anyone's score.
        final scored = two.result.groups[g]!.scored;
        expect(scored, lessThanOrEqualTo(kReviewerItems[g]!));
      }
      // Tapping three of one group is too many for it to be judged.
      final run = ReviewerCheckRun(bank: bank, seed: 1, audio: true);
      var tapped = 0;
      while (!run.finished) {
        final q = run.question!;
        if (q.group == ReviewerGroup.read && tapped < 3) {
          tapped++;
          run.alsoRight();
        } else {
          run.answer(q.options.indexOf(q.item.options[q.item.correct]));
        }
      }
      expect(
        run.result.groups[ReviewerGroup.read]!.status,
        ReviewerGroupStatus.notEnough,
      );
      expect(run.result.eligibility.passed, isFalse);
    });

    test('the questions carry no key, and the options are in a seeded '
        'order that is not the bank order', () {
      var moved = 0;
      var total = 0;
      final run = ReviewerCheckRun(bank: bank, seed: 3, audio: true);
      while (!run.finished) {
        final q = run.question!;
        total++;
        if (q.options.indexOf(q.item.options[q.item.correct]) != 0) moved++;
        run.answer(0);
      }
      expect(moved, greaterThan(total ~/ 2));
    });

    test('without sound Hear is not asked and its facets are not granted', () {
      final run = ReviewerCheckRun(bank: bank, seed: 1, audio: false);
      var heard = 0;
      while (!run.finished) {
        final q = run.question!;
        if (q.isHeard) heard++;
        run.answer(q.options.indexOf(q.item.options[q.item.correct]));
      }
      expect(heard, 0);
      expect(run.result.eligibility.facets, isNot(contains(Facet.reading)));
      expect(run.result.eligibility.facets, contains(Facet.word));
    });

    test('a card is never asked twice in a run', () {
      final run = ReviewerCheckRun(bank: bank, seed: 5, audio: true);
      final seen = <String>[];
      while (!run.finished) {
        final q = run.question!;
        seen.add(q.item.cardId);
        run.answer(0);
      }
      expect(seen.toSet().length, seen.length);
    });

    test('a retake asks fresh cards while the course has them', () {
      final big = ReviewerFixture(perDeck: 12).bank();
      final first = _scripted(big).result.asked.toSet();
      final second = _scripted(big, seed: 2, seen: first).result.asked.toSet();
      expect(second.intersection(first), isEmpty);
    });
  });

  group('what the phone remembers', () {
    final now = DateTime.utc(2026, 11, 21, 12);

    test('the check can be retaken after 7 days, not before', () {
      final done = const ReviewerCheckRecord().afterAttempt(
        _scripted(fixture.bank()).result,
        now,
      );
      expect(done.passed, isTrue);
      expect(done.canTake(now), isFalse);
      expect(done.cooldownDays(now.add(const Duration(days: 2))), 5);
      final almost = now.add(const Duration(days: 6, hours: 23));
      expect(done.canTake(almost), isFalse);
      expect(done.canTake(now.add(const Duration(days: 7))), isTrue);
    });

    test('a failed retake never takes status away', () {
      final passed = const ReviewerCheckRecord().afterAttempt(
        _scripted(fixture.bank()).result,
        now,
      );
      final failedRun = ReviewerCheckRun(
        bank: fixture.bank(),
        seed: 9,
        audio: true,
      );
      while (!failedRun.finished) {
        failedRun.dontKnow();
      }
      final after = passed.afterAttempt(failedRun.result, now);
      expect(after.eligibility.facets, passed.eligibility.facets);
    });

    test('the record keeps facets and the flag, never a score', () {
      final record = const ReviewerCheckRecord().afterAttempt(
        _scripted(fixture.bank()).result,
        now,
      );
      final json = record.toJson();
      expect(json.keys.toSet(), <String>{'passed', 'at', 'offered', 'used'});
      final back = ReviewerCheckRecord.fromJson(json);
      expect(back.eligibility.facets, record.eligibility.facets);
      expect(back.lastAttempt, record.lastAttempt);
      expect(ReviewerCheckRecord.fromJson('junk').passed, isFalse);
    });

    test('the quiet offer is made once per course', () {
      const fresh = ReviewerCheckRecord();
      expect(fresh.shouldOffer, isTrue);
      expect(fresh.withOffered().shouldOffer, isFalse);
    });
  });
}
