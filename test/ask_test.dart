import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';

Card card(String id, {String? target, String? native, String? pos}) => Card(
  id: id,
  deckId: 'test',
  target: target ?? 'target $id',
  native: native ?? 'native $id',
  pos: pos,
);

SessionItem item(Card card, DrillMode mode) =>
    SessionItem(card: card, mode: mode, state: null);

List<SessionItem> recognising(int count) => <SessionItem>[
  for (var i = 0; i < count; i++) item(card('r$i'), DrillMode.recognition),
];

String shape(SessionItem item) => item.ask == Ask.matchPairs
    ? 'match(${item.group.map((g) => g.card.id).join(',')})'
    : '${item.card.id}:${item.ask.name}';

List<String> asked(
  List<SessionItem> items, {
  bool Function(SessionItem item)? canChoose,
}) =>
    reviewAsks(items, canChoose: canChoose ?? (_) => true).map(shape).toList();

void main() {
  group('reviewAsks', () {
    test('recognition in fours: match pairs, then multiple choice', () {
      expect(asked(recognising(10)), <String>[
        'match(r0,r1,r2,r3)',
        'r4:chooseMeaning',
        'r5:chooseMeaning',
        'r6:chooseMeaning',
        'r7:chooseMeaning',
        'r8:chooseMeaning',
        'r9:chooseMeaning',
      ]);
    });

    test('a match takes the place of its first, and keeps the order of '
        'the rest', () {
      final items = <SessionItem>[
        item(card('p0'), DrillMode.production),
        ...recognising(2),
        item(card('l0'), DrillMode.listening),
        ...recognising(4).skip(2),
      ];
      // A new listening pair is Hear's choice of meaning (ADR-0034), not part
      // of the match.
      expect(asked(items), <String>[
        'p0:own',
        'match(r0,r1,r2,r3)',
        'l0:hearMeaning',
      ]);
    });

    test('four that share a meaning are chosen, not matched', () {
      final items = <SessionItem>[
        for (var i = 0; i < 4; i++)
          item(
            card('r$i', native: i < 2 ? 'same' : null),
            DrillMode.recognition,
          ),
      ];
      expect(asked(items), everyElement(endsWith(':chooseMeaning')));
    });

    test('with too little to choose from, recognition is rated', () {
      expect(
        asked(recognising(5), canChoose: (_) => false),
        everyElement(endsWith(':own')),
      );
    });

    test('a sentence of three words, or a phrase of two, is rearranged', () {
      final items = <SessionItem>[
        item(card('s', target: 'yo soy Ana'), DrillMode.production),
        item(
          card('p', target: 'muy bien', pos: 'phrase'),
          DrillMode.production,
        ),
        item(card('w', target: 'buenos días'), DrillMode.production),
        item(card('l', target: 'yo soy Ana'), DrillMode.listening),
      ];
      expect(asked(items), <String>[
        's:rearrange',
        'p:rearrange',
        'w:own',
        // Hearing a sentence is never rearranged: it asks the meaning.
        'l:hearMeaning',
      ]);
    });
  });

  group('Hear (ADR-0034)', () {
    final now = DateTime(2026, 10, 8, 9);
    SessionItem heard(String id, {FsrsState? state}) =>
        SessionItem(card: card(id), mode: DrillMode.listening, state: state);
    final remembered = Fsrs.next(null, 4, now: now);
    final missed = Fsrs.next(
      remembered,
      1,
      now: now.add(const Duration(days: 3)),
    );

    test('chooses the meaning while new or last missed, types it once '
        'remembered', () {
      expect(
        asked(<SessionItem>[
          heard('a'),
          heard('b', state: missed),
          heard('c', state: remembered),
        ]),
        <String>['a:hearMeaning', 'b:hearMeaning', 'c:own'],
      );
    });

    test('a new pair starts typed where the learner is strong in Hear', () {
      expect(
        reviewAsks(
          <SessionItem>[heard('a'), heard('b', state: missed)],
          canChoose: (_) => true,
          recallsFirst: (_) => true,
        ).map(shape),
        <String>['a:own', 'b:hearMeaning'],
      );
    });

    test('is typed as heard where the form is what is heard', () {
      expect(
        reviewAsks(
          <SessionItem>[heard('a')],
          canChoose: (_) => true,
          hearsForm: (_) => true,
        ).map(shape),
        <String>['a:own'],
      );
    });

    test('is typed where there is too little to choose from', () {
      expect(
        asked(<SessionItem>[heard('a')], canChoose: (_) => false),
        <String>['a:own'],
      );
    });

    test('options are meanings', () {
      expect(Ask.hearMeaning.chooses, isTrue);
      expect(Ask.hearMeaning.optionOf(card('a')), 'native a');
    });
  });

  group('Card.meanings', () {
    test('the whole meaning, its parts and the alternatives, each once', () {
      const c = Card(
        id: 'x',
        deckId: 'd',
        target: 't',
        native: 'to go, to leave; depart',
        altNative: <String>['go', 'to go'],
      );
      expect(c.meanings, <String>[
        'to go, to leave; depart',
        'to go',
        'to leave',
        'depart',
        'go',
      ]);
    });

    test('does not split inside brackets', () {
      expect(card('x', native: 'eats (he, she)').meanings, <String>[
        'eats (he, she)',
      ]);
      expect(card('y', native: 'pen / quill').meanings, <String>[
        'pen / quill',
        'pen',
        'quill',
      ]);
    });
  });

  group('Card', () {
    test('a phrase of two words or more can be produced, by rearranging', () {
      final two = card('a', target: 'muy bien', pos: 'phrase');
      final one = card('b', target: '¡Hola!', pos: 'phrase');
      expect(two.rearranges, isTrue);
      expect(two.modesIn(ttsAvailable: true), contains(DrillMode.production));
      expect(one.rearranges, isFalse);
      expect(
        one.modesIn(ttsAvailable: true),
        isNot(contains(DrillMode.production)),
      );
    });

    test('wordsOf keeps punctuation with its word', () {
      expect(wordsOf('मैं ठीक हूँ।'), <String>['मैं', 'ठीक', 'हूँ।']);
      expect(wordsOf('¿Cómo estás?'), <String>['¿Cómo', 'estás?']);
    });

    test('tilesOf gives each mark a tile, in lowercase (#347)', () {
      expect(tilesOf('मैं ठीक हूँ।'), <String>['मैं', 'ठीक', 'हूँ', '।']);
      expect(tilesOf('¿Cómo estás?'), <String>['¿', 'cómo', 'estás', '?']);
      expect(tilesOf('Rock-n-roll, no!'), <String>[
        'rock-n-roll',
        ',',
        'no',
        '!',
      ]);
      expect(tilesOf(' uno – dos '), <String>['uno', 'dos']);
    });
  });
}
