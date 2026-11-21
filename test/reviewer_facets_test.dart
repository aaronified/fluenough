// The facet model of a card review (ADR-0058, W1): which facets apply, the
// answers and their tags, the shortcut, completeness, receipts, the
// normalisation fixes are compared in, and that the review file stays
// compatible with files written before facets existed.

import 'dart:convert';
import 'dart:math';

import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/core/review/facets.dart';
import 'package:fluenough/core/review/fix_text.dart';
import 'package:fluenough/core/review/rater_code.dart';
import 'package:fluenough/core/review/review_file.dart';
import 'package:fluenough/core/review/review_problems.dart';
import 'package:fluenough/core/review/review_receipt.dart';
import 'package:flutter_test/flutter_test.dart';

const Card _bare = Card(
  id: 'te-0001',
  deckId: 'te-core',
  target: 'అమ్మ',
  native: 'mother',
);

const Card _full = Card(
  id: 'te-0002',
  deckId: 'te-core',
  target: 'అమ్మ',
  native: 'mother',
  reading: 'amma',
  ipa: 'amːa',
  audio: 'te-0002.ogg',
  register: 'offensive',
  examples: <CardExample>[
    CardExample(target: 'అమ్మ ఇక్కడ', native: 'Mother is here'),
  ],
  notes: <CardNote>[CardNote(id: '1', kind: NoteKind.note, text: 'A note')],
);

void main() {
  late List<String> problems;
  setUp(() {
    problems = <String>[];
    ReviewProblems.sink = problems.add;
  });
  tearDown(() => ReviewProblems.sink = null);

  group('which facets apply to a card', () {
    test('a bare card has word, meaning and unit placement only', () {
      expect(facetsOf(_bare), <Facet>{
        Facet.word,
        Facet.meaning,
        Facet.unitPlacement,
      });
    });

    test('a card outside any unit has no unit placement', () {
      expect(facetsOf(_bare, inUnit: false), <Facet>{
        Facet.word,
        Facet.meaning,
      });
    });

    test('a full card has every facet, in order', () {
      expect(facetsOf(_full).toList(), Facet.values);
    });

    test('an empty or blank reading, ipa or audio does not apply', () {
      const blank = Card(
        id: 'x-1',
        deckId: 'x',
        target: 'a',
        native: 'b',
        reading: '  ',
        ipa: '',
      );
      expect(facetsOf(blank), isNot(contains(Facet.reading)));
      expect(facetsOf(blank), isNot(contains(Facet.ipa)));
      expect(facetsOf(blank), isNot(contains(Facet.audio)));
    });
  });

  group('the shortcut and the facets confirmed apart', () {
    test('the plain facets are word, meaning and example', () {
      expect(plainFacets, <Facet>{Facet.word, Facet.meaning, Facet.example});
      expect(separatelyConfirmedFacets, <Facet>{
        Facet.reading,
        Facet.ipa,
        Facet.audio,
      });
      expect(plainFacets.intersection(separatelyConfirmedFacets), isEmpty);
    });

    test('everything looks right answers only the plain facets that apply', () {
      final answers = allGoodAnswers(facetsOf(_full));
      expect(answers.keys.toSet(), plainFacets);
      expect(answers.values.every((a) => a.isRight), isTrue);
      expect(allGoodAnswers(facetsOf(_bare)).keys.toSet(), <Facet>{
        Facet.word,
        Facet.meaning,
      });
    });

    test('the shortcut alone never completes a card with reading or audio', () {
      final applicable = facetsOf(_full);
      expect(isComplete(applicable, allGoodAnswers(applicable)), isFalse);
      expect(missingFacets(applicable, allGoodAnswers(applicable)), <Facet>{
        Facet.reading,
        Facet.ipa,
        Facet.note,
        Facet.unitPlacement,
        Facet.offenceRating,
        Facet.audio,
      });
    });
  });

  group('completeness', () {
    test('complete only when every applicable facet has an answer', () {
      final applicable = <Facet>{Facet.word, Facet.reading};
      final flag = FacetAnswer.flagged(<PointerTag>{PointerTag.readingWrong});
      expect(isComplete(applicable, const {}), isFalse);
      expect(
        isComplete(applicable, {Facet.word: const FacetAnswer.right()}),
        isFalse,
      );
      expect(
        isComplete(applicable, {
          Facet.word: const FacetAnswer.right(),
          Facet.reading: flag,
        }),
        isTrue,
        reason: 'a flag is an answer',
      );
    });

    test('an answer for a facet that does not apply does not complete one that does', () {
      expect(
        isComplete(
          <Facet>{Facet.word},
          {Facet.audio: const FacetAnswer.right()},
        ),
        isFalse,
      );
    });

    test('a card with no applicable facet is never complete', () {
      expect(isComplete(const <Facet>{}, const {}), isFalse);
    });
  });

  group('answers and pointer tags', () {
    test('a flag can carry several tags and a replacement', () {
      final answer = FacetAnswer.flagged(<PointerTag>{
        PointerTag.unnaturalOrRare,
        PointerTag.wrongRegister,
      }, replacement: 'అమ్మా');
      expect(answer.isFlagged, isTrue);
      expect(answer.isRight, isFalse);
      expect(answer.hasReplacement, isTrue);
      expect(const FacetAnswer.right().isRight, isTrue);
    });

    test('every tag names at least one facet and every facet has a tag', () {
      for (final tag in PointerTag.values) {
        expect(tag.facets, isNotEmpty, reason: tag.name);
      }
      final named = PointerTag.values.expand((t) => t.facets).toSet();
      expect(named, containsAll(Facet.values));
    });

    test('wire names are unique', () {
      expect(
        PointerTag.values.map((t) => t.wire).toSet().length,
        PointerTag.values.length,
      );
      expect(
        Facet.values.map((f) => f.wire).toSet().length,
        Facet.values.length,
      );
    });

    test('an answer reads back as it was written', () {
      for (final (facet, answer) in <(Facet, FacetAnswer)>[
        (Facet.meaning, const FacetAnswer.right()),
        (
          Facet.reading,
          FacetAnswer.flagged(<PointerTag>{PointerTag.readingWrong}),
        ),
        (
          Facet.word,
          FacetAnswer.flagged(<PointerTag>{
            PointerTag.spellingWrong,
            PointerTag.unnaturalOrRare,
          }, replacement: 'అమ్మా'),
        ),
      ]) {
        final back = FacetAnswer.fromJson(
          facet,
          jsonDecode(jsonEncode(answer.toJson())),
        );
        expect(back, answer, reason: facet.name);
      }
    });

    test('a tag that does not belong on the facet is dropped and reported', () {
      final back = FacetAnswer.fromJson(Facet.meaning, <String, Object?>{
        'tags': <String>['meaning_wrong', 'ipa_wrong', 'nonsense'],
      });
      expect(back!.tags, <PointerTag>{PointerTag.meaningWrong});
      expect(problems.length, 2);
    });

    test('a flag whose tags are all unusable is not turned into right', () {
      expect(
        FacetAnswer.fromJson(Facet.meaning, <String, Object?>{
          'tags': <String>['ipa_wrong'],
        }),
        isNull,
      );
      expect(
        FacetAnswer.fromJson(Facet.meaning, <String, Object?>{
          'tags': <Object>[],
        }),
        isNull,
      );
      expect(FacetAnswer.fromJson(Facet.meaning, 'right'), isNull);
      expect(FacetAnswer.fromJson(Facet.meaning, <String, Object?>{}), isNull);
      expect(FacetAnswer.fromJson(Facet.meaning, null), isNull);
    });
  });

  group('receipts', () {
    test('the hash is stable, short and ignores spelling differences', () {
      final h = hashOfSeen('ammā');
      expect(h.length, receiptHashLength);
      expect(hashOfSeen('ammā'), h);
      expect(hashOfSeen('  ammā  '), h);
      expect(hashOfSeen('amma'), isNot(h));
      expect(hashOfSeen(null), hashOfSeen(''));
    });

    test('a receipt knows whether the text changed since', () {
      final r = ReviewReceipt.of(
        cardId: 'te-0002',
        facet: Facet.reading,
        seen: 'amma',
        decision: ReceiptDecision.right,
      );
      expect(r.isCurrent('amma'), isTrue);
      expect(r.isCurrent('ammā'), isFalse);
    });

    test('a receipt reads back, with or without a reason', () {
      for (final reason in <String?>[null, 'dialect']) {
        final r = ReviewReceipt.of(
          cardId: 'te-0002',
          facet: Facet.meaning,
          seen: 'mother',
          decision: ReceiptDecision.offeredOther,
          reason: reason,
        );
        expect(ReviewReceipt.fromJson(jsonDecode(jsonEncode(r.toJson()))), r);
      }
    });

    test('a bad receipt is reported and left out, the others stay', () {
      final review = CardReview.fromJson(<String, Object?>{
        'at': '2026-11-21T10:00:00Z',
        'receipts': <Object?>[
          <String, Object?>{
            'facet': 'word',
            'hash': 'abc',
            'decision': 'right',
          },
          <String, Object?>{
            'facet': 'nope',
            'hash': 'abc',
            'decision': 'right',
          },
          'junk',
          <String, Object?>{'facet': 'word', 'hash': '', 'decision': 'right'},
        ],
      }, cardId: 'te-0002');
      expect(review!.receipts.length, 1);
      expect(review.receipts.single.cardId, 'te-0002');
      expect(problems.length, 3);
    });
  });

  group('normalising replacement texts', () {
    test('composed and decomposed Latin letters are the same fix', () {
      expect(sameFixText('ā', 'ā'), isTrue);
      expect(sameFixText('ṁ', 'ṁ'), isTrue);
      expect(sameFixText('ṇ', 'ṇ'), isTrue);
      expect(sameFixText('ś', 'ś'), isTrue);
      expect(normalizeFixText('ā'), 'ā');
    });

    test('marks under one letter come out in canonical order', () {
      // dot below (220) sorts before macron (230) whichever way typed.
      expect(sameFixText('ṝ', 'ṝ'), isTrue);
      expect(sameFixText('ṝ', 'ṝ'), isTrue);
    });

    test('Indic letters typed two ways compare equal', () {
      // Bengali o: e + aa sign is the single sign o.
      expect(sameFixText('ো', 'ো'), isTrue);
      // Telugu ai: e + length mark is the single sign.
      expect(sameFixText('ై', 'ై'), isTrue);
      // Kannada: composed and decomposed forms of one vowel sign.
      expect(sameFixText('ೀ', 'ೀ'), isTrue);
      // Devanagari qa: NFC keeps the nukta form decomposed, both agree.
      expect(sameFixText('क़', 'क़'), isTrue);
    });

    test('Japanese kana with a voicing mark, and Hangul, compose', () {
      expect(sameFixText('が', 'が'), isTrue);
      expect(sameFixText('한', '한'), isTrue);
    });

    test('white space is collapsed and trimmed', () {
      expect(normalizeFixText('  amma \t\n ammā  '), 'amma ammā');
      expect(normalizeFixText('a　b'), 'a b');
      expect(normalizeFixText('   '), '');
    });

    test('zero-width joiners and non-joiners are left alone', () {
      // TODO(per-script rules): stripping is not safe in general.
      expect(sameFixText('క్ష', 'క్‍ష'), isFalse);
      expect(normalizeFixText('a‍b'), 'a‍b');
    });

    test('different letters stay different', () {
      expect(sameFixText('amma', 'ammā'), isFalse);
      expect(sameFixText('Amma', 'amma'), isFalse);
    });

    test('plain text is returned as it is', () {
      expect(nfc('hello'), 'hello');
      expect(nfc(''), '');
    });
  });

  group('the review file stays compatible', () {
    // A card review as the app wrote it before facets existed.
    const oldFile = '''
{
  "format": "fluenough-review",
  "version": 1,
  "rater_code": "FL-AAAA-AAAA-0",
  "language": "te",
  "deck": "te-core",
  "app_version": "0.11.3",
  "made": "2026-11-01T10:00:00.000Z",
  "signed_off": false,
  "cards": [
    {"card": "te-0001", "at": "2026-11-01T09:00:00.000Z", "looks_right": true},
    {"card": "te-0002", "at": "2026-11-01T09:01:00.000Z",
     "suggestion": {"part": "meaning", "now": "mother", "text": "mum"},
     "items_right": ["synonyms:b"]}
  ]
}
''';

    // The profile's stored form of the same reviews.
    const oldStored = '''
{"te-core": {"language": "te", "cards": {
  "te-0001": {"at": "2026-11-01T09:00:00.000Z", "looks_right": true},
  "te-0002": {"at": "2026-11-01T09:01:00.000Z", "items_right": ["synonyms:b"]},
  "te-0003": "not a card review"
}, "signed_off": "2026-11-01T09:05:00.000Z"}}
''';

    test('stored reviews from before facets parse, with no facets', () {
      final reviews = Reviews.fromJson(oldStored)!;
      final deck = reviews.decks['te-core']!;
      expect(deck.cards.keys, <String>['te-0001', 'te-0002']);
      expect(deck.cards['te-0001']!.right, isTrue);
      expect(deck.cards['te-0001']!.facets, isEmpty);
      expect(deck.cards['te-0001']!.receipts, isEmpty);
      expect(deck.cards['te-0002']!.itemsRight, <String>{'synonyms:b'});
      expect(deck.signedOff, isNotNull);
    });

    test('an old card review writes exactly what it did before', () {
      final json = jsonDecode(oldStored)['te-core']['cards']['te-0001'];
      final back = CardReview.fromJson(json)!;
      expect(back.toJson().containsKey('facets'), isFalse);
      expect(back.toJson().containsKey('receipts'), isFalse);
      expect(back.toJson(), json);
    });

    test('an old review file is still read field by field', () {
      final file = jsonDecode(oldFile) as Map<String, Object?>;
      expect(file['format'], ReviewFile.format);
      final cards = (file['cards']! as List).cast<Map<String, Object?>>();
      final parsed = <String, CardReview?>{
        for (final c in cards)
          c['card']! as String: CardReview.fromJson(
            c,
            cardId: c['card'] as String,
          ),
      };
      expect(parsed['te-0001']!.right, isTrue);
      expect(parsed['te-0002']!.suggestions.single.text, 'mum');
      expect(parsed.values.every((r) => r!.facets.isEmpty), isTrue);
      expect(problems, isEmpty);
    });

    test(
      'facets and receipts are added to a card, and the file carries them',
      () {
        final at = DateTime.utc(2026, 11, 21, 10);
        final review = CardReview(
          at: at,
          right: true,
          facets: <Facet, FacetAnswer>{
            Facet.word: const FacetAnswer.right(),
            Facet.reading: FacetAnswer.flagged(<PointerTag>{
              PointerTag.readingWrong,
            }, replacement: 'ammā'),
          },
          receipts: <ReviewReceipt>[
            ReviewReceipt.of(
              cardId: 'te-0002',
              facet: Facet.reading,
              seen: 'amma',
              decision: ReceiptDecision.flagged,
            ),
          ],
        );
        final deck = DeckReview(
          deckId: 'te-core',
          language: 'te',
          cards: <String, CardReview>{'te-0002': review},
        );
        final text = ReviewFile.encode(
          deck,
          code: RaterCode.generate(Random(1)),
          appVersion: '0.12.0',
          made: at,
        );
        final file = jsonDecode(text) as Map<String, Object?>;
        final card = (file['cards']! as List).single as Map<String, Object?>;
        // The old keys are where they were; the new ones sit beside them.
        expect(card['card'], 'te-0002');
        expect(card['looks_right'], isTrue);
        expect(card['facets'], isA<Map<Object?, Object?>>());
        final back = CardReview.fromJson(card, cardId: 'te-0002')!;
        expect(back.facets, review.facets);
        expect(back.receipts, review.receipts);
      },
    );

    test('facets alone are something to send', () {
      final review = CardReview(
        at: DateTime.utc(2026, 11, 21),
        facets: <Facet, FacetAnswer>{Facet.word: const FacetAnswer.right()},
      );
      expect(review.isEmpty, isFalse);
      expect(review.marked, isFalse, reason: 'old marks are unchanged');
    });

    test('one malformed facet never stops the rest', () {
      final review = CardReview.fromJson(<String, Object?>{
        'at': '2026-11-21T10:00:00Z',
        'facets': <String, Object?>{
          'word': <String, Object?>{'ok': true},
          'bogus': <String, Object?>{'ok': true},
          'reading': 7,
          'meaning': <String, Object?>{
            'tags': <String>['meaning_wrong'],
            'fix': 'mum',
          },
        },
      })!;
      expect(review.facets.keys, <Facet>[Facet.word, Facet.meaning]);
      expect(review.facets[Facet.meaning]!.replacement, 'mum');
      expect(problems.length, 2);
    });

    test('facets that are not an object are reported, and the card stays', () {
      final review = CardReview.fromJson(<String, Object?>{
        'at': '2026-11-21T10:00:00Z',
        'looks_right': true,
        'facets': 'x',
        'receipts': 5,
      })!;
      expect(review.right, isTrue);
      expect(review.facets, isEmpty);
      expect(problems.length, 2);
    });

    test('problems carry no card text', () {
      CardReview.fromJson(<String, Object?>{
        'at': '2026-11-21T10:00:00Z',
        'facets': <String, Object?>{'word': 'SECRET-TEXT'},
      });
      expect(problems.any((p) => p.contains('SECRET-TEXT')), isFalse);
    });

    test('a sink that throws does not stop the read', () {
      ReviewProblems.sink = (_) => throw StateError('log down');
      final review = CardReview.fromJson(<String, Object?>{
        'at': '2026-11-21T10:00:00Z',
        'facets': <String, Object?>{
          'bogus': 1,
          'word': <String, Object?>{'ok': true},
        },
      })!;
      expect(review.facets.keys, <Facet>[Facet.word]);
    });
  });
}
