// The flagged queue and the tags sheet's helpers (ADR-0058, W4): which cards
// are listed, why, how a reviewer resolves one, and what the fix field is
// offered.

import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/core/review/facet_text.dart';
import 'package:fluenough/core/review/facets.dart';
import 'package:fluenough/core/review/flagged_queue.dart';
import 'package:fluenough/core/review/review_pairs.dart';
import 'package:fluenough/core/review/review_quorum.dart';
import 'package:fluenough/core/review/review_receipt.dart';
import 'package:flutter_test/flutter_test.dart';

const Card _card = Card(
  id: 'hi-0001',
  deckId: 'hi-core',
  target: 'ज़िंदगी',
  native: 'life',
  reading: 'zindagī',
  altReading: <String>['zindagi', 'zindagī', 'zindgī'],
  altTarget: <String>['ज़िन्दगी', 'जिंदगी'],
  ipa: 'zɪndəɡiː',
);

const Card _other = Card(
  id: 'hi-0002',
  deckId: 'hi-core',
  target: 'नमस्ते',
  native: 'hello',
);

const ReviewPair _hi = ReviewPair('hi', 'en');
const ReviewPair _bn = ReviewPair('bn', 'en');

Reviews _reviews(Map<String, Map<Facet, FacetAnswer>> byCard) =>
    Reviews(<String, DeckReview>{
      'hi-core': DeckReview(
        deckId: 'hi-core',
        language: 'hi',
        cards: <String, CardReview>{
          for (final e in byCard.entries)
            e.key: CardReview(at: DateTime.utc(2026, 11, 21), facets: e.value),
        },
      ),
    });

FlaggedQueue _queue(
  Reviews reviews, {
  Set<ReviewPair> allowed = const <ReviewPair>{_hi},
  OtherChecks others = const <String, Map<Facet, List<ReviewCheck>>>{},
  ReviewPair pair = _hi,
}) => FlaggedQueue.build(
  decks: <FlaggedSourceDeck>[
    FlaggedSourceDeck(
      deckId: 'hi-core',
      pair: pair,
      cards: const <Card>[_card, _other],
      others: others,
    ),
  ],
  allowed: allowed,
  reviews: reviews,
  ownCode: 'FL-AAAA',
);

FacetAnswer _flag(PointerTag tag, [String? fix]) =>
    FacetAnswer.flagged(<PointerTag>{tag}, replacement: fix);

void main() {
  group('the flagged queue', () {
    test('lists a card with a tag and no fix as flagged, with its tags', () {
      final queue = _queue(
        _reviews(<String, Map<Facet, FacetAnswer>>{
          'hi-0001': <Facet, FacetAnswer>{
            Facet.reading: _flag(PointerTag.readingWrong),
            Facet.meaning: _flag(PointerTag.meaningWrong),
            Facet.word: const FacetAnswer.right(),
          },
        }),
      );
      expect(queue.count, 1);
      final card = queue.cards.single;
      expect(card.cardId, 'hi-0001');
      expect(card.isContested, isFalse);
      expect(card.flaggedTags, <PointerTag>[
        PointerTag.meaningWrong,
        PointerTag.readingWrong,
      ]);
      expect(card.facets.map((f) => f.facet), <Facet>[
        Facet.reading,
        Facet.meaning,
      ]);
    });

    test('a card whose facets are all right is not listed', () {
      final queue = _queue(
        _reviews(<String, Map<Facet, FacetAnswer>>{
          'hi-0001': <Facet, FacetAnswer>{
            Facet.word: const FacetAnswer.right(),
          },
        }),
      );
      expect(queue.isEmpty, isTrue);
    });

    test('reviewers who disagree make the facet contested', () {
      final queue = _queue(
        _reviews(<String, Map<Facet, FacetAnswer>>{
          'hi-0001': <Facet, FacetAnswer>{
            Facet.word: _flag(PointerTag.spellingWrong),
          },
        }),
        others: <String, Map<Facet, List<ReviewCheck>>>{
          'hi-0001': <Facet, List<ReviewCheck>>{
            Facet.word: <ReviewCheck>[
              const ReviewCheck(rater: 'FL-BBBB', answer: FacetAnswer.right()),
            ],
          },
        },
      );
      final card = queue.cards.single;
      expect(card.isContested, isTrue);
      expect(card.contestedFacets, <Facet>[Facet.word]);
      expect(card.flaggedTags, isEmpty);
    });

    test('only the courses the reviewer may review are listed', () {
      final reviews = _reviews(<String, Map<Facet, FacetAnswer>>{
        'hi-0001': <Facet, FacetAnswer>{
          Facet.reading: _flag(PointerTag.readingWrong),
        },
      });
      expect(_queue(reviews, allowed: const <ReviewPair>{_bn}).isEmpty, isTrue);
    });

    test('a flag on a facet the card does not have is not listed', () {
      final queue = _queue(
        _reviews(<String, Map<Facet, FacetAnswer>>{
          'hi-0002': <Facet, FacetAnswer>{
            Facet.audio: _flag(PointerTag.audioWrong),
          },
        }),
      );
      expect(queue.isEmpty, isTrue);
    });
  });

  group('resolving a flagged facet', () {
    const flagged = FlaggedFacet(
      facet: Facet.reading,
      status: FacetStatus.flagged,
      tags: <PointerTag>[PointerTag.readingWrong],
      existingFix: 'zindagī',
    );

    test('right answers right', () {
      final a = resolveFlagged(flagged, FlaggedResolution.right)!;
      expect(a.answer.isRight, isTrue);
      expect(a.decision, ReceiptDecision.right);
    });

    test('agreeing repeats the flag and the fix', () {
      final a = resolveFlagged(flagged, FlaggedResolution.agreeWithFix)!;
      expect(a.answer.tags, <PointerTag>{PointerTag.readingWrong});
      expect(a.answer.replacement, 'zindagī');
      expect(a.decision, ReceiptDecision.accepted);
    });

    test('a fix of their own is another fix; the same text is agreement', () {
      final other = resolveFlagged(
        flagged,
        FlaggedResolution.offerFix,
        fix: 'zindgī',
      )!;
      expect(other.decision, ReceiptDecision.offeredOther);
      final same = resolveFlagged(
        flagged,
        FlaggedResolution.offerFix,
        fix: ' zindagī ',
      )!;
      expect(same.decision, ReceiptDecision.accepted);
    });

    test('what cannot be made is null', () {
      const noFix = FlaggedFacet(
        facet: Facet.reading,
        status: FacetStatus.flagged,
        tags: <PointerTag>[PointerTag.readingWrong],
      );
      expect(resolveFlagged(noFix, FlaggedResolution.agreeWithFix), isNull);
      expect(
        resolveFlagged(flagged, FlaggedResolution.offerFix, fix: '  '),
        isNull,
      );
    });
  });

  group('the tags sheet', () {
    test('offers the facet\'s own tag first and only tags that fit it', () {
      for (final facet in Facet.values) {
        final tags = tagsFor(facet);
        expect(tags.first, ownTagOf(facet));
        expect(tags.every((t) => t.facets.contains(facet)), isTrue);
        expect(tags.toSet().length, tags.length);
      }
    });

    test('candidates are what the card holds, never invented', () {
      expect(candidatesFor(_card, Facet.reading), <String>[
        'zindagi',
        'zindgī',
      ]);
      expect(candidatesFor(_card, Facet.word), <String>['ज़िन्दगी', 'जिंदगी']);
      expect(candidatesFor(_card, Facet.ipa), isEmpty);
      expect(candidatesFor(_other, Facet.reading), isEmpty);
    });

    test(
      'the field is prefilled from the card and the hint fits the script',
      () {
        expect(facetTextOf(_card, Facet.reading), 'zindagī');
        expect(readingBesideOf(_card, Facet.word), 'zindagī');
        expect(readingBesideOf(_card, Facet.meaning), isNull);
        expect(needsScriptKeyboard(_card.target), isTrue);
        expect(needsScriptKeyboard('zindagī'), isFalse);
        expect(needsScriptKeyboard('zɪndəɡiː'), isFalse);
        expect(isTextFacet(Facet.audio), isFalse);
      },
    );
  });
}
