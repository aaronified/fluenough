// The picture choice (#91, owner 2026-10-30: "A form of Recognition"): the
// word shown or heard, its picture chosen among four of the deck's. The words
// here are made up; what is checked is which pictures may be offered together
// and when a review asks one.
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/picture_choice.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:flutter_test/flutter_test.dart';

Card word(
  String id, {
  String? picture,
  String? native,
  String? target,
  bool ask = false,
  List<CardItem> synonyms = const <CardItem>[],
  List<CardBase> bases = const <CardBase>[],
  String? pos,
}) => Card(
  id: id,
  deckId: 'zz-en-probe',
  target: target ?? 'tar-$id',
  native: native ?? 'meaning $id',
  picture: picture,
  pictureAsk: ask,
  synonyms: synonyms,
  bases: bases,
  pos: pos,
);

final Set<String> faces = <String>{'🍎', '🐕', '🏠', '🚗', '🌳', '⚽'};

List<Card> deck() => <Card>[
  word('zz-1', picture: '🍎'),
  word('zz-2', picture: '🐕'),
  word('zz-3', picture: '🏠'),
  word('zz-4', picture: '🚗'),
  word('zz-5', picture: '🌳'),
  word('zz-6', picture: '⚽'),
  word('zz-7'),
];

FsrsState reviewed(int times) => FsrsState(
  stability: 6,
  difficulty: 5,
  repetitions: times,
  intervalDays: 6,
  dueAt: DateTime(2026, 9, 28),
  lastReviewAt: DateTime(2026, 9, 22),
);

void main() {
  group('the options', () {
    test('four different pictures, the word\'s own among them, the others '
        'from the deck', () {
      final cards = deck();
      final options = pictureOptions(cards.first, cards, seed: 7)!;
      expect(options, hasLength(4));
      expect(options.where((c) => c.id == 'zz-1'), hasLength(1));
      expect(options.map((c) => c.picture).toSet(), hasLength(4));
      expect(options.every(cards.contains), isTrue);
      // A card with no picture is never offered.
      expect(options.any((c) => c.picture == null), isFalse);
    });

    test('the same seed gives the same options in the same order, another '
        'seed may differ', () {
      final cards = deck();
      List<String> ids(int seed) => <String>[
        for (final c in pictureOptions(cards.first, cards, seed: seed)!) c.id,
      ];
      expect(ids(3), ids(3));
      expect(
        {for (var s = 0; s < 40; s++) ids(s).join(',')}.length,
        greaterThan(1),
      );
    });

    test('never fewer than four pictures: a deck with three cards that have '
        'one, or whose others cannot be told apart, asks none', () {
      final three = deck().take(3).toList();
      expect(canChoosePicture(three.first, three), isFalse);
      expect(pictureOptions(three.first, three), isNull);
      // Four cards, but one is the same picture as the word's own.
      final twins = <Card>[
        word('zz-1', picture: '🍎'),
        word('zz-2', picture: '🍎'),
        word('zz-3', picture: '🏠'),
        word('zz-4', picture: '🚗'),
      ];
      expect(canChoosePicture(twins.first, twins), isFalse);
    });

    test('a near-duplicate emoji (skin tone, variation selector, a joined '
        'sequence) counts as the same picture', () {
      expect(pictureFamily('👍🏽'), pictureFamily('👍'));
      expect(pictureFamily('❤️'), pictureFamily('❤'));
      expect(pictureFamily('🧑‍🍳'), pictureFamily('🧑'));
      expect(pictureFamily('🍎'), isNot(pictureFamily('🍏')));
      final cards = <Card>[
        word('zz-1', picture: '👍'),
        word('zz-2', picture: '👍🏽'),
        word('zz-3', picture: '🏠'),
        word('zz-4', picture: '🚗'),
        word('zz-5', picture: '🌳'),
      ];
      expect(canChoosePicture(cards.first, cards), isTrue);
      for (var seed = 0; seed < 20; seed++) {
        final ids = pictureOptions(
          cards.first,
          cards,
          seed: seed,
        )!.map((c) => c.id);
        expect(ids, isNot(contains('zz-2')));
      }
    });

    test('a card meaning the same is never a wrong option: the same meaning, '
        'a synonym, a word of the family or the same word', () {
      final cards = <Card>[
        word('zz-1', picture: '🍎', native: 'apple'),
        word('zz-2', picture: '🍏', native: 'Apple '),
        word(
          'zz-3',
          picture: '🍐',
          synonyms: const <CardItem>[CardItem(id: 's', ref: 'zz-1')],
        ),
        word(
          'zz-4',
          picture: '🍑',
          bases: const <CardBase>[CardBase(word: 'x', ref: 'zz-1')],
        ),
        word('zz-5', picture: '🍒', target: 'tar-zz-1'),
        word('zz-6', picture: '🏠'),
        word('zz-7', picture: '🚗'),
        word('zz-8', picture: '🌳'),
      ];
      for (var seed = 0; seed < 20; seed++) {
        final ids = pictureOptions(
          cards.first,
          cards,
          seed: seed,
        )!.map((c) => c.id).toSet();
        expect(ids.intersection({'zz-2', 'zz-3', 'zz-4', 'zz-5'}), isEmpty);
      }
    });

    test('two wrong options that mean the same are not offered together', () {
      final cards = <Card>[
        word('zz-1', picture: '🍎'),
        word('zz-2', picture: '🐕', native: 'dog'),
        word('zz-3', picture: '🐶', native: 'dog'),
        word('zz-4', picture: '🏠'),
        word('zz-5', picture: '🚗'),
      ];
      for (var seed = 0; seed < 30; seed++) {
        final ids = pictureOptions(
          cards.first,
          cards,
          seed: seed,
        )!.map((c) => c.id);
        expect(ids.contains('zz-2') && ids.contains('zz-3'), isFalse);
      }
    });

    test('a question word, a rules cell and a card with no emoji have no '
        'choosable picture', () {
      expect(choosablePicture(word('zz-1', picture: '📍', ask: true)), isNull);
      expect(choosablePicture(word('zz-2')), isNull);
      expect(choosablePicture(word('zz-3', picture: '🏠')), '🏠');
    });
  });

  group('when a review asks one', () {
    List<Ask> asked(
      Card card,
      int repetitions, {
      bool canHear = false,
      bool enough = true,
    }) => reviewAsks(
      <SessionItem>[
        SessionItem(
          card: card,
          mode: DrillMode.recognition,
          state: repetitions == 0 ? null : reviewed(repetitions),
        ),
      ],
      canChoose: (item) => !item.ask.choosesPicture || enough,
      canHear: (_) => canHear,
    ).map((i) => i.ask).toList();

    test('only a pair already reviewed, and on every other review: the '
        'rest are asked as before', () {
      final card = word('zz-1', picture: '🍎');
      expect(asked(card, 0), <Ask>[Ask.chooseMeaning]);
      final picks = <bool>[
        for (var r = 1; r <= 6; r++) asked(card, r).single.choosesPicture,
      ];
      expect(picks.where((p) => p), hasLength(3));
      expect(picks.where((p) => !p), hasLength(3));
      // It alternates, so no two in a row.
      for (var i = 1; i < picks.length; i++) {
        expect(picks[i], isNot(picks[i - 1]));
      }
    });

    test('the same pair and count give the same ask every time, and the '
        'ask is a form of Recognition', () {
      final card = word('zz-1', picture: '🍎');
      for (var r = 1; r <= 6; r++) {
        expect(asked(card, r), asked(card, r));
      }
      final items = reviewAsks(<SessionItem>[
        for (var r = 1; r <= 6; r++)
          SessionItem(
            card: word('zz-$r', picture: '🍎'),
            mode: DrillMode.recognition,
            state: reviewed(r),
          ),
      ], canChoose: (_) => true);
      expect(items.every((i) => i.mode == DrillMode.recognition), isTrue);
    });

    test('never for a card without a picture, a question word, or where '
        'the deck has too few pictures', () {
      for (var r = 1; r <= 6; r++) {
        expect(asked(word('zz-1'), r), <Ask>[Ask.chooseMeaning]);
        expect(asked(word('zz-1', picture: '📍', ask: true), r), <Ask>[
          Ask.chooseMeaning,
        ]);
        expect(asked(word('zz-1', picture: '🍎'), r, enough: false), <Ask>[
          Ask.chooseMeaning,
        ]);
      }
    });

    test('the heard form comes only where the word can be played', () {
      final card = word('zz-1', picture: '🍎');
      final shown = <Ask>{for (var r = 1; r <= 8; r++) ...asked(card, r)};
      expect(shown, isNot(contains(Ask.hearPicture)));
      final heard = <Ask>{
        for (var r = 1; r <= 8; r++) ...asked(card, r, canHear: true),
      };
      expect(heard, containsAll(<Ask>[Ask.choosePicture, Ask.hearPicture]));
    });

    test('the options of the ask are pictures: a right answer is the '
        'picture itself', () {
      expect(Ask.choosePicture.chooses, isTrue);
      expect(Ask.hearPicture.choosesMeaning, isFalse);
      final apple = word('zz-1', picture: '🍎');
      expect(Ask.choosePicture.optionOf(apple), '🍎');
      expect(Ask.choosePicture.rightChoiceGrade(DrillMode.recognition), 4);
    });
  });
}
