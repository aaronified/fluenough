import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/core/review/rater_code.dart';
import 'package:fluenough/core/review/review_file.dart';

void main() {
  final monday = DateTime.utc(2026, 10, 12, 9);
  final code = RaterCode.tryParse(
    'FL-7K3M-Q9TD-${RaterCode.checkSymbol('7K3MQ9TD')}',
  )!;

  Reviews marked() => const Reviews()
      .withCard(
        'te-family',
        'te',
        'te-0001',
        monday,
        (_) => CardReview(at: monday, right: true),
      )
      .withCard(
        'te-family',
        'te',
        'te-0384',
        monday,
        (_) => CardReview(
          at: monday,
          suggestions: const <Suggestion>[
            Suggestion(
              part: CardPart.notes,
              now: 'Formally కుమార్తె (kumārte).',
              text: 'In speech also అమ్మాయి (ammāyi).',
              why: 'As common',
            ),
          ],
        ),
      );

  test('a card is marked right or suggested, never both', () {
    final reviews = marked();
    expect(reviews.card('te-family', 'te-0001')!.marked, isTrue);
    expect(reviews.card('te-family', 'te-0384')!.suggestions, isNotEmpty);
    expect(reviews.of('te-family')!.markedCount, 2);
    // Read back, a stored card with both keeps the suggestion.
    final both = CardReview.fromJson(<String, Object?>{
      'at': monday.toIso8601String(),
      'looks_right': true,
      'suggestion': <String, Object?>{'part': 'word', 'now': 'a', 'text': 'b'},
    })!;
    expect(both.right, isFalse);
    expect(both.suggestions.single.text, 'b');
  });

  test('a card keeps one suggestion a part, one written as before and '
      'more in a list, and reads both back (#468)', () {
    const word = Suggestion(part: CardPart.word, now: 'a', text: 'b');
    const ipa = Suggestion(part: CardPart.ipa, now: 'c', text: 'd');
    final one = CardReview(
      at: monday,
      suggestions: const <Suggestion>[word],
    ).toJson();
    expect(one['suggestion'], word.toJson());
    expect(one.containsKey('suggestions'), isFalse);
    final two = CardReview(
      at: monday,
      suggestions: const <Suggestion>[word, ipa],
    ).toJson();
    expect(two.containsKey('suggestion'), isFalse);
    final back = CardReview.fromJson(jsonDecode(jsonEncode(two)))!;
    expect(back.suggestions.map((s) => s.part), <CardPart>[
      CardPart.word,
      CardPart.ipa,
    ]);
    // A part twice keeps the first.
    final twice = CardReview.fromJson(<String, Object?>{
      'at': monday.toIso8601String(),
      'suggestion': word.toJson(),
      'suggestions': <Object?>[ipa.toJson(), word.toJson()],
    })!;
    expect(twice.suggestions.length, 2);
  });

  test('a base suggestion names its word and reads back', () {
    const suggestion = Suggestion(
      part: CardPart.base,
      word: 'रहता',
      now: 'to live; to stay',
      text: 'to live',
      why: 'Stay is ठहरना (ṭhaharnā).',
    );
    final json = suggestion.toJson();
    expect(json['part'], 'base');
    expect(json['word'], 'रहता');
    final back = Suggestion.fromJson(jsonDecode(jsonEncode(json)))!;
    expect(back.part, CardPart.base);
    expect(back.word, 'रहता');
    expect(back.now, 'to live; to stay');
    expect(back.text, 'to live');
    // No other part writes a word, and a base without one is not read.
    expect(
      const Suggestion(part: CardPart.meaning, now: 'a', text: 'b').toJson(),
      isNot(contains('word')),
    );
    expect(
      Suggestion.fromJson(<String, Object?>{
        'part': 'base',
        'now': 'a',
        'text': 'b',
      }),
      isNull,
    );
    expect(
      Suggestion.fromJson(<String, Object?>{
        'part': 'meaning',
        'word': 'x',
        'now': 'a',
        'text': 'b',
      })!.word,
      isNull,
    );
  });

  test('a base added, changed or removed (#476) reads back with its forms, '
      'and one missing its form is not read', () {
    const was = BaseForm(base: 'शुभ', reading: 'śubh', meaning: 'good');
    final suggestions = <Suggestion>[
      const Suggestion(
        part: CardPart.base,
        word: 'आया',
        action: BaseAction.edit,
        was: BaseForm(base: 'आना', reading: 'ānā', meaning: 'to come'),
        base: BaseForm(base: 'आना', reading: 'ānā', meaning: 'to arrive'),
        now: 'आना (ānā) · to come',
        text: 'आना (ānā) · to arrive',
        why: 'Also arrive.',
      ),
      const Suggestion(
        part: CardPart.base,
        word: 'সকাল',
        action: BaseAction.add,
        base: BaseForm(ref: 'bn-0318'),
        now: '',
        text: 'সকাল',
      ),
      const Suggestion(
        part: CardPart.base,
        word: 'पाल',
        action: BaseAction.add,
        base: BaseForm(base: 'पाल', reading: 'pāl', link: false),
        now: '',
        text: 'पाल',
      ),
      const Suggestion(
        part: CardPart.base,
        word: 'शुभ',
        action: BaseAction.remove,
        was: was,
        now: 'शुभ',
        text: '',
      ),
      const Suggestion(part: CardPart.alt, now: '', text: 'शुभ सकाल!'),
    ];
    final json = jsonDecode(
      jsonEncode(<Object?>[for (final s in suggestions) s.toJson()]),
    ) as List<Object?>;
    expect(json[0], <String, Object?>{
      'part': 'base',
      'word': 'आया',
      'action': 'edit',
      'was': <String, Object?>{
        'base': 'आना',
        'reading': 'ānā',
        'meaning': 'to come',
      },
      'base': <String, Object?>{
        'base': 'आना',
        'reading': 'ānā',
        'meaning': 'to arrive',
      },
      'now': 'आना (ānā) · to come',
      'text': 'आना (ānā) · to arrive',
      'why': 'Also arrive.',
    });
    expect((json[1]! as Map)['base'], <String, Object?>{'ref': 'bn-0318'});
    expect((json[2]! as Map)['base'], <String, Object?>{
      'base': 'पाल',
      'reading': 'pāl',
      'link': false,
    });
    final back = json.map(Suggestion.fromJson).toList();
    for (final (i, s) in suggestions.indexed) {
      expect(back[i]!.part, s.part);
      expect(back[i]!.action, s.action);
      expect(back[i]!.was, s.was);
      expect(back[i]!.base, s.base);
      expect(back[i]!.text, s.text);
    }
    // An add without its base, or a removal without the base it removes,
    // is not one.
    expect(
      Suggestion.fromJson(<String, Object?>{
        'part': 'base',
        'word': 'x',
        'action': 'add',
        'now': '',
        'text': 'x',
      }),
      isNull,
    );
    expect(
      Suggestion.fromJson(<String, Object?>{
        'part': 'base',
        'word': 'x',
        'action': 'remove',
        'now': 'x',
        'text': '',
      }),
      isNull,
    );
  });

  test('a change that leaves nothing removes the card', () {
    final reviews = marked().withCard(
      'te-family',
      'te',
      'te-0001',
      monday,
      (_) => CardReview(at: monday),
    );
    expect(reviews.card('te-family', 'te-0001'), isNull);
  });

  test('a change after a sign-off takes the sign-off back', () {
    var reviews = marked().signOff('te-family', 'te', monday);
    expect(reviews.of('te-family')!.signedOff, monday);
    reviews = reviews.withCard(
      'te-family',
      'te',
      'te-0001',
      monday,
      (old) => CardReview(at: monday, right: true),
    );
    expect(reviews.of('te-family')!.signedOff, isNull);
  });

  test('sent reviews stay, but only later changes are unsent', () {
    final later = monday.add(const Duration(hours: 1));
    var reviews = marked().sentAt(<String>['te-family'], monday);
    expect(reviews.unsent, isEmpty);
    expect(reviews.of('te-family')!.markedCount, 2);
    reviews = reviews.withCard(
      'te-family',
      'te',
      'te-0002',
      later,
      (_) => CardReview(at: later, right: true),
    );
    expect(reviews.unsent.single.unsentCards.keys, <String>['te-0002']);
    reviews = reviews.signOff('te-family', 'te', later);
    expect(reviews.unsent.single.unsentSignOff, isTrue);
  });

  test('the last send can be taken back once, for a mail that never went: '
      'its decks wait again, as they did before it', () {
    final later = monday.add(const Duration(hours: 1));
    final latest = monday.add(const Duration(hours: 2));
    expect(marked().lastSend, isEmpty);
    // A first mail, then a second with the family deck again and another.
    var reviews = marked().sentAt(<String>['te-family'], monday);
    reviews = reviews
        .withCard(
          'te-family',
          'te',
          'te-0002',
          later,
          (_) => CardReview(at: later, right: true),
        )
        .withCard(
          'te-rude',
          'te',
          'te-0900',
          later,
          (_) => CardReview(at: later, rating: const WordRating(score: 3)),
        )
        .sentAt(<String>['te-family', 'te-rude'], latest);
    expect(reviews.unsent, isEmpty);
    expect(reviews.lastSend.map((d) => d.deckId), <String>[
      'te-family',
      'te-rude',
    ]);
    // Stored and read back, it can still be taken back.
    reviews = Reviews.fromJson(reviews.toJson())!;
    expect(reviews.lastSend, hasLength(2));

    reviews = reviews.unsend(reviews.lastSend.map((d) => d.deckId));
    // What the second mail carried waits again; the first mail's stays sent.
    expect(reviews.of('te-family')!.sent, monday);
    expect(reviews.of('te-rude')!.sent, isNull);
    expect(reviews.unsent.map((d) => d.deckId), <String>[
      'te-family',
      'te-rude',
    ]);
    expect(reviews.of('te-family')!.unsentCards.keys, <String>['te-0002']);
    // Once only: nothing more can be taken back, and taking the second
    // mail back again changes nothing.
    expect(reviews.lastSend, isEmpty);
    final again = reviews.unsend(<String>['te-family', 'te-rude']);
    expect(again.toJson(), reviews.toJson());
  });

  test('stored and read back whole', () {
    final reviews = marked()
        .withCard(
          'te-rude',
          'te',
          'te-0900',
          monday,
          (_) => CardReview(
            at: monday,
            rating: const WordRating(
              score: 4,
              region: 'coastal-andhra',
              friendly: Friendly.yes,
            ),
          ),
        )
        .withCard(
          'te-family',
          'te',
          'te-0450',
          monday,
          (_) => CardReview(
            at: monday,
            alike: const AlikeCheck(
              partner: 'te-0900',
              kind: AlikeKind.sound,
              real: true,
              care: 'Keep the short i at the start.',
            ),
          ),
        )
        .signOff('te-rude', 'te', monday);
    final back = Reviews.fromJson(reviews.toJson())!;
    expect(back.toJson(), reviews.toJson());
    expect(back.card('te-rude', 'te-0900')!.rating!.score, 4);
    expect(back.card('te-family', 'te-0450')!.alike!.care, startsWith('Keep'));
    expect(back.of('te-rude')!.signedOff, monday);
  });

  test('a broken store reads as nothing, a broken card is left out', () {
    expect(Reviews.fromJson('not json'), isNull);
    expect(Reviews.fromJson('[]'), isNull);
    final back = Reviews.fromJson(
      jsonEncode(<String, Object?>{
        'te-family': <String, Object?>{
          'language': 'te',
          'cards': <String, Object?>{
            'te-0001': <String, Object?>{
              'at': monday.toIso8601String(),
              'looks_right': true,
            },
            'te-0002': <String, Object?>{'at': 'never'},
          },
        },
      }),
    )!;
    expect(back.of('te-family')!.cards.keys, <String>['te-0001']);
  });

  test('a rating is 1 to 9', () {
    expect(WordRating.fromJson(<String, Object?>{'score': 0}), isNull);
    expect(WordRating.fromJson(<String, Object?>{'score': 10}), isNull);
    expect(WordRating.fromJson(<String, Object?>{'score': 9})!.score, 9);
  });

  test('the file carries code, language, deck, app version and time, and '
      'the unsent cards in deck order', () {
    final deck = marked().of('te-family')!;
    final text = ReviewFile.encode(
      deck,
      code: code,
      appVersion: '0.3.4',
      made: monday,
      order: <String>['te-0384', 'te-0001'],
    );
    final json = jsonDecode(text) as Map<String, Object?>;
    expect(json['format'], 'fluenough-review');
    expect(json['version'], 1);
    expect(json['rater_code'], '$code');
    expect(json['language'], 'te');
    expect(json['deck'], 'te-family');
    expect(json['app_version'], '0.3.4');
    expect(json['made'], '2026-10-12T09:00:00.000Z');
    expect(json['signed_off'], isFalse);
    final cards = json['cards']! as List<Object?>;
    expect(
      <Object?>[for (final c in cards) (c! as Map)['card']],
      <String>['te-0384', 'te-0001'],
    );
    expect((cards.last! as Map)['looks_right'], isTrue);
    expect(ReviewFile.name('te-family'), 'fluenough-review-te-family.json');
  });

  test('the subject has the code and every language once', () {
    final reviews = marked().withCard(
      'bn-family',
      'bn',
      'bn-0001',
      monday,
      (_) => CardReview(at: monday, right: true),
    );
    expect(
      ReviewMail.subject(code, reviews.decks.values),
      '[Fluenough review] $code (te, bn)',
    );
  });

  test('answers to proposals are kept, read back and sent (ADR-0038)', () {
    const accept = ProposalAnswer(
      id: '3f9c0a1b2d',
      verdict: ProposalVerdict.accept,
      field: 'native',
      text: 'mum',
    );
    const reject = ProposalAnswer(
      id: '0123456789',
      verdict: ProposalVerdict.reject,
      field: 'target',
      text: 'అమ్మా',
    );
    final reviews = const Reviews().withCard(
      'te-family',
      'te',
      'te-0001',
      monday,
      (_) => CardReview(
        at: monday,
        answers: const <String, ProposalAnswer>{
          '3f9c0a1b2d': accept,
          '0123456789': reject,
        },
      ),
    );
    final card = reviews.card('te-family', 'te-0001')!;
    // An answer alone is something to send.
    expect(card.isEmpty, isFalse);
    expect(card.marked, isFalse);
    final back = Reviews.fromJson(reviews.toJson())!;
    final answers = back.card('te-family', 'te-0001')!.answers;
    expect(answers.keys, <String>['3f9c0a1b2d', '0123456789']);
    expect(answers['3f9c0a1b2d']!.verdict, ProposalVerdict.accept);
    expect(answers['0123456789']!.text, 'అమ్మా');

    final file = jsonDecode(
      ReviewFile.encode(
        reviews.of('te-family')!,
        code: code,
        appVersion: '0.4.0',
        made: monday,
      ),
    ) as Map<String, Object?>;
    final sent = (file['cards']! as List).single as Map<String, Object?>;
    expect(sent['proposals'], <Object?>[
      <String, Object?>{
        'id': '3f9c0a1b2d',
        'answer': 'accept',
        'field': 'native',
        'text': 'mum',
      },
      <String, Object?>{
        'id': '0123456789',
        'answer': 'reject',
        'field': 'target',
        'text': 'అమ్మా',
      },
    ]);
    // One that cannot be read is left out.
    final odd = CardReview.fromJson(<String, Object?>{
      'at': monday.toIso8601String(),
      'proposals': <Object?>[
        <String, Object?>{
          'id': 'x',
          'answer': 'maybe',
          'field': 'f',
          'text': 't',
        },
        accept.toJson(),
      ],
    })!;
    expect(odd.answers.keys, <String>['3f9c0a1b2d']);
  });
}
