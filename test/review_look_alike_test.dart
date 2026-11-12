// Wrong options and the "pick the wrong one" grammar item of a review, made
// by code from the decks' own cards and examples
// (lib/core/scheduling/look_alike_options.dart, wrong_one.dart).
import 'dart:math' as math;

import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/scheduling/look_alike_options.dart';
import 'package:fluenough/core/scheduling/wrong_one.dart';
import 'package:flutter_test/flutter_test.dart';

Card card(
  String id,
  String native, {
  String? pos,
  List<String> tags = const <String>[],
}) => Card(
  id: id,
  deckId: 'zz-en-test',
  target: 'word $id',
  native: native,
  pos: pos,
  tags: tags,
);

String meaning(Card c) => c.native;

void main() {
  group('rankLookAlikes', () {
    final answer = card('zz-1', 'a red apple', pos: 'noun', tags: ['food']);

    test('options in one length band come first, then the word class, the '
        'tags and the nearest spelling', () {
      final nearVerb = card('zz-2', 'a red apron', pos: 'verb');
      final nounTag = card('zz-3', 'a big carrot', pos: 'noun', tags: ['food']);
      final noun = card('zz-4', 'the tall house', pos: 'noun');
      final tooLong = card(
        'zz-5',
        'a very large and heavy wooden table in the hall',
        pos: 'noun',
        tags: ['food'],
      );
      final tooShort = card('zz-6', 'ox', pos: 'noun', tags: ['food']);
      final ranked = rankLookAlikes(answer, <Card>[
        tooLong,
        tooShort,
        noun,
        nearVerb,
        nounTag,
      ], textOf: meaning);
      expect(ranked.take(3).toSet(), <Card>{nearVerb, nounTag, noun});
      // Of the band, the word class and the tags decide before spelling.
      expect(ranked.first, nounTag);
      expect(ranked[1], noun);
      expect(ranked[2], nearVerb);
      // The ones outside the band follow; none is lost.
      expect(ranked.skip(3).toSet(), <Card>{tooLong, tooShort});
    });

    test('the card itself and a card with the same text are never options, '
        'and the rest of the pool is kept', () {
      final twin = card('zz-7', 'A Red Apple');
      final other = card('zz-8', 'a green pear');
      final ranked = rankLookAlikes(answer, <Card>[
        answer,
        twin,
        other,
      ], textOf: meaning);
      expect(ranked, <Card>[other]);
    });

    test('equal cards come in the order the random gives, and the same seed '
        'gives the same order', () {
      final pool = <Card>[
        for (var i = 0; i < 8; i++) card('zz-1$i', 'a blue plum $i'),
      ];
      final a = rankLookAlikes(
        answer,
        pool,
        textOf: meaning,
        random: math.Random(7),
      );
      final b = rankLookAlikes(
        answer,
        pool,
        textOf: meaning,
        random: math.Random(7),
      );
      expect(a, b);
      expect(a.toSet(), pool.toSet());
    });
  });

  group('wrongOneItem', () {
    const right = <String>[
      'Ella canta en casa.',
      'Ellos comen aqui hoy.',
      'Yo bebo agua fria.',
      'Tu lees un libro.',
      'Nosotros vamos a casa.',
    ];

    test('is offered only where a deck gives a wrong example', () {
      const noWrong = WrongOneSource(id: 'r1', right: right);
      expect(offersWrongOne(noWrong), isFalse);
      expect(wrongOneItem(noWrong, const <WrongOneSource>[noWrong]), isNull);
      const blank = WrongOneSource(
        id: 'r2',
        right: right,
        wrong: <String>['  '],
      );
      expect(offersWrongOne(blank), isFalse);
      expect(wrongOneItem(blank, const <WrongOneSource>[blank]), isNull);
    });

    test('lists three right sentences of one band and the deck\'s wrong one, '
        'and exactly one is wrong', () {
      const source = WrongOneSource(
        id: 'r1',
        right: right,
        wrong: <String>['Ella cantan en casa.'],
      );
      final item = wrongOneItem(source, const <WrongOneSource>[
        source,
      ], random: math.Random(3))!;
      expect(item.sentences, hasLength(4));
      expect(item.sentences.toSet(), hasLength(4));
      expect(item.wrong, 'Ella cantan en casa.');
      expect(item.isRight(item.wrongIndex), isTrue);
      expect(
        <int>[
          for (var i = 0; i < 4; i++)
            if (item.isRight(i)) i,
        ],
        <int>[item.wrongIndex],
      );
      for (final s in item.sentences) {
        if (s != item.wrong) expect(right, contains(s));
      }
    });

    test('takes right sentences of other entries when its own are too few, '
        'and none that another entry marks wrong', () {
      const source = WrongOneSource(
        id: 'a',
        right: <String>['Ella canta en casa.'],
        wrong: <String>['Ella cantan en casa.'],
      );
      const other = WrongOneSource(
        id: 'b',
        right: <String>[
          'Yo bebo agua fria.',
          'Tu lees un libro.',
          'Ellos cantan aqui.',
        ],
        wrong: <String>['Ellos cantan aqui.'],
      );
      final item = wrongOneItem(source, const <WrongOneSource>[source, other])!;
      expect(item.sentences, isNot(contains('Ellos cantan aqui.')));
      expect(item.sentences, hasLength(4));
      expect(item.wrong, 'Ella cantan en casa.');
    });

    test('is not made when fewer than three right sentences look like the '
        'wrong one', () {
      const source = WrongOneSource(
        id: 'a',
        right: <String>[
          'Ella canta en casa.',
          'Esta es una frase mucho mas larga que todas las otras de la lista.',
        ],
        wrong: <String>['Ella cantan en casa.'],
      );
      expect(wrongOneItem(source, const <WrongOneSource>[source]), isNull);
    });
  });
}
