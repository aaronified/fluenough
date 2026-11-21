// What the decks publish of other reviewers' facet answers (ADR-0058, W9):
// the `facet_checks` key of a card entry, read from a single-file deck and
// from a core and its layer, and how it reaches the flagged queue and the
// second-speaker views as `FlaggedSourceDeck.others`. The made-up language zz.

import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart' show Deck;
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/core/review/facets.dart';
import 'package:fluenough/core/review/flagged_queue.dart';
import 'package:fluenough/core/review/published_facets.dart';
import 'package:fluenough/core/review/review_pairs.dart';
import 'package:fluenough/core/review/review_problems.dart';
import 'package:fluenough/core/review/review_quorum.dart';
import 'package:fluenough/core/review/second_speaker.dart';
import 'package:flutter_test/flutter_test.dart';

const String _header = '''
schema: 1
id: "zz-en-words"
name: "Words"
language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "latin" }
native: { code: "en", iso639_3: "eng", name: "English" }
license: "CC0-1.0"
''';

/// A block card with `facet_checks` on its own line and a flow card with it
/// last before the closing brace, as the review bot writes them; a third has
/// none, as every deck written before W9.
const String _cards = '''
cards:
  - id: "zz-9801"
    target: "kala"
    native: "black"
    reading: "kala"
    checked_by: ["FL-0000-0000-0"]
    facet_checks: {"reading": {"by": ["FL-AAAA-AAAA-A"], "flags": [{"by": "FL-BBBB-BBBB-B", "tags": ["reading_wrong"], "fix": "kaala"}]}, "meaning": {"by": ["FL-AAAA-AAAA-A", "FL-BBBB-BBBB-B"]}}
  - { id: "zz-9802", target: "nila", native: "blue", facet_checks: {"word": {"flags": [{"by": "FL-AAAA-AAAA-A", "tags": ["spelling_wrong"], "fix": "a}, b: [c] \\" d"}]}} }
  - { id: "zz-9803", target: "pita", native: "yellow", checked_by: ["FL-0000-0000-0"] }
''';

Deck _deck() => DeckParser.parse('$_header$_cards', source: 'zz-en-words.yaml');

void main() {
  group('reading facet_checks', () {
    test('a block card and a flow card each give their facets', () {
      final published = _deck().facetChecks;
      expect(published.keys, <String>['zz-9801', 'zz-9802']);

      final reading = published['zz-9801']![Facet.reading]!;
      expect(reading.by, <String>['FL-AAAA-AAAA-A']);
      expect(reading.flags.single.rater, 'FL-BBBB-BBBB-B');
      expect(reading.flags.single.tags, <PointerTag>{PointerTag.readingWrong});
      expect(reading.flags.single.fix, 'kaala');
      expect(published['zz-9801']![Facet.meaning]!.by, <String>[
        'FL-AAAA-AAAA-A',
        'FL-BBBB-BBBB-B',
      ]);

      // Quoted text keeps its braces, brackets and quotes.
      final word = published['zz-9802']![Facet.word]!;
      expect(word.by, isEmpty);
      expect(word.flags.single.fix, 'a}, b: [c] " d');
    });

    test('checked_by is read as it was, beside it', () {
      final deck = _deck();
      expect(deck.checkedBy['zz-9801'], <String>['FL-0000-0000-0']);
      expect(deck.checkedBy['zz-9803'], <String>['FL-0000-0000-0']);
    });

    test('a deck with no facet_checks has none, as before', () {
      final deck = DeckParser.parse(
        '$_header\ncards:\n  - { id: "zz-9803", target: "pita", native: "yellow" }\n',
        source: 'zz-en-words.yaml',
      );
      expect(deck.facetChecks, isEmpty);
    });

    test('what is not of the shape is reported and left out', () {
      final reported = <String>[];
      ReviewProblems.sink = reported.add;
      addTearDown(() => ReviewProblems.sink = null);
      final deck = DeckParser.parse(
        '$_header\ncards:\n'
        '  - { id: "zz-9801", target: "kala", native: "black", reading: "kala", '
        'facet_checks: {"reading": {"by": ["FL-AAAA-AAAA-A"]}, '
        '"zzz": {"by": ["FL-AAAA-AAAA-A"]}, '
        '"meaning": {"flags": [{"by": "FL-BBBB-BBBB-B", "tags": ["ipa_wrong"]}]}} }\n',
        source: 'zz-en-words.yaml',
      );
      final facets = deck.facetChecks['zz-9801']!;
      // The unknown facet, and the flag whose only tag does not belong on the
      // meaning, are dropped; the good facet stays.
      expect(facets.keys, <Facet>[Facet.reading]);
      expect(reported, isNotEmpty);
    });
  });

  group('a core and its layer', () {
    test('the merged card has the answers of both entries', () {
      final core = DeckParser.parseCore('''
schema: 1
id: "zz-words"
part: "core"
kind: "vocab"
language: { code: "zz", iso639_3: "zzz", name: "Testlang", script: "latin" }
license: "CC0-1.0"
cards:
  - { id: "zz-9801", target: "kala", reading: "kala", facet_checks: {"reading": {"by": ["FL-AAAA-AAAA-A"]}} }
''', source: 'zz-words.yaml');
      final layer = DeckParser.parseLayer('''
schema: 1
id: "zz-en-words"
kind: "layer"
core: "zz-words"
native: { code: "en", iso639_3: "eng", name: "English" }
name: "Words"
license: "CC0-1.0"
cards:
  "zz-9801": { native: "black", facet_checks: {"meaning": {"flags": [{"by": "FL-BBBB-BBBB-B", "tags": ["meaning_wrong"]}]}} }
''', source: 'zz-en-words.yaml');
      final merged = mergeLayer(
        core,
        layer,
        source: 'zz-en-words.yaml',
      ).facetChecks['zz-9801']!;
      expect(merged[Facet.reading]!.by, <String>['FL-AAAA-AAAA-A']);
      expect(merged[Facet.meaning]!.flags.single.rater, 'FL-BBBB-BBBB-B');
    });

    test('one rater has one answer to a facet in the merge', () {
      final merged = mergePublishedFacets(
        <Facet, PublishedFacet>{
          Facet.word: const PublishedFacet(by: <String>['FL-AAAA-AAAA-A']),
        },
        <Facet, PublishedFacet>{
          Facet.word: const PublishedFacet(
            flags: <PublishedFlag>[
              PublishedFlag(
                rater: 'FL-AAAA-AAAA-A',
                tags: <PointerTag>{PointerTag.spellingWrong},
              ),
            ],
          ),
        },
      );
      expect(merged[Facet.word]!.by, isEmpty);
      expect(merged[Facet.word]!.flags, hasLength(1));
    });
  });

  group('the other speakers checks', () {
    const card = Card(
      id: 'zz-9801',
      deckId: 'zz-en-words',
      target: 'kala',
      native: 'black',
      reading: 'kala',
    );

    Map<Facet, List<ReviewCheck>> checksOf(
      Map<Facet, PublishedFacet> published, {
      List<String> bare = const <String>[],
    }) => otherChecksOfCard(
      applicable: facetsOf(card),
      bareCodes: bare,
      published: published,
    );

    test('with nothing published, a code in checked_by checks every facet', () {
      final checks = checksOf(
        const <Facet, PublishedFacet>{},
        bare: <String>['FL-0000-0000-0'],
      );
      expect(checks.keys.toSet(), facetsOf(card));
      for (final facet in facetsOf(card)) {
        expect(facetStatus(checks[facet]!), FacetStatus.checking);
      }
    });

    test('a rater own answer replaces their card-level check', () {
      final checks = checksOf(
        <Facet, PublishedFacet>{
          Facet.reading: const PublishedFacet(
            flags: <PublishedFlag>[
              PublishedFlag(
                rater: 'FL-0000-0000-0',
                tags: <PointerTag>{PointerTag.readingWrong},
              ),
            ],
          ),
        },
        bare: <String>['FL-0000-0000-0'],
      );
      expect(facetStatus(checks[Facet.reading]!), FacetStatus.flagged);
      expect(facetStatus(checks[Facet.meaning]!), FacetStatus.checking);
    });

    test(
      'two distinct raters settle a facet; a flag of a third contests it',
      () {
        const both = PublishedFacet(
          by: <String>['FL-AAAA-AAAA-A', 'FL-BBBB-BBBB-B'],
        );
        expect(
          facetStatus(
            checksOf(<Facet, PublishedFacet>{Facet.word: both})[Facet.word]!,
          ),
          FacetStatus.settled,
        );
        final contested = checksOf(<Facet, PublishedFacet>{
          Facet.word: PublishedFacet(
            by: both.by,
            flags: <PublishedFlag>[
              const PublishedFlag(
                rater: 'FL-CCCC-CCCC-C',
                tags: <PointerTag>{PointerTag.spellingWrong},
                fix: 'kalaa',
              ),
            ],
          ),
        });
        expect(facetStatus(contested[Facet.word]!), FacetStatus.contested);
      },
    );

    test('the flagged queue lists a published flag, and the second speaker '
        'is asked about the fix', () {
      final deck = DeckParser.parse(
        '$_header$_cards',
        source: 'zz-en-words.yaml',
      );
      final others = <String, Map<Facet, List<ReviewCheck>>>{
        for (final c in deck.cards)
          if (deck.facetChecks[c.id] != null)
            c.id: otherChecksOfCard(
              applicable: facetsOf(c),
              bareCodes: deck.checkedBy[c.id] ?? const <String>[],
              published: deck.facetChecks[c.id]!,
            ),
      };
      final source = FlaggedSourceDeck(
        deckId: deck.id,
        pair: const ReviewPair('zz', 'en'),
        cards: deck.cards,
        others: others,
      );
      final queue = FlaggedQueue.build(
        decks: <FlaggedSourceDeck>[source],
        allowed: <ReviewPair>{const ReviewPair('zz', 'en')},
        reviews: const Reviews(),
        ownCode: 'FL-DDDD-DDDD-D',
      );
      // zz-9801: the reading is contested (one right, one flag), zz-9802's
      // word is flagged with a fix. zz-9803 has only a sign-off.
      expect(queue.cards.map((c) => c.cardId), <String>['zz-9801', 'zz-9802']);
      final first = queue.cards.first.facets.single;
      expect(first.facet, Facet.reading);
      expect(first.status, FacetStatus.contested);
      expect(first.existingFix, 'kaala');
      final second = queue.cards.last.facets.single;
      expect(second.status, FacetStatus.flagged);
      expect(second.existingFix, 'a}, b: [c] " d');

      // The second speaker is asked to accept, reject or offer another.
      for (final flagged in queue.cards) {
        final card = deck.cards.firstWhere((c) => c.id == flagged.cardId);
        final steps = stepsOfFlagged(flagged, card, source, 'FL-DDDD-DDDD-D');
        expect(steps.single, isA<ProposalStep>());
      }
      final step =
          stepsOfFlagged(
                queue.cards.last,
                deck.cards[1],
                source,
                'FL-DDDD-DDDD-D',
              ).single
              as ProposalStep;
      expect(step.proposed, 'a}, b: [c] " d');
    });
  });
}
