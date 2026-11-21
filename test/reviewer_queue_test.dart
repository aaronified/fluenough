// The review queue and the second-speaker rules (ADR-0058, W3): what a
// session holds, how a card counts as checked, how the pool follows, what
// the one button answers, and what a second speaker is asked.

import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/core/review/facets.dart';
import 'package:fluenough/core/review/flagged_queue.dart';
import 'package:fluenough/core/review/review_pairs.dart';
import 'package:fluenough/core/review/review_quorum.dart';
import 'package:fluenough/core/review/review_session.dart';
import 'package:fluenough/core/review/second_speaker.dart';
import 'package:flutter_test/flutter_test.dart';

const ReviewPair _pair = ReviewPair('hi', 'en');
const String _me = 'FL-AAAA-AAAA-0';

Card _card(int n) => Card(
  id: 'hi-${n.toString().padLeft(4, '0')}',
  deckId: 'hi-core',
  target: 'word$n',
  native: 'meaning$n',
);

String _id(int n) => _card(n).id;

/// What a card without a reading, IPA or audio has: word, meaning, unit.
const Set<Facet> _all = <Facet>{Facet.word, Facet.meaning, Facet.unitPlacement};

/// Another speaker's right answer on every facet of cards [numbers].
OtherChecks _checked(Iterable<int> numbers, List<String> raters) =>
    <String, Map<Facet, List<ReviewCheck>>>{
      for (final n in numbers)
        _id(n): <Facet, List<ReviewCheck>>{
          for (final facet in _all)
            facet: <ReviewCheck>[
              for (final r in raters)
                ReviewCheck(rater: r, answer: const FacetAnswer.right()),
            ],
        },
    };

/// A course of units, each a list of card numbers.
ReviewSource _source(
  List<List<int>> units, {
  OtherChecks others = const <String, Map<Facet, List<ReviewCheck>>>{},
}) => ReviewSource(
  pair: _pair,
  units: <QueueUnit>[
    for (final (i, numbers) in units.indexed)
      QueueUnit(
        number: i + 1,
        title: 'Unit ${i + 1}',
        decks: <FlaggedSourceDeck>[
          FlaggedSourceDeck(
            deckId: 'hi-core-${i + 1}',
            pair: _pair,
            cards: <Card>[for (final n in numbers) _card(n)],
            others: others,
          ),
        ],
      ),
  ],
);

Reviews _own(Map<String, Set<Facet>> byCard, {String deck = 'hi-core-1'}) =>
    Reviews(<String, DeckReview>{
      deck: DeckReview(
        deckId: deck,
        language: 'hi',
        cards: <String, CardReview>{
          for (final e in byCard.entries)
            e.key: CardReview(
              at: DateTime.utc(2026, 11, 21),
              facets: <Facet, FacetAnswer>{
                for (final f in e.value) f: const FacetAnswer.right(),
              },
            ),
        },
      ),
    });

void main() {
  group('a session', () {
    test('is one unit\'s 20 least-checked cards, in path order', () {
      // Unit 1 has 25 cards; the first five were checked by another speaker.
      final source = _source(<List<int>>[
        <int>[for (var n = 1; n <= 25; n++) n],
        <int>[101, 102],
      ], others: _checked(<int>[1, 2, 3, 4, 5], <String>['FL-BBBB-BBBB-0']));
      final run = ReviewQueueBuilder.startSession(
        source,
        reviews: const Reviews(),
        ownCode: _me,
      )!;
      expect(run.unit, 1);
      expect(run.phase, ReviewPhase.session);
      expect(run.cards, hasLength(kSessionCards));
      expect(run.cards.first.cardId, _id(6));
      expect(run.cards.last.cardId, _id(25));
      expect(run.cards.map((c) => c.cardId).toList(), <String>[
        for (var n = 6; n <= 25; n++) _id(n),
      ], reason: 'path order, the checked ones left out');
    });

    test('takes the unit whose card is the least checked; a tie is the '
        'earlier unit', () {
      final source = _source(<List<int>>[
        <int>[1, 2],
        <int>[3, 4],
      ], others: _checked(<int>[1, 2], <String>['FL-BBBB-BBBB-0']));
      final run = ReviewQueueBuilder.startSession(
        source,
        reviews: const Reviews(),
        ownCode: _me,
      )!;
      expect(run.unit, 2);
      final tie = ReviewQueueBuilder.startSession(
        _source(<List<int>>[
          <int>[1],
          <int>[2],
        ]),
        reviews: const Reviews(),
        ownCode: _me,
      )!;
      expect(tie.unit, 1);
    });

    test('a unit of fewer cards is a shorter session', () {
      final run = ReviewQueueBuilder.startSession(
        _source(<List<int>>[
          <int>[1, 2, 3],
        ]),
        reviews: const Reviews(),
        ownCode: _me,
      )!;
      expect(run.cards, hasLength(3));
    });

    test('a course with no card has none', () {
      expect(
        ReviewQueueBuilder.startSession(
          _source(const <List<int>>[<int>[]]),
          reviews: const Reviews(),
          ownCode: _me,
        ),
        isNull,
      );
    });
  });

  group('how checked a card is', () {
    final deck = FlaggedSourceDeck(
      deckId: 'hi-core-1',
      pair: _pair,
      cards: <Card>[_card(1)],
      others: <String, Map<Facet, List<ReviewCheck>>>{
        _id(1): <Facet, List<ReviewCheck>>{
          Facet.word: <ReviewCheck>[
            const ReviewCheck(
              rater: 'FL-BBBB-BBBB-0',
              answer: FacetAnswer.right(),
            ),
            // The same reviewer again, in other letters: once.
            const ReviewCheck(rater: ' fl-bbbb-bbbb-0 '),
          ],
        },
      },
    );

    test('counts distinct reviewers on the least-checked facet', () {
      final score = scoreOf(_card(1), deck, const Reviews(), null);
      expect(score.least, 0, reason: 'meaning and unit are unchecked');
      expect(
        score.total,
        1,
        reason: 'one reviewer, however often they said it',
      );
    });

    test('the reviewer\'s own answers count, so a card drops back', () {
      final own = _own(<String, Set<Facet>>{_id(1): _all});
      final score = scoreOf(_card(1), deck, own, _me);
      expect(score.least, 1);
      expect(score.compareTo(const CheckScore(0, 0)), greaterThan(0));
    });
  });

  group('resuming', () {
    test('stands at the first card with an applicable facet unanswered', () {
      final source = _source(<List<int>>[
        <int>[1, 2, 3],
      ]);
      final cards = source.cardsOf(1);
      final reviews = _own(<String, Set<Facet>>{
        _id(1): _all,
        _id(2): <Facet>{Facet.word},
      });
      expect(ReviewQueueBuilder.firstOpen(source, cards, reviews), 1);
      final all = _own(<String, Set<Facet>>{
        for (final n in <int>[1, 2, 3]) _id(n): _all,
      });
      expect(ReviewQueueBuilder.firstOpen(source, cards, all), 3);
    });

    test('a run survives being kept; anything else is no run', () {
      final run = ReviewQueueBuilder.startSession(
        _source(<List<int>>[
          <int>[1, 2],
        ]),
        reviews: const Reviews(),
        ownCode: _me,
      )!;
      final back = ReviewRun.decode(run.encode())!;
      expect(back.course, 'hi/en');
      expect(back.unit, run.unit);
      expect(back.cards, run.cards);
      expect(back.phase, ReviewPhase.session);
      expect(ReviewRun.decode('not json'), isNull);
      expect(ReviewRun.decode('{"course":"x"}'), isNull);
      expect(ReviewRun.decode(null), isNull);
    });
  });

  group('the pool after the session', () {
    test(
      'goes on with the rest of the unit, then the next unit, once each',
      () {
        final source = _source(<List<int>>[
          <int>[for (var n = 1; n <= 25; n++) n],
          <int>[101, 102],
          <int>[201],
        ]);
        final session = ReviewQueueBuilder.startSession(
          source,
          reviews: const Reviews(),
          ownCode: _me,
        )!;
        expect(session.cards, hasLength(20));
        final rest = ReviewQueueBuilder.continuePool(
          source,
          session,
          reviews: const Reviews(),
          ownCode: _me,
        )!;
        expect(rest.phase, ReviewPhase.pool);
        expect(rest.unit, 1);
        expect(rest.cards.map((c) => c.cardId), <String>[
          for (var n = 21; n <= 25; n++) _id(n),
        ]);
        final second = ReviewQueueBuilder.nextGroup(
          source,
          rest,
          reviews: const Reviews(),
          ownCode: _me,
        )!;
        expect(second.unit, 2, reason: 'earlier unit on a tie');
        final third = ReviewQueueBuilder.nextGroup(
          source,
          second,
          reviews: const Reviews(),
          ownCode: _me,
        )!;
        expect(third.unit, 3);
        expect(
          ReviewQueueBuilder.nextGroup(
            source,
            third,
            reviews: const Reviews(),
            ownCode: _me,
          ),
          isNull,
          reason: 'every unit has been gone through',
        );
      },
    );

    test('the least-checked unit comes first', () {
      final source = _source(<List<int>>[
        <int>[1],
        <int>[2],
        <int>[3],
      ], others: _checked(<int>[2], <String>['FL-BBBB-BBBB-0']));
      final session = ReviewQueueBuilder.startSession(
        source,
        reviews: const Reviews(),
        ownCode: _me,
      )!;
      expect(session.unit, 1);
      final next = ReviewQueueBuilder.continuePool(
        source,
        session,
        reviews: const Reviews(),
        ownCode: _me,
      )!;
      expect(next.unit, 3, reason: 'unit 2 was checked by another speaker');
    });
  });

  group('the one button', () {
    test('waits for reading, IPA and audio, where the card has them', () {
      const all = <Facet>{
        Facet.word,
        Facet.reading,
        Facet.ipa,
        Facet.meaning,
        Facet.audio,
      };
      expect(canFinishCard(all, const <Facet, FacetAnswer>{}), isFalse);
      expect(
        canFinishCard(all, <Facet, FacetAnswer>{
          Facet.reading: const FacetAnswer.right(),
          Facet.ipa: const FacetAnswer.right(),
        }),
        isFalse,
      );
      expect(
        canFinishCard(all, <Facet, FacetAnswer>{
          Facet.reading: const FacetAnswer.right(),
          Facet.ipa: FacetAnswer.flagged(<PointerTag>{PointerTag.ipaWrong}),
          Facet.audio: const FacetAnswer.right(),
        }),
        isTrue,
      );
      expect(canFinishCard(_all, const <Facet, FacetAnswer>{}), isTrue);
    });

    test('answers the rest right and leaves a flag as it is', () {
      final flag = FacetAnswer.flagged(<PointerTag>{PointerTag.meaningWrong});
      final answers = <Facet, FacetAnswer>{Facet.meaning: flag};
      final shortcut = shortcutAnswers(<Facet>{
        Facet.word,
        Facet.reading,
        Facet.meaning,
        Facet.note,
        Facet.unitPlacement,
        Facet.audio,
      }, answers);
      expect(shortcut.keys.toSet(), <Facet>{
        Facet.word,
        Facet.note,
        Facet.unitPlacement,
      }, reason: 'reading and audio are never answered by the shortcut');
      expect(shortcut.values.every((a) => a.isRight), isTrue);
      expect(anyFlagged(answers), isTrue);
      expect(anyFlagged(shortcut), isFalse);
    });
  });

  group('what a second speaker is asked', () {
    FacetAnswer fix(String text) => FacetAnswer.flagged(<PointerTag>{
      PointerTag.readingWrong,
    }, replacement: text);

    FlaggedFacet flagged(Facet facet, {String? existingFix}) => FlaggedFacet(
      facet: facet,
      status: FacetStatus.flagged,
      tags: const <PointerTag>[PointerTag.readingWrong],
      existingFix: existingFix,
    );

    final card = Card(
      id: 'hi-0001',
      deckId: 'hi-core',
      target: 'नमस्ते',
      native: 'hello',
      reading: 'namaste',
    );

    FlaggedSourceDeck deck(OtherChecks others) => FlaggedSourceDeck(
      deckId: 'hi-core',
      pair: _pair,
      cards: <Card>[card],
      others: others,
    );

    FlaggedCard flaggedCard(FlaggedFacet facet) => FlaggedCard(
      deckId: 'hi-core',
      cardId: card.id,
      pair: _pair,
      facets: <FlaggedFacet>[facet],
    );

    test('one proposed fix is checked open: the original beside it', () {
      final steps = stepsOfFlagged(
        flaggedCard(flagged(Facet.reading, existingFix: 'namastē')),
        card,
        deck(<String, Map<Facet, List<ReviewCheck>>>{
          card.id: <Facet, List<ReviewCheck>>{
            Facet.reading: <ReviewCheck>[
              ReviewCheck(rater: 'FL-BBBB-BBBB-0', answer: fix('namastē')),
            ],
          },
        }),
        _me,
      );
      final step = steps.single as ProposalStep;
      expect(step.original, 'namaste');
      expect(step.proposed, 'namastē');
    });

    test('different fixes from two speakers are a pick-one, each once', () {
      final steps = stepsOfFlagged(
        flaggedCard(flagged(Facet.reading, existingFix: 'namaskār')),
        card,
        deck(<String, Map<Facet, List<ReviewCheck>>>{
          card.id: <Facet, List<ReviewCheck>>{
            Facet.reading: <ReviewCheck>[
              ReviewCheck(rater: 'FL-BBBB-BBBB-0', answer: fix('namastē')),
              ReviewCheck(rater: 'FL-CCCC-CCCC-0', answer: fix('namaskār')),
              // The same text as the first, spelled with other whitespace.
              ReviewCheck(rater: 'FL-DDDD-DDDD-0', answer: fix(' namastē ')),
            ],
          },
        }),
        _me,
      );
      final step = steps.single as RivalStep;
      expect(step.fixes, <String>['namastē', 'namaskār']);
    });

    test('the reviewer\'s own fix is not a rival to themselves', () {
      expect(
        rivalFixesOf(<ReviewCheck>[
          ReviewCheck(rater: _me, answer: fix('a')),
          ReviewCheck(rater: 'FL-BBBB-BBBB-0', answer: fix('b')),
        ], exceptRater: _me),
        <String>['b'],
      );
    });

    test('a tag with no fix is the original, to call right or to fix', () {
      final steps = stepsOfFlagged(
        flaggedCard(flagged(Facet.reading)),
        card,
        deck(const <String, Map<Facet, List<ReviewCheck>>>{}),
        _me,
      );
      expect(steps.single, isA<FlagStep>());
    });

    test('the digest lists only what others changed or contest, with the '
        'reason', () {
      final source = ReviewSource(
        pair: _pair,
        units: <QueueUnit>[
          QueueUnit(
            number: 1,
            title: 'Greetings',
            decks: <FlaggedSourceDeck>[
              deck(<String, Map<Facet, List<ReviewCheck>>>{
                card.id: <Facet, List<ReviewCheck>>{
                  Facet.reading: <ReviewCheck>[
                    ReviewCheck(
                      rater: 'FL-BBBB-BBBB-0',
                      answer: fix('namastē'),
                    ),
                  ],
                  Facet.meaning: <ReviewCheck>[
                    const ReviewCheck(
                      rater: 'FL-BBBB-BBBB-0',
                      answer: FacetAnswer.right(),
                    ),
                    ReviewCheck(
                      rater: 'FL-CCCC-CCCC-0',
                      answer: FacetAnswer.flagged(<PointerTag>{
                        PointerTag.meaningWrong,
                      }),
                    ),
                  ],
                  // One speaker says right: nothing to digest.
                  Facet.word: <ReviewCheck>[
                    const ReviewCheck(
                      rater: 'FL-BBBB-BBBB-0',
                      answer: FacetAnswer.right(),
                    ),
                  ],
                },
              }),
            ],
          ),
        ],
      );
      final items = digestOf(
        source,
        1,
        reasons: <String, Map<Facet, String>>{
          card.id: <Facet, String>{Facet.reading: 'Too formal.'},
        },
      );
      expect(items.map((i) => (i.facet, i.kind)), <(Facet, DigestKind)>[
        (Facet.reading, DigestKind.changed),
        (Facet.meaning, DigestKind.contested),
      ]);
      expect(items.first.before, 'namaste');
      expect(items.first.after, 'namastē');
      expect(items.first.reason, 'Too formal.');
      expect(items.last.reason, isNull);
    });

    test('a facet that needs another speaker says so, with no number', () {
      expect(
        needsAnotherSpeaker(<ReviewCheck>[
          const ReviewCheck(
            rater: 'FL-BBBB-BBBB-0',
            answer: FacetAnswer.right(),
          ),
        ]),
        isTrue,
      );
      final two = <ReviewCheck>[
        for (var i = 0; i < kReviewQuorum; i++)
          ReviewCheck(rater: 'FL-BBBB-BBBB-$i'),
      ];
      expect(needsAnotherSpeaker(two), isFalse);
    });
  });
}
