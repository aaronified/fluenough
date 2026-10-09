import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/lesson.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';

Card card(
  String id,
  String target, {
  String? reading,
  String? pos,
  Set<DrillMode> modes = const {},
}) => Card(
  id: id,
  deckId: 'test',
  target: target,
  native: 'native $id',
  reading: reading,
  pos: pos,
  modes: modes,
);

List<String> ids(List<Card> cards) => <String>[for (final c in cards) c.id];

void main() {
  group('Difficulty', () {
    test('a phrase, three words or a grammar cell is hard', () {
      expect(Difficulty.of(card('a', 'hola', pos: 'phrase')), Difficulty.hard);
      expect(Difficulty.of(card('b', 'me llamo Ana')), Difficulty.hard);
      expect(
        Difficulty.of(card('c', 'voy', modes: {DrillMode.grammar})),
        Difficulty.hard,
      );
    });

    test('two words, or seven letters or more, is medium', () {
      expect(Difficulty.of(card('a', 'buenos días')), Difficulty.medium);
      expect(Difficulty.of(card('b', 'gracias')), Difficulty.medium);
    });

    test('the rest is easy', () {
      expect(Difficulty.of(card('a', 'sí')), Difficulty.easy);
      expect(Difficulty.of(card('b', 'agua')), Difficulty.easy);
    });

    test('letters are counted in the reading where there is one', () {
      // Four letters of script, the signs aside; seven read.
      expect(
        Difficulty.of(card('a', 'नमस्ते', reading: 'namaste')),
        Difficulty.medium,
      );
      expect(Difficulty.of(card('b', 'आप', reading: 'aap')), Difficulty.easy);
    });

    test('a dash or a mark standing alone is not a word', () {
      expect(wordsOf(' uno – dos '), <String>['uno', 'dos']);
      expect(Difficulty.of(card('a', 'uno – dos')), Difficulty.medium);
    });
  });

  group('lessonItems', () {
    final easy = [for (var i = 0; i < 5; i++) card('e$i', 'sí')];
    final medium = [for (var i = 0; i < 5; i++) card('m$i', 'gracias')];
    final hard = [
      for (var i = 0; i < 5; i++) card('h$i', 'hola', pos: 'phrase'),
    ];

    test('takes the first three of each difficulty, easy first', () {
      final mixed = <Card>[
        hard[0],
        medium[0],
        easy[0],
        hard[1],
        easy[1],
        medium[1],
        easy[2],
        easy[3],
        hard[2],
        medium[2],
        hard[3],
        medium[3],
      ];
      expect(ids(lessonItems(mixed)), <String>[
        'e0',
        'e1',
        'e2',
        'm0',
        'm1',
        'm2',
        'h0',
        'h1',
        'h2',
      ]);
    });

    test('a difficulty short of three is made up from the others in order', () {
      final cards = <Card>[easy[0], ...hard, ...medium];
      expect(ids(lessonItems(cards)), <String>[
        'e0',
        'm0',
        'm1',
        'm2',
        'h0',
        'h1',
        'h2',
        'h3',
        'h4',
      ]);
    });

    test('fewer than nine cards are all taken', () {
      expect(ids(lessonItems(<Card>[hard[0], easy[0]])), <String>['e0', 'h0']);
      expect(lessonItems(const <Card>[]), isEmpty);
    });

    test('a card given twice is taken once', () {
      expect(ids(lessonItems(<Card>[easy[0], easy[0], easy[1]])), <String>[
        'e0',
        'e1',
      ]);
    });

    test('each sets the size', () {
      expect(lessonItems([...easy, ...medium, ...hard], each: 1), hasLength(3));
    });
  });

  group('lessonPlan', () {
    final easy = [for (var i = 0; i < 3; i++) card('e$i', 'sí$i')];
    final medium = [for (var i = 0; i < 3; i++) card('m$i', 'gracias$i')];
    final hard = [for (var i = 0; i < 3; i++) card('h$i', 'me llamo Ana$i')];
    final nine = <Card>[...easy, ...medium, ...hard];

    String shape(SessionItem item) => item.ask == Ask.matchPairs
        ? 'match(${item.group.map((g) => g.card.id).join(',')})'
        : '${item.card.id}:${item.mode.name}:${item.ask.name}';

    List<String> plan(
      List<Card> cards, {
      bool voice = true,
      bool speech = true,
      bool choose = true,
    }) => lessonPlan(
      cards,
      modesOf: (c) => c.modesIn(ttsAvailable: voice, speechAvailable: speech),
      canChoose: (_, _) => choose,
    ).map(shape).toList();

    test('teaches and checks each card, then asks each once more in another '
        'skill, mixed, the medium ones matched together', () {
      expect(plan(nine), <String>[
        'e0:recognition:teach',
        'e0:recognition:chooseMeaning',
        'e1:recognition:teach',
        'e1:recognition:chooseMeaning',
        'e2:recognition:teach',
        'e2:recognition:chooseMeaning',
        'm0:listening:teach',
        'm0:listening:hearMeaning',
        'm1:listening:teach',
        'm1:listening:hearMeaning',
        'm2:listening:teach',
        'm2:listening:hearMeaning',
        'h0:production:teach',
        'h0:production:rearrange',
        'h1:production:teach',
        'h1:production:rearrange',
        'h2:production:teach',
        'h2:production:rearrange',
        // The exercise.
        'e0:speaking:own',
        'match(m0,m1,m2)',
        'h0:speaking:own',
        'e1:speaking:own',
        'h1:speaking:own',
        'e2:speaking:own',
        'h2:speaking:own',
      ]);
    });

    test('where the phone cannot hear, words are heard and their meaning chosen instead (ADR-0034)', () {
      final exercise = plan(nine, speech: false).skip(18);
      expect(exercise, contains('e0:listening:hearMeaning'));
      expect(exercise, contains('h0:listening:hearMeaning'));
      expect(exercise, isNot(contains(matches('speaking'))));
    });

    test('without a voice, a medium card is checked by choosing the word', () {
      final items = plan(medium, voice: false, speech: false);
      expect(items, <String>[
        'm0:production:teach',
        'm0:production:chooseWord',
        'm1:production:teach',
        'm1:production:chooseWord',
        'm2:production:teach',
        'm2:production:chooseWord',
        'match(m0,m1,m2)',
      ]);
    });

    test('with too little to choose from, a question is asked its own way', () {
      final items = plan(easy, speech: false, voice: false, choose: false);
      expect(items.take(2), <String>[
        'e0:recognition:teach',
        'e0:recognition:own',
      ]);
      expect(items.last, 'e2:production:own');
    });

    test('one card to match is chosen instead', () {
      expect(plan(<Card>[medium.first]).last, 'm0:recognition:chooseMeaning');
    });

    test('a grammar cell is taught and typed, and has no second question', () {
      final cell = card('g', 'voy', modes: {DrillMode.grammar});
      expect(plan(<Card>[cell]), <String>['g:grammar:teach', 'g:grammar:own']);
    });
  });
}
